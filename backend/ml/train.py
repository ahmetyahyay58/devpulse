"""Commit türü modeli: eğitim ve ölçüm (projedeki tek gözetimli ML bileşeni).

    py -m ml.train     # ölçüm tablosunu yazdırır, modeli app/classify/model.joblib'e kaydeder

Veri: ml/data/tr_pool.jsonl (Türkçe, öneki etiket olarak kullanılmış, önek metinden silinmiş).
Ayırma repo bazındadır: test repoları eğitimde hiç görülmez (yazım alışkanlığı ezberlenmesin).
Kıyas: en sık sınıf tabanı, kelime TF-IDF, harf parçası (3-5) TF-IDF, kurallar, hibrit.
"""
import json
from collections import Counter
from pathlib import Path

import joblib
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, confusion_matrix, f1_score
from sklearn.model_selection import GroupShuffleSplit
from sklearn.pipeline import Pipeline

from app.classify.rules import classify_rules, normalize
from ml.collect import DATA_DIR

MODEL_PATH = Path(__file__).resolve().parent.parent / "app" / "classify" / "model.joblib"
CLASSES = ["feat", "fix", "docs", "refactor", "test", "chore"]  # model "diger" öğrenmez
SEED = 20261112
TEST_SIZE = 0.2
THRESHOLD = 0.5  # model bu olasılığın altındaysa "diger" (Belirsiz)


def load() -> list[dict]:
    rows = [json.loads(line) for line in (DATA_DIR / "tr_pool.jsonl").read_text(encoding="utf-8").splitlines() if line]
    return [r for r in rows if r["label"] in CLASSES]


def char_model() -> Pipeline:
    """Harf parçası (3-5) TF-IDF: Türkçe eklerden etkilenmez ("düzelt" kökü her ekte ortak)."""
    return Pipeline([
        ("tfidf", TfidfVectorizer(analyzer="char_wb", ngram_range=(3, 5), preprocessor=normalize,
                                  min_df=2, sublinear_tf=True)),
        ("clf", LogisticRegression(max_iter=3000, class_weight="balanced", random_state=SEED)),
    ])


def word_model() -> Pipeline:
    """Kıyas: kelime TF-IDF ("düzeltildi" ile "düzeltme" ayrı kelimeler sayılır)."""
    return Pipeline([
        ("tfidf", TfidfVectorizer(analyzer="word", preprocessor=normalize, min_df=2, sublinear_tf=True)),
        ("clf", LogisticRegression(max_iter=3000, class_weight="balanced", random_state=SEED)),
    ])


def split(rows: list[dict]) -> tuple[list[dict], list[dict]]:
    splitter = GroupShuffleSplit(n_splits=1, test_size=TEST_SIZE, random_state=SEED)
    train_idx, test_idx = next(splitter.split(rows, groups=[r["repo"] for r in rows]))
    return [rows[i] for i in train_idx], [rows[i] for i in test_idx]


def hybrid_predict(model: Pipeline, texts: list[str]) -> list[tuple[str, str]]:
    """(etiket, kaynak) — kaynak: "kural", "model" ya da "belirsiz"."""
    out = []
    probas = model.predict_proba(texts)
    for text, p in zip(texts, probas):
        rule = classify_rules(text)
        if rule:
            out.append((rule.label, "kural"))
        elif p.max() >= THRESHOLD:
            out.append((model.classes_[p.argmax()], "model"))
        else:
            out.append(("diger", "belirsiz"))
    return out


def _row(name: str, y_true: list[str], y_pred: list[str], covered: int | None = None) -> dict:
    return {
        "yöntem": name,
        "doğruluk": f"{accuracy_score(y_true, y_pred):.2f}",
        "macro-F1": f"{f1_score(y_true, y_pred, labels=CLASSES, average='macro', zero_division=0):.2f}",
        "karar verilen": f"%{round(100 * (covered if covered is not None else len(y_true)) / len(y_true))}",
    }


def evaluate(train: list[dict], test: list[dict]) -> tuple[list[dict], dict]:
    x_train, y_train = [r["text"] for r in train], [r["label"] for r in train]
    x_test, y_test = [r["text"] for r in test], [r["label"] for r in test]
    rows = []

    majority = Counter(y_train).most_common(1)[0][0]
    rows.append(_row(f"Taban: hep '{majority}'", y_test, [majority] * len(y_test)))

    word = word_model().fit(x_train, y_train)
    rows.append(_row("Kelime TF-IDF + LR", y_test, list(word.predict(x_test))))

    char = char_model().fit(x_train, y_train)
    char_pred = list(char.predict(x_test))
    rows.append(_row("Harf parçası TF-IDF + LR", y_test, char_pred))

    # Kurallar yalnızca karar verdiği mesajlarda; karar vermediğinde "diger" sayılır (hata).
    rules = [classify_rules(t) for t in x_test]
    rows.append(_row("Yalnız kurallar", y_test, [r.label if r else "diger" for r in rules],
                     covered=sum(r is not None for r in rules)))

    hybrid = hybrid_predict(char, x_test)
    rows.append(_row("Hibrit (kural → model → belirsiz)", y_test, [h[0] for h in hybrid],
                     covered=sum(h[1] != "belirsiz" for h in hybrid)))

    detail = {
        "per_class_f1": dict(zip(CLASSES, f1_score(y_test, char_pred, labels=CLASSES, average=None, zero_division=0))),
        "confusion": confusion_matrix(y_test, char_pred, labels=CLASSES).tolist(),
        "hybrid_sources": Counter(h[1] for h in hybrid),
    }
    return rows, detail


def to_markdown(rows: list[dict]) -> str:
    cols = list(rows[0])
    return "\n".join(["| " + " | ".join(cols) + " |", "|" + "---|" * len(cols)]
                     + ["| " + " | ".join(str(r[c]) for c in cols) + " |" for r in rows])


if __name__ == "__main__":
    data = load()
    train, test = split(data)
    print(f"Veri: {len(data)} örnek, {len({r['repo'] for r in data})} repo")
    print(f"Eğitim: {len(train)} ({len({r['repo'] for r in train})} repo) | "
          f"Test: {len(test)} ({len({r['repo'] for r in test})} repo, eğitimde hiç yok)")
    print("Sınıf dağılımı:", dict(Counter(r["label"] for r in data)), "\n")

    rows, detail = evaluate(train, test)
    print(to_markdown(rows))
    print("\nHarf parçası modeli, sınıf başına F1:",
          {k: round(v, 2) for k, v in detail["per_class_f1"].items()})
    print("Karışıklık matrisi (satır gerçek, sütun tahmin):", CLASSES)
    for label, row in zip(CLASSES, detail["confusion"]):
        print(f"  {label:<9} {row}")
    print("Hibrit kararların kaynağı:", dict(detail["hybrid_sources"]))

    # Uygulamada kullanılacak model: ölçümden sonra tüm veriyle yeniden eğitilir.
    final = char_model().fit([r["text"] for r in data], [r["label"] for r in data])
    joblib.dump(final, MODEL_PATH)
    print(f"\nModel kaydedildi: {MODEL_PATH} ({MODEL_PATH.stat().st_size // 1024} KB)")
