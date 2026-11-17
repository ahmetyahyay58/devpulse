"""Yıllık özet: var olan tanımların tek yıla uygulanması. Tanım: docs/metrikler.md "Yıllık özet".

Saf fonksiyon: veritabanı bilgisi yok. Girdi yerel saatli commit zamanları ve her commit'in
atıldığı reponun ana dili (bilinmiyorsa None).
"""
from collections import Counter
from dataclasses import dataclass
from datetime import date, datetime

from pydantic import BaseModel

from app.metrics import activity
from app.metrics.sufficiency import Sufficiency


@dataclass(frozen=True)
class YearCommit:
    at: datetime  # yerel saat
    language: str | None  # reponun ana dili


class LanguageStep(BaseModel):
    language: str
    first_month: int  # 1-12: o dilde ilk commit'in ayı
    commits: int


class YearSummaryOut(BaseModel):
    year: int
    period_start: date
    period_end: date  # bu yıl için bugün, geçmiş yıl için 31 Aralık
    commits: int
    active_days: int
    busiest_month: int | None  # 1-12
    busiest_month_commits: int
    top_language: str | None
    top_language_share: float | None  # ana dili bilinen commit'ler içinde
    night_share: float | None
    peak_hour: int | None
    longest_streak: int
    coding_hours: int  # oturum sürelerinin toplamı; alt sınır (tahmin)
    sessions: int
    language_journey: list[LanguageStep]  # ilk commit tarihine göre
    reviews: int | None  # GitHub'ın o yıl saydığı inceleme; veri yoksa None
    badges_unlocked: int
    badges_total: int
    sufficiency: Sufficiency


def sufficiency(commits: int) -> Sufficiency:
    if commits < 10:
        return Sufficiency.NONE
    if commits < 50:
        return Sufficiency.LOW
    return Sufficiency.NORMAL


def year_summary(commits: list[YearCommit], year: int, today: date, reviews: int | None,
                 badges_unlocked: int, badges_total: int) -> YearSummaryOut:
    start = date(year, 1, 1)
    end = today if year == today.year else date(year, 12, 31)
    inside = sorted((c for c in commits if start <= c.at.date() <= end), key=lambda c: c.at)
    times = [c.at for c in inside]
    days = activity.active_days(times)

    months = Counter(t.month for t in times)
    busiest = min(months, key=lambda m: (-months[m], m)) if months else None  # eşitlikte erken ay

    langs = Counter(c.language for c in inside if c.language)
    known = sum(langs.values())
    top = min(langs, key=lambda l: (-langs[l], l)) if langs else None

    first: dict[str, datetime] = {}
    for c in inside:
        if c.language and c.language not in first:
            first[c.language] = c.at
    journey = [LanguageStep(language=l, first_month=first[l].month, commits=langs[l])
               for l in sorted(first, key=lambda l: first[l])]

    rh = activity.rhythm(times)
    sess = activity.sessions(times)
    return YearSummaryOut(
        year=year, period_start=start, period_end=end,
        commits=len(inside), active_days=len(days),
        busiest_month=busiest, busiest_month_commits=months[busiest] if busiest else 0,
        top_language=top, top_language_share=langs[top] / known if top else None,
        night_share=rh.night_share, peak_hour=rh.peak_hour,
        longest_streak=activity.longest_streak(days),
        coding_hours=round(sum(s.minutes for s in sess) / 60), sessions=len(sess),
        language_journey=journey, reviews=reviews,
        badges_unlocked=badges_unlocked, badges_total=badges_total,
        sufficiency=sufficiency(len(inside)),
    )
