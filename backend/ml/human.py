"""İnsan etiketleriyle model: seçenek seçimi (çapraz doğrulama), test ve kayıt.

    py -m ml.human select     # yalnız eğitim etiketlerinde 5 katlı CV: hangi seçenek?
    py -m ml.human evaluate   # seçileni test kümesinde (tr_gold) bir kez ölç, eskiyle kıyasla
    py -m ml.human save       # seçileni uygulama modeli olarak kaydet

Tüm sistemler yalnızca mesajın İLK SATIRINA bakar (kullanıcı commit'leri çoğunlukla tek satır).
Yazar önekleri (zayıf, gürültülü etiket) atılmaz; düşük örnek ağırlığıyla eklenir.
Uygulama modeli de test repolarını hiç görmeden eğitilir: altın küme ileride yeniden
ölçüm için temiz kalır.
"""
import sys

import joblib
import numpy as np
from sklearn.model_selection import GroupKFold

from app.classify.rules import classify_rules
from ml.gold import (GOLD_LABELS, GOLD_POOL, OWN_LABELS, OWN_POOL, TRAIN_LABELS, TRAIN_POOL)
from ml.label import read_jsonl
from ml.train import MODEL_PATH, char_model, load, split

# Seçenek adı -> yazar öneki verisinin örnek ağırlığı (None: hiç kullanılmaz)
OPTIONS = {
    "Yalnız yazar önekleri (eski)": "weak-only",
    "Yalnız insan etiketleri": None,
    "İnsan + yazar (ağırlık 0,1)": 0.1,
    "İnsan + yazar (ağırlık 0,3)": 0.3,
    "İnsan + yazar (ağırlık 1,0)": 1.0,
}
CHOSEN = "İnsan + yazar (ağırlık 0,3)"  # `select` sonucuna göre güncellenir (test kümesine bakmadan)


def first_line(text: str) -> str:
    return text.strip().splitlines()[0] if text.strip() else ""


def human_train() -> list[dict]:
    labels = {r["id"]: r["label"] for r in read_jsonl(TRAIN_LABELS)}
    return [{"id": p["id"], "repo": p["id"].split("@")[0], "text": first_line(p["message"]),
             "label": labels[p["id"]]} for p in read_jsonl(TRAIN_POOL) if p["id"] in labels]


def weak_train() -> list[dict]:
    train, _ = split(load())
    return [{**r, "text": first_line(r["text"])} for r in train]


def fit(option, human: list[dict], weak: list[dict]):
    """Seçeneğe göre modeli eğitir. İnsan etiketleri ağırlık 1, yazar önekleri `option`."""
    if option == "weak-only":
        rows, weights = weak, [1.0] * len(weak)
    elif option is None:
        rows, weights = human, [1.0] * len(human)
    else:
        human_ids = {h["id"] for h in human}
        extra = [w for w in weak if w["id"] not in human_ids]  # aynı mesaj iki kez girmesin
        rows, weights = human + extra, [1.0] * len(human) + [option] * len(extra)
    model = char_model()
    model.fit([r["text"] for r in rows], [r["label"] for r in rows], clf__sample_weight=np.array(weights))
    return model


def hybrid(model, texts: list[str]) -> list[str]:
    out = []
    for text, m in zip(texts, model.predict(texts)):
        rule = classify_rules(text)
        out.append(rule.label if rule else str(m))
    return out


def select() -> None:
    human, weak = human_train(), weak_train()
    groups = [h["repo"] for h in human]
    scores: dict[tuple[str, str], list[float]] = {}
    for fit_idx, val_idx in GroupKFold(n_splits=5).split(human, groups=groups):
        fold_train = [human[i] for i in fit_idx]
        val = [human[i] for i in val_idx]
        val_ids = {v["id"] for v in val}
        fold_weak = [w for w in weak if w["id"] not in val_ids]  # doğrulama mesajı eğitimde olmasın
        texts, gold = [v["text"] for v in val], [v["label"] for v in val]
        for name, option in OPTIONS.items():
            model = fit(option, fold_train, fold_weak)
            for system, pred in (("yalnız model", list(model.predict(texts))),
                                 ("kural önce", hybrid(model, texts))):
                acc = np.mean([p == g for p, g in zip(pred, gold)])
                scores.setdefault((name, system), []).append(acc)
    print(f"İnsan etiketli eğitim verisi: {len(human)} mesaj, 5 katlı CV (repo bazında)\n")
    print("| seçenek | sistem | CV doğruluk (ort. ± sapma) |\n|---|---|---|")
    for (name, system), accs in sorted(scores.items(), key=lambda kv: -np.mean(kv[1])):
        print(f"| {name} | {system} | {np.mean(accs):.2f} ± {np.std(accs):.2f} |")


def evaluate() -> None:
    human, weak = human_train(), weak_train()
    sets = {
        "Türkçe test (94)": (read_jsonl(GOLD_POOL), read_jsonl(GOLD_LABELS)),
        "Kendi commit'lerin (33)": (read_jsonl(OWN_POOL), read_jsonl(OWN_LABELS)),
    }
    print("| model | sistem | " + " | ".join(sets) + " |\n|---|---|" + "---|" * len(sets))
    for name in ("Yalnız yazar önekleri (eski)", CHOSEN):
        model = fit(OPTIONS[name], human, weak)
        cells = {"yalnız model": [], "kural önce": []}
        for pool, labels in sets.values():
            gold = {r["id"]: r["label"] for r in labels}
            items = [p for p in pool if p["id"] in gold]
            texts = [first_line(p["message"]) for p in items]
            y = [gold[p["id"]] for p in items]
            for system, pred in (("yalnız model", list(model.predict(texts))),
                                 ("kural önce", hybrid(model, texts))):
                cells[system].append(f"{np.mean([p == g for p, g in zip(pred, y)]):.2f}")
        for system, vals in cells.items():
            print(f"| {name} | {system} | " + " | ".join(vals) + " |")


def save() -> None:
    model = fit(OPTIONS[CHOSEN], human_train(), weak_train())
    joblib.dump(model, MODEL_PATH)
    print(f"Kaydedildi: {MODEL_PATH} ({CHOSEN}; sınıflar: {list(model.classes_)})")


if __name__ == "__main__":
    {"select": select, "evaluate": evaluate, "save": save}.get(
        sys.argv[1] if len(sys.argv) > 1 else "", lambda: print(__doc__))()
