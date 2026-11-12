"""Yapay zekâ etiketli test standardı (geliştirici kararı, 13 Kasım 2026).

    py -m ml.llm_ref evaluate   # sistemleri iki referansla ölç
    py -m ml.llm_ref save       # yeni uygulama modelini kaydet
    py -m ml.llm_ref check      # insan kontrolü: 20 rastgele yapay zekâ etiketini onayla/reddet

Karar (sonuçlar görülmeden verildi):
- Test referansı: altın kümenin yapay zekâ (Claude, kör) etiketleri. Gerekçe: mesajların
  yazarlarıyla bağımsız olarak %78 uyuşuyor (kappa 0,73); tek etiketleyicinin etiketleri iki
  kaynakla da ~%40 uyuşuyordu.
- Eğitim: yalnız yazar önekleri (bu standarda uyumlu); geliştiricinin 200 etiketi farklı bir
  yorum yansıttığından eğitime alınmaz. Kural önce, sonra model; 6 sade sınıf.
- Yapay zekâ etiketleri eğitimde ve tasarımda kullanılmaz; yalnızca ölçüm referansıdır.
"""
import random
import sys

import joblib
import numpy as np
from sklearn.metrics import cohen_kappa_score

from app.classify.labels import LABEL_TR, to_app_label
from ml.agreement import LLM_LABELS
from ml.collect import DATA_DIR, write_jsonl
from ml.gold import GOLD_LABELS, GOLD_POOL
from ml.human import first_line, human_train, weak_train
from ml.label import read_jsonl
from ml.merge import MERGES, fit as fit_merged, predict
from ml.train import MODEL_PATH

MAPPING = MERGES["6: Kod düzenleme + Bakım"]
CHECK_POOL = DATA_DIR / "llm_check_pool.jsonl"
CHECK_LABELS = DATA_DIR / "llm_check_labels.jsonl"


def fit_weak_only():
    """Yalnız yazar önekleriyle (6 sınıf) model."""
    from ml.train import char_model

    weak = weak_train()
    model = char_model()
    model.fit([w["text"] for w in weak], [to_app_label(w["label"]) for w in weak])
    return model


def _score(model, refs: dict, rules_first: bool) -> tuple[float, float, int]:
    items = [p for p in read_jsonl(GOLD_POOL) if p["id"] in refs]
    texts = [first_line(p["message"]) for p in items]
    gold = [to_app_label(refs[p["id"]]) for p in items]
    pred = predict(model, texts, MAPPING) if rules_first else [str(m) for m in model.predict(texts)]
    return float(np.mean([p == g for p, g in zip(pred, gold)])), float(cohen_kappa_score(gold, pred)), len(gold)


def evaluate() -> None:
    refs = {
        "yapay zekâ (98)": {r["id"]: r["label"] for r in read_jsonl(LLM_LABELS)},
        "geliştirici (94)": {r["id"]: r["label"] for r in read_jsonl(GOLD_LABELS)},
    }
    systems = {
        "YENİ: yazar önekleri, kural önce": (fit_weak_only(), True),
        "yeni model, yalnız model": (None, False),
        "ÖNCEKİ: insan + yazar (0,3), kural önce": (fit_merged(MAPPING, human_train(), weak_train()), True),
    }
    systems["yeni model, yalnız model"] = (systems["YENİ: yazar önekleri, kural önce"][0], False)
    print("| sistem (6 sınıf) | " + " | ".join(f"ref: {r} doğruluk / kappa" for r in refs) + " |")
    print("|---|" + "---|" * len(refs))
    for name, (model, rules_first) in systems.items():
        cells = [f"{a:.2f} / {k:.2f}" for a, k, _ in (_score(model, ref, rules_first) for ref in refs.values())]
        print(f"| {name} | " + " | ".join(cells) + " |")


def save() -> None:
    model = fit_weak_only()
    joblib.dump(model, MODEL_PATH)
    print(f"Kaydedildi: {MODEL_PATH} (yazar önekleri; model sınıfları: {[str(c) for c in model.classes_]};"
          " 'Belirsiz' yalnız kurallardan)")


def check() -> None:
    """20 rastgele yapay zekâ etiketini geliştiricinin onayına sunar (etiketi göstererek)."""
    llm = {r["id"]: r["label"] for r in read_jsonl(LLM_LABELS)}
    pool = {p["id"]: p for p in read_jsonl(GOLD_POOL)}
    if not CHECK_POOL.exists():
        ids = random.Random(20261113).sample(sorted(llm), 20)
        write_jsonl(CHECK_POOL, [{"id": i, "message": pool[i]["message"], "llm_label": llm[i]} for i in ids])
    done = {r["id"]: r for r in read_jsonl(CHECK_LABELS)}
    for row in read_jsonl(CHECK_POOL):
        if row["id"] in done:
            continue
        lines = [ln for ln in row["message"].splitlines() if ln.strip()]
        print(f"\n[{len(done) + 1}/20] >>> {lines[0]}")
        for ln in lines[1:7]:
            print("    " + ln[:110])
        print(f"Yapay zekânın etiketi: {LABEL_TR[row['llm_label']]}")
        try:
            ans = input("Katılıyor musun? (e = evet, h = hayır, q = çık) > ").strip().lstrip("﻿").lower()
        except (EOFError, KeyboardInterrupt):
            ans = "q"
        if ans == "q":
            print("Kaydedildi. Devam: py -m ml.llm_ref check")
            return
        if ans in ("e", "h"):
            entry = {"id": row["id"], "agree": ans == "e"}
            with CHECK_LABELS.open("a", encoding="utf-8") as f:
                import json
                f.write(json.dumps(entry, ensure_ascii=False) + "\n")
            done[row["id"]] = entry
    agree = sum(r["agree"] for r in done.values())
    print(f"\nBitti: yapay zekâ etiketlerinin {len(done)} örneğinden {agree} tanesine katıldın.")


if __name__ == "__main__":
    {"evaluate": evaluate, "save": save, "check": check}.get(
        sys.argv[1] if len(sys.argv) > 1 else "", lambda: print(__doc__))()
