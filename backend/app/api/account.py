"""Hesap uç noktaları.

GET    /privacy  aydınlatma metni (girişsiz: kullanıcı giriş yapmadan okuyabilmeli)
DELETE /me       hesabı ve tüm verileri kalıcı olarak siler; istenirse GitHub iznini kaldırır
"""
from datetime import datetime, timezone
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import PlainTextResponse
from pydantic import BaseModel, Field
from sqlalchemy import delete, func, select

from app import github_oauth
from app.auth import current_user
from app.db import SessionLocal
from app.models import Commit, ContributionDay, Repo, SyncJob, User
from app.sync.runner import STALE_AFTER

router = APIRouter(tags=["hesap"])

PRIVACY_FILE = Path(__file__).resolve().parent.parent / "legal" / "aydinlatma_metni.md"


@router.get("/privacy", response_class=PlainTextResponse)
def privacy() -> str:
    """Tek kaynak: metin güncellenince uygulama da günceli gösterir."""
    return PRIVACY_FILE.read_text(encoding="utf-8")


class DeleteRequest(BaseModel):
    github_token: str | None = Field(
        default=None, description="Verilirse GitHub'daki DevPulse izni de kaldırılır; saklanmaz."
    )


class DeleteResult(BaseModel):
    deleted: dict[str, int]  # silinen satır sayıları (kullanıcıya özet göstermek için)
    github_grant_revoked: bool | None  # None: istenmedi


@router.delete("/me", response_model=DeleteResult)
def delete_me(body: DeleteRequest | None = None, user: User = Depends(current_user)) -> DeleteResult:
    with SessionLocal() as db:
        # Senkron sürerken silinirse arka plan görevi silinmiş kullanıcıya yazmaya çalışır.
        running = db.scalar(
            select(func.count()).select_from(SyncJob).where(
                SyncJob.user_id == user.id,
                SyncJob.status.in_(["pending", "running"]),
                SyncJob.created_at > datetime.now(timezone.utc) - STALE_AFTER,
            )
        )
        if running:
            raise HTTPException(
                status.HTTP_409_CONFLICT, "Senkron sürerken veriler silinemez; bitmesini bekle."
            )

        def count(stmt) -> int:
            return db.scalar(select(func.count()).select_from(stmt.subquery()))

        deleted = {
            "repos": count(select(Repo.id).where(Repo.user_id == user.id)),
            "commits": count(select(Commit.id).join(Repo).where(Repo.user_id == user.id)),
            "contribution_days": count(
                select(ContributionDay.day).where(ContributionDay.user_id == user.id)
            ),
            "sync_jobs": count(select(SyncJob.id).where(SyncJob.user_id == user.id)),
        }
        # Tek komut: geri kalanını veritabanındaki ON DELETE CASCADE kuralları siler.
        db.execute(delete(User).where(User.id == user.id))
        db.commit()

    revoked = None
    if body and body.github_token:
        revoked = github_oauth.revoke_grant(body.github_token)
    return DeleteResult(deleted=deleted, github_grant_revoked=revoked)
