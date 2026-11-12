"""/metrics uç noktalarının testleri."""
from datetime import date, datetime, timedelta

from app.models import ContributionDay


def test_calendar_fills_missing_days_with_zero(api, db, login_as):
    headers = login_as("U_cal", "takvim")
    today = datetime.now().astimezone().date()  # kullanıcının saat dilimi yok: UTC; yakın gün yeter
    db.add_all([
        ContributionDay(user_id=1, day=today - timedelta(days=2), count=4),
        ContributionDay(user_id=1, day=today - timedelta(days=400), count=9),  # pencere dışı
    ])
    db.commit()

    body = api.get("/metrics/calendar?days=7", headers=headers).json()
    assert len(body["days"]) == 7
    assert [d["count"] for d in body["days"]].count(4) == 1
    assert body["total"] == 4  # 400 gün önceki sayılmadı
    assert date.fromisoformat(body["days"][0]["day"]) < date.fromisoformat(body["days"][-1]["day"])
    assert "PR" in body["note"]


def test_calendar_rejects_bad_range(api, login_as):
    assert api.get("/metrics/calendar?days=5000", headers=login_as("U_x", "x")).status_code == 422


def test_overview_requires_session(api):
    assert api.get("/metrics/overview").status_code == 401


def test_overview_for_new_user_without_data(api, login_as):
    body = api.get("/metrics/overview", headers=login_as("U_new", "yeni")).json()
    assert body["kpi"]["total_commits"] == 0
    assert body["timezone_known"] is False
    for section in ("continuity", "rhythm", "sessions"):
        assert body[section]["sufficiency"] == "yetersiz"
        assert body[section]["how"]  # "nasıl hesaplandı" metni her zaman var


def test_overview_after_demo_sync(api, demo_auth):
    api.post("/sync", json={"timezone": "Europe/Istanbul"}, headers=demo_auth)
    body = api.get("/metrics/overview", headers=demo_auth).json()

    assert body["timezone"] == "Europe/Istanbul"
    assert body["kpi"]["total_commits"] == 6
    assert body["kpi"]["repos"] == 2
    # Demo: 6 commit, 6 farklı gün (İstanbul saatine göre).
    assert body["kpi"]["active_days"] == 6
    assert sum(body["rhythm"]["by_hour"]) == 6
    # 6 commit < 10: ritim için yeterli veri yok; özet bunu açıkça söyler.
    assert body["rhythm"]["sufficiency"] == "yetersiz"
    assert "yeterli veri yok" in body["rhythm"]["summary"]
