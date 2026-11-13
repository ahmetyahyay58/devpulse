"""/sync uç noktalarının testleri (oturum belirteci gerekli)."""
from datetime import datetime, timedelta, timezone

import httpx
import jwt
import pytest
from sqlalchemy import func, select, text

from app.api import sync as sync_api
from app.models import SyncJob, User
from app.sync.github_client import LiveGitHubClient
from tests.test_github_client import FakeGitHub


def _use_fake_github(monkeypatch, handler):
    """API'nin oluşturduğu canlı istemci, gerçek GitHub yerine sahte sunucuya gitsin."""
    monkeypatch.setattr(
        sync_api, "LiveGitHubClient",
        lambda token: LiveGitHubClient(token, transport=httpx.MockTransport(handler)),
    )


# --- Kimlik doğrulama ---------------------------------------------------------

def test_sync_requires_session_token(api):
    assert api.post("/sync", json={}).status_code == 401
    assert api.get("/sync/jobs/1").status_code == 401


def test_invalid_session_token_is_rejected(api):
    headers = {"Authorization": "Bearer bu-bir-jwt-degil"}
    assert api.post("/sync", json={}, headers=headers).status_code == 401


def test_expired_session_token_is_rejected(api, demo_auth):
    past = datetime.now(timezone.utc) - timedelta(days=1)
    expired = jwt.encode({"sub": "1", "exp": past}, "test-jwt-secret-yalnizca-testlerde-kullanilir-32b")
    resp = api.post("/sync", json={}, headers={"Authorization": f"Bearer {expired}"})
    assert resp.status_code == 401
    assert "süresi doldu" in resp.json()["detail"]


def test_token_of_another_account_is_rejected(api, db, login_as, monkeypatch):
    headers = login_as("U_someone_else", "baskasi")
    _use_fake_github(monkeypatch, FakeGitHub())  # token'ın sahibi U_me ("ben")

    resp = api.post("/sync", json={"github_token": "ben-in-tokeni"}, headers=headers)
    assert resp.status_code == 403
    # Kontrol yazmadan önce yapıldı: "ben" kullanıcısı oluşturulmadı.
    assert db.scalar(select(func.count()).select_from(User)) == 1


def test_cannot_see_another_users_job(api, demo_auth, login_as):
    job_id = api.post("/sync", json={}, headers=demo_auth).json()["job_id"]
    other = login_as("U_someone_else", "baskasi")
    assert api.get(f"/sync/jobs/{job_id}", headers=other).status_code == 404
    assert api.get(f"/sync/jobs/{job_id}", headers=demo_auth).status_code == 200


# --- Senkron davranışı ----------------------------------------------------------

def test_demo_sync_runs_in_background_and_reports_progress(api, db, demo_auth):
    resp = api.post("/sync", json={"timezone": "Europe/Istanbul"}, headers=demo_auth)
    assert resp.status_code == 202
    job_id = resp.json()["job_id"]

    # TestClient arka plan görevini cevaptan hemen sonra çalıştırır; iş bitmiş olmalı.
    job = api.get(f"/sync/jobs/{job_id}", headers=demo_auth).json()
    assert job["status"] == "done"
    assert job["progress"] == 1.0
    assert (job["repos_total"], job["commits_inserted"], job["calendar_days"]) == (2, 6, 7)
    assert job["phase"] == "done"
    assert db.scalar(select(User.timezone)) == "Europe/Istanbul"


# --- Dolan takvim (commit günleri) -----------------------------------------------

def test_commit_days_counts_commits_in_window(api, db, demo_auth):
    api.post("/sync", json={}, headers=demo_auth)
    body = api.get("/sync/commit-days?weeks=53", headers=demo_auth).json()
    days = body["days"]
    assert len(days) == 53 * 7  # eksik günler 0 ile dolu
    assert [d["day"] for d in days] == sorted(d["day"] for d in days)  # eskiden yeniye
    # Pencere içindeki commit'ler (demo_small'da 3'ü 2025 Eylül'de, pencere dışında).
    in_window = db.scalar(text("SELECT count(*) FROM commits WHERE authored_at::date >= :d"),
                          {"d": days[0]["day"]})
    assert sum(d["count"] for d in days) == in_window > 0


def test_commit_days_uses_users_timezone(api, db, demo_auth):
    # UTC 22:30 İstanbul'da ertesi gün 01:30'dur: commit ertesi güne sayılmalı.
    api.post("/sync", json={"timezone": "Europe/Istanbul"}, headers=demo_auth)
    db.execute(text("DELETE FROM commits"))
    utc_day = datetime.now(timezone.utc).date() - timedelta(days=3)
    authored = datetime(utc_day.year, utc_day.month, utc_day.day, 22, 30, tzinfo=timezone.utc)
    db.execute(text(
        "INSERT INTO commits (repo_id, oid, authored_at, message, is_coauthored) "
        "SELECT id, 'abc', :t, 'deneme', false FROM repos WHERE user_id = 1 LIMIT 1"), {"t": authored})
    db.commit()

    days = api.get("/sync/commit-days", headers=demo_auth).json()["days"]
    counted = [d["day"] for d in days if d["count"]]
    assert counted == [(utc_day + timedelta(days=1)).isoformat()]


