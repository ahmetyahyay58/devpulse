"""Başarımlar (rozetler) ve yıl kıyası. Tanım: docs/metrikler.md "Başarımlar", "Yıl kıyası".

Rozetler yeni bir hesap yapmaz: süreklilik, proje sağlığı ve teknoloji sonuçlarını eşikle
karşılaştırır. Ham commit sayısını ödüllendiren rozet yoktur.
"""
from datetime import date, datetime

from pydantic import BaseModel

from app.metrics import activity, sufficiency
from app.metrics.projects import ProjectsOut
from app.metrics.sufficiency import Sufficiency
from app.metrics.technology import TechnologyOut

MULTI_LANG_SHARE = 0.05  # "Çok dilli" için dil başına en az pay

HOW_YEAR = (
    "Bu yılın 1 Ocak'ından bugüne kadarki dönem, geçen yılın aynı dönemiyle (1 Ocak'tan geçen "
    "yılın bugünkü tarihine) karşılaştırıldı; tam geçen yıl yarım bu yılla kıyaslanmaz. "
    "Değişim = (bu yıl − geçen yıl) / geçen yıl. Sayılar alışkanlığı betimler; daha çok commit "
    "daha iyi anlamına gelmez."
)


class BadgeOut(BaseModel):
    key: str
    name: str
    description: str  # koşul, kullanıcıya gösterilir
    current: int
    target: int
    unlocked: bool


def _badge(key: str, name: str, description: str, current: int, target: int) -> BadgeOut:
    current = max(0, current)
    return BadgeOut(key=key, name=name, description=description, current=min(current, target),
                    target=target, unlocked=current >= target)


def badges(
    days: set[date], today: date, projects: ProjectsOut, technology: TechnologyOut
) -> list[BadgeOut]:
    longest = activity.longest_streak(days)
    active_90 = sum(1 for d in days if 0 <= (today - d).days < 90)
    scored = [p for p in projects.projects if p.score is not None]

    def all_ok(key: str) -> int:
        return sum(1 for p in scored for c in p.checks if c.key == key and c.status == "ok")

    multi = sum(1 for lang in technology.languages if lang.name != "Diğer" and lang.share >= MULTI_LANG_SHARE)
    contributed = sum(1 for p in projects.projects if not p.is_owner and p.commit_count > 0)
    best = max((p.score for p in scored), default=0)
    n = len(scored)
    return [
        _badge("streak7", "Bir haftalık seri", "7 gün üst üste commit at.", longest, 7),
        _badge("streak30", "Bir aylık seri", "30 gün üst üste commit at.", longest, 30),
        _badge("regular", "Düzenli", "Son 90 günün en az 27'sinde commit at.", active_90, 27),
        _badge("showcase", "Vitrin", "Bir reponun proje sağlığını 100 yap.", best, 100),
        # Puanlanan repo yoksa hedef 1: rozet kilitli kalır (boş küme "hepsi" sayılmaz).
        _badge("docs", "Belgelendirici", "Bütün repolarına README ekle.", all_ok("readme"), max(n, 1)),
        _badge("license", "Lisanslı", "Bütün repolarına lisans ekle.", all_ok("license"), max(n, 1)),
        _badge("polyglot", "Çok dilli", "Kodunun en az %5'i olan 3 dilde yaz.", multi, 3),
        _badge("contributor", "Katkıcı", "Başkasına ait bir repoya commit at.", contributed, 1),
    ]


# --- Yıl kıyası ------------------------------------------------------------------------

class YearStat(BaseModel):
    label: str
    this_year: int
    last_year: int
    change_pct: int | None  # geçen yıl 0 ise None


class YearCompareOut(BaseModel):
    this_year: int
    last_year: int
    period_end: date  # bu yılın dönem sonu (bugün)
    stats: list[YearStat]
    sufficiency: Sufficiency
    basis: str
    summary: str
    how: str = HOW_YEAR


def _same_day_last_year(d: date) -> date:
    try:
        return d.replace(year=d.year - 1)
    except ValueError:  # 29 Şubat -> 28 Şubat
        return d.replace(year=d.year - 1, day=28)


def _period(commits: list[tuple[datetime, int]], start: date, end: date) -> tuple[int, int, int, int]:
    """(commit, aktif gün, en uzun seri, repo) — start..end dahil, yerel günlere göre."""
    inside = [(t, r) for t, r in commits if start <= t.date() <= end]
    days = {t.date() for t, _ in inside}
    return len(inside), len(days), activity.longest_streak(days), len({r for _, r in inside})


def _change(now: int, before: int) -> int | None:
    return None if before == 0 else round((now - before) / before * 100)


def year_compare(commits: list[tuple[datetime, int]], today: date) -> YearCompareOut:
    """commits: (yerel zaman, repo id)."""
    this = _period(commits, date(today.year, 1, 1), today)
    last = _period(commits, date(today.year - 1, 1, 1), _same_day_last_year(today))
    labels = ["Commit", "Aktif gün", "En uzun seri (gün)", "Commit atılan repo"]
    stats = [YearStat(label=l, this_year=a, last_year=b, change_pct=_change(a, b))
             for l, a, b in zip(labels, this, last)]

    suff = sufficiency.year_compare(this[0], last[0])
    basis = f"bu yıl {this[0]}, geçen yıl {last[0]} commit"
    if suff == Sufficiency.NONE:
        summary = (f"Geçen yılın aynı dönemiyle kıyaslamak için iki dönemde de commit gerekiyor "
                   f"({basis}).")
    else:
        pct = stats[0].change_pct
        direction = "daha fazla" if pct >= 0 else "daha az"
        summary = (f"Yılbaşından bu yana geçen yılın aynı dönemine göre %{abs(pct)} {direction} "
                   f"commit; aktif gün {this[1]} (geçen yıl {last[1]}).")
    return YearCompareOut(this_year=today.year, last_year=today.year - 1, period_end=today,
                          stats=stats, sufficiency=suff, basis=basis, summary=summary)


class AchievementsOut(BaseModel):
    badges: list[BadgeOut]
    unlocked: int
    year: YearCompareOut
