"""Aydınlatma metni ve veri silme testleri."""
import json

import httpx
from sqlalchemy import func, select, text

from app import github_oauth
from app.config import settings
from app.models import SyncJob

TABLES = ["users", "repos", "commits", "sync_jobs", "contribution_days"]


def _rows_of(db, user_id: int) -> dict[str, int]:
    """Her tabloda bu kullanıcıya ait kaç satır kaldı?"""
    q = {
        "users": "SELECT count(*) FROM users WHERE id = :u",
        "repos": "SELECT count(*) FROM repos WHERE user_id = :u",
        "commits": "SELECT count(*) FROM commits c JOIN repos r ON r.id = c.repo_id WHERE r.user_id = :u",
        "sync_jobs": "SELECT count(*) FROM sync_jobs WHERE user_id = :u",
        "contribution_days": "SELECT count(*) FROM contribution_days WHERE user_id = :u",
    }
    return {t: db.scalar(text(q[t]), {"u": user_id}) for t in TABLES}


# --- Aydınlatma metni ------------------------------------------------------------------

def test_privacy_text_is_public(api):
    resp = api.get("/privacy")  # oturum belirteci yok
    assert resp.status_code == 200
    assert "Saklanmayan veriler" in resp.text
    assert "Verilerimi sil" in resp.text


def test_privacy_text_matches_requested_scope(api):
    # Metin "yalnızca read:user" diyor; kod başka bir yetki isterse bu test kırılır.
    assert f'Yalnızca "{settings.github_oauth_scope}"' in api.get("/privacy").text


# --- Veri silme ---------------------------------------------------------------------------

def test_delete_removes_everything_of_user_only(api, db, demo_auth, login_as):
    api.post("/sync", json={}, headers=demo_auth)  # demo: kullanıcı 1
    other = login_as("U_other", "baskasi")
    # Numarası 2 olmayabilir: ON CONFLICT'li upsert'ler de sequence değeri harcar.
    other_id = db.scalar(text("SELECT id FROM users WHERE github_login = 'baskasi'"))
    assert _rows_of(db, 1) == {"users": 1, "repos": 2, "commits": 6, "sync_jobs": 1, "contribution_days": 7}

    resp = api.request("DELETE", "/me", headers=demo_auth)
    assert resp.status_code == 200
    assert resp.json() == {
        "deleted": {"repos": 2, "commits": 6, "contribution_days": 7, "sync_jobs": 1},
        "github_grant_revoked": None,  # istenmedi
    }
    assert _rows_of(db, 1) == dict.fromkeys(TABLES, 0)  # hiçbir kalıntı yok
    assert _rows_of(db, other_id)["users"] == 1  # başkasına dokunulmadı
    assert api.get("/projects", headers=other).status_code == 200


def test_old_session_token_stops_working(api, demo_auth):
    api.request("DELETE", "/me", headers=demo_auth)
    resp = api.get("/metrics/overview", headers=demo_auth)
    assert resp.status_code == 401
    assert "bulunamadı" in resp.json()["detail"]


def test_delete_requires_session(api):
    assert api.request("DELETE", "/me").status_code == 401


def test_cannot_delete_while_sync_running(api, db, demo_auth):
    api.post("/sync", json={}, headers=demo_auth)
    db.add(SyncJob(user_id=1, status="running"))
    db.commit()

    assert api.request("DELETE", "/me", headers=demo_auth).status_code == 409
    assert _rows_of(db, 1)["repos"] == 2  # hiçbir şey silinmedi


def test_delete_with_github_token_revokes_grant(api, demo_auth, monkeypatch):
    seen = []
    monkeypatch.setattr(github_oauth, "revoke_grant", lambda token: seen.append(token) or True)

    resp = api.request("DELETE", "/me", headers=demo_auth, json={"github_token": "gho_x"})
    assert resp.json()["github_grant_revoked"] is True
    assert seen == ["gho_x"]


# --- GitHub iznini kaldırma (sahte GitHub) ------------------------------------------------

def test_revoke_grant_calls_github_correctly():
    seen = {}

    def github(request: httpx.Request) -> httpx.Response:
        seen.update(method=request.method, url=str(request.url),
                    auth=request.headers["Authorization"], body=json.loads(request.content))
        return httpx.Response(204)

    assert github_oauth.revoke_grant("gho_x", httpx.MockTransport(github)) is True
    assert seen["method"] == "DELETE"
    assert seen["url"] == "https://api.github.com/applications/test-client-id/grant"
    assert seen["auth"].startswith("Basic ")  # client_id:client_secret
    assert seen["body"] == {"access_token": "gho_x"}


def test_revoke_grant_failure_returns_false():
    assert github_oauth.revoke_grant("x", httpx.MockTransport(lambda r: httpx.Response(404))) is False

    def boom(request):
        raise httpx.ConnectError("ağ yok")

    assert github_oauth.revoke_grant("x", httpx.MockTransport(boom)) is False


def test_failed_revoke_does_not_block_deletion(api, db, demo_auth, monkeypatch):
    monkeypatch.setattr(github_oauth, "revoke_grant", lambda token: False)
    resp = api.request("DELETE", "/me", headers=demo_auth, json={"github_token": "gho_x"})
    assert resp.status_code == 200
    assert resp.json()["github_grant_revoked"] is False
    assert db.scalar(select(func.count()).select_from(text("users"))) == 0
