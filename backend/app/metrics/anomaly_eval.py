"""Enjeksiyon testi: sentetik demoya bilerek eklenen yoğunluğu iki yöntem buluyor mu?

    py -m app.metrics.anomaly_eval

Sentetik veri yöntemin genel başarısını kanıtlamaz; yalnızca bilinen bir olayı yakalayıp
yakalamadığını ve kaç yanlış alarm verdiğini gösterir (docs/metrikler.md).
"""
from datetime import date, datetime, timedelta

from app.metrics.activity import CommitPoint
from app.metrics.anomaly import Z_THRESHOLD, daily_features, iforest_flags, robust_z
from app.sync import demo_generator as gen


def evaluate(seed: int = gen.SEED) -> list[dict]:
    data = gen.generate(seed)
    points = [
        CommitPoint(datetime.fromisoformat(c["authored_at"]), c["additions"] + c["deletions"])
        for r in data["repos"] for c in r["commits"]
    ]
    days = daily_features(points, "Europe/Istanbul")
    inj = data["_injected"][0]
    start, end = date.fromisoformat(inj["start"]), date.fromisoformat(inj["end"])
    # Olay akşam başlayıp gece yarısını geçtiği için son günün ertesi sabahı da pencerede.
    window = {start + timedelta(days=k) for k in range((end - start).days + 2)}
    injected_active = sorted(d.day for d in days if d.day in window)

    zs, _, _ = robust_z([d.commits for d in days])
    methods = {
        f"Robust z (MAD), z > {Z_THRESHOLD}": [zs is not None and z > Z_THRESHOLD for z in (zs or [0] * len(days))],
        "Isolation Forest (5 özellik, %5)": iforest_flags(days),
    }
    rows = []
    for name, flags in methods.items():
        flagged = {d.day for d, f in zip(days, flags) if f}
        hits = flagged & window
        rows.append({
            "yöntem": name,
            "aktif gün": len(days),
            "işaretlenen": len(flagged),
            "olay bulundu": "evet" if hits else "hayır",
            "olay günü yakalanan": f"{len(hits)}/{len(injected_active)}",
            "yanlış alarm": len(flagged - window),
        })
    return rows


def evaluate_many(n_seeds: int = 30) -> list[dict]:
    """Tek bir sentetik kişi şans eseri iyi/kötü sonuç verebilir: n farklı tohumla tekrarla."""
    per_method: dict[str, list[dict]] = {}
    for seed in range(1, n_seeds + 1):
        for row in evaluate(seed):
            per_method.setdefault(row["yöntem"], []).append(row)
    out = []
    for name, rows in per_method.items():
        caught = [int(r["olay günü yakalanan"].split("/")[0]) for r in rows]
        total = [int(r["olay günü yakalanan"].split("/")[1]) for r in rows]
        alarms = [r["yanlış alarm"] for r in rows]
        out.append({
            "yöntem": name,
            "kişi (tohum)": len(rows),
            "olayı bulma oranı": f"{sum(r['olay bulundu'] == 'evet' for r in rows)}/{len(rows)}",
            "olay günü yakalama": f"%{round(100 * sum(caught) / sum(total))}",
            "ort. yanlış alarm": f"{sum(alarms) / len(alarms):.1f}",
            "en çok yanlış alarm": max(alarms),
        })
    return out


def to_markdown(rows: list[dict]) -> str:
    cols = list(rows[0])
    lines = ["| " + " | ".join(cols) + " |", "|" + "---|" * len(cols)]
    lines += ["| " + " | ".join(str(r[c]) for c in cols) + " |" for r in rows]
    return "\n".join(lines)


if __name__ == "__main__":
    print(f"Demo kullanıcı (tohum {gen.SEED}):\n")
    print(to_markdown(evaluate()))
    print("\n30 farklı sentetik kişi (tohum 1-30):\n")
    print(to_markdown(evaluate_many()))
