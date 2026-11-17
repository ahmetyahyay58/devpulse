"""CV taslağı (docs/cv.md): saf fonksiyon ve uç nokta."""
import re
from datetime import date, datetime, timezone

from app.cv.draft import CvFacts, CvRepo, build_draft, order_projects


def repo(name, score=80, commits=10, **kw):
    return CvRepo(node_id=f"R_{name}", name=name, description=kw.get("description", f"{name} açıklaması"),
                  language=kw.get("language", "Python"), tools=kw.get("tools", ["Docker"]), commit_count=commits,
                  score=score, has_readme=kw.get("readme", True), has_license=kw.get("license", True),
                  created_at=kw.get("created"), pushed_at=kw.get("pushed"))


def facts(**kw):
    base = dict(login="ben", total_commits=120, active_days=40, repo_count=5, longest_streak=9,
                languages=["Python", "Dart", "Shell"], tools=["Docker", "GitHub Actions"],
                repos=[repo("a"), repo("b", score=55), repo("c", score=None)],
                prs_to_others=6, prs_to_others_merged=4, reviews=11)
    return CvFacts(**(base | kw))


def all_items(d):
    return ([d.summary] if d.summary else []) + [i for p in d.projects for i in p.items] + d.skills + d.activity


def test_every_item_has_a_source_and_stable_id():
    d = build_draft(facts(), "tr")
    items = all_items(d)
    assert all(i.source for i in items)
    assert len({i.id for i in items}) == len(items)  # kimlikler tekil
    assert d.projects[0].items[1].id == "proj:R_a:stack"  # kimlik veriden, konumdan değil


def test_numbers_come_only_from_data():
    # Taslaktaki her sayı girdideki bir sayıdır; yer tutucular dışında sayı uydurulmaz.
    f = facts()
    allowed = {"120", "40", "5", "9", "6", "4", "11", "10"}
    for i in all_items(build_draft(f, "tr")):
        if not i.placeholder:
            assert set(re.findall(r"\d+", i.text)) <= allowed, i.text


def test_impact_is_a_placeholder_for_every_project():
    d = build_draft(facts(), "en")
    impacts = [p.items[-1] for p in d.projects]
    assert all(i.placeholder and "[" in i.text for i in impacts)


def test_projects_ordered_by_health_then_commits_first_four_selected():
    repos = [repo("low", score=40), repo("none", score=None, commits=99), repo("hi", score=90),
             repo("hi2", score=90, commits=30), repo("mid", score=70)]
    assert [r.name for r in order_projects(repos)] == ["hi2", "hi", "mid", "low", "none"]
    d = build_draft(facts(repos=repos), "tr")
    # Hepsi gönderilir (kullanıcı telefonda seçer); varsayılan seçili olan ilk 4.
    assert [(p.name, p.default_selected) for p in d.projects] == [
        ("hi2", True), ("hi", True), ("mid", True), ("low", True), ("none", False)]


def test_languages_same_ids_in_both_languages():
    tr, en = build_draft(facts(), "tr"), build_draft(facts(), "en")
    assert [i.id for i in all_items(tr)] == [i.id for i in all_items(en)]
    assert tr.summary.text.startswith("Ağırlıklı olarak Python") and en.summary.text.startswith("Mostly working with Python")


def test_documentation_wording_follows_checks():
    d = build_draft(facts(repos=[repo("x", readme=True, license=False)]), "tr")
    assert d.projects[0].items[2].text == "Commit sayısı: 10; README ile belgelendi."


def test_empty_account_has_no_numbers_and_no_empty_sections():
    d = build_draft(facts(total_commits=0, active_days=0, languages=[], tools=[], repos=[],
                          prs_to_others=0, reviews=0), "tr")
    assert d.summary is None and d.projects == [] and d.skills == [] and d.activity == []


def test_endpoint_with_small_demo(api, demo_auth):
    assert api.get("/cv/draft").status_code == 401
    api.post("/sync", json={}, headers=demo_auth)
    body = api.get("/cv/draft?lang=en", headers=demo_auth).json()
    assert body["lang"] == "en" and body["login"] == "demo-gelistirici"
    assert body["profile_url"] == "https://github.com/demo-gelistirici"
    assert body["projects"] and all(p["items"][-1]["placeholder"] for p in body["projects"])
    assert api.get("/cv/draft?lang=de", headers=demo_auth).status_code == 422


def test_project_fields_for_formats_come_from_data():
    r = repo("api", language="Python", tools=["Docker", "Python"],
             created=datetime(2025, 3, 1, 10, tzinfo=timezone.utc), pushed=datetime(2026, 2, 7, tzinfo=timezone.utc))
    p = build_draft(facts(repos=[r]), "en").projects[0]
    assert p.url == "https://github.com/ben/api"
    assert p.tech == ["Python", "Docker"]  # dil başta, tekrar yok
    assert (p.start, p.end) == (date(2025, 3, 1), date(2026, 2, 7))


def test_unknown_dates_stay_empty():
    p = build_draft(facts(repos=[repo("x")]), "tr").projects[0]
    assert p.start is None and p.end is None  # tarih uydurulmaz


def test_skill_lists_for_formats():
    d = build_draft(facts(), "tr")
    assert d.languages == ["Python", "Dart", "Shell"] and d.tools == ["Docker", "GitHub Actions"]
