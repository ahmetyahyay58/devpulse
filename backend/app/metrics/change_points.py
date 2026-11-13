"""Değişim noktaları: haftalık commit sayısının kalıcı olarak değiştiği haftalar.

Tanım: docs/metrikler.md "Değişim noktaları". İstatistiksel bölütlemedir (ruptures PELT,
l1 maliyeti); makine öğrenmesi değildir, etiketli veri yoktur.
"""
import math
from datetime import date, datetime, timedelta
from statistics import median

import numpy as np
import ruptures as rpt
from pydantic import BaseModel

from app.metrics import sufficiency
from app.metrics.sufficiency import Sufficiency

WINDOW_WEEKS = 52
MIN_PHASE_WEEKS = 4
MAX_PHASES = 6  # renkler sabit sırayla verilir; döngüye girmesin

HOW = (
    "Son 52 haftanın haftalık commit sayıları (yerel saatle, Pazartesi başlayan haftalar) "
    "ruptures kütüphanesinin PELT algoritmasıyla evrelere bölündü: her evre kendi medyanıyla "
    "temsil edilir (l1), böylece tek bir çok yoğun hafta ayrı evre sayılmaz; en kısa evre 4 "
    "hafta. Ceza = 2 · σ · ln(n); σ haftadan haftaya oynamanın (gürültünün) MAD ile ölçülen "
    "büyüklüğü. Evrede haftalık ortalama gösterilir. Ceza ve en kısa evre sezgiseldir. Bu bir istatistik "
    "yöntemidir, makine öğrenmesi değildir; değişimin nedenini bilmez."
)


class WeekOut(BaseModel):
    start: date  # haftanın Pazartesi'si
    commits: int
    phase: int  # 0'dan başlayan evre numarası


class PhaseOut(BaseModel):
    index: int
    start: date
    end: date  # evrenin son haftasının Pazartesi'si
    weeks: int
    mean: float  # haftalık ortalama commit


class ChangePointsOut(BaseModel):
    weeks: list[WeekOut]
    phases: list[PhaseOut]
    sufficiency: Sufficiency
    basis: str
    summary: str
    how: str = HOW


def weekly_series(local_times: list[datetime], today: date) -> list[tuple[date, int]]:
    """Son 52 hafta (ilk commit daha yeniyse onun haftasından) için (Pazartesi, sayı)."""
    this_monday = today - timedelta(days=today.weekday())
    first = this_monday - timedelta(weeks=WINDOW_WEEKS - 1)
    if local_times:
        first_commit = min(t.date() for t in local_times)
        first = max(first, first_commit - timedelta(days=first_commit.weekday()))
    n = (this_monday - first).days // 7 + 1
    counts = [0] * n
    for t in local_times:
        i = (t.date() - first).days // 7
        if 0 <= i < n:
            counts[i] += 1
    return [(first + timedelta(weeks=i), c) for i, c in enumerate(counts)]


def noise_sigma(values: list[int]) -> float:
    """Gürültü: ardışık farkların MAD'i (düzey değişiminden etkilenmez). 0 ise 1."""
    diffs = [b - a for a, b in zip(values, values[1:])]
    if not diffs:
        return 1.0
    m = median(diffs)
    mad = median(abs(d - m) for d in diffs)
    sigma = 1.4826 * mad / math.sqrt(2)
    return sigma if sigma > 0 else 1.0


def segment(values: list[int]) -> list[int]:
    """Evre sınırları (her evrenin bitiş indeksi, son eleman len(values))."""
    n = len(values)
    if n < 2 * MIN_PHASE_WEEKS:
        return [n]
    signal = np.array(values, dtype=float).reshape(-1, 1)
    # l1: evre medyanla temsil edilir; tek bir patlama haftası evre olmaz (bkz. metrikler.md).
    algo = rpt.Pelt(model="l1", min_size=MIN_PHASE_WEEKS, jump=1).fit(signal)
    pen = 2 * noise_sigma(values) * math.log(n)
    bkps = algo.predict(pen=pen)
    while len(bkps) > MAX_PHASES:  # çok parçalıysa cezayı artır
        pen *= 2
        bkps = algo.predict(pen=pen)
    return bkps


def _fmt(d: date) -> str:
    return f"{d.day:02d}.{d.month:02d}.{d.year}"


def build_change_points(local_times: list[datetime], today: date) -> ChangePointsOut:
    series = weekly_series(local_times, today)
    values = [c for _, c in series]
    total = sum(values)
    suff = sufficiency.change_points(len(series), total)
    basis = f"{len(series)} hafta, {total} commit"

    phases: list[PhaseOut] = []
    weeks: list[WeekOut] = []
    start = 0
    for idx, end in enumerate(segment(values)):
        part = values[start:end]
        phases.append(PhaseOut(index=idx, start=series[start][0], end=series[end - 1][0],
                               weeks=len(part), mean=round(sum(part) / len(part), 1)))
        weeks += [WeekOut(start=series[i][0], commits=values[i], phase=idx) for i in range(start, end)]
        start = end

    if suff == Sufficiency.NONE:
        summary = f"Bu metrik için henüz yeterli veri yok ({basis})."
    elif len(phases) == 1:
        summary = (f"Son {len(series)} haftada belirgin bir düzey değişimi yok; haftada ortalama "
                   f"{phases[0].mean:g} commit.")
    else:
        prev, last = phases[-2], phases[-1]
        direction = "arttı" if last.mean > prev.mean else "azaldı"
        summary = (f"{len(phases) - 1} değişim noktası bulundu. Son değişim {_fmt(last.start)} "
                   f"haftasında: haftalık ortalama {prev.mean:g} commit'ten {last.mean:g} "
                   f"commit'e {direction}.")
    return ChangePointsOut(weeks=weeks, phases=phases, sufficiency=suff, basis=basis, summary=summary)
