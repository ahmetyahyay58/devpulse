"""Senkron: bir GitHubSource'tan veriyi çekip veritabanına yazar.

Tekrar çalıştırılabilir: kullanıcı ve repolar güncellenir (upsert), commit'ler
(repo_id, oid) benzersizliği sayesinde ikinci kez yazılmaz.
"""
from dataclasses import asdict
from datetime import datetime, timedelta, timezone

from sqlalchemy import select, update
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from app.db import SessionLocal
from app.models import Commit, ContributionDay, Repo, SyncJob, User
from app.sync.source import CalendarDay, GitHubSource, Profile, RepoData

COMMIT_BATCH = 500
# Bu süreden eski "pending/running" iş yarıda kalmış sayılır (ör. sunucu yeniden başladı).
STALE_AFTER = timedelta(minutes=30)


class SyncAlreadyRunning(Exception):
    def __init__(self, job_id: int):
        super().__init__(f"Bu kullanıcı için senkron zaten sürüyor (iş #{job_id}).")
        self.job_id = job_id


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _upsert_user(db: Session, profile: Profile, tz: str | None) -> int:
    values = {"github_node_id": profile.node_id, "github_login": profile.login}
    if tz:  # saat dilimi gönderilmediyse eskisini silme
        values["timezone"] = tz
    stmt = (
        insert(User)
        .values(**values)
        .on_conflict_do_update(
            index_elements=[User.github_node_id],
            set_={k: v for k, v in values.items() if k != "github_node_id"},
        )
        .returning(User.id)
    )
    return db.execute(stmt).scalar_one()


def _check_not_running(db: Session, user_id: int) -> None:
    """Aynı kullanıcı için iki senkron aynı anda çalışmasın."""
    active = db.scalars(
        select(SyncJob).where(SyncJob.user_id == user_id, SyncJob.status.in_(["pending", "running"]))
    ).all()
    for job in active:
        if _now() - job.created_at < STALE_AFTER:
            raise SyncAlreadyRunning(job.id)
        job.status = "failed"
        job.error = "Yarıda kaldı (sunucu yeniden başlatılmış olabilir)."
        job.finished_at = _now()


def _upsert_repo(db: Session, user_id: int, repo: RepoData) -> int:
    values = asdict(repo)
    values["github_node_id"] = values.pop("node_id")
    stmt = insert(Repo).values(user_id=user_id, **values)
    stmt = stmt.on_conflict_do_update(
        index_elements=[Repo.user_id, Repo.github_node_id],
        set_={k: stmt.excluded[k] for k in values if k != "github_node_id"},
    ).returning(Repo.id)
    return db.execute(stmt).scalar_one()


def _insert_commits(db: Session, repo_id: int, batch: list[dict]) -> int:
    """Yeni commit'leri yazar, var olanları atlar. Kaç tanesinin yeni olduğunu döner."""
    stmt = (
        insert(Commit)
        .values([{"repo_id": repo_id, **c} for c in batch])
        .on_conflict_do_nothing(index_elements=[Commit.repo_id, Commit.oid])
        .returning(Commit.id)
    )
    return len(db.execute(stmt).all())


def _upsert_calendar(db: Session, user_id: int, days: list[CalendarDay]) -> int:
    """Takvim günlerini yazar; gün zaten varsa sayıyı günceller (gün içinde artabilir)."""
    if not days:
        return 0
    stmt = insert(ContributionDay).values(
        [{"user_id": user_id, "day": d.day, "count": d.count} for d in days]
    )
    stmt = stmt.on_conflict_do_update(
        index_elements=[ContributionDay.user_id, ContributionDay.day],
        set_={"count": stmt.excluded.count},
    )
    db.execute(stmt)
    return len(days)


def _record_requests(job: SyncJob, source: GitHubSource) -> None:
    log = [asdict(s) for s in source.request_log]
    job.requests = log  # yeni liste atanır ki SQLAlchemy değişikliği fark etsin
    job.request_count = len(log)
    job.total_cost = sum(s["cost"] for s in log)
    job.total_duration_ms = sum(s["duration_ms"] for s in log)


