"""İşbirliği: açılan PR'ların sonucu ve kod incelemeleri (docs/metrikler.md, "İşbirliği").

Saf fonksiyonlar: veritabanını bilmez. Kendi reposuna açılan PR'lar ayrı tutulur, çünkü
çoğunu kişi kendisi merge eder ve bu merge oranını şişirir.
"""
import statistics
from dataclasses import dataclass
from datetime import date, datetime

from pydantic import BaseModel

from app.metrics import sufficiency
from app.metrics.sufficiency import Sufficiency

HOW = (
    "Açtığın PR'lar GitHub'dan okunur (başlık, repo adı ve karşı tarafın adı saklanmaz). Merge oranı = "
    "merge edilen / (merge edilen + merge edilmeden kapatılan); açık PR'lar henüz sonuçlanmadığı için "
    "sayılmaz. Merge süresi açılıştan merge'e geçen sürenin medyanıdır (aylarca açık kalan tek bir PR "
    "ortalamayı bozardı). Kendi repona açtığın PR'ları çoğunlukla kendin merge ettiğin için onlar ayrı "
    "gösterilir. İnceleme sayısı GitHub'ın saydığı kod incelemesi katkılarıdır."
)


@dataclass(frozen=True)
class PrFact:
    created_at: datetime
    merged_at: datetime | None
    closed_at: datetime | None
    state: str  # OPEN | MERGED | CLOSED
    is_own_repo: bool


class PrGroupOut(BaseModel):
    opened: int
    merged: int
    closed_unmerged: int
    still_open: int
    merge_rate: float | None  # 0-1; sonuçlanmış PR yoksa None
    median_merge_hours: float | None


class YearRowOut(BaseModel):
    year: int
    prs: int  # o yıl açılan PR (UTC yıl)
    reviews: int


class CollaborationOut(BaseModel):
    total: PrGroupOut
    own: PrGroupOut  # kendi repolarına
    others: PrGroupOut  # başkalarının repolarına
    reviews_total: int
    reviews_this_year: int
    years: list[YearRowOut]  # eskiden yeniye
    sufficiency: Sufficiency
    basis: str
    summary: str
    how: str = HOW


def group(prs: list[PrFact]) -> PrGroupOut:
    merged = [p for p in prs if p.state == "MERGED" and p.merged_at is not None]
    closed = sum(1 for p in prs if p.state == "CLOSED")
    resolved = len(merged) + closed
    hours = [(p.merged_at - p.created_at).total_seconds() / 3600 for p in merged]
    return PrGroupOut(
        opened=len(prs), merged=len(merged), closed_unmerged=closed,
        still_open=sum(1 for p in prs if p.state == "OPEN"),
        merge_rate=round(len(merged) / resolved, 3) if resolved else None,
        median_merge_hours=round(statistics.median(hours), 1) if hours else None,
    )


def format_duration(hours: float) -> str:
    """48 saatten kısa ise saat, değilse gün (ondalık virgülle)."""
    if hours < 48:
        return f"{round(hours)} saat"
    return f"{hours / 24:.1f} gün".replace(".", ",")


def build_collaboration(prs: list[PrFact], reviews_by_year: dict[int, int], today: date) -> CollaborationOut:
    total, own = group(prs), group([p for p in prs if p.is_own_repo])
    others = group([p for p in prs if not p.is_own_repo])
    resolved = total.merged + total.closed_unmerged
    suff = sufficiency.collaboration(resolved)
    reviews_total = sum(reviews_by_year.values())
    basis = f"{resolved} sonuçlanmış PR, {reviews_total} inceleme"

    if suff == Sufficiency.NONE:
        summary = f"PR metrikleri için henüz yeterli veri yok ({basis})."
    else:
        # Asıl işbirliği göstergesi başkasının reposu; orada sonuçlanmış PR yoksa toplam kullanılır.
        g, where = (others, "Başkalarının repolarına") if others.merge_rate is not None else (total, "Toplam")
        parts = [f"{where} açılan PR: {g.opened}, merge edilen: {g.merged} (oran %{round(g.merge_rate * 100)})."]
        if g.median_merge_hours is not None:
            parts.append(f"Merge süresi medyanı {format_duration(g.median_merge_hours)}.")
        summary = " ".join(parts)
    summary += f" Kod incelemesi: toplam {reviews_total}."

    pr_years: dict[int, int] = {}
    for p in prs:
        pr_years[p.created_at.year] = pr_years.get(p.created_at.year, 0) + 1
    years = [
        YearRowOut(year=y, prs=pr_years.get(y, 0), reviews=reviews_by_year.get(y, 0))
        for y in sorted(set(pr_years) | set(reviews_by_year))
    ]
    return CollaborationOut(
        total=total, own=own, others=others, reviews_total=reviews_total,
        reviews_this_year=reviews_by_year.get(today.year, 0), years=years,
        sufficiency=suff, basis=basis, summary=summary,
    )
