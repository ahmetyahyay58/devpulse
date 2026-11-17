"""Repo kümeleri (docs/metrikler.md "Repo kümeleri"): gözetimsiz, deterministik."""
from app.metrics.clusters import build_clusters
from app.metrics.projects import ProjectOut
from app.metrics.sufficiency import Sufficiency


def repo(name, commits, days, score, active_weeks, lang="Python", owner=True, fork=False):
    return ProjectOut(
        name=name, language=lang, is_private=False, is_fork=fork, is_owner=owner, scored=score is not None,
        not_scored_reason=None, score=score, checks=[], days_since_push=days, commit_count=commits,
        state="aktif", topics=[], weekly_commits=[1] * active_weeks + [0] * (12 - active_weeks), suggestion=None,
    )


ACTIVE = [repo(f"aktif{i}", 80 + i, 2 + i, 90, 10, lang="Dart") for i in range(3)]
OLD = [repo(f"eski{i}", 5 + i, 400 + i, 30, 0) for i in range(3)]


def test_too_few_repos_no_clustering():
    out = build_clusters(ACTIVE[:2] + OLD[:2])
    assert out.sufficiency == Sufficiency.NONE and out.clusters == [] and out.k is None
    assert "en az 5" in out.summary


def test_two_clear_groups_named_by_rule_and_others_repos_ignored():
    others = [repo("baskasi", 50, 1, None, 12, owner=False), repo("fork", 50, 1, 100, 12, fork=True)]
    out = build_clusters(ACTIVE + OLD + others)
    assert out.sufficiency == Sufficiency.LOW and out.k == 2 and out.repo_count == 6
    by_name = {c.name: c for c in out.clusters}
    assert set(by_name) == {"Aktif, belgeli", "Durağan, belgesi eksik"}
    assert by_name["Aktif, belgeli"].repos == ["aktif0", "aktif1", "aktif2"]
    assert by_name["Aktif, belgeli"].top_language == "Dart"
    assert all("baskasi" not in c.repos and "fork" not in c.repos for c in out.clusters)


def test_deterministic_and_k_chosen_for_ten_plus():
    mid = [repo(f"orta{i}", 30 + i, 120 + i, 60, 3) for i in range(4)]
    a = build_clusters(ACTIVE + OLD + mid)
    b = build_clusters(list(reversed(ACTIVE + OLD + mid)))
    assert a.sufficiency == Sufficiency.NORMAL and 2 <= a.k <= 3 and a.silhouette is not None
    assert [c.repos for c in a.clusters] == [c.repos for c in b.clusters]  # sıra fark etmez


def test_endpoint(api, demo_auth):
    assert api.get("/projects/clusters").status_code == 401
    api.post("/sync", json={}, headers=demo_auth)
    body = api.get("/projects/clusters", headers=demo_auth).json()
    assert body["sufficiency"] in ("yetersiz", "dusuk", "normal")
    assert "gözetimsiz" in body["how"].lower()
