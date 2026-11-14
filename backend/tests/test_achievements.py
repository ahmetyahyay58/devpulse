"""Başarımlar ve yıl kıyası (docs/metrikler.md "Başarımlar", "Yıl kıyası")."""
from datetime import date, datetime, timedelta

from app.metrics.achievements import badges, year_compare
from app.metrics.projects import RepoFacts, build_projects
from app.metrics.sufficiency import Sufficiency
from app.metrics.technology import RepoTech, build_technology

TODAY = date(2026, 11, 14)
NOW = datetime(2026, 11, 14, 12)


def repo(name, **kw) -> RepoFacts:
    base = dict(name=name, is_owner=True, is_fork=False, is_private=False, primary_language="Python",
                description="a", has_readme=True, license_spdx="MIT", topics=["x"],
                pushed_at=None, commit_count=3, readme_bytes=1000)
    return RepoFacts(**(base | kw))


def by_key(bs):
    return {b.key: b for b in bs}


def streak(n: int, end: date = TODAY) -> set[date]:
    return {end - timedelta(days=i) for i in range(n)}


def test_badges_progress_and_unlock():
    projects = build_projects([
        repo("tam"),                                      # 100
        repo("lisanssiz", license_spdx=None),             # README var, lisans yok
        repo("katki", is_owner=False, commit_count=2),    # başkasının reposu
    ], NOW)
    tech = build_technology([
        RepoTech(True, False, {"Python": 80, "Dart": 15, "Shell": 4, "C": 1}),
    ])
    b = by_key(badges(streak(8), TODAY, projects, tech))

    assert b["streak7"].unlocked and (b["streak7"].current, b["streak7"].target) == (7, 7)
    assert not b["streak30"].unlocked and b["streak30"].current == 8
    assert (b["regular"].current, b["regular"].unlocked) == (8, False)
    assert b["showcase"].unlocked                        # bir repo 100
    assert (b["docs"].current, b["docs"].target, b["docs"].unlocked) == (2, 2, True)
    assert (b["license"].current, b["license"].target, b["license"].unlocked) == (1, 2, False)
    assert (b["polyglot"].current, b["polyglot"].unlocked) == (2, False)  # Shell %4 sayılmaz
    assert b["contributor"].unlocked
    assert len(b) == 8


def test_no_scored_repos_keeps_repo_badges_locked():
    b = by_key(badges(set(), TODAY, build_projects([], NOW), build_technology([])))
    assert not any(x.unlocked for x in b.values())
    assert (b["docs"].current, b["docs"].target) == (0, 1)


def test_regular_counts_only_last_90_days():
    old = {TODAY - timedelta(days=100 + i) for i in range(40)}
    recent = {TODAY - timedelta(days=i * 3) for i in range(27)}  # 0..78. gün
    b = by_key(badges(old | recent, TODAY, build_projects([], NOW), build_technology([])))
    assert (b["regular"].current, b["regular"].unlocked) == (27, True)


def at(d: date, repo_id: int = 1, hour: int = 10) -> tuple[datetime, int]:
    return datetime(d.year, d.month, d.day, hour), repo_id


def test_year_compare_same_period_only():
    commits = (
        [at(date(2026, 1, 5)), at(date(2026, 1, 6)), at(date(2026, 3, 1), 2)] * 5     # 15, 3 gün
        + [at(date(2025, 2, 1))] * 10                                                 # 10, 1 gün
        + [at(date(2025, 12, 1))] * 50  # geçen yılın 14 Kasım'ından sonra: kıyasa girmez
    )
    out = year_compare(commits, TODAY)
    s = {x.label: x for x in out.stats}
    assert (s["Commit"].this_year, s["Commit"].last_year, s["Commit"].change_pct) == (15, 10, 50)
    assert (s["Aktif gün"].this_year, s["Aktif gün"].last_year) == (3, 1)
    assert s["En uzun seri (gün)"].this_year == 2
    assert (s["Commit atılan repo"].this_year, s["Commit atılan repo"].last_year) == (2, 1)
    assert out.sufficiency == Sufficiency.NORMAL
    assert "%50 daha fazla commit" in out.summary and "daha üretken" not in out.summary


def test_year_compare_decrease_and_no_last_year():
    down = year_compare([at(date(2026, 2, 1))] * 3 + [at(date(2025, 2, 1))] * 12, TODAY)
    assert down.stats[0].change_pct == -75 and "%75 daha az" in down.summary
    assert down.sufficiency == Sufficiency.LOW
    none = year_compare([at(date(2026, 2, 1))] * 20, TODAY)
    assert none.stats[0].change_pct is None and none.sufficiency == Sufficiency.NONE


def test_leap_day_maps_to_feb_28():
    out = year_compare([at(date(2027, 2, 28))] * 2 + [at(date(2028, 2, 29))] * 2, date(2028, 2, 29))
    # 29 Şubat 2028'in geçen yıl karşılığı 28 Şubat 2027: o günün commit'leri dahil
    assert (out.stats[0].this_year, out.stats[0].last_year, out.last_year) == (2, 2, 2027)


def test_achievements_endpoint(api, demo_auth):
    assert api.get("/metrics/achievements").status_code == 401
    api.post("/sync", json={}, headers=demo_auth)
    body = api.get("/metrics/achievements", headers=demo_auth).json()
    assert len(body["badges"]) == 8
    assert body["unlocked"] == sum(b["unlocked"] for b in body["badges"])
    assert [s["label"] for s in body["year"]["stats"]][0] == "Commit"
