"""Olağan dışı yoğun günler (anomali). Tanım: docs/metrikler.md "Olağan dışı günler".

Ana yöntem istatistikseldir (robust z-skoru, medyan/MAD). Isolation Forest yalnızca kıyas
içindir ve gözetimsizdir (etiketli veri yok). Yalnızca aktif günler incelenir.
"""
from dataclasses import dataclass
from datetime import date
from math import log1p
from statistics import median

from pydantic import BaseModel

from app.metrics import activity, sufficiency
from app.metrics.activity import CommitPoint
from app.metrics.sufficiency import Sufficiency

Z_THRESHOLD = 3.5  # Iglewicz ve Hoaglin (1993)
MAD_CONSTANT = 0.6745  # normal dağılımda MAD'i standart sapmaya ölçekler
IFOREST_CONTAMINATION = 0.05
IFOREST_SEED = 0

HOW = (
    "Yalnızca en az bir commit attığın günler incelendi. Her günün commit sayısı için robust "
    "z-skoru hesaplandı: z = 0,6745 × (gün − medyan) / MAD (MAD: medyandan uzaklıkların medyanı). "
    "z > 3,5 olan gün olağan dışı sayıldı (Iglewicz ve Hoaglin, 1993). Ortalama yerine medyan "
    "kullanıldığı için tek bir çok yoğun gün ölçüyü bozmaz. Bu bir yargı değildir; yalnızca "
    "alışkanlığının dışında kalan günleri gösterir."
)


@dataclass(frozen=True)
class DayFeatures:
    day: date
    commits: int
    lines: int  # bilinmeyen satırlar 0 sayılır
    night_share: float  # 00-06 arası commit oranı
    sessions: int
    span_hours: float  # gün içinde ilk ve son commit arası

    def vector(self) -> list[float]:
        """Isolation Forest'a giden özellikler (satır sayısı log ile sıkıştırılır)."""
        return [self.commits, log1p(self.lines), self.night_share, self.sessions, self.span_hours]


def daily_features(points: list[CommitPoint], tz: str | None) -> list[DayFeatures]:
    by_day: dict[date, list[tuple]] = {}
    for p in points:
        local = activity.to_local([p], tz)[0]
        by_day.setdefault(local.date(), []).append((local, p.lines or 0))
    out = []
    for day in sorted(by_day):
        items = sorted(by_day[day])
        times = [t for t, _ in items]
        out.append(DayFeatures(
            day=day,
            commits=len(items),
            lines=sum(lines for _, lines in items),
            night_share=sum(1 for t in times if t.hour in activity.NIGHT_HOURS) / len(times),
            sessions=len(activity.sessions(times)),
            span_hours=(times[-1] - times[0]).total_seconds() / 3600,
        ))
    return out


def robust_z(values: list[float]) -> tuple[list[float] | None, float, float]:
    """(z-skorları, medyan, MAD). MAD 0 ise z hesaplanamaz: (None, medyan, 0)."""
    med = median(values)
    mad = median(abs(v - med) for v in values)
    if mad == 0:
        return None, med, 0.0
    return [MAD_CONSTANT * (v - med) / mad for v in values], med, mad


def iforest_flags(days: list[DayFeatures]) -> list[bool]:
    """Kıyas yöntemi: çok değişkenli Isolation Forest. True = olağan dışı."""
    from sklearn.ensemble import IsolationForest  # ağır kütüphane: yalnızca gerekince yüklenir

    model = IsolationForest(contamination=IFOREST_CONTAMINATION, random_state=IFOREST_SEED)
    labels = model.fit_predict([d.vector() for d in days])  # -1: aykırı, 1: olağan
    # bool(): numpy'nin np.True_ tipi yerine düz Python bool (JSON vb. için güvenli).
    return [bool(label == -1) for label in labels]


class AnomalyDay(BaseModel):
    day: date
    commits: int
    lines: int
    robust_z: float


class AnomaliesOut(BaseModel):
    flagged: list[AnomalyDay]  # z'si en yüksekten başlayarak
    active_days: int
    median_commits: float | None
    mad: float | None
    threshold: float = Z_THRESHOLD
    sufficiency: Sufficiency
    basis: str
    summary: str
    how: str = HOW


def _fmt(d: date) -> str:
    return f"{d.day:02d}.{d.month:02d}.{d.year}"


def build_anomalies(points: list[CommitPoint], tz: str | None) -> AnomaliesOut:
    days = daily_features(points, tz)
    suff = sufficiency.anomaly(len(days))
    basis = f"{len(days)} aktif gün"
    if not days:
        return AnomaliesOut(flagged=[], active_days=0, median_commits=None, mad=None,
                            sufficiency=suff, basis=basis,
                            summary=f"Bu metrik için henüz yeterli veri yok ({basis}).")

    zs, med, mad = robust_z([d.commits for d in days])
    flagged = [] if zs is None else sorted(
        (AnomalyDay(day=d.day, commits=d.commits, lines=d.lines, robust_z=round(z, 2))
         for d, z in zip(days, zs) if z > Z_THRESHOLD),
        key=lambda a: a.robust_z, reverse=True,
    )

    if suff == Sufficiency.NONE:
        summary = f"Bu metrik için henüz yeterli veri yok ({basis})."
    elif zs is None:
        summary = "Aktif günlerinin çoğunda aynı sayıda commit var; sapma ölçülemedi."
    elif not flagged:
        summary = "Alışkanlığının belirgin dışında yoğun bir gün bulunmadı."
    else:
        top = flagged[0]
        summary = (f"{len(flagged)} gün alışkanlığının belirgin dışında yoğundu. En yoğunu "
                   f"{_fmt(top.day)}: {top.commits} commit (aktif günlerde medyan {med:g}).")
    return AnomaliesOut(flagged=flagged, active_days=len(days), median_commits=med, mad=mad,
                        sufficiency=suff, basis=basis, summary=summary)
