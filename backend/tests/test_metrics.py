"""Metrik birim testleri: her beklenen değer elle hesaplanmıştır (docs/metrikler.md)."""
from datetime import date, datetime, timedelta, timezone

import pytest

from app.metrics import activity, sufficiency
from app.metrics.activity import CommitPoint
from app.metrics.overview import build_overview
from app.metrics.sufficiency import Sufficiency

IST = "Europe/Istanbul"  # UTC+3, yaz saati yok


def utc(*args) -> datetime:
    return datetime(*args, tzinfo=timezone.utc)


def pts(*times: datetime, lines: int | None = 10) -> list[CommitPoint]:
    return [CommitPoint(t, lines) for t in times]


def d(day: int, month: int = 11) -> date:
    return date(2026, month, day)


# --- Saat dilimi --------------------------------------------------------------------

def test_timezone_moves_commit_to_next_day_and_night():
    # UTC 4 Mart 21:30 = İstanbul 5 Mart 00:30
    [t] = activity.to_local(pts(utc(2026, 3, 4, 21, 30)), IST)
    assert (t.date(), t.hour) == (date(2026, 3, 5), 0)
    assert activity.rhythm([t]).night_share == 1.0


def test_unknown_timezone_falls_back_to_utc():
    [t] = activity.to_local(pts(utc(2026, 3, 4, 21, 30)), None)
    assert (t.date(), t.hour) == (date(2026, 3, 4), 21)


# --- Süreklilik ----------------------------------------------------------------------

@pytest.mark.parametrize("today, expected", [
    (d(12), 3),  # bugün aktif: 10-11-12
    (d(13), 3),  # bugün henüz commit yok ama dün aktif: seri sürüyor
    (d(14), 0),  # dün de boş: seri bitti
])
def test_current_streak(today, expected):
    assert activity.current_streak({d(10), d(11), d(12)}, today) == expected


def test_current_streak_stops_at_gap():
    assert activity.current_streak({d(8), d(10), d(11)}, d(11)) == 2


def test_longest_streak():
    assert activity.longest_streak({d(1), d(2), d(3), d(5), d(7), d(8)}) == 3
    assert activity.longest_streak(set()) == 0


def test_active_ratio_uses_days_since_first_commit_when_younger_than_90():
    days = {d(3), d(5), d(7), d(9), d(12)}  # ilk commit 3 Kasım; 12 Kasım dahil 10 gün
    assert activity.active_ratio(days, d(12)) == pytest.approx(5 / 10)


def test_active_ratio_ignores_days_older_than_90():
    days = {d(12) - timedelta(days=200), d(12)}
    assert activity.active_ratio(days, d(12)) == pytest.approx(1 / 90)


# --- Oturum ----------------------------------------------------------------------------

def _t(h: int, m: int = 0) -> datetime:
    return datetime(2026, 11, 12, h, m, tzinfo=timezone.utc)


def test_sessions_split_on_gaps_longer_than_two_hours():
    times = [_t(10), _t(10, 30), _t(12, 31), _t(12, 40), _t(15)]
    s = activity.sessions(times)
    # 10:30 -> 12:31 boşluk 2s01dk (yeni oturum); 12:40 -> 15:00 boşluk 2s20dk (yeni oturum)
    assert [(x.commits, x.minutes) for x in s] == [(2, 30), (2, 9), (1, 0)]


def test_exactly_two_hours_is_same_session():
    assert len(activity.sessions([_t(10), _t(12)])) == 1


# --- Ritim -------------------------------------------------------------------------------

def test_rhythm_counts_and_tie_breaks_to_earliest_hour():
    # 16 Kasım 2026 Pazartesi, 21 Kasım Cumartesi (yerel = UTC, saat dilimi verilmedi)
    times = activity.to_local(pts(
        utc(2026, 11, 16, 9), utc(2026, 11, 16, 23), utc(2026, 11, 21, 2), utc(2026, 11, 21, 23),
        utc(2026, 11, 21, 9),
    ), None)
    r = activity.rhythm(times)
    assert r.by_hour[9] == 2 and r.by_hour[23] == 2
    assert r.peak_hour == 9  # 9 ile 23 eşit: en erken saat
    assert r.night_share == pytest.approx(1 / 5)  # yalnız 02:00
    assert r.weekend_share == pytest.approx(3 / 5)
    assert r.by_weekday == [2, 0, 0, 0, 0, 3, 0]