def test_commit_days_requires_session(api):
    assert api.get("/sync/commit-days").status_code == 401


def test_live_sync_with_github_token(api, login_as, monkeypatch):
    headers = login_as("U_me", "ben")
    _use_fake_github(monkeypatch, FakeGitHub())
    job_id = api.post("/sync", json={"github_token": "t"}, headers=headers).json()["job_id"]
    assert api.get(f"/sync/jobs/{job_id}", headers=headers).json()["status"] == "done"


def test_progress_is_below_one_until_done(api, db, demo_auth):
    api.post("/sync", json={}, headers=demo_auth)
    job = SyncJob(user_id=1, status="running", repos_total=4, repos_done=4)  # takvim bekleniyor
    db.add(job)
    db.commit()
    progress = api.get(f"/sync/jobs/{job.id}", headers=demo_auth).json()["progress"]
    assert progress == pytest.approx(0.8)


def test_timezone_is_kept_when_not_sent(api, db, demo_auth):
    api.post("/sync", json={"timezone": "Europe/Istanbul"}, headers=demo_auth)
    api.post("/sync", json={}, headers=demo_auth)
    assert db.scalar(select(User.timezone)) == "Europe/Istanbul"


def test_invalid_timezone_is_rejected(api, demo_auth):
    resp = api.post("/sync", json={"timezone": "Mars/Olympus"}, headers=demo_auth)
    assert resp.status_code == 422


def test_live_user_without_github_token_gets_400(api, login_as):
    assert api.post("/sync", json={}, headers=login_as("U_me", "ben")).status_code == 400


def test_bad_github_token_returns_401(api, login_as, monkeypatch):
    _use_fake_github(monkeypatch, lambda request: httpx.Response(401))
    resp = api.post("/sync", json={"github_token": "yanlis"}, headers=login_as("U_me", "ben"))
    assert resp.status_code == 401


def test_github_rate_limit_returns_429(api, login_as, monkeypatch):
    _use_fake_github(monkeypatch, lambda request: httpx.Response(429, headers={"retry-after": "60"}))
    resp = api.post("/sync", json={"github_token": "t"}, headers=login_as("U_me", "ben"))
    assert resp.status_code == 429
    assert "istek sınırı" in resp.json()["detail"]


def test_second_sync_while_running_returns_409(api, db, demo_auth):
    api.post("/sync", json={}, headers=demo_auth)
    running = SyncJob(user_id=1, status="running")
    db.add(running)
    db.commit()

    resp = api.post("/sync", json={}, headers=demo_auth)
    assert resp.status_code == 409
    assert resp.json()["detail"]["job_id"] == running.id


def test_stale_running_job_does_not_block(api, db, demo_auth):
    api.post("/sync", json={}, headers=demo_auth)
    stale = SyncJob(user_id=1, status="running", created_at=datetime.now(timezone.utc) - timedelta(hours=1))
    db.add(stale)
    db.commit()

    assert api.post("/sync", json={}, headers=demo_auth).status_code == 202
    db.refresh(stale)
    assert stale.status == "failed"
    assert "Yarıda kaldı" in stale.error


def test_latest_job(api, demo_auth, login_as):
    assert api.get("/sync/jobs/latest", headers=demo_auth).status_code == 404  # henüz yok

    api.post("/sync", json={}, headers=demo_auth)
    second = api.post("/sync", json={}, headers=demo_auth).json()["job_id"]
    latest = api.get("/sync/jobs/latest", headers=demo_auth).json()
    assert latest["id"] == second
    assert latest["repos_skipped"] == 2  # ikinci senkronda push yoktu

    # Başka kullanıcı demo kullanıcının işini "en son iş" olarak görmez.
    other = login_as("U_someone_else", "baskasi")
    assert api.get("/sync/jobs/latest", headers=other).status_code == 404


def test_unknown_job_returns_404(api, demo_auth):
    assert api.get("/sync/jobs/999", headers=demo_auth).status_code == 404


def test_github_token_is_never_stored(api, db, login_as, monkeypatch):
    secret = "gizli-token-123"
    fake = FakeGitHub()
    _use_fake_github(monkeypatch, fake)
    headers = login_as("U_me", "ben")

    resp = api.post("/sync", json={"github_token": secret}, headers=headers)
    assert api.get(f"/sync/jobs/{resp.json()['job_id']}", headers=headers).json()["status"] == "done"
    assert fake.calls[0]["auth"] == f"bearer {secret}"  # token GitHub'a gitti...

    # ...ama veritabanındaki hiçbir tablonun hiçbir satırında geçmiyor.
    for table in ["users", "repos", "commits", "sync_jobs", "contribution_days"]:
        rows = db.execute(text(f"SELECT t::text FROM {table} t")).scalars().all()
        assert rows, f"{table} boş olmamalı"
        assert not any(secret in row for row in rows), f"token {table} tablosunda!"
