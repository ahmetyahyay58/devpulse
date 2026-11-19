"""Yıllık özet (docs/metrikler.md "Yıllık özet")."""
from datetime import date, datetime

from app.metrics.sufficiency import Sufficiency
from app.metrics.year_summary import YearCommit, year_summary


def c(y, m, d, h=12, minute=0, lang="Python"):
    return YearCommit(datetime(y, m, d, h, minute), lang)


def test_period_this_year_is_jan_1_to_today_and_past_year_full():
    commits = [c(2026, 1, 5), c(2026, 11, 20), c(2025, 12, 31)]
    now = year_summary(commits, 2026, date(2026, 11, 17), None, 0, 8)
    assert (now.period_start, now.period_end, now.commits) == (date(2026, 1, 1), date(2026, 11, 17), 1)
    past = year_summary(commits, 2025, date(2026, 11, 17), None, 0, 8)
    assert past.period_end == date(2025, 12, 31) and past.commits == 1


def test_slides_values():
    commits = (
        [c(2026, 3, d) for d in (1, 2, 3)]  # 3 günlük seri, Python
        + [c(2026, 5, 10, 2, lang="Dart"), c(2026, 5, 10, 3, lang="Dart"), c(2026, 5, 11, 1, lang="Dart")]
        + [c(2026, 5, 20, 10, 0, lang=None), c(2026, 5, 20, 11, 30, lang=None)]  # dili bilinmeyen repo
    )
    out = year_summary(commits, 2026, date(2026, 11, 17), 7, 3, 8)
    assert out.commits == 8 and out.active_days == 6
    assert (out.busiest_month, out.busiest_month_commits) == (5, 5)
    assert out.top_language == "Dart" and out.top_language_share == 0.5  # 3/6, eşitlikte alfabetik
    assert [(s.language, s.first_month) for s in out.language_journey] == [("Python", 3), ("Dart", 5)]
    assert out.night_share == 3 / 8  # 02:00, 03:00, 01:00
    assert out.longest_streak == 3
    # Oturumlar: 10 Mayıs 02-03 (60 dk), 20 Mayıs 10:00-11:30 (90 dk); diğerleri tek commit (0)
    assert out.coding_hours == round(150 / 60)
    assert out.reviews == 7 and (out.badges_unlocked, out.badges_total) == (3, 8)
    assert out.sufficiency == Sufficiency.NONE  # < 10 commit


def test_ties_pick_earlier_month_and_sufficiency_levels():
    commits = [c(2026, 4, 1), c(2026, 2, 1)]
    assert year_summary(commits, 2026, date(2026, 11, 17), None, 0, 8).busiest_month == 2
    many = [c(2026, 1, 1 + i % 28, i % 24) for i in range(60)]
    assert year_summary(many[:20], 2026, date(2026, 11, 17), None, 0, 8).sufficiency == Sufficiency.LOW
    assert year_summary(many, 2026, date(2026, 11, 17), None, 0, 8).sufficiency == Sufficiency.NORMAL


def test_endpoint(api, demo_auth):
    assert api.get("/metrics/year-summary").status_code == 401
    api.post("/sync", json={}, headers=demo_auth)
    body = api.get("/metrics/year-summary", headers=demo_auth).json()
    assert body["commits"] > 0 and body["badges_total"] == 20
    assert body["period_start"].endswith("-01-01")
    assert api.get("/metrics/year-summary?year=2999", headers=demo_auth).status_code in (400, 422)
