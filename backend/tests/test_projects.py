"""Proje sağlığı birim testleri (beklenen değerler elle hesaplandı, docs/metrikler.md)."""
from datetime import datetime, timedelta, timezone

from app.metrics.projects import RepoFacts, build_projects, project_health

NOW = datetime(2026, 11, 12, 12, tzinfo=timezone.utc)


def repo(**overrides) -> RepoFacts:
    base = dict(
        name="proje", is_owner=True, is_fork=False, is_private=False, primary_language="Python",
        description="Açıklama", has_readme=True, license_spdx="MIT", topics=["api"],
        pushed_at=NOW - timedelta(days=3), commit_count=5,
    )
    return RepoFacts(**(base | overrides))


def statuses(p):
    return {c.key: c.status for c in p.checks}


def test_complete_repo_scores_100():
    p = project_health(repo(), NOW)
    assert p.score == 100
    assert all(c.hint is None for c in p.checks)
    assert p.days_since_push == 3


def test_missing_items_lower_score_and_get_hints():
    # Lisans (20) ve topic (20) eksik: 60/100
    p = project_health(repo(license_spdx=None, topics=[]), NOW)
    assert p.score == 60
    assert statuses(p) == {"readme": "ok", "description": "ok", "license": "missing", "topics": "missing"}
    hints = {c.key: c.hint for c in p.checks if c.hint}
    assert set(hints) == {"license", "topics"} and "LICENSE" in hints["license"]


def test_blank_description_counts_as_missing():
    assert statuses(project_health(repo(description="   "), NOW))["description"] == "missing"


def test_unrecognized_license_still_counts_as_present():
    assert project_health(repo(license_spdx="NOASSERTION"), NOW).score == 100


def test_unknown_readme_is_excluded_not_penalized():
    # README bilinmiyor: payda 65 (25+20+20). Açıklama eksik: 40/65 -> 62
    p = project_health(repo(has_readme=None, description=None), NOW)
    assert statuses(p)["readme"] == "unknown"
    assert p.score == round(40 / 65 * 100) == 62


def test_forks_and_others_repos_are_not_scored():
    fork = project_health(repo(is_fork=True, has_readme=False), NOW)
    other = project_health(repo(is_owner=False), NOW)
    assert (fork.scored, fork.score) == (False, None) and "Fork" in fork.not_scored_reason
    assert (other.scored, other.score) == (False, None) and "Başkasına ait" in other.not_scored_reason


def test_summary_average_most_common_gap_and_order():
    out = build_projects([
        repo(name="tam"),                                             # 100
        repo(name="lisanssiz", license_spdx=None),                    # 80
        repo(name="bos", has_readme=False, description=None,          # 0
             license_spdx=None, topics=[]),
        repo(name="katki", is_owner=False, license_spdx=None),       # puanlanmaz
    ], NOW)

    s = out.summary
    assert s.scored_count == 3
    assert s.average_score == round((100 + 80 + 0) / 3) == 60
    assert s.missing_counts == {"readme": 1, "description": 1, "license": 2, "topics": 1}
    # Puanlanmayan reponun eksikleri sayılmaz (katki'nin lisansı yok ama 2'de kaldı).
    assert s.summary == "Puanlanan 3 reponun ortalama skoru 60/100. En sık eksik: Lisans (2/3 repoda)."
    assert [p.name for p in out.projects] == ["bos", "lisanssiz", "tam", "katki"]


def test_no_scored_repos():
    out = build_projects([repo(is_fork=True)], NOW)
    assert out.summary.average_score is None
    assert "Puanlanacak kendi reponun yok" in out.summary.summary
