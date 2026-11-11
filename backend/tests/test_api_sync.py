"""/sync uç noktalarının testleri."""
from datetime import datetime, timedelta, timezone

import httpx
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select, text

from app.api import sync as sync_api
from app.main import app
from app.models import SyncJob, User
from app.sync.github_client import LiveGitHubClient
from tests.test_github_client import FakeGitHub


@pytest.fixture
def api():
    return TestClient(app)


def _use_fake_github(monkeypatch, handler):
    """API'nin oluşturduğu canlı istemci, gerçek GitHub yerine sahte sunucuya gitsin."""
    monkeypatch.setattr(
        sync_api, "LiveGitHubClient",
        lambda token: LiveGitHubClient(token, transport=httpx.MockTransport(handler)),
    )


def test_demo_sync_runs_in_background_and_reports_progress(api, db):
    resp = api.post("/sync", json={"demo": True, "timezone": "Europe/Istanbul"})
    assert resp.status_code == 202
    job_id = resp.json()["job_id"]

    # TestClient arka plan görevini cevaptan hemen sonra çalıştırır; iş bitmiş olmalı.
    job = api.get(f"/sync/jobs/{job_id}").json()
    assert job["status"] == "done"
    assert job["progress"] == 1.0
    assert (job["repos_total"], job["commits_inserted"], job["calendar_days"]) == (2, 6, 7)
    assert db.scalar(select(User.timezone)) == "Europe/Istanbul"


def test_progress_is_below_one_until_done(api, db):
    api.post("/sync", json={"demo": True})
    # Repolar bitmiş ama takvim henüz çekilmemiş bir iş:
    job = SyncJob(user_id=1, status="running", repos_total=4, repos_done=4)
    db.add(job)
    db.commit()
    assert api.get(f"/sync/jobs/{job.id}").json()["progress"] == pytest.approx(0.8)


def test_timezone_is_kept_when_not_sent(api, db):
    api.post("/sync", json={"demo": True, "timezone": "Europe/Istanbul"})
    api.post("/sync", json={"demo": True})
    assert db.scalar(select(User.timezone)) == "Europe/Istanbul"


def test_invalid_timezone_is_rejected(api):
    resp = api.post("/sync", json={"demo": True, "timezone": "Mars/Olympus"})
    assert resp.status_code == 422


def test_missing_token_returns_400(api):
    assert api.post("/sync", json={}).status_code == 400


def test_bad_github_token_returns_401(api, monkeypatch):
    _use_fake_github(monkeypatch, lambda request: httpx.Response(401))
    resp = api.post("/sync", json={"github_token": "yanlis"})
    assert resp.status_code == 401


def test_second_sync_while_running_returns_409(api, db):
    api.post("/sync", json={"demo": True})
    running = SyncJob(user_id=1, status="running")
    db.add(running)
    db.commit()

    resp = api.post("/sync", json={"demo": True})
    assert resp.status_code == 409
    assert resp.json()["detail"]["job_id"] == running.id


def test_stale_running_job_does_not_block(api, db):
    api.post("/sync", json={"demo": True})
    stale = SyncJob(user_id=1, status="running", created_at=datetime.now(timezone.utc) - timedelta(hours=1))
    db.add(stale)
    db.commit()

    assert api.post("/sync", json={"demo": True}).status_code == 202
    db.refresh(stale)
    assert stale.status == "failed"
    assert "Yarıda kaldı" in stale.error


def test_unknown_job_returns_404(api):
    assert api.get("/sync/jobs/999").status_code == 404


def test_github_token_is_never_stored(api, db, monkeypatch):
    secret = "gizli-token-123"
    fake = FakeGitHub()
    _use_fake_github(monkeypatch, fake)

    resp = api.post("/sync", json={"github_token": secret})
    assert api.get(f"/sync/jobs/{resp.json()['job_id']}").json()["status"] == "done"
    assert fake.calls[0]["auth"] == f"bearer {secret}"  # token GitHub'a gitti...

    # ...ama veritabanındaki hiçbir tablonun hiçbir satırında geçmiyor.
    for table in ["users", "repos", "commits", "sync_jobs", "contribution_days"]:
        rows = db.execute(text(f"SELECT t::text FROM {table} t")).scalars().all()
        assert rows, f"{table} boş olmamalı"
        assert not any(secret in row for row in rows), f"token {table} tablosunda!"
