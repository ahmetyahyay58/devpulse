"""Hesap uç noktaları.

GET    /privacy    aydınlatma metni (girişsiz: kullanıcı giriş yapmadan okuyabilmeli)
GET    /me         hesap özeti: saklanan satır sayıları, veri kapsamı, son etkinlik, 90 gün kuralıyla silinme tarihi
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

from app import github_oauth, retention
from app.auth import current_user
from app.db import SessionLocal
from app.models import Commit, ContributionDay, PullRequest, Repo, ReviewYear, SyncJob, User
from app.sync.runner import STALE_AFTER

router = APIRouter(tags=["hesap"])

PRIVACY_FILE = Path(__file__).resolve().parent.parent / "legal" / "aydinlatma_metni.md"


@router.get("/privacy", response_class=PlainTextResponse)
def privacy() -> str:
    """Tek kaynak: metin güncellenince uygulama da günceli gösterir."""
    return PRIVACY_FILE.read_text(encoding="utf-8")


class ScopeOut(BaseModel):
    """Veri kapsamı (docs/metrikler.md): analizler hangi veriye dayanıyor."""
    first_commit_at: datetime | None
    last_commit_at: datetime | None
    owned_repos: int
    contributed_repos: int  # başkasına ait, katkı verilen
    forks: int  # kendi repolarından fork olanlar
    archived: int  # kendi repolarından arşivlenmiş olanlar


class MeOut(BaseModel):
    login: str
    avatar_url: str | None
    created_at: datetime
    last_synced_at: datetime | None
    last_active_at: datetime
    delete_after: datetime  # bu tarihe kadar giriş/senkron olmazsa veriler otomatik silinir
    retention_days: int
    counts: dict[str, int]  # saklanan satır sayıları
    scope: ScopeOut


def _counts(db, user_id: int) -> dict[str, int]:
    def count(stmt) -> int:
        return db.scalar(select(func.count()).select_from(stmt.subquery()))

    return {
        "repos": count(select(Repo.id).where(Repo.user_id == user_id)),
        "commits": count(select(Commit.id).join(Repo).where(Repo.user_id == user_id)),
        "contribution_days": count(select(ContributionDay.day).where(ContributionDay.user_id == user_id)),
        "sync_jobs": count(select(SyncJob.id).where(SyncJob.user_id == user_id)),
        "pull_requests": count(select(PullRequest.id).where(PullRequest.user_id == user_id)),
        "review_years": count(select(ReviewYear.year).where(ReviewYear.user_id == user_id)),
    }


def _scope(db, user_id: int) -> ScopeOut:
    first, last = db.execute(
        select(func.min(Commit.authored_at), func.max(Commit.authored_at)).join(Repo).where(Repo.user_id == user_id)
    ).one()
    owned, contributed, forks, archived = db.execute(select(
        func.count().filter(Repo.is_owner),
        func.count().filter(~Repo.is_owner),
        func.count().filter(Repo.is_owner, Repo.is_fork),
        func.count().filter(Repo.is_owner, Repo.is_archived),
    ).where(Repo.user_id == user_id)).one()
    return ScopeOut(first_commit_at=first, last_commit_at=last, owned_repos=owned,
                    contributed_repos=contributed, forks=forks, archived=archived)


@router.get("/me", response_model=MeOut)
def me(user: User = Depends(current_user)) -> MeOut:
    """"Verilerim" kartı için: ne kadar veri saklanıyor ve ne zaman otomatik silinir."""
    with SessionLocal() as db:
        counts = _counts(db, user.id)
        scope = _scope(db, user.id)
    return MeOut(
        login=user.github_login, avatar_url=user.avatar_url, created_at=user.created_at, last_synced_at=user.last_synced_at,
        last_active_at=user.last_active_at, delete_after=retention.delete_after(user.last_active_at),
        retention_days=retention.RETENTION.days, counts=counts, scope=scope,
    )


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
            "pull_requests": _rows(db, PullRequest, PullRequest.user_id == user.id, [PullRequest.created_at]),
            "review_years": _rows(db, ReviewYear, ReviewYear.user_id == user.id, [ReviewYear.year]),
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

        deleted = _counts(db, user.id)
        # Tek komut: geri kalanını veritabanındaki ON DELETE CASCADE kuralları siler.
        db.execute(delete(User).where(User.id == user.id))
        db.commit()

    revoked = None
    if body and body.github_token:
        revoked = github_oauth.revoke_grant(body.github_token)
    return DeleteResult(deleted=deleted, github_grant_revoked=revoked)