# --- Yoğunluk -----------------------------------------------------------------------------

def test_intensity_uses_medians_and_skips_unknown_lines():
    points = [
        CommitPoint(_t(10), 5), CommitPoint(_t(11), 15), CommitPoint(_t(18), None),
        CommitPoint(utc(2026, 11, 13, 9), 5000),  # dev commit medyanı bozmaz
    ]
    times = activity.to_local(points, None)
    i = activity.intensity(times, points, activity.sessions(times))
    assert i.commits_per_active_day == 2  # 12 Kasım: 3, 13 Kasım: 1 -> medyan 2
    assert i.lines_per_commit == 15  # [5, 15, 5000] -> 15 (None atlandı)
    assert i.commits_per_session == 1  # oturumlar: 2, 1, 1 -> medyan 1


# --- Veri yeterliliği eşikleri ---------------------------------------------------------------

@pytest.mark.parametrize("args, expected", [
    ((2, 100), Sufficiency.NONE), ((3, 100), Sufficiency.LOW),
    ((10, 29), Sufficiency.LOW), ((10, 30), Sufficiency.NORMAL),
])
def test_continuity_thresholds(args, expected):
    assert sufficiency.continuity(*args) == expected


@pytest.mark.parametrize("args, expected", [
    ((9, True), Sufficiency.NONE), ((10, True), Sufficiency.LOW),
    ((50, True), Sufficiency.NORMAL), ((50, False), Sufficiency.LOW),
])
def test_rhythm_thresholds(args, expected):
    assert sufficiency.rhythm(*args) == expected


@pytest.mark.parametrize("n, expected", [
    (2, Sufficiency.NONE), (3, Sufficiency.LOW), (14, Sufficiency.LOW), (15, Sufficiency.NORMAL),
])
def test_session_thresholds(n, expected):
    assert sufficiency.sessions(n) == expected


# --- Genel Bakış ---------------------------------------------------------------------------

def test_overview_with_no_commits_does_not_crash():
    o = build_overview([], IST, d(12), repo_count=0)
    assert o.kpi.total_commits == 0
    assert {o.continuity.sufficiency, o.rhythm.sufficiency, o.sessions.sufficiency} == {Sufficiency.NONE}
    assert "yeterli veri yok" in o.rhythm.summary


def test_overview_summary_and_kpi():
    # Son 60 günün her günü 1 commit, İstanbul 10:00 (UTC 07:00)
    points = pts(*[utc(2026, 11, 12, 7) - timedelta(days=k) for k in range(60)])
    o = build_overview(points, IST, d(12), repo_count=3)

    assert o.kpi.model_dump() == {
        "total_commits": 60, "active_days": 60, "repos": 3,
        "current_streak": 60, "commits_last_30_days": 30,
    }
    assert o.continuity.sufficiency == Sufficiency.NORMAL
    assert o.continuity.active_ratio_90d == 1.0  # ilk commit 60 gün önce: payda 60
    assert o.rhythm.sufficiency == Sufficiency.NORMAL
    assert o.rhythm.peak_hour == 10
    assert o.rhythm.summary == (
        "Commit'lerin en çok 10:00-10:59 arasında. Gece (00-06) oranı %0, hafta sonu oranı %27."
    )  # 13 Eyl-12 Kas: 8 tam hafta (16 hafta sonu günü) + Pzt-Prş 4 gün -> 16/60 = %27
    assert o.continuity.summary == "Son 90 günde aktif gün oranın %100; en uzun serin 60 gün."
    assert o.sessions.count == 60  # günde 1 commit: her biri ayrı oturum


def test_overview_without_timezone_caps_rhythm_confidence():
    points = pts(*[utc(2026, 11, 12, 7) - timedelta(days=k) for k in range(60)])
    o = build_overview(points, None, d(12), repo_count=1)
    assert o.timezone_known is False
    assert o.rhythm.sufficiency == Sufficiency.LOW
    assert "saat dilimi bilinmiyor" in o.rhythm.basis
