"""Sınıf sadeleştirme: hangi birleştirme gerçekten işe yarıyor?

    py -m ml.merge select     # yalnız 200 insan eğitim etiketinde 5 katlı CV
    py -m ml.merge evaluate   # seçileni test kümesinde bir kez ölç
    py -m ml.merge save       # seçileni uygulama modeli olarak kaydet (app/classify/model.joblib)

Sınıf azalınca doğruluk kendiliğinden artar (şans eseri tutma olasılığı büyür). Bu yüzden
Cohen's kappa da raporlanır: şans eseri beklenen uyuşmayı çıkarır, sınıf sayısından bağımsız
karşılaştırılabilir (0: şanstan farksız, 1: tam uyuşma).
"""
import sys

import numpy as np
from sklearn.metrics import cohen_kappa_score
from sklearn.model_selection import GroupKFold

from app.classify.rules import classify_rules
from ml.gold import GOLD_LABELS, GOLD_POOL, OWN_LABELS, OWN_POOL
from ml.human import OPTIONS, first_line, human_train, weak_train
from ml.label import read_jsonl
from ml.train import char_model

# Birleştirme adı -> {eski etiket: yeni etiket} (listede olmayan etiket aynen kalır)
MERGES = {
    "7 sınıf (şimdiki)": {},
    "6: Kod düzenleme + Bakım": {"refactor": "bakim", "chore": "bakim"},
    "5: + Test": {"refactor": "bakim", "chore": "bakim", "test": "bakim"},
    "4: + Hata düzeltme": {"refactor": "diger_is", "chore": "diger_is", "test": "diger_is",
                           "fix": "diger_is"},
}
WEAK_WEIGHT = OPTIONS["İnsan + yazar (ağırlık 0,3)"]
CHOSEN = "6: Kod düzenleme + Bakım"  # `select` sonucuna göre (test kümesine bakmadan)


def remap(label: str, mapping: dict) -> str:
    return mapping.get(label, label)


def fit(mapping: dict, human: list[dict], weak: list[dict]):
    human_ids = {h["id"] for h in human}
    extra = [w for w in weak if w["id"] not in human_ids]
    rows = human + extra
    weights = np.array([1.0] * len(human) + [WEAK_WEIGHT] * len(extra))
    model = char_model()
    model.fit([r["text"] for r in rows], [remap(r["label"], mapping) for r in rows],
              clf__sample_weight=weights)
    return model


def predict(model, texts: list[str], mapping: dict) -> list[str]:
    """Kural önce, sonra model; kural çıktısı da aynı birleştirmeden geçer."""
    out = []
    for text, m in zip(texts, model.predict(texts)):
        rule = classify_rules(text)
        out.append(remap(rule.label, mapping) if rule else str(m))
    return out


def scores(pred: list[str], gold: list[str]) -> tuple[float, float]:
    return float(np.mean([p == g for p, g in zip(pred, gold)])), float(cohen_kappa_score(gold, pred))


def select() -> None:
    human, weak = human_train(), weak_train()
    groups = [h["repo"] for h in human]
    print("| birleştirme | sınıf | CV doğruluk | CV kappa | en sık sınıf tabanı |\n|---|---|---|---|---|")
    for name, mapping in MERGES.items():
        accs, kappas, bases = [], [], []
        for fit_idx, val_idx in GroupKFold(n_splits=5).split(human, groups=groups):
            fold = [human[i] for i in fit_idx]
            val = [human[i] for i in val_idx]
            val_ids = {v["id"] for v in val}
            model = fit(mapping, fold, [w for w in weak if w["id"] not in val_ids])
            gold = [remap(v["label"], mapping) for v in val]
            acc, kappa = scores(predict(model, [v["text"] for v in val], mapping), gold)
            accs.append(acc)
            kappas.append(kappa)
            fold_labels = [remap(h["label"], mapping) for h in fold]
            majority = max(set(fold_labels), key=fold_labels.count)
            bases.append(np.mean([g == majority for g in gold]))
        n = len({remap(h["label"], mapping) for h in human})
        print(f"| {name} | {n} | {np.mean(accs):.2f} ± {np.std(accs):.2f} | "
              f"{np.mean(kappas):.2f} ± {np.std(kappas):.2f} | {np.mean(bases):.2f} |")


def evaluate() -> None:
    human, weak = human_train(), weak_train()
    sets = {"Türkçe test (94)": (GOLD_POOL, GOLD_LABELS), "Kendi (33)": (OWN_POOL, OWN_LABELS)}
    print("| birleştirme | " + " | ".join(f"{s} doğruluk / kappa" for s in sets) + " |\n|---|"
          + "---|" * len(sets))
    for name in ("7 sınıf (şimdiki)", CHOSEN):
        mapping = MERGES[name]
        model = fit(mapping, human, weak)
        cells = []
        for pool_path, labels_path in sets.values():
            gold = {r["id"]: r["label"] for r in read_jsonl(labels_path)}
            items = [p for p in read_jsonl(pool_path) if p["id"] in gold]
            pred = predict(model, [first_line(p["message"]) for p in items], mapping)
            acc, kappa = scores(pred, [remap(gold[p["id"]], mapping) for p in items])
            cells.append(f"{acc:.2f} / {kappa:.2f}")
        print(f"| {name} | " + " | ".join(cells) + " |")


def save() -> None:
    """Uygulama modeli: seçilen birleştirmeyle, test repolarını görmeden eğitilir."""
    import joblib

    from ml.train import MODEL_PATH

    model = fit(MERGES[CHOSEN], human_train(), weak_train())
    joblib.dump(model, MODEL_PATH)
    print(f"Kaydedildi: {MODEL_PATH} ({CHOSEN}; sınıflar: {[str(c) for c in model.classes_]})")


if __name__ == "__main__":
    {"select": select, "evaluate": evaluate, "save": save}.get(
        sys.argv[1] if len(sys.argv) > 1 else "", lambda: print(__doc__))()
