"""CV uç noktası (docs/cv.md; oturum belirteci gerekir).

GET /cv/draft?lang=tr|en  GitHub verisinden kaynaklı CV taslağı. Düzenlemeler telefonda tutulur;
                          sunucu kullanıcının yazdığı metni almaz ve saklamaz.
"""
from fastapi import APIRouter, Depends, Query
from sqlalchemy import select

from app.api import metrics
from app.api.projects import load_projects
from app.auth import current_user
from app.cv.draft import CvDraftOut, CvFacts, CvRepo, Lang, build_draft
from app.db import SessionLocal
from app.models import Repo, User

router = APIRouter(prefix="/cv", tags=["cv"])


def cv_facts(user: User) -> CvFacts:
    ov = metrics.overview(user)
    tech = metrics.technology(user)
    collab = metrics.collaboration(user)
    projects = {p.name: p for p in load_projects(user).projects if p.is_owner and not p.is_fork}
    with SessionLocal() as db:
        # CV başkalarına gösterilen bir belge: yalnızca herkese açık, kendi, fork olmayan, arşivsiz repolar.
        rows = db.scalars(select(Repo).where(
            Repo.user_id == user.id, Repo.is_owner, ~Repo.is_fork, ~Repo.is_archived, ~Repo.is_private,
        )).all()
    repos = []
    for r in rows:
        p = projects.get(r.name)
        repos.append(CvRepo(
            node_id=r.github_node_id, name=r.name, description=r.description, language=r.primary_language,
            tools=list(r.tools or []), commit_count=p.commit_count if p else 0, score=p.score if p else None,
            has_readme=bool(r.has_readme), has_license=bool(r.license_spdx),
        ))
    return CvFacts(
        login=user.github_login, total_commits=ov.kpi.total_commits, active_days=ov.kpi.active_days,
        repo_count=ov.kpi.repos, longest_streak=ov.continuity.longest_streak,
        languages=[l.name for l in tech.languages if l.name != "Diğer"], tools=[t.name for t in tech.tools],
        repos=repos, prs_to_others=collab.others.opened, prs_to_others_merged=collab.others.merged,
        reviews=collab.reviews_total,
    )


@router.get("/draft", response_model=CvDraftOut)
def draft(lang: Lang = Query(default="tr"), user: User = Depends(current_user)) -> CvDraftOut:
    return build_draft(cv_facts(user), lang)
