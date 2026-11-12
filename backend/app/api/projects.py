"""Projeler uç noktası (oturum belirteci gerekir).

GET /projects  her repo için sağlık skoru, eksikler ve öneriler; genel özet
Hesap mantığı app/metrics/projects.py içinde (saf fonksiyon).
"""
from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from sqlalchemy import func, select

from app.auth import current_user
from app.db import SessionLocal
from app.metrics.projects import ProjectsOut, RepoFacts, build_projects
from app.models import Commit, Repo, User

router = APIRouter(prefix="/projects", tags=["projeler"])


@router.get("", response_model=ProjectsOut)
def projects(user: User = Depends(current_user)) -> ProjectsOut:
    with SessionLocal() as db:
        # LEFT JOIN: commit'i olmayan repolar da listede kalır (sayı 0).
        rows = db.execute(
            select(Repo, func.count(Commit.id))
            .outerjoin(Commit, Commit.repo_id == Repo.id)
            .where(Repo.user_id == user.id)
            .group_by(Repo.id)
        ).all()
        facts = [
            RepoFacts(
                name=r.name, is_owner=r.is_owner, is_fork=r.is_fork, is_private=r.is_private,
                primary_language=r.primary_language, description=r.description,
                has_readme=r.has_readme, license_spdx=r.license_spdx, topics=list(r.topics or []),
                pushed_at=r.pushed_at, commit_count=count,
            )
            for r, count in rows
        ]
    return build_projects(facts, datetime.now(timezone.utc))
