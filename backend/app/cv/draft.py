"""CV taslağı (docs/cv.md): GitHub verisinden deterministik, kaynaklı maddeler. LLM yok.

Saf fonksiyon: veritabanını bilmez, metrik katmanının hazır çıktılarını alır. Her maddenin kimliği
veriden türetilir (konumdan değil); telefondaki düzenlemeler bu kimliklere bağlanır.
"""
from dataclasses import dataclass, field
from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel

Lang = Literal["tr", "en"]
MAX_PROJECTS = 6  # varsayılan seçili proje sayısı; kullanıcı telefonda değiştirebilir (docs/cv.md)
MAX_LISTED = 30  # seçim listesi için gönderilen en çok proje
MAX_LANGUAGES = 6


class CvItem(BaseModel):
    id: str
    text: str
    source: str  # hangi veriden üretildi (arayüzde maddenin altında)
    placeholder: bool = False  # [...] kısmını kullanıcı doldurur; uygulama sayı uydurmaz


class CvProject(BaseModel):
    id: str
    name: str
    url: str
    tech: list[str]  # ana dil + tespit edilen araçlar (Jake's: "Ad | teknolojiler")
    start: date | None  # GitHub'daki oluşturma tarihi; uydurulmaz, yoksa None
    end: date | None  # son push tarihi
    default_selected: bool  # sağlık puanına göre ilk 6; kullanıcı telefonda başka 6 seçebilir
    items: list[CvItem]


class CvDraftOut(BaseModel):
    lang: Lang
    login: str
    profile_url: str
    summary: CvItem | None
    projects: list[CvProject]
    skills: list[CvItem]
    activity: list[CvItem]
    languages: list[str]  # formatlardaki "Teknik beceriler" satırları için ham liste
    tools: list[str]


@dataclass(frozen=True)
class CvRepo:
    node_id: str
    name: str
    description: str | None
    language: str | None
    tools: list[str] = field(default_factory=list)
    commit_count: int = 0
    score: int | None = None  # proje sağlık puanı (puanlanmıyorsa None)
    has_readme: bool = False
    has_license: bool = False
    created_at: datetime | None = None
    pushed_at: datetime | None = None


@dataclass(frozen=True)
class CvFacts:
    login: str
    total_commits: int
    active_days: int
    repo_count: int
    longest_streak: int
    languages: list[str]  # paya göre azalan, "Diğer" hariç
    tools: list[str]
    repos: list[CvRepo]  # yalnızca kendi, fork olmayan, arşivlenmemiş repolar
    prs_to_others: int = 0
    prs_to_others_merged: int = 0
    reviews: int = 0


TEXT = {
    "tr": {
        "summary": "Ağırlıklı olarak {lang} ile çalışıyorum; GitHub'da {repos} repoda {commits} commit.",
        "summary_nolang": "GitHub'da {repos} repoda {commits} commit.",
        "src_summary": "Genel Bakış sayıları ve dil dağılımı",
        "src_desc": "GitHub repo açıklaması",
        "stack": "{lang} ile geliştirildi",
        "stack_nolang": "Kullanılan araçlar",
        "tools": "araçlar: {tools}",
        "src_stack": "Dil dağılımı ve kök dizindeki dosyalar",
        "work": "Commit sayısı: {n}",
        "docs_both": "README ve lisansla belgelendi",
        "docs_readme": "README ile belgelendi",
        "src_work": "Senkronlanan commit'ler ve proje sağlığı kontrolleri",
        "impact": "Etki: [ör. kullanıcı sayısı ya da hızlanma yüzdesi]",
        "src_impact": "Bu sayıyı sen yazarsın; uygulama bilemez",
        "langs": "Diller: {langs}",
        "src_langs": "Kendi repolarının dil dağılımı (bayt payı)",
        "skill_tools": "Araçlar: {tools}",
        "src_tools": "Kök dizindeki dosyalardan tespit (ör. Dockerfile)",
        "act": "Toplam commit: {commits}; aktif gün: {days}; en uzun seri: {streak} gün.",
        "src_act": "Senkronlanan commit'ler",
        "prs": "Başkalarının repolarına açılan PR: {opened}, merge edilen: {merged}.",
        "src_prs": "GitHub'daki pull request'lerin (İşbirliği)",
        "reviews": "Kod incelemesi: {n}.",
        "src_reviews": "GitHub'ın saydığı kod incelemesi katkıları",
    },
    "en": {
        "summary": "Mostly working with {lang}; {commits} commits across {repos} repositories on GitHub.",
        "summary_nolang": "{commits} commits across {repos} repositories on GitHub.",
        "src_summary": "Overview numbers and language breakdown",
        "src_desc": "GitHub repository description",
        "stack": "Built with {lang}",
        "stack_nolang": "Tools used",
        "tools": "tools: {tools}",
        "src_stack": "Language breakdown and root-level files",
        "work": "{n} commits",
        "docs_both": "documented with a README and a license",
        "docs_readme": "documented with a README",
        "src_work": "Synced commits and project health checks",
        "impact": "Impact: [e.g., number of users or % speed-up]",
        "src_impact": "You fill this in; the app cannot know this number",
        "langs": "Languages: {langs}",
        "src_langs": "Language breakdown of your own repositories (by bytes)",
        "skill_tools": "Tools: {tools}",
        "src_tools": "Detected from root-level files (e.g., Dockerfile)",
        "act": "{commits} commits, {days} active days, longest streak {streak} days.",
        "src_act": "Synced commits",
        "prs": "Opened {opened} pull requests to other people's repositories; {merged} merged.",
        "src_prs": "Your pull requests on GitHub (Collaboration)",
        "reviews": "{n} code reviews.",
        "src_reviews": "Code review contributions counted by GitHub",
    },
}


