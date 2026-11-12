"""Hibrit tasarım seçimi: YALNIZCA eğitim verisinde, repo bazında 5 katlı çapraz doğrulama.

    py -m ml.tune

Test verisine bakılmaz (bakılsaydı tasarım test verisine göre seçilmiş olur, test sonucu
olduğundan iyi görünürdü). Seçilen ayar sonra ml/train.py ile testte bir kez ölçülür.
"""
import numpy as np
from sklearn.model_selection import GroupKFold

from app.classify.rules import classify_rules
from ml.train import char_model, load, split

STRONG = ("önek", "geri alma", "dosya silme", "test ile", "Markdown")  # yalnız kesin kurallar


def out_of_fold(train: list[dict]) -> tuple[np.ndarray, list[str], list]:
    """Her örnek için, o örneğin reposunu görmemiş modelin olasılıkları."""
    texts = [r["text"] for r in train]
    labels = [r["label"] for r in train]
    groups = [r["repo"] for r in train]
    proba = np.zeros((len(train), 6))
    classes = None
    for fit_idx, pred_idx in GroupKFold(n_splits=5).split(texts, labels, groups):
        m = char_model().fit([texts[i] for i in fit_idx], [labels[i] for i in fit_idx])
        classes = list(m.classes_)
        proba[pred_idx] = m.predict_proba([texts[i] for i in pred_idx])
    return proba, labels, classes


def score(pred: list[str], gold: list[str]) -> tuple[float, float]:
    decided = [(p, g) for p, g in zip(pred, gold) if p != "diger"]
    acc = sum(p == g for p, g in zip(pred, gold)) / len(gold)
    return acc, len(decided) / len(gold)


if __name__ == "__main__":
    train, _ = split(load())  # test kısmı kullanılmaz
    proba, gold, classes = out_of_fold(train)
    rules = [classify_rules(r["text"]) for r in train]
    model_top = [classes[i] for i in proba.argmax(1)]
    conf = proba.max(1)

    covered = [i for i, r in enumerate(rules) if r]
    print(f"Eğitim (çapraz doğrulama): {len(train)} örnek")
    print(f"Kuralların karar verdiği {len(covered)} örnekte: kural doğru %{100 * np.mean([rules[i].label == gold[i] for i in covered]):.0f}, "
          f"model doğru %{100 * np.mean([model_top[i] == gold[i] for i in covered]):.0f}")
    strong = [i for i, r in enumerate(rules) if r and r.reason.startswith(STRONG)]
    print(f"Yalnız kesin kurallar ({len(strong)} örnek): kural doğru %{100 * np.mean([rules[i].label == gold[i] for i in strong]):.0f}, "
          f"model doğru %{100 * np.mean([model_top[i] == gold[i] for i in strong]):.0f}\n")

    print("| seçenek | eşik | doğruluk (belirsiz = hata) | karar verilen |")
    print("|---|---|---|---|")
    for t in (0.0, 0.25, 0.3, 0.35, 0.4, 0.5):
        variants = {
            "Yalnız model": [m if c >= t else "diger" for m, c in zip(model_top, conf)],
            "Kural önce (tüm kurallar)": [r.label if r else (m if c >= t else "diger")
                                          for r, m, c in zip(rules, model_top, conf)],
            "Kesin kural önce, sonra model": [
                r.label if r and r.reason.startswith(STRONG) else (m if c >= t else "diger")
                for r, m, c in zip(rules, model_top, conf)],
        }
        for name, pred in variants.items():
            acc, cov = score(pred, gold)
            print(f"| {name} | {t} | {acc:.2f} | %{100 * cov:.0f} |")
