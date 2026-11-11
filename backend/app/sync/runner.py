"""Senkron: bir GitHubSource'tan veriyi çekip veritabanına yazar.

Tekrar çalıştırılabilir: kullanıcı ve repolar güncellenir (upsert), commit'ler
(repo_id, oid) benzersizliği sayesinde ikinci kez yazılmaz.
"""
from dataclasses import asdict
from datetime import datetime, timezone

from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from app.db import SessionLocal
from app.models import Commit, Repo, SyncJob, User
from app.sync.source import GitHubSource, Profile, RepoData

COMMIT_BATCH = 500


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _upsert_user(db: Session, profile: Profile) -> int:
    stmt = (
        insert(User)
        .values(github_node_id=profile.node_id, github_login=profile.login)
        .on_conflict_do_update(index_elements=[User.github_node_id], set_={"github_login": profile.login})
        .returning(User.id)
    )
    return db.execute(stmt).scalar_one()


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


def _record_requests(job: SyncJob, source: GitHubSource) -> None:
    log = [asdict(s) for s in source.request_log]
    job.requests = log  # yeni liste atanır ki SQLAlchemy değişikliği fark etsin
    job.request_count = len(log)
    job.total_cost = sum(s["cost"] for s in log)
    job.total_duration_ms = sum(s["duration_ms"] for s in log)


def run_sync(source: GitHubSource) -> int:
    """Senkronu çalıştırır, sync_jobs kaydının id'sini döner."""
    with SessionLocal() as db:
        profile = source.fetch_profile()
        user_id = _upsert_user(db, profile)
        job = SyncJob(user_id=user_id, status="running", started_at=_now())
        db.add(job)
        _record_requests(job, source)
        db.commit()
        job_id = job.id

        try:
            repos = source.fetch_repos(profile)
            job.repos_total = len(repos)
            _record_requests(job, source)
            db.commit()

            for repo in repos:
                repo_id = _upsert_repo(db, user_id, repo)
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
                job.repos_done += 1
                _record_requests(job, source)
                db.commit()  # her repodan sonra: ilerleme ekranı bunu görür

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
    return job_id
