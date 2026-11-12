"""Proje sağlığı ve eksiklik takibi: saf fonksiyon (veritabanı bilgisi yok).

Tanım: docs/metrikler.md "Proje sağlığı". Skor vitrin/belgelendirme eksiksizliğini ölçer;
kod kalitesini ölçmez. Kural tabanlıdır.
"""
from dataclasses import dataclass
from datetime import datetime
from typing import Literal

from pydantic import BaseModel

Status = Literal["ok", "missing", "unknown"]

# (anahtar, etiket, ağırlık, eksikse öneri) — ağırlıklar sezgisel, toplam 100
CHECKS = [
    ("readme", "README", 35,
     "Projenin ne yaptığını ve nasıl kurulup çalıştırılacağını anlatan bir README ekle."),
    ("description", "Açıklama", 25,
     "Repo sayfasındaki 'About' bölümüne tek cümlelik bir açıklama yaz."),
    ("license", "Lisans", 20,
     "Kodunun hangi koşullarda kullanılabileceğini belirten bir LICENSE dosyası ekle (ör. MIT)."),
    ("topics", "Topic", 20,
     "'About' bölümüne birkaç topic ekle (ör. python, fastapi); repo daha kolay bulunur."),
]

HOW = (
    "Her kendi repon için dört kontrol yapılır: README (35), açıklama (25), lisans (20), "
    "topic (20). Skor = geçen kontrollerin ağırlığı / durumu bilinen kontrollerin ağırlığı × 100. "
    "Ağırlıklar sezgiseldir. Skor vitrin ve belgelendirme eksiksizliğini ölçer, kod kalitesini "
    "ölçmez. Fork'lar ve başkasına ait repolar puanlanmaz. README yalnızca dört yaygın dosya "
    "adına bakılarak aranır."
)


@dataclass(frozen=True)
class RepoFacts:
    name: str
    is_owner: bool
    is_fork: bool
    is_private: bool
    primary_language: str | None
    description: str | None
    has_readme: bool | None  # None: bilinmiyor
    license_spdx: str | None  # GitHub tanıyamadığı lisansa "NOASSERTION" der: yine de var
    topics: list[str]
    pushed_at: datetime | None
    commit_count: int


class CheckOut(BaseModel):
    key: str
    label: str
    weight: int
    status: Status
    hint: str | None  # yalnızca eksikse


class ProjectOut(BaseModel):
    name: str
    language: str | None
    is_private: bool
    is_fork: bool
    is_owner: bool
    scored: bool
    not_scored_reason: str | None
    score: int | None
    checks: list[CheckOut]
    days_since_push: int | None
    commit_count: int


class ProjectsSummary(BaseModel):
    scored_count: int
    average_score: int | None
    missing_counts: dict[str, int]  # ör. {"license": 4}: kaç puanlanan repoda eksik
    summary: str
    how: str = HOW


class ProjectsOut(BaseModel):
    summary: ProjectsSummary
    projects: list[ProjectOut]


def _status(repo: RepoFacts, key: str) -> Status:
    match key:
        case "readme":
            return "unknown" if repo.has_readme is None else ("ok" if repo.has_readme else "missing")
        case "description":
            return "ok" if (repo.description or "").strip() else "missing"
        case "license":
            return "ok" if repo.license_spdx else "missing"
        case "topics":
            return "ok" if repo.topics else "missing"
    raise ValueError(key)


def _not_scored_reason(repo: RepoFacts) -> str | None:
    if not repo.is_owner:
        return "Başkasına ait repo (yalnızca katkı yaptın); vitrini senin elinde değil."
    if repo.is_fork:
        return "Fork; README ve lisans asıl repodan gelir."
    return None


def project_health(repo: RepoFacts, now: datetime) -> ProjectOut:
    reason = _not_scored_reason(repo)
    checks = [
        CheckOut(
            key=key, label=label, weight=weight, status=(s := _status(repo, key)),
            hint=hint if s == "missing" else None,
        )
        for key, label, weight, hint in CHECKS
    ]
    known = sum(c.weight for c in checks if c.status != "unknown")
    earned = sum(c.weight for c in checks if c.status == "ok")
    score = round(earned / known * 100) if reason is None and known else None
    return ProjectOut(
        name=repo.name,
        language=repo.primary_language,
        is_private=repo.is_private,
        is_fork=repo.is_fork,
        is_owner=repo.is_owner,
        scored=reason is None,
        not_scored_reason=reason,
        score=score,
        checks=checks,
        days_since_push=(now - repo.pushed_at).days if repo.pushed_at else None,
        commit_count=repo.commit_count,
    )


def build_projects(repos: list[RepoFacts], now: datetime) -> ProjectsOut:
    projects = [project_health(r, now) for r in repos]
    scored = [p for p in projects if p.score is not None]
    missing = {
        key: sum(1 for p in scored for c in p.checks if c.key == key and c.status == "missing")
        for key, *_ in CHECKS
    }
    labels = {key: label for key, label, *_ in CHECKS}

    if not scored:
        summary = "Puanlanacak kendi reponun yok (fork'lar ve katkı yaptığın repolar puanlanmaz)."
        average = None
    else:
        average = round(sum(p.score for p in scored) / len(scored))
        top_key, top_count = max(missing.items(), key=lambda kv: kv[1])
        summary = f"Puanlanan {len(scored)} reponun ortalama skoru {average}/100."
        if top_count:
            summary += f" En sık eksik: {labels[top_key]} ({top_count}/{len(scored)} repoda)."
        else:
            summary += " Hiçbir repoda eksik yok."

    # Önce puanlananlar, en eksikliden başlayarak; sonra puanlanmayanlar.
    projects.sort(key=lambda p: (p.score is None, p.score if p.score is not None else 0, p.name))
    return ProjectsOut(
        summary=ProjectsSummary(
            scored_count=len(scored), average_score=average, missing_counts=missing, summary=summary
        ),
        projects=projects,
    )
