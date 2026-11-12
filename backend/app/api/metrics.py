"""Metrik uç noktaları (oturum belirteci gerekir).

GET /metrics/overview  Genel Bakış: KPI, süreklilik, ritim, oturum/yoğunluk
Hesap mantığı app/metrics içinde (saf fonksiyonlar); burası yalnızca veriyi okur.
"""
from datetime import datetime
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends
from sqlalchemy import func, select

from app.auth import current_user
from app.db import SessionLocal
from app.metrics.activity import CommitPoint
from app.metrics.overview import Overview, build_overview
from app.models import Commit, Repo, User

router = APIRouter(prefix="/metrics", tags=["metrikler"])


@router.get("/overview", response_model=Overview)
def overview(user: User = Depends(current_user)) -> Overview:
    with SessionLocal() as db:
        rows = db.execute(
            select(Commit.authored_at, Commit.additions, Commit.deletions)
            .join(Repo)
            .where(Repo.user_id == user.id)
        ).all()
        repo_count = db.scalar(select(func.count()).select_from(Repo).where(Repo.user_id == user.id))

    points = [
        CommitPoint(t, a + d if a is not None and d is not None else None) for t, a, d in rows
    ]
    # "Bugün" kullanıcının saat dilimindeki tarihtir (İstanbul'da gece 01:00 ise UTC'de dün).
    today = datetime.now(ZoneInfo(user.timezone or "UTC")).date()
    return build_overview(points, user.timezone, today, repo_count)
