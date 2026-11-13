"""Proje sağlığı birim testleri (beklenen değerler elle hesaplandı, docs/metrikler.md)."""
from datetime import datetime, timedelta, timezone

from zoneinfo import ZoneInfo

from app.api.projects import weekly_counts
from app.metrics.projects import RepoFacts, build_projects, project_health

NOW = datetime(2026, 11, 12, 12, tzinfo=timezone.utc)


def repo(**overrides) -> RepoFacts:
    base = dict(
        name="proje", is_owner=True, is_fork=False, is_private=False, primary_language="Python",
        description="Açıklama", has_readme=True, license_spdx="MIT", topics=["api"],
        pushed_at=NOW - timedelta(days=3), commit_count=5, readme_bytes=1000,
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
    # Lisans (20) ve topic (15) eksik: 65/100
    p = project_health(repo(license_spdx=None, topics=[]), NOW)
    assert p.score == 65
    assert statuses(p) == {
        "readme": "ok", "readme_content": "ok", "description": "ok", "license": "missing", "topics": "missing",
    }
    hints = {c.key: c.hint for c in p.checks if c.hint}
    assert set(hints) == {"license", "topics"} and "LICENSE" in hints["license"]


def test_blank_description_counts_as_missing():
    assert statuses(project_health(repo(description="   "), NOW))["description"] == "missing"


def test_unrecognized_license_still_counts_as_present():
    assert project_health(repo(license_spdx="NOASSERTION"), NOW).score == 100


def test_unknown_readme_is_excluded_not_penalized():
    # README bilinmiyor (içeriği de): payda 55 (20+20+15). Açıklama eksik: 35/55 -> 64
    p = project_health(repo(has_readme=None, description=None), NOW)
    assert statuses(p)["readme"] == statuses(p)["readme_content"] == "unknown"
    assert p.score == round(35 / 55 * 100) == 64


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
    assert s.missing_counts == {"readme": 1, "readme_content": 1, "description": 1, "license": 2, "topics": 1}
    # Puanlanmayan reponun eksikleri sayılmaz (katki'nin lisansı yok ama 2'de kaldı).
    assert s.summary == "Puanlanan 3 reponun ortalama skoru 60/100. En sık eksik: Lisans (2/3 repoda)."
    assert [p.name for p in out.projects] == ["bos", "lisanssiz", "tam", "katki"]


def test_no_scored_repos():
    out = build_projects([repo(is_fork=True)], NOW)
    assert out.summary.average_score is None
    assert "Puanlanacak kendi reponun yok" in out.summary.summary


def test_short_readme_fails_content_check():
    # README var ama 120 bayt: içerik (15) eksik -> 85
    p = project_health(repo(readme_bytes=120), NOW)
    assert statuses(p)["readme_content"] == "missing" and p.score == 85
    assert project_health(repo(readme_bytes=300), NOW).score == 100  # eşik dahil


def test_no_readme_fails_both_checks():
    p = project_health(repo(has_readme=False, readme_bytes=None), NOW)
    assert statuses(p)["readme"] == statuses(p)["readme_content"] == "missing"
    assert p.score == 55  # 100 - 30 - 15


def test_unknown_readme_size_is_excluded():
    # Eski senkron: README var ama boyutu bilinmiyor -> içerik hesaptan çıkar, skor 100
    p = project_health(repo(readme_bytes=None), NOW)
    assert statuses(p)["readme_content"] == "unknown" and p.score == 100


def test_state_label():
    assert project_health(repo(), NOW).state == "aktif"
    assert project_health(repo(pushed_at=NOW - timedelta(days=90)), NOW).state == "aktif"
    assert project_health(repo(pushed_at=NOW - timedelta(days=91)), NOW).state == "durgun"
    assert project_health(repo(pushed_at=None), NOW).state == "durgun"
    assert project_health(repo(is_archived=True), NOW).state == "arsiv"  # arşiv önce gelir


def test_suggestion_names_two_heaviest_gaps_and_exact_gain():
    # README (30) + içerik (15) + lisans (20) eksik: skor 35. En ağır iki: README, Lisans -> 85 (+50)
    p = project_health(repo(has_readme=False, readme_bytes=None, license_spdx=None), NOW)
    assert p.score == 35
    assert p.suggestion == "Şu eksikleri kapatırsan skor 50 puan artar: README, Lisans."
    assert project_health(repo(topics=[]), NOW).suggestion == (
        "Şu eksikleri kapatırsan skor 15 puan artar: Topic."
    )


def test_no_suggestion_when_complete_or_not_scored():
    assert project_health(repo(), NOW).suggestion is None
    assert project_health(repo(is_fork=True, license_spdx=None), NOW).suggestion is None


def test_weekly_counts_local_monday_weeks():
    tz = ZoneInfo("Europe/Istanbul")
    today = datetime(2026, 11, 12).date()  # Perşembe; bu haftanın Pazartesi'si 9 Kasım
    utc = timezone.utc
    counts = weekly_counts([
        datetime(2026, 11, 8, 22, 30, tzinfo=utc),   # yerel 9 Kas 01:30 (Pzt) -> son hafta
        datetime(2026, 11, 8, 20, 0, tzinfo=utc),    # yerel 8 Kas 23:00 (Paz) -> önceki hafta
        datetime(2026, 8, 24, 9, 0, tzinfo=utc),     # 12 haftanın ilk günü (24 Ağu, Pzt)
        datetime(2026, 8, 23, 9, 0, tzinfo=utc),     # pencerenin dışında (Paz)
    ], tz, today)
    assert len(counts) == 12
    assert counts[-1] == 1 and counts[-2] == 1 and counts[0] == 1 and sum(counts) == 3
