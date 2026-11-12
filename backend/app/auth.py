"""Oturum belirteci (JWT) üretme, doğrulama ve "isteği yapan kim?" bağımlılığı.

Tasarım (CLAUDE.md açık kararı için öneri): HS256 imzalı JWT, 7 gün geçerli,
yenileme (refresh) yok. Süre dolunca kullanıcı GitHub ile yeniden giriş yapar.
Belirteçte yalnızca kullanıcı id'si (sub) ve zaman bilgisi bulunur; kişisel veri yok.
"""
from datetime import datetime, timedelta, timezone

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.config import settings
from app.db import SessionLocal
from app.models import User

ALGORITHM = "HS256"
_bearer = HTTPBearer(auto_error=False)  # "Authorization: Bearer <jwt>" başlığını okur


def _secret() -> str:
    if not settings.jwt_secret:
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, "JWT_SECRET ayarlanmamış.")
    return settings.jwt_secret


def create_session_token(user_id: int) -> str:
    now = datetime.now(timezone.utc)
    payload = {"sub": str(user_id), "iat": now, "exp": now + timedelta(days=settings.jwt_ttl_days)}
    return jwt.encode(payload, _secret(), algorithm=ALGORITHM)


def _unauthorized(detail: str) -> HTTPException:
    return HTTPException(
        status.HTTP_401_UNAUTHORIZED, detail, headers={"WWW-Authenticate": "Bearer"}
    )


def current_user(creds: HTTPAuthorizationCredentials | None = Depends(_bearer)) -> User:
    """Uç noktalarda `user: User = Depends(current_user)` ile kullanılır."""
    if creds is None:
        raise _unauthorized("Oturum belirteci gerekli.")
    try:
        payload = jwt.decode(creds.credentials, _secret(), algorithms=[ALGORITHM])
    except jwt.ExpiredSignatureError:
        raise _unauthorized("Oturumun süresi doldu, yeniden giriş yapın.") from None
    except jwt.InvalidTokenError:
        raise _unauthorized("Geçersiz oturum belirteci.") from None

    with SessionLocal() as db:
        user = db.get(User, int(payload["sub"]))
        if user is None:  # kullanıcı verisini silmiş olabilir
            raise _unauthorized("Kullanıcı bulunamadı.")
        db.expunge(user)  # oturum kapansa da nesne okunabilsin
        return user