def _project(repo: CvRepo, t: dict, login: str, selected: bool) -> CvProject:
    pid = f"proj:{repo.node_id}"
    items: list[CvItem] = []
    if repo.description and repo.description.strip():
        items.append(CvItem(id=f"{pid}:desc", text=repo.description.strip(), source=t["src_desc"]))
    if repo.language or repo.tools:
        head = t["stack"].format(lang=repo.language) if repo.language else t["stack_nolang"]
        parts = [head] + ([t["tools"].format(tools=", ".join(repo.tools))] if repo.tools else [])
        text = "; ".join(parts) if repo.language else f"{head}: {', '.join(repo.tools)}"
        items.append(CvItem(id=f"{pid}:stack", text=text + ".", source=t["src_stack"]))
    if repo.commit_count > 0:
        docs = t["docs_both"] if repo.has_readme and repo.has_license else t["docs_readme"] if repo.has_readme else None
        text = t["work"].format(n=repo.commit_count) + (f"; {docs}" if docs else "") + "."
        items.append(CvItem(id=f"{pid}:work", text=text, source=t["src_work"]))
    items.append(CvItem(id=f"{pid}:impact", text=t["impact"], source=t["src_impact"], placeholder=True))
    return CvProject(
        id=pid, name=repo.name, url=f"https://github.com/{login}/{repo.name}",
        tech=([repo.language] if repo.language else []) + [x for x in repo.tools if x != repo.language],
        start=repo.created_at.date() if repo.created_at else None,
        end=repo.pushed_at.date() if repo.pushed_at else None,
        default_selected=selected,
        items=items,
    )


def order_projects(repos: list[CvRepo]) -> list[CvRepo]:
    """Sağlık puanı yüksekten düşüğe, eşitlikte commit sayısı; puanlanmayan en sonda."""
    return sorted(repos, key=lambda r: (r.score is None, -(r.score or 0), -r.commit_count, r.name))[:MAX_LISTED]


def build_draft(f: CvFacts, lang: Lang) -> CvDraftOut:
    t = TEXT[lang]
    summary = None
    if f.total_commits > 0:
        key = "summary" if f.languages else "summary_nolang"
        text = t[key].format(lang=f.languages[0] if f.languages else "", repos=f.repo_count, commits=f.total_commits)
        summary = CvItem(id="summary", text=text, source=t["src_summary"])

    skills = []
    if f.languages:
        skills.append(CvItem(id="skills:languages", text=t["langs"].format(langs=", ".join(f.languages[:MAX_LANGUAGES])),
                             source=t["src_langs"]))
    if f.tools:
        skills.append(CvItem(id="skills:tools", text=t["skill_tools"].format(tools=", ".join(f.tools)),
                             source=t["src_tools"]))

    activity = []
    if f.total_commits > 0:
        activity.append(CvItem(id="act:commits", source=t["src_act"], text=t["act"].format(
            commits=f.total_commits, days=f.active_days, streak=f.longest_streak)))
    if f.prs_to_others > 0:
        activity.append(CvItem(id="act:prs", source=t["src_prs"], text=t["prs"].format(
            opened=f.prs_to_others, merged=f.prs_to_others_merged)))
    if f.reviews > 0:
        activity.append(CvItem(id="act:reviews", source=t["src_reviews"], text=t["reviews"].format(n=f.reviews)))

    return CvDraftOut(
        lang=lang, login=f.login, profile_url=f"https://github.com/{f.login}", summary=summary,
        projects=[_project(r, t, f.login, i < MAX_PROJECTS) for i, r in enumerate(order_projects(f.repos))], skills=skills, activity=activity,
        languages=f.languages[:MAX_LANGUAGES], tools=f.tools,
    )
