"""Giriş uç noktaları.

GET  /auth/config  telefonun GitHub giriş sayfasını açması için gereken herkese açık bilgiler
POST /auth/github  yetki kodu + PKCE verifier -> GitHub token'ı + oturum belirteci (JWT)
POST /auth/demo    sentetik demo kullanıcı için oturum belirteci (GitHub gerekmez)

GitHub token'ı cevapta telefona döner ve telefonun güvenli deposunda durur;
backend onu hiçbir yere yazmaz.
"""
from typing import Literal

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, Field

from app import github_oauth
from app.auth import create_session_token
from app.config import settings
from app.db import SessionLocal
from app.sync.demo_client import DemoClient, demo_path
from app.sync.github_client import GitHubError, LiveGitHubClient
from app.sync.runner import upsert_user
from app.sync.source import Profile

router = APIRouter(prefix="/auth", tags=["giriş"])


class AuthConfig(BaseModel):
    client_id: str
    scope: str
    authorize_url: str


class GitHubLogin(BaseModel):
    code: str = Field(min_length=1)
    # RFC 7636: verifier 43-128 karakter olmalı.
    code_verifier: str = Field(min_length=43, max_length=128)
    redirect_uri: str


class UserOut(BaseModel):
    id: int
    login: str


class LoginResult(BaseModel):
    session_token: str = Field(description="Backend'e bağlanmak için JWT (Authorization: Bearer)")
    github_token: str | None = Field(description="Telefon güvenli depoda saklar; demo'da null")
    user: UserOut


def _login(profile: Profile, github_token: str | None) -> LoginResult:
    with SessionLocal() as db:
        user_id = upsert_user(db, profile, tz=None)
        db.commit()
    return LoginResult(
        session_token=create_session_token(user_id),
        github_token=github_token,
        user=UserOut(id=user_id, login=profile.login),
    )


@router.get("/config", response_model=AuthConfig)
def config(platform: Literal["web", "android"] = "web") -> AuthConfig:
    """Platforma göre (web / android) OAuth App'in herkese açık client_id'si."""
    app = github_oauth.app_for_platform(platform)
    if app is None:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE,
                            f"GitHub girişi bu platform için yapılandırılmamış ({platform}).")
    return AuthConfig(
        client_id=app.client_id,
        scope=settings.github_oauth_scope,
        authorize_url=github_oauth.AUTHORIZE_URL,
    )


@router.post("/github", response_model=LoginResult)
def github_login(body: GitHubLogin) -> LoginResult:
    try:
        token = github_oauth.exchange_code(body.code, body.code_verifier, body.redirect_uri)
    except github_oauth.OAuthError as exc:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, f"GitHub girişi başarısız: {exc}") from None
    try:
        profile = LiveGitHubClient(token).fetch_profile()
    except GitHubError as exc:
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, str(exc)) from None
    return _login(profile, github_token=token)


@router.post("/demo", response_model=LoginResult)
def demo_login() -> LoginResult:
    return _login(DemoClient(demo_path()).fetch_profile(), github_token=None)
