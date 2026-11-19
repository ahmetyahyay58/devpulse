"""İşbirliği metrikleri (docs/metrikler.md, "İşbirliği"): saf fonksiyon ve uç nokta."""
from datetime import date, datetime, timedelta, timezone

from app.metrics.collaboration import PrFact, build_collaboration, format_duration, group, last_months

T0 = datetime(2026, 3, 1, 10, tzinfo=timezone.utc)


def merged(hours: float, own: bool = False, start: datetime = T0) -> PrFact:
    end = start + timedelta(hours=hours)
    return PrFact(start, end, end, "MERGED", own)


def closed(own: bool = False) -> PrFact:
    return PrFact(T0, None, T0 + timedelta(days=1), "CLOSED", own)


def opened(own: bool = False) -> PrFact:
    return PrFact(T0, None, None, "OPEN", own)


def test_open_prs_are_not_in_merge_rate():
    g = group([merged(2), merged(4), closed(), opened(), opened()])
    assert (g.opened, g.merged, g.closed_unmerged, g.still_open) == (5, 2, 1, 2)
    assert g.merge_rate == 0.667  # 2 / (2 + 1); açıklar paydada yok


def test_median_not_mean_for_merge_time():
    # Aylarca açık kalan tek PR ortalamayı bozar, medyanı bozmaz.
    g = group([merged(2), merged(3), merged(24 * 90)])
    assert g.median_merge_hours == 3.0


def test_no_resolved_prs_means_no_rate():
    g = group([opened()])
    assert g.merge_rate is None and g.median_merge_hours is None


def test_own_and_others_are_separated_and_summary_uses_others():
    prs = [merged(1, own=True)] * 6 + [merged(48), merged(96), closed(), closed()]
    out = build_collaboration(prs, {2026: 5}, date(2026, 3, 10))
    assert out.own.merge_rate == 1.0  # kendi reposunda hepsi merge (şişkin oran)
    assert out.others.merge_rate == 0.5
    assert out.sufficiency == "normal"  # 10 sonuçlanmış PR
    assert out.summary.startswith("Başkalarının repolarına açılan PR: 4, merge edilen: 2 (oran %50).")
    assert "Merge süresi medyanı 3,0 gün." in out.summary


def test_summary_falls_back_to_total_when_no_other_repo_prs():
    out = build_collaboration([merged(1, own=True)] * 3, {}, date(2026, 3, 10))
    assert out.summary.startswith("Toplam açılan PR: 3")
    assert out.sufficiency == "dusuk"


def test_not_enough_data():
    out = build_collaboration([merged(5), opened()], {2025: 2}, date(2026, 3, 10))
    assert out.sufficiency == "yetersiz"
    assert "yeterli veri yok (1 sonuçlanmış PR, 2 inceleme)" in out.summary


def test_years_merge_pr_and_review_years():
    prs = [merged(1, start=datetime(2024, 5, 1, tzinfo=timezone.utc)), merged(1)]
    out = build_collaboration(prs, {2025: 3, 2026: 4}, date(2026, 3, 10))
    assert [(y.year, y.prs, y.reviews) for y in out.years] == [(2024, 1, 0), (2025, 0, 3), (2026, 1, 4)]
    assert out.reviews_total == 7 and out.reviews_this_year == 4


def test_last_months_crosses_year_boundary():
    months = last_months(date(2026, 3, 10))
    assert len(months) == 12 and months[0] == "2025-04" and months[-1] == "2026-03"


def test_monthly_merge_time_by_merge_month_with_gaps():
    jan = datetime(2026, 1, 5, tzinfo=timezone.utc)
    prs = [
        merged(10, start=jan), merged(30, start=jan), merged(20, start=jan),  # ocak: medyan 20
        merged(24 * 40, start=jan),  # ocakta açıldı, şubatta merge edildi: şubat ayına sayılır
        closed(), opened(),  # merge edilmeyenler aylara girmez
    ]
    out = build_collaboration(prs, {}, date(2026, 3, 10))
    by = {m.month: m for m in out.monthly}
    assert out.monthly_group == "others"
    assert (by["2026-01"].merged, by["2026-01"].median_merge_hours) == (3, 20.0)
    assert (by["2026-02"].merged, by["2026-02"].median_merge_hours) == (1, 960.0)
    assert (by["2025-12"].merged, by["2025-12"].median_merge_hours) == (0, None)  # boş ay 0 değil


def test_monthly_uses_others_rule_and_falls_back_to_total():
    own_fast = [merged(0.1, own=True)] * 5
    out = build_collaboration(own_fast + [merged(48)], {}, date(2026, 3, 10))
    assert out.monthly_group == "others"
    assert {m.month: m.merged for m in out.monthly}["2026-03"] == 1  # kendi repondakiler karışmaz
    out = build_collaboration(own_fast, {}, date(2026, 3, 10))
    assert out.monthly_group == "total"
    assert {m.month: m.merged for m in out.monthly}["2026-03"] == 5


def test_contribution_balance_counts_and_share():
    out = build_collaboration([merged(1, own=True)] * 3 + [merged(5)], {}, date(2026, 3, 10),
                              commits_own=90, commits_others=10)
    assert (out.balance_commits.own, out.balance_commits.others, out.balance_commits.others_share) == (90, 10, 0.1)
    assert (out.balance_prs.own, out.balance_prs.others, out.balance_prs.others_share) == (3, 1, 0.25)
    empty = build_collaboration([], {}, date(2026, 3, 10))
    assert empty.balance_commits.others_share is None and empty.balance_prs.others_share is None


def test_format_duration():
    assert format_duration(5.4) == "5 saat"
    assert format_duration(47) == "47 saat"
    assert format_duration(60) == "2,5 gün"


def test_endpoint_with_small_demo(api, demo_auth):
    assert api.get("/metrics/collaboration").status_code == 401
    api.post("/sync", json={}, headers=demo_auth)
    body = api.get("/metrics/collaboration", headers=demo_auth).json()
    # tests/fixtures/demo_small.json: 1 kendi (merge), 3 başkası (merge, kapalı, açık); 3 inceleme
    assert (body["total"]["opened"], body["others"]["opened"], body["own"]["merged"]) == (4, 3, 1)
    assert body["others"]["merge_rate"] == 0.5
    assert body["reviews_total"] == 3
    assert body["sufficiency"] == "dusuk"  # 3 sonuçlanmış PR
    assert body["how"]
    # Küçük demoda iki repo da kendi: başkalarına commit yok; PR'lar 1 kendi, 3 başkası.
    assert body["balance_commits"]["others"] == 0 and body["balance_commits"]["own"] > 0
    assert (body["balance_prs"]["own"], body["balance_prs"]["others"]) == (1, 3)


def test_resync_replaces_rows_instead_of_duplicating(api, db, demo_auth):
    from sqlalchemy import func, select

    from app.models import PullRequest
    api.post("/sync", json={}, headers=demo_auth)
    api.post("/sync", json={}, headers=demo_auth)
    assert db.scalar(select(func.count()).select_from(PullRequest)) == 4
