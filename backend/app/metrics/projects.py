"""Proje sağlığı ve eksiklik takibi: saf fonksiyon (veritabanı bilgisi yok).

Tanım: docs/metrikler.md "Proje sağlığı". Skor vitrin/belgelendirme eksiksizliğini ölçer;
kod kalitesini ölçmez. Kural tabanlıdır.
"""
from dataclasses import dataclass, field
from datetime import datetime
from typing import Literal

from pydantic import BaseModel

Status = Literal["ok", "missing", "unknown"]
RepoState = Literal["aktif", "durgun", "arsiv"]

README_MIN_BYTES = 300  # bundan kısa README "içerik" kontrolünü geçmez (sezgisel)
ACTIVE_DAYS = 90  # son push bu kadar gün içindeyse "Aktif"
WEEKS = 12  # proje detayındaki haftalık commit çubukları

# (anahtar, etiket, ağırlık, eksikse öneri) — ağırlıklar sezgisel, toplam 100
CHECKS = [
    ("readme", "README", 30,
     "Projenin ne yaptığını ve nasıl kurulup çalıştırılacağını anlatan bir README ekle."),
    ("readme_content", "README içeriği", 15,
     "README'ye kurulum, kullanım ve kısa bir örnek ekle; şu an yalnızca birkaç satır."),
    ("description", "Açıklama", 20,
     "Repo sayfasındaki 'About' bölümüne tek cümlelik bir açıklama yaz."),
    ("license", "Lisans", 20,
     "Kodunun hangi koşullarda kullanılabileceğini belirten bir LICENSE dosyası ekle (ör. MIT)."),
    ("topics", "Topic", 15,
     "'About' bölümüne birkaç topic ekle (ör. python, fastapi); repo daha kolay bulunur."),
]

HOW = (
    "Her kendi repon için beş kontrol yapılır: README (30), README içeriği en az 300 bayt (15), "
    "açıklama (20), lisans (20), topic (15). Skor = geçen kontrollerin ağırlığı / durumu bilinen "
    "kontrollerin ağırlığı × 100. Ağırlıklar ve eşik sezgiseldir. Skor vitrin ve belgelendirme "
    "eksiksizliğini ölçer, kod kalitesini ölçmez. Fork'lar ve başkasına ait repolar puanlanmaz. "
    "README yalnızca dört yaygın dosya adına bakılarak aranır; içeriği okunmaz, yalnız boyutuna "
    "bakılır. Durum etiketi skora girmez: arşivlenmişse Arşiv, son push 90 gün içindeyse Aktif, "
    "değilse Durağan."
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
    readme_bytes: int | None = None  # None: bilinmiyor (eski senkron) ya da README yok
    is_archived: bool = False
    weekly_commits: list[int] = field(default_factory=lambda: [0] * WEEKS)  # eskiden yeniye


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
    state: RepoState
    topics: list[str]
    weekly_commits: list[int]  # son 12 hafta, eskiden yeniye
    suggestion: str | None  # yalnızca puanlanan ve eksiği olan repoda


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
        case "readme_content":
            if repo.has_readme is False:
                return "missing"  # README yoksa içerik de yok
            if repo.has_readme is None or repo.readme_bytes is None:
                return "unknown"
            return "ok" if repo.readme_bytes >= README_MIN_BYTES else "missing"
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


def repo_state(repo: RepoFacts, days_since_push: int | None) -> RepoState:
    if repo.is_archived:
        return "arsiv"
    return "aktif" if days_since_push is not None and days_since_push <= ACTIVE_DAYS else "durgun"


def suggestion(checks: list["CheckOut"]) -> str | None:
    """En ağır en çok iki eksik kapatılırsa skor kaç puan artar? (aynı formülle, deterministik)"""
    known = sum(c.weight for c in checks if c.status != "unknown")
    earned = sum(c.weight for c in checks if c.status == "ok")
    missing = sorted((c for c in checks if c.status == "missing"), key=lambda c: -c.weight)[:2]
    if not missing or not known:
        return None
    gain = round((earned + sum(c.weight for c in missing)) / known * 100) - round(earned / known * 100)
    names = ", ".join(c.label for c in missing)
    return f"Şu eksikleri kapatırsan skor {gain} puan artar: {names}."


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
    days = (now - repo.pushed_at).days if repo.pushed_at else None
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
        days_since_push=days,
        commit_count=repo.commit_count,
        state=repo_state(repo, days),
        topics=repo.topics,
        weekly_commits=repo.weekly_commits,
        suggestion=suggestion(checks) if score is not None else None,
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
