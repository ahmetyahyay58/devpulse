"""/metrics uç noktalarının testleri."""


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
