"""Teknoloji: dil dağılımı, çeşitlilik (betimleyici entropi) ve tespit edilen araçlar.

Tanım: docs/metrikler.md "Teknoloji". Saf fonksiyon; kaynak kendi (fork olmayan) repolar.
"""
import math
from dataclasses import dataclass, field

from pydantic import BaseModel

from app.metrics import sufficiency
from app.metrics.sufficiency import Sufficiency

MIN_LISTED_SHARE = 0.01  # %1'in altındaki diller listede "Diğer" altında toplanır

HOW = (
    "Kendi (fork olmayan) repolarındaki dil başına bayt toplandı (GitHub'ın Linguist tespiti). "
    "Pay = dilin baytı / toplam bayt; bayt emeği ölçmez, büyük bir repo dağılımı belirler. "
    "Çeşitlilik normalleştirilmiş Shannon entropisidir: H / ln(dil sayısı), %0 tek dil, %100 "
    "bütün diller eşit. Bir puan değildir; yalnız dağılımın dengesini betimler. Araçlar kök "
    "dizindeki dosya adlarından bulunur (ör. Dockerfile → Docker); dosya içeriği okunmaz, alt "
    "klasörler görülmez."
)


@dataclass(frozen=True)
class RepoTech:
    is_owner: bool
    is_fork: bool
    languages: dict[str, int]  # dil -> bayt
    tools: list[str] = field(default_factory=list)


class LanguageOut(BaseModel):
    name: str  # "Diğer": %1'in altındaki diller toplamı
    bytes: int
    share: float  # 0-1
    repos: int  # kaç repoda geçtiği ("Diğer" için o dillerin geçtiği farklı repo sayısı)


class ToolOut(BaseModel):
    name: str
    repos: int


class TechnologyOut(BaseModel):
    repo_count: int  # dil bilgisi olan kendi repoları
    language_count: int
    dominant: str | None
    dominant_share: float | None
    diversity: float | None  # 0-1, normalleştirilmiş entropi; puan değil
    languages: list[LanguageOut]  # paya göre azalan; "Diğer" en sonda
    tools: list[ToolOut]  # repo sayısına göre azalan, eşitlikte ada göre
    sufficiency: Sufficiency
    basis: str
    summary: str
    how: str = HOW


def normalized_entropy(shares: list[float]) -> float:
    """H / ln(k); tek dil (k <= 1) için 0."""
    shares = [p for p in shares if p > 0]
    if len(shares) <= 1:
        return 0.0
    h = -sum(p * math.log(p) for p in shares)
    return h / math.log(len(shares))


def build_technology(repos: list[RepoTech]) -> TechnologyOut:
    own = [r for r in repos if r.is_owner and not r.is_fork]
    # Boyutu 0 olan diller sayılmaz; dil bilgisi olmayan repolar dağılıma girmez.
    with_lang = [
        RepoTech(r.is_owner, r.is_fork, {k: v for k, v in r.languages.items() if v > 0}, r.tools)
        for r in own if any(v > 0 for v in r.languages.values())
    ]
    totals: dict[str, int] = {}
    repo_counts: dict[str, int] = {}
    for r in with_lang:
        for lang, size in r.languages.items():
            totals[lang] = totals.get(lang, 0) + size
            repo_counts[lang] = repo_counts.get(lang, 0) + 1
    total = sum(totals.values())

    ranked = sorted(totals.items(), key=lambda kv: (-kv[1], kv[0]))
    languages: list[LanguageOut] = []
    other_bytes, other_langs = 0, set()
    for lang, size in ranked:
        share = size / total
        if share >= MIN_LISTED_SHARE:
            languages.append(LanguageOut(name=lang, bytes=size, share=round(share, 4), repos=repo_counts[lang]))
        else:
            other_bytes += size
            other_langs.add(lang)
    if other_bytes:
        other_repos = sum(1 for r in with_lang if other_langs & r.languages.keys())
        languages.append(LanguageOut(name="Diğer", bytes=other_bytes,
                                     share=round(other_bytes / total, 4), repos=other_repos))

    tool_counts: dict[str, int] = {}
    for r in own:
        for t in r.tools:
            tool_counts[t] = tool_counts.get(t, 0) + 1
    tools = [ToolOut(name=t, repos=n) for t, n in sorted(tool_counts.items(), key=lambda kv: (-kv[1], kv[0]))]

    suff = sufficiency.technology(len(with_lang))
    basis = f"{len(with_lang)} repo, {len(totals)} dil"
    diversity = round(normalized_entropy([v / total for v in totals.values()]), 4) if total else None
    dominant, dominant_share = (ranked[0][0], round(ranked[0][1] / total, 4)) if total else (None, None)

    if suff == Sufficiency.NONE:
        summary = f"Bu metrik için henüz yeterli veri yok ({basis})."
    elif len(totals) == 1:
        summary = f"Kodunun tamamı tek dilde: {dominant}."
    else:
        summary = (f"{len(totals)} dil kullanıyorsun; en çok {dominant} (kodun "
                   f"%{round(dominant_share * 100)} kadarı). Dil dağılımının dengesi "
                   f"%{round(diversity * 100)}.")
    return TechnologyOut(
        repo_count=len(with_lang), language_count=len(totals), dominant=dominant,
        dominant_share=dominant_share, diversity=diversity, languages=languages, tools=tools,
        sufficiency=suff, basis=basis, summary=summary,
    )
