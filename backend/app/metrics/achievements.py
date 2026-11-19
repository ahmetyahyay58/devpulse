"""Başarımlar (rozetler) ve yıl kıyası. Tanım: docs/metrikler.md "Başarımlar", "Yıl kıyası".

Rozetler yeni bir hesap yapmaz: süreklilik, proje sağlığı ve teknoloji sonuçlarını eşikle
karşılaştırır. Ham commit sayısını ödüllendiren rozet yoktur.
"""
from dataclasses import dataclass, field
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
    hidden: bool = False  # gizli rozet: açılana kadar adı ve koşulu gönderilmez


HIDDEN_NAME = "Gizli rozet"
HIDDEN_DESCRIPTION = "Açınca ne olduğunu göreceksin."


def _badge(key: str, name: str, description: str, current: int, target: int, hidden: bool = False) -> BadgeOut:
    current = max(0, current)
    unlocked = current >= target
    if hidden and not unlocked:  # sır sunucuda kalır: ad ve koşul uygulamaya gitmez
        return BadgeOut(key=key, name=HIDDEN_NAME, description=HIDDEN_DESCRIPTION, current=0, target=1,
                        unlocked=False, hidden=True)
    return BadgeOut(key=key, name=name, description=description, current=min(current, target),
                    target=target, unlocked=unlocked, hidden=hidden)


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


# --- Alışkanlık rozetleri (docs/metrikler.md "Alışkanlık rozetleri") ---------------------

NIGHT_MIN_COMMITS = 20
NO_TZ = " (saat dilimin bilinmiyor; senkronla gelir)"


@dataclass(frozen=True)
class HabitFacts:
    local_times: list[datetime]  # commit'lerin yerel zamanı, sıralı
    tz_known: bool  # False: saate bağlı rozetler kilitli
    labels: list[str] = field(default_factory=list)  # her commit'in uygulama türü (APP_LABELS)
    max_net_removed: int = 0  # en büyük (silinen - eklenen) satır, tek commit'te
    has_actions: bool = False  # kendi repolarından birinde GitHub Actions
    merged_to_others: int = 0  # başkasının reposunda merge edilen PR


def _longest_gap_then_back(days: set[date]) -> int:
    """Ardışık iki aktif gün arasındaki en uzun ara (gün). Sonraki gün aktif olduğu için 'geri dönüş'."""
    ordered = sorted(days)
    return max(((b - a).days for a, b in zip(ordered, ordered[1:])), default=0)


def habit_badges(f: HabitFacts) -> list[BadgeOut]:
    from app.classify.labels import APP_LABELS  # döngüsel içe aktarımı önler

    times = f.local_times if f.tz_known else []
    hours = {t.hour for t in times}
    n = len(times)
    night = sum(1 for t in times if t.hour in activity.NIGHT_HOURS)
    night_pct = round(night / n * 100) if n >= NIGHT_MIN_COMMITS else 0
    early = sum(1 for t in times if 6 <= t.hour < 8)
    longest = activity.longest_session(activity.sessions(sorted(times)))
    tz = "" if f.tz_known else NO_TZ
    days = activity.active_days(f.local_times)
    return [
        _badge("hours24", "24 Saat", "Günün 24 saatinin her birinde en az bir commit at." + tz, len(hours), 24),
        _badge("night_owl", "Gece Kuşu",
               f"En az {NIGHT_MIN_COMMITS} commit'in %30'u gece (00:00-05:59) olsun. Betimler, övmez." + tz,
               night_pct, 30),
        _badge("early_bird", "Erkenci", "06:00-07:59 arasında 10 commit at." + tz, early, 10),
        _badge("new_year", "Yılbaşı", "1 Ocak'ta commit at." + tz,
               int(any(t.month == 1 and t.day == 1 for t in times)), 1, hidden=True),
        _badge("leet", "13:37", "Saat tam 13:37'de commit at." + tz,
               int(any(t.hour == 13 and t.minute == 37 for t in times)), 1, hidden=True),
        _badge("marathon", "Maraton", "4 saat ya da daha uzun bir oturum (aradaki boşluk 2 saati geçmeden)." + tz,
               round(longest.minutes) if longest else 0, 240),
        _badge("comeback", "Geri Dönüş", "30 günden uzun bir aradan sonra yeniden commit at.",
               int(_longest_gap_then_back(days) > 30), 1),
        _badge("bug_hunter", "Böcek Avcısı", "\"Hata düzeltme\" türünde 10 commit at.",
               sum(1 for l in f.labels if l == "fix"), 10),
        _badge("all_types", "Her Telden", "6 commit türünün hepsinde en az bir commit at.",
               len(set(f.labels) & set(APP_LABELS)), len(APP_LABELS)),
        _badge("less_is_more", "Az Çoktur", "Sildiği satır eklediğinden en az 100 fazla olan bir commit at.",
               int(f.max_net_removed >= 100), 1),
        _badge("automation", "Otomasyoncu", "Repolarından birine GitHub Actions ekle.", int(f.has_actions), 1),
        _badge("first_merge", "İlk Merge", "Başkasının reposuna açtığın bir PR merge edilsin.", f.merged_to_others, 1),
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
