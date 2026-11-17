"""Haftalık özet (docs/metrikler.md "Haftalık özet")."""
from datetime import date, datetime

from app.metrics.sufficiency import Sufficiency
from app.metrics.weekly import weekly

TODAY = date(2026, 11, 18)  # Çarşamba


def at(d, repo=1):
    return (datetime(d.year, d.month, d.day, 12), repo)


def test_this_week_monday_to_today_vs_same_days_last_week():
    commits = [at(date(2026, 11, 16)), at(date(2026, 11, 18), 2), at(date(2026, 11, 18)),  # bu hafta
               at(date(2026, 11, 10)),  # geçen hafta Salı: dahil
               at(date(2026, 11, 13))]  # geçen hafta Cuma: bugünden sonraki gün, dahil değil
    out = weekly(commits, TODAY)
    assert (out.this_week.start, out.this_week.end) == (date(2026, 11, 16), TODAY)
    assert (out.last_week.start, out.last_week.end) == (date(2026, 11, 9), date(2026, 11, 11))
    assert (out.this_week.commits, out.this_week.active_days, out.this_week.repos) == (3, 2, 2)
    assert out.last_week.commits == 1 and out.difference == 2
    assert out.summary == "Bu hafta 3 commit, 2 aktif gün; geçen haftanın aynı günlerine göre 2 commit fazla."


def test_no_commits_is_insufficient_and_equal_wording():
    assert weekly([], TODAY).sufficiency == Sufficiency.NONE
    same = weekly([at(date(2026, 11, 16)), at(date(2026, 11, 9))], TODAY)
    assert same.summary.endswith("geçen haftanın aynı günleriyle aynı.")


def test_endpoint(api, demo_auth):
    assert api.get("/metrics/weekly").status_code == 401
    api.post("/sync", json={}, headers=demo_auth)
    body = api.get("/metrics/weekly", headers=demo_auth).json()
    assert body["this_week"]["start"] <= body["this_week"]["end"]
