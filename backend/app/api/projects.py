"""Projeler uç noktası (oturum belirteci gerekir).

GET /projects  her repo için sağlık skoru, eksikler, durum, son 12 hafta commit ve öneri; genel özet
Hesap mantığı app/metrics/projects.py içinde (saf fonksiyon).
"""
from collections import defaultdict
from datetime import date, datetime, time, timedelta, timezone
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends
from sqlalchemy import func, select

from app.auth import current_user
from app.db import SessionLocal
from app.metrics.projects import WEEKS, ProjectsOut, RepoFacts, build_projects
from app.models import Commit, Repo, User

router = APIRouter(prefix="/projects", tags=["projeler"])


def weekly_counts(times: list[datetime], tz: ZoneInfo, today: date) -> list[int]:
    """Commit zamanlarını yerel, Pazartesi başlayan son 12 haftaya sayar (eskiden yeniye)."""
    first_monday = today - timedelta(days=today.weekday()) - timedelta(weeks=WEEKS - 1)
    counts = [0] * WEEKS
    for t in times:
        week = (t.astimezone(tz).date() - first_monday).days // 7
        if 0 <= week < WEEKS:
            counts[week] += 1
    return counts


@router.get("", response_model=ProjectsOut)
def projects(user: User = Depends(current_user)) -> ProjectsOut:
    tz = ZoneInfo(user.timezone or "UTC")
    now = datetime.now(timezone.utc)
    today = now.astimezone(tz).date()
    # 12 haftalık pencerenin başı (yerel Pazartesi 00:00); bir gün pay bırakılır, kesin sınır
    # weekly_counts'ta yerel güne göre çizilir.
    since = datetime.combine(today - timedelta(weeks=WEEKS, days=1), time(), tz)
    with SessionLocal() as db:
        # LEFT JOIN: commit'i olmayan repolar da listede kalır (sayı 0).
        rows = db.execute(
            select(Repo, func.count(Commit.id))
            .outerjoin(Commit, Commit.repo_id == Repo.id)
            .where(Repo.user_id == user.id)
            .group_by(Repo.id)
        ).all()
        recent: dict[int, list[datetime]] = defaultdict(list)
        for repo_id, authored_at in db.execute(
            select(Commit.repo_id, Commit.authored_at)
            .join(Repo, Repo.id == Commit.repo_id)
            .where(Repo.user_id == user.id, Commit.authored_at >= since)
        ):
            recent[repo_id].append(authored_at)
        facts = [
            RepoFacts(
                name=r.name, is_owner=r.is_owner, is_fork=r.is_fork, is_private=r.is_private,
                primary_language=r.primary_language, description=r.description,
                has_readme=r.has_readme, license_spdx=r.license_spdx, topics=list(r.topics or []),
                pushed_at=r.pushed_at, commit_count=count, readme_bytes=r.readme_bytes,
                is_archived=r.is_archived, weekly_commits=weekly_counts(recent[r.id], tz, today),
            )
            for r, count in rows
        ]
    return build_projects(facts, now)
