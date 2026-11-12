"""Giriş testleri: kod-token değişimi (PKCE), JWT ve /auth uç noktaları."""
from urllib.parse import parse_qs

import httpx
import jwt
import pytest

from app import github_oauth
from app.api import auth as auth_api
from app.sync.github_client import LiveGitHubClient
from tests.test_github_client import FakeGitHub

VERIFIER = "v" * 43  # PKCE verifier en az 43 karakter


# --- exchange_code: GitHub'ın token uç noktasıyla konuşma ----------------------------

def test_exchange_code_sends_secret_and_verifier():
    seen = {}

    def github(request: httpx.Request) -> httpx.Response:
        seen["url"] = str(request.url)
        seen["accept"] = request.headers["Accept"]
        seen["form"] = {k: v[0] for k, v in parse_qs(request.content.decode()).items()}
        return httpx.Response(200, json={"access_token": "gho_abc", "token_type": "bearer"})

    token = github_oauth.exchange_code("kod", VERIFIER, "devpulse://cb", httpx.MockTransport(github))

    assert token == "gho_abc"
    assert seen["url"] == github_oauth.TOKEN_URL
    assert seen["accept"] == "application/json"
    assert seen["form"] == {
        "client_id": "test-client-id",
        "client_secret": "test-client-secret",  # secret yalnızca backend'den GitHub'a gider
        "code": "kod",
        "code_verifier": VERIFIER,
        "redirect_uri": "devpulse://cb",
    }


def test_exchange_code_error_in_200_body():
    # GitHub hatayı 200 ile ve "error" alanında döner.
    reply = httpx.Response(200, json={"error": "bad_verification_code", "error_description": "geçersiz"})
    with pytest.raises(github_oauth.OAuthError, match="bad_verification_code"):
        github_oauth.exchange_code("eski", VERIFIER, "x", httpx.MockTransport(lambda r: reply))


# --- /auth uç noktaları ------------------------------------------------------------

def test_auth_config_exposes_only_public_values(api):
    body = api.get("/auth/config").json()
    assert body == {
        "client_id": "test-client-id",
        "scope": "read:user",
        "authorize_url": "https://github.com/login/oauth/authorize",
    }
    assert "secret" not in str(body).lower()


@pytest.fixture
def fake_github_login(monkeypatch):
    """Kod-token değişimi 'gho_fake' döner; profil sahte GitHub'dan (U_me / ben) gelir."""
    monkeypatch.setattr(github_oauth, "exchange_code", lambda code, verifier, uri: "gho_fake")
    monkeypatch.setattr(
        auth_api, "LiveGitHubClient",
        lambda token: LiveGitHubClient(token, transport=httpx.MockTransport(FakeGitHub())),
    )


def test_github_login_returns_both_tokens(api, fake_github_login):
    resp = api.post("/auth/github", json={"code": "k", "code_verifier": VERIFIER, "redirect_uri": "x"})
    assert resp.status_code == 200
    body = resp.json()
    assert body["github_token"] == "gho_fake"  # telefona döner, backend saklamaz
    assert body["user"]["login"] == "ben"

    # Oturum belirteci korumalı uç noktaya erişim sağlar (401 değil, 404: iş yok).
    headers = {"Authorization": f"Bearer {body['session_token']}"}
    assert api.get("/sync/jobs/999", headers=headers).status_code == 404


def test_session_token_has_no_personal_data(api, fake_github_login):
    body = api.post("/auth/github", json={"code": "k", "code_verifier": VERIFIER, "redirect_uri": "x"}).json()
    payload = jwt.decode(body["session_token"], options={"verify_signature": False})
    assert set(payload) == {"sub", "iat", "exp"}  # login, e-posta vb. yok


def test_failed_code_exchange_returns_400(api, monkeypatch):
    def fail(code, verifier, uri):
        raise github_oauth.OAuthError("bad_verification_code")

    monkeypatch.setattr(github_oauth, "exchange_code", fail)
    resp = api.post("/auth/github", json={"code": "k", "code_verifier": VERIFIER, "redirect_uri": "x"})
    assert resp.status_code == 400
    assert "bad_verification_code" in resp.json()["detail"]


def test_short_pkce_verifier_is_rejected(api):
    resp = api.post("/auth/github", json={"code": "k", "code_verifier": "kisa", "redirect_uri": "x"})
    assert resp.status_code == 422


def test_demo_login(api):
    body = api.post("/auth/demo").json()
    assert body["user"]["login"] == "demo-gelistirici"
    assert body["github_token"] is None
