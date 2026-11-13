"""Metrik uç noktaları (oturum belirteci gerekir).

GET /metrics/overview  Genel Bakış: KPI, süreklilik, ritim, oturum/yoğunluk
GET /metrics/calendar  Katkı takvimi (ısı haritası için, eksik günler 0)
GET /metrics/anomalies Olağan dışı yoğun günler (robust z / MAD)
GET /metrics/commit-types  Commit türleri dağılımı (kural + model, gerekçeli örnekler)
GET /metrics/change-points Haftalık commit sayısında değişim noktaları (PELT, istatistik)
GET /metrics/catalog   Metrik kataloğu (tanım, birim, yorum, güvenilirlik koşulu)
Hesap mantığı app/metrics içinde (saf fonksiyonlar); burası yalnızca veriyi okur.
"""
from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from sqlalchemy import func, select

from app.auth import current_user
from app.db import SessionLocal
from app.metrics import activity
from app.metrics.activity import CommitPoint
from app.metrics.catalog import CATALOG, CatalogOut
from app.metrics.change_points import ChangePointsOut, build_change_points
from app.metrics.anomaly import AnomaliesOut, build_anomalies
from app.metrics.commit_types import CommitText, CommitTypesOut, build_commit_types
from app.metrics.overview import Overview, build_overview
from app.models import Commit, ContributionDay, Repo, User

router = APIRouter(prefix="/metrics", tags=["metrikler"])


CALENDAR_NOTE = (
    "GitHub katkı takvimi: commit'lerin yanında PR, issue ve kod incelemelerini de sayar; "
    "bu yüzden commit sayılarıyla birebir tutmaz. Günler GitHub'ın verdiği haliyle gösterilir."
)


class CalendarDayOut(BaseModel):
    day: date
    count: int


class CalendarOut(BaseModel):
    days: list[CalendarDayOut]  # eskiden yeniye, eksik günler 0 ile dolu
    total: int
    note: str = CALENDAR_NOTE


@router.get("/calendar", response_model=CalendarOut)
def calendar(
    days: int = Query(default=371, ge=7, le=731), user: User = Depends(current_user)
) -> CalendarOut:
    """Isı haritası için son `days` gün (varsayılan 53 hafta)."""
    today = datetime.now(ZoneInfo(user.timezone or "UTC")).date()
    start = today - timedelta(days=days - 1)
    with SessionLocal() as db:
        stored = dict(
            db.execute(
                select(ContributionDay.day, ContributionDay.count).where(
                    ContributionDay.user_id == user.id, ContributionDay.day >= start
                )
            ).all()
        )
    out = [
        CalendarDayOut(day=d, count=stored.get(d, 0))
        for d in (start + timedelta(days=k) for k in range(days))
    ]
    return CalendarOut(days=out, total=sum(x.count for x in out))


def _load_points(user_id: int) -> list[CommitPoint]:
    """Kullanıcının commit'leri: zaman + değişen satır (bilinmiyorsa None)."""
    with SessionLocal() as db:
        rows = db.execute(
            select(Commit.authored_at, Commit.additions, Commit.deletions)
            .join(Repo)
            .where(Repo.user_id == user_id)
        ).all()
    return [CommitPoint(t, a + d if a is not None and d is not None else None) for t, a, d in rows]


@router.get("/overview", response_model=Overview)
def overview(user: User = Depends(current_user)) -> Overview:
    points = _load_points(user.id)
    with SessionLocal() as db:
        repo_count = db.scalar(select(func.count()).select_from(Repo).where(Repo.user_id == user.id))
    # "Bugün" kullanıcının saat dilimindeki tarihtir (İstanbul'da gece 01:00 ise UTC'de dün).
    today = datetime.now(ZoneInfo(user.timezone or "UTC")).date()
    return build_overview(points, user.timezone, today, repo_count)


@router.get("/commit-types", response_model=CommitTypesOut)
def commit_types(user: User = Depends(current_user)) -> CommitTypesOut:
    """Commit türleri dağılımı ve her türden en yeni örnekler (kural/model gerekçesiyle)."""
    with SessionLocal() as db:
        rows = db.execute(
            select(Commit.message, Commit.authored_at, Repo.name).join(Repo).where(Repo.user_id == user.id)
        ).all()
    return build_commit_types([CommitText(m, t, r) for m, t, r in rows])


@router.get("/anomalies", response_model=AnomaliesOut)
def anomalies(user: User = Depends(current_user)) -> AnomaliesOut:
    """Olağan dışı yoğun günler (robust z / MAD). Isolation Forest yalnızca ölçüm betiğinde."""
    return build_anomalies(_load_points(user.id), user.timezone)


@router.get("/change-points", response_model=ChangePointsOut)
def change_points(user: User = Depends(current_user)) -> ChangePointsOut:
    """Son 52 haftada haftalık commit sayısının kalıcı olarak değiştiği haftalar."""
    times = activity.to_local(_load_points(user.id), user.timezone)
    today = datetime.now(ZoneInfo(user.timezone or "UTC")).date()
    return build_change_points(times, today)


@router.get("/catalog", response_model=CatalogOut)
def catalog(user: User = Depends(current_user)) -> CatalogOut:
    """Metrik kataloğu (kullanıcıya göre değişmez; yine de oturum ister)."""
    return CatalogOut(entries=CATALOG)
