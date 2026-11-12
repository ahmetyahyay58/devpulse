"""Senkron testleri: demo istemcisiyle, internetsiz."""
import json
from datetime import date, datetime, timezone
from pathlib import Path

import pytest
from sqlalchemy import func, select

from app.models import Commit, ContributionDay, Repo, SyncJob, User
from app.sync.demo_client import DemoClient
from app.sync.runner import run_sync

DEMO_FILE = Path(__file__).resolve().parent / "fixtures" / "demo_small.json"


def _count(db, model) -> int:
    return db.scalar(select(func.count()).select_from(model))


def test_demo_sync_writes_repos_and_commits(db):
    job_id = run_sync(DemoClient(DEMO_FILE))

    job = db.get(SyncJob, job_id)
    assert job.status == "done"
    assert (job.repos_total, job.repos_done) == (2, 2)
    assert (job.commits_synced, job.commits_inserted) == (6, 6)
    assert _count(db, Repo) == 2
    assert _count(db, Commit) == 6

    user = db.scalar(select(User))
    assert user.github_login == "demo-gelistirici"
    assert user.last_synced_at is not None


def test_request_log_is_recorded(db):
    job = db.get(SyncJob, run_sync(DemoClient(DEMO_FILE)))
    # 1 profil + 1 repo listesi + her repo için 1 commit isteği + 1 takvim
    assert [r["kind"] for r in job.requests] == ["profile", "repos", "commits", "commits", "calendar"]
    assert job.request_count == 5
    assert job.total_cost == 0  # demo istemcisi puan harcamaz


def test_resync_does_not_duplicate(db):
    run_sync(DemoClient(DEMO_FILE))
    # full=True: atlama kapalı, commit'ler yeniden gelir; ON CONFLICT çift kaydı engellemeli.
    second = db.get(SyncJob, run_sync(DemoClient(DEMO_FILE), full=True))

    assert second.commits_synced == 6  # kaynak yine 6 commit verdi
    assert second.commits_inserted == 0  # ama hiçbiri tekrar yazılmadı
    assert _count(db, Commit) == 6
    assert _count(db, Repo) == 2
    assert _count(db, User) == 1


def _write_demo(tmp_path, change) -> Path:
    """Demo verisinin değiştirilmiş bir kopyasını yazar."""
    data = json.loads(DEMO_FILE.read_text(encoding="utf-8"))
    change(data)
    path = tmp_path / "demo.json"
    path.write_text(json.dumps(data), encoding="utf-8")
    return path


def test_unchanged_repos_are_skipped(db):
    run_sync(DemoClient(DEMO_FILE))
    second = db.get(SyncJob, run_sync(DemoClient(DEMO_FILE)))

    assert second.repos_skipped == 2
    assert second.commits_synced == 0
    assert "commits" not in [r["kind"] for r in second.requests]  # GitHub'a commit sorulmadı


def test_pushed_repo_is_refetched(db, tmp_path):
    run_sync(DemoClient(DEMO_FILE))

    def new_push(data):
        repo = data["repos"][1]
        repo["pushed_at"] = "2026-11-01T10:00:00Z"
        repo["commits"].append({
            "oid": "d000000000000000000000000000000000000007", "authored_at": "2026-11-01T10:00:00Z",
            "message": "yeni not", "additions": 2, "deletions": 0, "changed_files": 1,
            "is_coauthored": False,
        })

    second = db.get(SyncJob, run_sync(DemoClient(_write_demo(tmp_path, new_push))))
    assert second.repos_skipped == 1  # push gelmeyen repo atlandı
    assert (second.commits_synced, second.commits_inserted) == (3, 1)  # yalnız değişen repo
    assert _count(db, Commit) == 7


class FailsOnSecondRepo(DemoClient):
    """İkinci reponun commit'lerini çekerken bağlantı kopar."""

    def fetch_commits(self, repo, profile):
        if repo.node_id == "DEMO_REPO_2":
            raise RuntimeError("bağlantı koptu")
        yield from super().fetch_commits(repo, profile)


def test_interrupted_repo_is_not_skipped_next_time(db):
    with pytest.raises(RuntimeError):
        run_sync(FailsOnSecondRepo(DEMO_FILE))

    retry = db.get(SyncJob, run_sync(DemoClient(DEMO_FILE)))
    # Birinci repo tamamlanmıştı, atlanır; yarıda kalan ikinci repo yeniden çekilir.
    assert retry.repos_skipped == 1
    assert retry.commits_inserted == 2
    assert _count(db, Commit) == 6


def test_resync_updates_repo_metadata(db, tmp_path):
    run_sync(DemoClient(DEMO_FILE))

    data = json.loads(DEMO_FILE.read_text(encoding="utf-8"))
    data["repos"][1]["description"] = "Artık açıklaması var"
    data["repos"][1]["license_spdx"] = "MIT"
    changed = tmp_path / "demo.json"
    changed.write_text(json.dumps(data), encoding="utf-8")
    run_sync(DemoClient(changed))

    repo = db.scalar(select(Repo).where(Repo.name == "notlar"))
    assert repo.description == "Artık açıklaması var"
    assert repo.license_spdx == "MIT"


def test_commit_fields_are_stored_correctly(db):
    run_sync(DemoClient(DEMO_FILE))

    commit = db.scalar(select(Commit).where(Commit.oid.endswith("0002")))
    # GitHub UTC verir; saat dilimiyle birlikte aynen saklanmalı.
    assert commit.authored_at == datetime(2025, 9, 3, 22, 40, tzinfo=timezone.utc)
    assert (commit.additions, commit.deletions, commit.changed_files) == (85, 12, 3)
    assert db.scalar(select(func.count()).where(Commit.is_coauthored)) == 1


def test_calendar_is_stored(db):
    job = db.get(SyncJob, run_sync(DemoClient(DEMO_FILE)))

    assert job.calendar_days == 7
    days = {d.day: d.count for d in db.scalars(select(ContributionDay))}
    assert days[date(2026, 10, 20)] == 2
    # Takvim commit'ten fazlasını sayar: bu günde commit yok ama katkı (ör. PR) var.
    assert days[date(2026, 3, 5)] == 2
    assert db.scalar(
        select(func.count()).where(func.date(Commit.authored_at) == date(2026, 3, 5))
    ) == 0


def test_calendar_resync_updates_counts(db, tmp_path):
    run_sync(DemoClient(DEMO_FILE))

    data = json.loads(DEMO_FILE.read_text(encoding="utf-8"))
    data["calendar"][-1]["count"] = 5  # gün içinde yeni katkılar geldi
    changed = tmp_path / "demo.json"
    changed.write_text(json.dumps(data), encoding="utf-8")
    run_sync(DemoClient(changed))

    assert _count(db, ContributionDay) == 7  # satır sayısı aynı, çift kayıt yok
    assert db.get(ContributionDay, (1, date(2026, 10, 20))).count == 5


class FailingSource(DemoClient):
    """Repo listesini çekerken hata veren kaynak (ör. GitHub 502)."""

    def fetch_repos(self, profile):
        raise RuntimeError("GitHub 502 döndü.")


def test_failed_source_marks_job_failed(db):
    with pytest.raises(RuntimeError):
        run_sync(FailingSource(DEMO_FILE))

    job = db.scalar(select(SyncJob))
    assert job.status == "failed"
    assert "502" in job.error
    assert job.finished_at is not None
    assert job.request_count == 1  # hatadan önceki profil isteği yine kayıtlı
    assert _count(db, Repo) == 0
