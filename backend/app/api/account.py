"""Hesap uç noktaları.

GET    /privacy    aydınlatma metni (girişsiz: kullanıcı giriş yapmadan okuyabilmeli)
GET    /me/export  sunucuda saklanan tüm verilerin JSON kopyası (indirme)
DELETE /me         hesabı ve tüm verileri kalıcı olarak siler; istenirse GitHub iznini kaldırır
"""
from datetime import datetime, timezone
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.encoders import jsonable_encoder
from fastapi.responses import JSONResponse, PlainTextResponse
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


def _rows(db, model, where, order_by) -> list[dict]:
    """Bir tablonun satırlarını TÜM sütunlarıyla döner. Sütunlar elle sayılmaz, tablodan
    okunur: ileride eklenen bir sütun da indirilen dosyaya kendiliğinden girer."""
    columns = [c.name for c in model.__table__.columns]
    rows = db.scalars(select(model).where(where).order_by(*order_by))
    return [{name: getattr(row, name) for name in columns} for row in rows]


@router.get("/me/export")
def export_me(user: User = Depends(current_user)) -> JSONResponse:
    """Sunucuda bu kullanıcı hakkında ne varsa: hesap, repolar, commit'ler, takvim, senkronlar."""
    with SessionLocal() as db:
        data = {
            "exported_at": datetime.now(timezone.utc),
            "note": "DevPulse sunucusunda senin hakkında saklanan verilerin tamamı. "
                    "Zamanlar UTC'dir. GitHub token'ın sunucuda saklanmadığı için burada yoktur.",
            "user": _rows(db, User, User.id == user.id, [User.id])[0],
            "repos": _rows(db, Repo, Repo.user_id == user.id, [Repo.id]),
            "commits": _rows(
                db, Commit,
                Commit.repo_id.in_(select(Repo.id).where(Repo.user_id == user.id)),
                [Commit.repo_id, Commit.authored_at],
            ),
            "contribution_days": _rows(
                db, ContributionDay, ContributionDay.user_id == user.id, [ContributionDay.day]
            ),
            "sync_jobs": _rows(db, SyncJob, SyncJob.user_id == user.id, [SyncJob.id]),
        }
    filename = f"devpulse-verilerim-{datetime.now(timezone.utc):%Y-%m-%d}.json"
    return JSONResponse(
        jsonable_encoder(data),  # datetime/date -> ISO metin
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


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
