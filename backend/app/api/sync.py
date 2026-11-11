"""Senkron uç noktaları.

POST /sync            senkronu başlatır, iş numarasını hemen döner (202)
GET  /sync/jobs/{id}  işin durumunu ve ilerlemesini döner

Token kuralı (CLAUDE.md): GitHub token'ı yalnızca istek gövdesinde gelir, arka plan
görevi bitene kadar bellekte durur; veritabanına ya da loglara yazılmaz.

Not: Kimlik doğrulama (JWT) 3. aşamada eklenecek; o zamana kadar bu uç noktalar
yalnızca yerel geliştirme içindir.
"""
import logging
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from fastapi import APIRouter, BackgroundTasks, HTTPException, status
from pydantic import BaseModel, Field, field_validator

from app.config import settings
from app.db import SessionLocal
from app.models import SyncJob
from app.sync.demo_client import DemoClient
from app.sync.github_client import GitHubError, LiveGitHubClient
from app.sync.runner import SyncAlreadyRunning, execute_sync, start_sync
from app.sync.source import GitHubSource, Profile

log = logging.getLogger("uvicorn.error")
router = APIRouter(prefix="/sync", tags=["senkron"])

DEMO_FILE = Path(__file__).resolve().parent.parent.parent / "demo" / "demo_user.json"


class SyncRequest(BaseModel):
    github_token: str | None = Field(
        default=None, description="Kullanıcının GitHub token'ı; saklanmaz."
    )
    timezone: str | None = Field(default=None, examples=["Europe/Istanbul"])
    full: bool = False
    demo: bool = Field(default=False, description="Gerçek GitHub yerine sentetik demo kullanıcı")

    @field_validator("timezone")
    @classmethod
    def _valid_timezone(cls, value: str | None) -> str | None:
        if value is None:
            return None
        try:
            ZoneInfo(value)
        except (ZoneInfoNotFoundError, ValueError):
            raise ValueError(f"Geçersiz saat dilimi: {value!r} (ör. 'Europe/Istanbul')") from None
        return value


class SyncStarted(BaseModel):
    job_id: int
    status: str


class SyncJobOut(BaseModel):
    id: int
    status: str
    progress: float | None = Field(description="0-1 arası; repo sayısı henüz bilinmiyorsa null")
    repos_total: int | None
    repos_done: int
    repos_skipped: int
    commits_synced: int
    commits_inserted: int
    calendar_days: int
    request_count: int
    total_cost: int
    total_duration_ms: int
    error: str | None
    created_at: datetime
    started_at: datetime | None
    finished_at: datetime | None


def _source_for(req: SyncRequest) -> GitHubSource:
    if req.demo:
        return DemoClient(DEMO_FILE)
    # Geçici: OAuth gelene kadar istek token'ı yoksa .env'deki GITHUB_TOKEN kullanılır.
    token = req.github_token or settings.github_token
    if not token:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "GitHub token'ı gerekli.")
    return LiveGitHubClient(token)


def _run_in_background(job_id: int, source: GitHubSource, profile: Profile, full: bool) -> None:
    try:
        execute_sync(job_id, source, profile, full)
    except Exception as exc:  # hata zaten sync_jobs'a yazıldı; burada yalnızca logla
        log.warning("Senkron #%s başarısız: %s", job_id, exc)


@router.post("", status_code=status.HTTP_202_ACCEPTED, response_model=SyncStarted)
def start(req: SyncRequest, background: BackgroundTasks) -> SyncStarted:
    source = _source_for(req)
    try:
        job_id, profile = start_sync(source, req.timezone)
    except SyncAlreadyRunning as exc:
        raise HTTPException(
            status.HTTP_409_CONFLICT, {"message": str(exc), "job_id": exc.job_id}
        ) from None
    except GitHubError as exc:
        code = status.HTTP_401_UNAUTHORIZED if "401" in str(exc) else status.HTTP_502_BAD_GATEWAY
        raise HTTPException(code, str(exc)) from None

    # Cevap gönderildikten SONRA aynı süreçte çalışır.
    background.add_task(_run_in_background, job_id, source, profile, req.full)
    return SyncStarted(job_id=job_id, status="pending")


@router.get("/jobs/{job_id}", response_model=SyncJobOut)
def job_status(job_id: int) -> SyncJobOut:
    with SessionLocal() as db:
        job = db.get(SyncJob, job_id)
        if job is None:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Böyle bir senkron işi yok.")
        # Adımlar: her repo + en sonda takvim (+1). Böylece %100 yalnızca iş bitince görünür.
        progress = job.repos_done / (job.repos_total + 1) if job.repos_total is not None else None
        if job.status == "done":
            progress = 1.0
        return SyncJobOut(
            progress=progress,
            **{k: getattr(job, k) for k in SyncJobOut.model_fields if k != "progress"},
        )
