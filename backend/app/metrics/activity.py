"""Etkinlik metrikleri: saf fonksiyonlar (veritabanı ve web bilgisi yok).

Tanımlar: docs/metrikler.md. Hepsi kural tabanlıdır; makine öğrenmesi yoktur.
"Bugün" dışarıdan verilir; böylece testler her gün aynı sonucu verir.
"""
from collections import Counter
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from statistics import median
from zoneinfo import ZoneInfo

SESSION_GAP = timedelta(hours=2)  # bundan uzun boşluk yeni oturum başlatır
NIGHT_HOURS = range(0, 6)  # 00:00-05:59
WEEKEND = {5, 6}  # Python'da Pazartesi=0 ... Pazar=6


@dataclass(frozen=True)
class CommitPoint:
    authored_at: datetime  # saat dilimli (UTC)
    lines: int | None  # eklenen + silinen; bilinmiyorsa None


def to_local(points: list[CommitPoint], tz: str | None) -> list[datetime]:
    """Commit zamanlarını kullanıcının saat dilimine çevirir, sıralı döner."""
    zone = ZoneInfo(tz or "UTC")
    return sorted(p.authored_at.astimezone(zone) for p in points)


# --- Süreklilik ------------------------------------------------------------------

def active_days(local_times: list[datetime]) -> set[date]:
    return {t.date() for t in local_times}


def current_streak(days: set[date], today: date) -> int:
    """Bugün ya da dün aktifse oradan geriye kesintisiz gün sayısı; değilse 0."""
    if today in days:
        day = today
    elif today - timedelta(days=1) in days:
        day = today - timedelta(days=1)  # gün bitmeden seri sıfırlanmasın
    else:
        return 0
    streak = 0
    while day in days:
        streak += 1
        day -= timedelta(days=1)
    return streak


def longest_streak(days: set[date]) -> int:
    best = 0
    for day in days:
        if day - timedelta(days=1) in days:
            continue  # bir dizinin başı değil; yalnız başlardan say
        length = 1
        while day + timedelta(days=length) in days:
            length += 1
        best = max(best, length)
    return best


def active_ratio(days: set[date], today: date, window: int = 90) -> float | None:
    """Son `window` günde aktif gün oranı. İlk commit daha yeniyse payda o günden bugüne."""
    if not days:
        return None
    span = min(window, (today - min(days)).days + 1)
    start = today - timedelta(days=span - 1)
    return sum(1 for d in days if start <= d <= today) / span


# --- Ritim ------------------------------------------------------------------------

@dataclass(frozen=True)
class Rhythm:
    by_hour: list[int]  # 24 eleman: 0..23
    by_weekday: list[int]  # 7 eleman: Pazartesi..Pazar
    peak_hour: int | None
    night_share: float | None
    weekend_share: float | None


def rhythm(local_times: list[datetime]) -> Rhythm:
    hours = Counter(t.hour for t in local_times)
    weekdays = Counter(t.weekday() for t in local_times)
    n = len(local_times)
    by_hour = [hours[h] for h in range(24)]
    return Rhythm(
        by_hour=by_hour,
        by_weekday=[weekdays[d] for d in range(7)],
        # max() eşitlikte ilk (en erken) saati verir.
        peak_hour=max(range(24), key=lambda h: by_hour[h]) if n else None,
        night_share=sum(hours[h] for h in NIGHT_HOURS) / n if n else None,
        weekend_share=sum(weekdays[d] for d in WEEKEND) / n if n else None,
    )


# --- Oturum ve yoğunluk -------------------------------------------------------------

@dataclass(frozen=True)
class Session:
    start: datetime
    end: datetime
    commits: int

    @property
    def minutes(self) -> float:
        return (self.end - self.start).total_seconds() / 60


def sessions(local_times: list[datetime], gap: timedelta = SESSION_GAP) -> list[Session]:
    """Sıralı commit zamanlarını oturumlara böler: boşluk > gap ise yeni oturum."""
    result: list[Session] = []
    for t in local_times:
        if result and t - result[-1].end <= gap:
            last = result[-1]
            result[-1] = Session(last.start, t, last.commits + 1)
        else:
            result.append(Session(t, t, 1))
    return result


@dataclass(frozen=True)
class Intensity:
    commits_per_active_day: float | None
    commits_per_session: float | None
    session_minutes: float | None
    lines_per_commit: float | None


def intensity(local_times: list[datetime], points: list[CommitPoint], sess: list[Session]) -> Intensity:
    per_day = Counter(t.date() for t in local_times)
    lines = [p.lines for p in points if p.lines is not None]
    return Intensity(
        commits_per_active_day=median(per_day.values()) if per_day else None,
        commits_per_session=median(s.commits for s in sess) if sess else None,
        session_minutes=median(s.minutes for s in sess) if sess else None,
        lines_per_commit=median(lines) if lines else None,
    )
