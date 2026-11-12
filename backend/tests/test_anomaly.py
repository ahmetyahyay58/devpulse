"""Anomali birim testleri (beklenen değerler elle hesaplandı, docs/metrikler.md)."""
from datetime import date, datetime, timedelta, timezone

import pytest

from app.metrics import sufficiency
from app.metrics.activity import CommitPoint
from app.metrics.anomaly import build_anomalies, daily_features, iforest_flags, robust_z
from app.metrics.sufficiency import Sufficiency


def utc(*a) -> datetime:
    return datetime(*a, tzinfo=timezone.utc)


def test_robust_z_hand_computed():
    zs, med, mad = robust_z([1, 2, 2, 3, 10])
    # medyan 2; |x-2| = [1,0,0,1,8] -> MAD 1; z(10) = 0,6745*8 = 5,396; z(3) = 0,6745
    assert (med, mad) == (2, 1)
    assert zs[4] == pytest.approx(5.396)
    assert zs[3] == pytest.approx(0.6745)


def test_robust_z_with_zero_mad_returns_none():
    zs, med, mad = robust_z([2, 2, 2, 5])  # sapmaların medyanı 0
    assert zs is None and med == 2 and mad == 0


def test_daily_features_in_local_time():
    # İstanbul (UTC+3): 21:30 UTC = 00:30 ertesi gün (gece), 23:00 UTC = 02:00
    points = [CommitPoint(utc(2026, 3, 4, 21, 30), 10), CommitPoint(utc(2026, 3, 4, 23, 0), None),
              CommitPoint(utc(2026, 3, 5, 9, 0), 5)]  # 12:00, aynı gün, 10 saat sonra
    [day] = daily_features(points, "Europe/Istanbul")
    assert day.day == date(2026, 3, 5)
    assert (day.commits, day.lines) == (3, 15)  # bilinmeyen satır 0 sayıldı
    assert day.night_share == pytest.approx(2 / 3)
    assert day.sessions == 2  # 02:00 -> 12:00 arası 10 saat boşluk
    assert day.span_hours == pytest.approx(11.5)


def _days(counts: list[int], start=date(2026, 1, 1)) -> list[CommitPoint]:
    """Her gün için verilen sayıda commit (10:00'dan itibaren 10 dk arayla)."""
    points = []
    for k, n in enumerate(counts):
        base = datetime.combine(start + timedelta(days=2 * k), datetime.min.time(), timezone.utc)
        points += [CommitPoint(base + timedelta(hours=10, minutes=10 * i), 5) for i in range(n)]
    return points


def test_busy_day_is_flagged_and_summarized():
    counts = [1, 2, 3] * 10 + [15]  # 31 aktif gün; medyan 2, MAD 1; z(15) = 0,6745*13 = 8,77
    out = build_anomalies(_days(counts), None)
    assert out.sufficiency == Sufficiency.NORMAL
    [a] = out.flagged
    assert (a.commits, a.robust_z) == (15, pytest.approx(8.77))
    assert out.summary == ("1 gün alışkanlığının belirgin dışında yoğundu. En yoğunu "
                           f"{a.day.day:02d}.{a.day.month:02d}.{a.day.year}: 15 commit "
                           "(aktif günlerde medyan 2).")


def test_no_busy_day():
    out = build_anomalies(_days([1, 2, 3] * 10), None)
    assert out.flagged == []
    assert "bulunmadı" in out.summary


def test_zero_mad_is_explained():
    out = build_anomalies(_days([2] * 20 + [9]), None)
    assert out.flagged == [] and out.mad == 0
    assert "sapma ölçülemedi" in out.summary


def test_empty_and_too_few_days():
    assert build_anomalies([], None).sufficiency == Sufficiency.NONE
    few = build_anomalies(_days([1, 1, 9]), None)
    assert few.sufficiency == Sufficiency.NONE and "yeterli veri yok" in few.summary


@pytest.mark.parametrize("n, expected", [
    (9, Sufficiency.NONE), (10, Sufficiency.LOW), (29, Sufficiency.LOW), (30, Sufficiency.NORMAL),
])
def test_anomaly_thresholds(n, expected):
    assert sufficiency.anomaly(n) == expected


def test_injection_eval_finds_event_with_both_methods():
    from app.metrics.anomaly_eval import evaluate

    rows = evaluate()
    assert len(rows) == 2
    assert all(r["olay bulundu"] == "evet" for r in rows)


def test_iforest_is_deterministic_and_finds_obvious_outlier():
    points = _days([1, 2, 3, 2] * 10)
    # Çok belirgin bir aykırı gün: 40 commit, gece, uzun.
    night = utc(2026, 12, 31, 0, 0)
    points += [CommitPoint(night + timedelta(minutes=9 * i), 400) for i in range(40)]
    days = daily_features(points, None)

    flags = iforest_flags(days)
    assert flags == iforest_flags(days)  # sabit random_state: aynı sonuç
    assert flags[-1] is True  # son gün (aykırı) işaretlendi
    assert sum(flags) <= round(0.05 * len(days)) + 1  # contamination ~%5
