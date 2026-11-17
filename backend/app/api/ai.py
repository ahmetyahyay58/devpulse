"""AI katmanı uç noktaları (docs/ai_katmani.md; oturum belirteci gerekir).

GET  /ai/status   onay durumu, LLM hazır mı, hazır soru listesi
POST /ai/consent  onay ver / geri al
GET  /ai/facts    LLM'e giden sayılar (uygulamadaki "LLM'e giden veri" ekranı)
POST /ai/ask      hazır bir sorunun cevabı: onay + anahtar varsa Gemini, yoksa ya da hata olursa şablon
POST /ai/interview mülakat koçu: seçilen proje için 3 soru (Gemini ya da şablon) + kanıt önerileri
"""
import json
import logging
from datetime import datetime, timezone
from typing import Literal
from zoneinfo import ZoneInfo

import httpx
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from sqlalchemy import select

from app.ai import gemini
from app.ai.facts import Context, build_facts
from app.ai.interview import (SYSTEM_INTERVIEW, ProjectFacts, evidence, interview_facts, parse_questions,
                              template_questions)
from app.ai.questions import BY_ID, QUESTIONS
from app.api import metrics
from app.api.projects import load_projects
from app.auth import current_user
from app.config import settings
from app.db import SessionLocal
from app.metrics.commit_types import CommitText, build_commit_types
from app.models import Commit, Repo, User

log = logging.getLogger("uvicorn.error")
router = APIRouter(prefix="/ai", tags=["yapay zekâ"])

# Testler sahte Gemini sunucusu verir (gerçek API'ye gidilmez).
transport: httpx.BaseTransport | None = None

# Önbellek: (kullanıcı, soru, sayılar) -> cevap. Yalnız bellekte; ücretsiz kotayı korur.
_cache: dict[tuple[int, str, str], str] = {}
CACHE_MAX = 1000


class QuestionOut(BaseModel):
    id: str
    kind: str
    text: str


class StatusOut(BaseModel):
    consent: bool
    consent_at: datetime | None
    llm_ready: bool  # sunucuda anahtar tanımlı mı (değilse her cevap şablon)
    provider: str
    model: str
    questions: list[QuestionOut]


class ConsentIn(BaseModel):
    enabled: bool


class FactsOut(BaseModel):
    facts: dict
    note: str = "Yapay zekâya yalnızca bu sayılar gider. Kullanıcı adın, repo adların, commit mesajların ve kodun gitmez."


class AskIn(BaseModel):
    question: str


class AskOut(BaseModel):
    question_id: str
    question: str
    answer: str
    source: Literal["llm", "sablon"]
    reason: str | None  # şablonsa neden (onay yok, anahtar yok, kota doldu...)
    facts: dict


def _status(user: User) -> StatusOut:
    return StatusOut(
        consent=user.ai_consent_at is not None, consent_at=user.ai_consent_at,
        llm_ready=bool(settings.gemini_api_key), provider="Google Gemini", model=settings.gemini_model,
        questions=[QuestionOut(id=q.id, kind=q.kind, text=q.text) for q in QUESTIONS],
    )


@router.get("/status", response_model=StatusOut)
def status(user: User = Depends(current_user)) -> StatusOut:
    return _status(user)


@router.post("/consent", response_model=StatusOut)
def consent(body: ConsentIn, user: User = Depends(current_user)) -> StatusOut:
    with SessionLocal() as db:
        row = db.get(User, user.id)
        row.ai_consent_at = datetime.now(timezone.utc) if body.enabled else None
        db.commit()
        db.refresh(row)
        if not body.enabled:  # onay geri alınınca önbellekteki cevaplar da silinir
            for key in [k for k in _cache if k[0] == user.id]:
                del _cache[key]
        return _status(row)


def _context(user: User) -> Context:
    return Context(
        overview=metrics.overview(user), commit_types=metrics.commit_types(user),
        anomalies=metrics.anomalies(user), projects=load_projects(user),
        technology=metrics.technology(user), year=metrics.achievements(user).year,
    )


@router.get("/facts", response_model=FactsOut)
def facts(user: User = Depends(current_user)) -> FactsOut:
    return FactsOut(facts=build_facts(_context(user)))


def prompt_for(question: str, facts: dict) -> str:
    return f"Soru: {question}\nSayılar (JSON): {json.dumps(facts, ensure_ascii=False, sort_keys=True)}"


