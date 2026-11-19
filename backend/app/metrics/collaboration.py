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


class MonthRowOut(BaseModel):
    month: str  # "2026-03" (UTC ay; PR'ın ayı merge zamanına göre)
    merged: int
    median_merge_hours: float | None  # o ay merge yoksa None (0 değil)


class BalanceOut(BaseModel):
    """Katkı dengesi: kendi repoların / başkalarınınki (yalnız sayılar, repo adı yok)."""
    own: int
    others: int
    others_share: float | None  # 0-1; ikisi de 0 ise None


def balance(own: int, others: int) -> BalanceOut:
    total = own + others
    return BalanceOut(own=own, others=others, others_share=round(others / total, 3) if total else None)


class CollaborationOut(BaseModel):
    total: PrGroupOut
    own: PrGroupOut  # kendi repolarına
    others: PrGroupOut  # başkalarının repolarına
    reviews_total: int
    reviews_this_year: int
    years: list[YearRowOut]  # eskiden yeniye
    monthly_group: str  # "others" (başkalarının repoları) ya da "total"; özet cümlesiyle aynı kural
    monthly: list[MonthRowOut]  # bu ay dahil son 12 ay, eskiden yeniye
    balance_commits: BalanceOut  # commit'ler: kendi repoların / başkalarınınki
    balance_prs: BalanceOut  # açılan PR'lar: kendi repoların / başkalarınınki
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


MONTHS = 12


def last_months(today: date, n: int = MONTHS) -> list[str]:
    """Bu ay dahil son n ay, eskiden yeniye: ["2025-04", ..., "2026-03"]."""
    y, m = today.year, today.month
    out = []
    for _ in range(n):
        out.append(f"{y:04d}-{m:02d}")
        y, m = (y, m - 1) if m > 1 else (y - 1, 12)
    return out[::-1]


def monthly_merge(prs: list[PrFact], today: date) -> list[MonthRowOut]:
    """Ay ay merge edilen PR sayısı ve merge süresi medyanı (PR'ın ayı = merge zamanının UTC ayı)."""
    hours: dict[str, list[float]] = {}
    for p in prs:
        if p.state == "MERGED" and p.merged_at is not None:
            key = p.merged_at.strftime("%Y-%m")
            hours.setdefault(key, []).append((p.merged_at - p.created_at).total_seconds() / 3600)
    return [
        MonthRowOut(month=k, merged=len(hours.get(k, [])),
                    median_merge_hours=round(statistics.median(hours[k]), 1) if k in hours else None)
        for k in last_months(today)
    ]


def build_collaboration(prs: list[PrFact], reviews_by_year: dict[int, int], today: date,
                        commits_own: int = 0, commits_others: int = 0) -> CollaborationOut:
    total, own = group(prs), group([p for p in prs if p.is_own_repo])
    others = group([p for p in prs if not p.is_own_repo])
    resolved = total.merged + total.closed_unmerged
    suff = sufficiency.collaboration(resolved)
    use_others = others.merge_rate is not None  # asıl işbirliği göstergesi; yoksa toplam
    reviews_total = sum(reviews_by_year.values())
    basis = f"{resolved} sonuçlanmış PR, {reviews_total} inceleme"

    if suff == Sufficiency.NONE:
        summary = f"PR metrikleri için henüz yeterli veri yok ({basis})."
    else:
        # Asıl işbirliği göstergesi başkasının reposu; orada sonuçlanmış PR yoksa toplam kullanılır.
        g, where = (others, "Başkalarının repolarına") if use_others else (total, "Toplam")
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
        balance_commits=balance(commits_own, commits_others),
        balance_prs=balance(own.opened, others.opened),
        monthly_group="others" if use_others else "total",
        monthly=monthly_merge([p for p in prs if not p.is_own_repo] if use_others else prs, today),
        sufficiency=suff, basis=basis, summary=summary,
    )
