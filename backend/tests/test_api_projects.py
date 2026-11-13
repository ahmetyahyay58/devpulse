"""/projects uç noktası testleri."""


def test_projects_requires_session(api):
    assert api.get("/projects").status_code == 401


def test_projects_after_demo_sync(api, demo_auth):
    api.post("/sync", json={}, headers=demo_auth)
    body = api.get("/projects", headers=demo_auth).json()

    by_name = {p["name"]: p for p in body["projects"]}
    # Demo: "notlar" hiçbir kontrolü geçmez (0), "hava-durumu-api" hepsini geçer (100).
    assert by_name["notlar"]["score"] == 0
    assert by_name["hava-durumu-api"]["score"] == 100
    assert by_name["hava-durumu-api"]["commit_count"] == 4
    assert by_name["notlar"]["commit_count"] == 2
    assert [p["name"] for p in body["projects"]] == ["notlar", "hava-durumu-api"]  # en eksikli önce

    s = body["summary"]
    assert (s["scored_count"], s["average_score"]) == (2, 50)
    # README boyutu demo_small'da yok: hava-durumu-api'de içerik bilinmiyor, notlar'da README yok.
    assert s["missing_counts"] == {"readme": 1, "readme_content": 1, "description": 1, "license": 1, "topics": 1}

    hava = by_name["hava-durumu-api"]
    assert hava["topics"] == ["fastapi", "weather"]
    assert hava["state"] in {"aktif", "durgun"} and hava["suggestion"] is None
    assert len(hava["weekly_commits"]) == 12 and sum(hava["weekly_commits"]) <= hava["commit_count"]
    assert by_name["notlar"]["suggestion"].startswith("Şu eksikleri kapatırsan skor 50 puan artar: README, ")
    assert "kod kalitesini" in s["how"]


def test_user_without_repos(api, login_as):
    body = api.get("/projects", headers=login_as("U_bos", "bos")).json()
    assert body["projects"] == []
    assert body["summary"]["average_score"] is None