@router.post("/ask", response_model=AskOut)
def ask(body: AskIn, user: User = Depends(current_user)) -> AskOut:
    q = BY_ID.get(body.question)
    if q is None:
        raise HTTPException(status_code=404, detail="Böyle bir hazır soru yok.")
    ctx = _context(user)
    data = build_facts(ctx)
    if q.keys is not None:  # yalnızca bu soruyla ilgili sayılar gider (ve "Giden veri"de görünür)
        data = {k: data[k] for k in q.keys}

    def template(reason: str) -> AskOut:
        return AskOut(question_id=q.id, question=q.text, answer=q.template(ctx), source="sablon",
                      reason=reason, facts=data)

    # Önce anahtar: anahtar yoksa kullanıcıya onay hiç sorulmaz, sebep "onay yok" olmamalı.
    if not settings.gemini_api_key:
        return template("Sunucuda yapay zekâ anahtarı tanımlı değil.")
    if user.ai_consent_at is None:
        return template("Yapay zekâ yorumlarına onay vermedin.")

    key = (user.id, q.id, json.dumps(data, sort_keys=True))
    answer = _cache.get(key)
    if answer is None:
        try:
            answer, used = gemini.generate_with_fallback(
                prompt_for(q.text, data), api_key=settings.gemini_api_key,
                models=[settings.gemini_model, settings.gemini_fallback_model or ""], transport=transport,
            )
        except gemini.GeminiError as exc:
            log.warning("Gemini kullanılamadı, şablon gösteriliyor: %s", exc)
            return template("Yapay zekâ şu an cevap veremedi.")
        log.info("Gemini cevabı (%s): soru %s", used, q.id)
        if len(_cache) >= CACHE_MAX:
            _cache.clear()
        _cache[key] = answer
    return AskOut(question_id=q.id, question=q.text, answer=answer, source="llm", reason=None, facts=data)


class InterviewIn(BaseModel):
    project_id: str  # CV taslağındaki kimlik: "proj:<GitHub node id>"


class InterviewOut(BaseModel):
    project_id: str
    questions: list[str]  # tam 3
    evidence: list[str]  # veriden kurallı; LLM'e gitmez
    source: Literal["llm", "sablon"]
    reason: str | None
    facts: dict  # LLM'e giden (ya da gidecek olan) sayılar


def _project_facts(user: User, node_id: str) -> tuple[ProjectFacts, list[CommitText]]:
    """CV ile aynı küme: kendi, fork olmayan, arşivsiz, herkese açık repo. Yoksa 404."""
    with SessionLocal() as db:
        repo = db.scalars(select(Repo).where(
            Repo.user_id == user.id, Repo.github_node_id == node_id,
            Repo.is_owner, ~Repo.is_fork, ~Repo.is_archived, ~Repo.is_private,
        )).first()
        if repo is None:
            raise HTTPException(status_code=404, detail="Bu proje bulunamadı.")
        rows = db.execute(select(Commit.message, Commit.authored_at).where(Commit.repo_id == repo.id)).all()
        name, url_login = repo.name, user.github_login
        language, tools = repo.primary_language, list(repo.tools or [])
        created, pushed = repo.created_at, repo.pushed_at
    tz = ZoneInfo(user.timezone or "UTC")
    health = next((p for p in load_projects(user).projects if p.name == name), None)
    months = None
    if created and pushed:
        months = max(0, (pushed - created).days // 30)
    facts = ProjectFacts(
        name=name, url=f"https://github.com/{url_login}/{name}", language=language,
        tools=[x for x in tools if x != language], commit_count=len(rows),
        active_days=len({at.astimezone(tz).date() for _, at in rows}), months=months,
        score=health.score if health else None,
        missing=[c.label for c in health.checks if c.status == "missing"] if health else [],
    )
    return facts, [CommitText(m, at, name) for m, at in rows]


@router.post("/interview", response_model=InterviewOut)
def interview(body: InterviewIn, user: User = Depends(current_user)) -> InterviewOut:
    node_id = body.project_id.removeprefix("proj:")
    pf, commits = _project_facts(user, node_id)
    types = build_commit_types(commits)
    data = interview_facts(pf, types)
    tips = evidence(pf, types)

    def template(reason: str) -> InterviewOut:
        return InterviewOut(project_id=body.project_id, questions=template_questions(pf, types), evidence=tips,
                            source="sablon", reason=reason, facts=data)

    if not settings.gemini_api_key:
        return template("Sunucuda yapay zekâ anahtarı tanımlı değil.")
    if user.ai_consent_at is None:
        return template("Yapay zekâ yorumlarına onay vermedin.")

    key = (user.id, "interview", json.dumps(data, sort_keys=True))
    answer = _cache.get(key)
    if answer is None:
        try:
            text, used = gemini.generate_with_fallback(
                f"Sayılar (JSON): {json.dumps(data, ensure_ascii=False, sort_keys=True)}",
                api_key=settings.gemini_api_key,
                models=[settings.gemini_model, settings.gemini_fallback_model or ""], transport=transport,
                system=SYSTEM_INTERVIEW, max_chars=800,
            )
        except gemini.GeminiError as exc:
            log.warning("Gemini kullanılamadı, şablon gösteriliyor: %s", exc)
            return template("Yapay zekâ şu an cevap veremedi.")
        if parse_questions(text) is None:
            log.warning("Mülakat sorusu biçimi uymadı (%s), şablon gösteriliyor", used)
            return template("Yapay zekâ cevabı beklenen biçimde değildi.")
        answer = text
        if len(_cache) >= CACHE_MAX:
            _cache.clear()
        _cache[key] = answer
    return InterviewOut(project_id=body.project_id, questions=parse_questions(answer), evidence=tips,
                        source="llm", reason=None, facts=data)
