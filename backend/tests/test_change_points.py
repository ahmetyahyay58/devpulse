"""Değişim noktaları birim testleri (docs/metrikler.md "Değişim noktaları")."""
from datetime import date, datetime, timedelta

from app.metrics import change_points as cp
from app.metrics.sufficiency import Sufficiency

TODAY = date(2026, 11, 12)  # Perşembe; bu haftanın Pazartesi'si 9 Kasım
MONDAY = date(2026, 11, 9)


def commits(per_week: list[int]) -> list[datetime]:
    """Son len(per_week) hafta için her haftaya verilen sayıda commit (Salı 10:00)."""
    first = MONDAY - timedelta(weeks=len(per_week) - 1)
    return [
        datetime.combine(first + timedelta(weeks=w, days=1), datetime.min.time()).replace(hour=10)
        for w, n in enumerate(per_week) for _ in range(n)
    ]


def test_weekly_series_starts_at_first_commit_week_and_ends_this_week():
    s = cp.weekly_series(commits([2, 0, 3]), TODAY)
    assert s == [(MONDAY - timedelta(weeks=2), 2), (MONDAY - timedelta(weeks=1), 0), (MONDAY, 3)]


def test_weekly_series_caps_at_52_weeks():
    s = cp.weekly_series(commits([1] * 60), TODAY)
    assert len(s) == 52 and s[-1][0] == MONDAY and sum(c for _, c in s) == 52


def test_clear_level_shift_is_found():
    # 20 hafta 1 commit, 20 hafta 6 commit (küçük oynamayla)
    weeks = [1, 2, 1, 1, 0] * 4 + [6, 5, 7, 6, 6] * 4
    out = cp.build_change_points(commits(weeks), TODAY)
    assert [p.weeks for p in out.phases] == [20, 20]
    assert [p.mean for p in out.phases] == [1.0, 6.0]
    assert out.phases[1].start == MONDAY - timedelta(weeks=19)
    assert "1 değişim noktası" in out.summary and "1 commit'ten 6 commit'e arttı" in out.summary
    assert [w.phase for w in out.weeks] == [0] * 20 + [1] * 20


def test_single_burst_week_is_not_a_phase():
    # Sessiz haftalar arasında tek bir 25 commit'lik hafta: düzey değişimi değil (gerçek veriden)
    weeks = [2] + [0] * 35 + [25, 0, 1] + [0] * 12 + [5]
    out = cp.build_change_points(commits(weeks), TODAY)
    assert len(out.phases) == 1


def test_stopping_is_found():
    weeks = [3, 4, 2, 5, 3, 4, 3, 2, 4, 3, 3, 4, 5, 2, 3] + [0] * 15
    out = cp.build_change_points(commits(weeks), TODAY)
    assert [p.weeks for p in out.phases] == [15, 15] and out.phases[1].mean == 0
    assert "azaldı" in out.summary


def test_noise_alone_gives_single_phase():
    weeks = [2, 3, 1, 2, 4, 2, 3, 2, 1, 3, 2, 2] * 3
    out = cp.build_change_points(commits(weeks), TODAY)
    assert len(out.phases) == 1
    assert "belirgin bir düzey değişimi yok" in out.summary


def test_phases_never_exceed_six():
    weeks = sum(([0] * 4 + [10] * 4 for _ in range(6)), [])  # 12 kısa evre
    out = cp.build_change_points(commits(weeks), TODAY)
    assert 1 <= len(out.phases) <= cp.MAX_PHASES
    assert all(p.weeks >= cp.MIN_PHASE_WEEKS for p in out.phases)


def test_noise_sigma_ignores_level_and_falls_back_to_one():
    assert cp.noise_sigma([5] * 10) == 1.0  # fark yok -> 1
    assert cp.noise_sigma([1, 1, 1, 9, 9, 9]) == 1.0  # tek sıçrama gürültü sayılmaz


def test_sufficiency_thresholds():
    assert cp.build_change_points(commits([5] * 11), TODAY).sufficiency == Sufficiency.NONE  # 11 hafta
    assert cp.build_change_points(commits([0] * 11 + [9]), TODAY).sufficiency == Sufficiency.NONE  # 9 commit
    assert cp.build_change_points(commits([1] * 12), TODAY).sufficiency == Sufficiency.LOW
    assert cp.build_change_points(commits([1] * 26), TODAY).sufficiency == Sufficiency.NORMAL


def test_no_commits_does_not_crash():
    out = cp.build_change_points([], TODAY)
    assert out.sufficiency == Sufficiency.NONE and "yeterli veri yok" in out.summary