def _sync_repo_commits(
    db: Session, source: GitHubSource, profile: Profile, job: SyncJob, repo_id: int, repo: RepoData
) -> None:
    batch: list[dict] = []
    for commit in source.fetch_commits(repo, profile):
        batch.append(asdict(commit))
        if len(batch) >= COMMIT_BATCH:
            job.commits_inserted += _insert_commits(db, repo_id, batch)
            job.commits_synced += len(batch)
            batch = []
    if batch:
        job.commits_inserted += _insert_commits(db, repo_id, batch)
        job.commits_synced += len(batch)
    # Yalnızca tüm sayfalar başarıyla çekildikten sonra işaretlenir; yarıda kesilirse
    # (hata, rollback) işaret yazılmaz ve repo bir sonraki senkronda yeniden çekilir.
    db.execute(update(Repo).where(Repo.id == repo_id).values(commits_synced_pushed_at=repo.pushed_at))


def start_sync(source: GitHubSource, tz: str | None = None) -> tuple[int, Profile]:
    """Hızlı kısım (tek istek): profili çeker, kullanıcıyı yazar, işi 'pending' açar.

    Aynı kullanıcı için süren bir iş varsa SyncAlreadyRunning fırlatır.
    """
    with SessionLocal() as db:
        profile = source.fetch_profile()
        user_id = _upsert_user(db, profile, tz)
        _check_not_running(db, user_id)
        job = SyncJob(user_id=user_id, status="pending")
        db.add(job)
        _record_requests(job, source)
        db.commit()
        return job.id, profile


def execute_sync(job_id: int, source: GitHubSource, profile: Profile, full: bool = False) -> None:
    """Uzun kısım: repolar, commit'ler, takvim. API'de arka planda çalışır.

    full=False: son senkrondan beri push gelmeyen repoların commit'leri tekrar çekilmez.
    full=True: tüm repoların commit'leri baştan çekilir (yine de çift kayıt oluşmaz).
    """
    with SessionLocal() as db:
        job = db.get(SyncJob, job_id)
        user_id = job.user_id
        job.status = "running"
        job.started_at = _now()
        db.commit()

        try:
            repos = source.fetch_repos(profile)
            job.repos_total = len(repos)
            _record_requests(job, source)
            db.commit()

            for repo in repos:
                # Upsert'ten ÖNCE oku: commit'ler en son hangi push'ta çekilmişti?
                last_synced_push = db.scalar(
                    select(Repo.commits_synced_pushed_at).where(
                        Repo.user_id == user_id, Repo.github_node_id == repo.node_id
                    )
                )
                repo_id = _upsert_repo(db, user_id, repo)

                unchanged = repo.pushed_at is not None and last_synced_push == repo.pushed_at
                if unchanged and not full:
                    job.repos_skipped += 1  # yeni push yok: commit'ler değişmemiştir
                else:
                    _sync_repo_commits(db, source, profile, job, repo_id, repo)
                job.repos_done += 1
                _record_requests(job, source)
                db.commit()  # her repodan sonra: ilerleme ekranı bunu görür

            job.calendar_days = _upsert_calendar(db, user_id, source.fetch_calendar(profile))
            _record_requests(job, source)

            job.status = "done"
            job.finished_at = _now()
            db.get(User, user_id).last_synced_at = job.finished_at
            db.commit()
        except Exception as exc:
            db.rollback()
            job = db.get(SyncJob, job_id)
            job.status = "failed"
            job.error = str(exc)[:1000]
            job.finished_at = _now()
            _record_requests(job, source)
            db.commit()
            raise


def run_sync(source: GitHubSource, full: bool = False, tz: str | None = None) -> int:
    """İki kısmı art arda çalıştırır (komut satırı ve testler). İş id'sini döner."""
    job_id, profile = start_sync(source, tz)
    execute_sync(job_id, source, profile, full)
    return job_id
