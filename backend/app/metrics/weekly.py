"""Haftalık özet: bu haftanın Pazartesi'sinden bugüne, geçen haftanın aynı günleriyle.
Tanım: docs/metrikler.md "Haftalık özet". Saf fonksiyon.
"""
from datetime import date, datetime, timedelta

from pydantic import BaseModel

from app.metrics.sufficiency import Sufficiency


class WeekPeriod(BaseModel):
    start: date
    end: date
    commits: int
    active_days: int
    repos: int


class WeeklyOut(BaseModel):
    this_week: WeekPeriod
    last_week: WeekPeriod
    difference: int  # commit farkı (bu - geçen)
    sufficiency: Sufficiency
    summary: str


def _period(commits: list[tuple[datetime, int]], start: date, end: date) -> WeekPeriod:
    inside = [(t, r) for t, r in commits if start <= t.date() <= end]
    return WeekPeriod(start=start, end=end, commits=len(inside), active_days=len({t.date() for t, _ in inside}),
                      repos=len({r for _, r in inside}))


def weekly(commits: list[tuple[datetime, int]], today: date) -> WeeklyOut:
    """commits: (yerel zaman, repo id)."""
    monday = today - timedelta(days=today.weekday())
    this = _period(commits, monday, today)
    last = _period(commits, monday - timedelta(days=7), today - timedelta(days=7))
    diff = this.commits - last.commits
    if this.commits == 0 and last.commits == 0:
        suff = Sufficiency.NONE
        summary = "Bu hafta ve geçen haftanın aynı günlerinde commit yok."
    else:
        suff = Sufficiency.NORMAL
        if diff == 0:
            change = "geçen haftanın aynı günleriyle aynı"
        else:
            change = f"geçen haftanın aynı günlerine göre {abs(diff)} commit {'fazla' if diff > 0 else 'az'}"
        summary = f"Bu hafta {this.commits} commit, {this.active_days} aktif gün; {change}."
    return WeeklyOut(this_week=this, last_week=last, difference=diff, sufficiency=suff, summary=summary)
