"""Hibrit commit türü sınıflandırıcı: önek/kural -> model -> belirsiz.

Model (harf parçası TF-IDF + lojistik regresyon) ml/train.py ile eğitilir ve
app/classify/model.joblib dosyasına kaydedilir. Dosya yoksa yalnızca kurallar çalışır.
Commit mesajları hiçbir dış hizmete (LLM vb.) gönderilmez; sınıflandırma tamamen yereldir.
"""
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

from app.classify.labels import LABEL_TR
from app.classify.rules import classify_rules

MODEL_PATH = Path(__file__).resolve().parent / "model.joblib"
THRESHOLD = 0.5  # ml/train.py ile aynı olmalı


@dataclass(frozen=True)
class Classification:
    label: str  # iç anahtar (feat, fix, ...)
    label_tr: str  # uygulamada görünen ad
    source: str  # "kural" | "model" | "belirsiz"
    reason: str  # kullanıcıya gösterilecek gerekçe
    confidence: float | None  # yalnızca model kararlarında


@lru_cache(maxsize=1)
def _model():
    """Model ilk kullanımda bir kez yüklenir; dosya yoksa None (yalnız kurallar)."""
    if not MODEL_PATH.exists():
        return None
    import joblib  # ağır: yalnızca gerekince

    return joblib.load(MODEL_PATH)


def classify(message: str, model=None) -> Classification:
    rule = classify_rules(message)
    if rule:
        return Classification(rule.label, LABEL_TR[rule.label], "kural", rule.reason, None)

    model = model if model is not None else _model()
    if model is not None and message.strip():
        proba = model.predict_proba([message])[0]
        best = int(proba.argmax())
        if proba[best] >= THRESHOLD:
            label = str(model.classes_[best])
            return Classification(label, LABEL_TR[label], "model",
                                  f"model, %{round(100 * proba[best])} güven", float(proba[best]))
    return Classification("diger", LABEL_TR["diger"], "belirsiz",
                          "kurallar ve model emin değil", None)
