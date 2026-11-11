"""Senkron testleri: demo istemcisiyle, internetsiz."""
import json
from datetime import datetime, timezone
from pathlib import Path

import pytest
from sqlalchemy import func, select

from app.models import Commit, Repo, SyncJob, User
from app.sync.demo_client import DemoClient
from app.sync.runner import run_sync

DEMO_FILE = Path(__file__).resolve().parent.parent / "demo" / "demo_user.json"


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
    # 1 profil + 1 repo listesi + her repo için 1 commit isteği
    assert [r["kind"] for r in job.requests] == ["profile", "repos", "commits", "commits"]
    assert job.request_count == 4
    assert job.total_cost == 0  # demo istemcisi puan harcamaz


def test_resync_does_not_duplicate(db):
    run_sync(DemoClient(DEMO_FILE))
    second = db.get(SyncJob, run_sync(DemoClient(DEMO_FILE)))

    assert second.commits_synced == 6  # kaynak yine 6 commit verdi
    assert second.commits_inserted == 0  # ama hiçbiri tekrar yazılmadı
    assert _count(db, Commit) == 6
    assert _count(db, Repo) == 2
    assert _count(db, User) == 1


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
