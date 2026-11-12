"""Hibrit sınıflandırıcı testleri (küçük, testte eğitilen bir modelle)."""
import pytest

from app.classify.classifier import classify
from ml.train import char_model

# Kurallara takılmayan, yalnızca modelin öğrenebileceği küçük bir örnek küme.
TRAIN = [
    ("kullanıcı profil sayfası", "feat"), ("profil fotoğrafı yükleme", "feat"),
    ("sepet sayfası", "feat"), ("ödeme sayfası", "feat"),
    ("profil sayfasında çökmeyi önle", "fix"), ("boş sepette patlama", "fix"),
    ("ödeme sırasında patlama", "fix"), ("sepette patlayan sayaç", "fix"),
]


@pytest.fixture(scope="module")
def model():
    texts, labels = zip(*TRAIN)
    return char_model().fit(list(texts), list(labels))


def test_rules_win_before_model(model):
    c = classify("tarih biçimi hatası düzeltildi", model)
    assert (c.label, c.label_tr, c.source) == ("fix", "Hata düzeltme", "kural")
    assert c.confidence is None


def test_model_decides_when_rules_cannot(model):
    c = classify("fatura sayfası", model)  # kurallara uymuyor
    assert c.source in ("model", "belirsiz")
    if c.source == "model":
        assert c.label in ("feat", "fix") and c.confidence >= 0.5
        assert c.reason.startswith("model, %")


def test_low_confidence_is_belirsiz(model, monkeypatch):
    import app.classify.classifier as clf

    monkeypatch.setattr(clf, "THRESHOLD", 1.01)  # hiçbir olasılık eşiği geçemez
    c = clf.classify("fatura sayfası", model)
    assert (c.label, c.label_tr, c.source) == ("diger", "Belirsiz", "belirsiz")


def test_refactor_and_chore_rules_merge_into_bakim(model):
    # Kural ince sınıfı ve gerekçesini korur; çıktıda ikisi tek sade sınıfta birleşir.
    for msg, reason_part in (("servis katmanı sadeleştirildi", "düzenleme"),
                             ("gitignore güncellendi", "bakım")):
        c = classify(msg, model)
        assert (c.label, c.label_tr, c.source) == ("bakim", "Bakım ve düzenleme", "kural")
        assert reason_part in c.reason


def test_only_first_line_is_used(model):
    # Gövdedeki "düzeltildi" ilk satırın kararını değiştirmez (model ilk satırlarla eğitildi).
    c = classify("README\n\nayrıca giriş hatası düzeltildi", model)
    assert (c.label, c.source) == ("docs", "kural")


def test_belirsiz_comes_from_rules():
    from app.classify.classifier import classify as real_classify

    c = real_classify("Merge branch 'dev'")
    assert (c.label, c.label_tr, c.source) == ("diger", "Belirsiz", "kural")


def test_saved_app_model_loads():
    import app.classify.classifier as clf

    clf._model.cache_clear()
    m = clf._model()
    assert m is not None
    classes = set(map(str, m.classes_))
    # Model yalnız yazar önekleriyle eğitildi (ml/llm_ref.py): öneklerde "Belirsiz" yok;
    # "Belirsiz" yalnızca kurallardan gelir (ör. Revert, Merge).
    assert classes == {"feat", "fix", "docs", "bakim", "test"}
    c = clf.classify("kullanıcı profili sayfası")
    assert c.source in ("kural", "model") and isinstance(c.label, str)


def test_works_without_model_file(monkeypatch):
    import app.classify.classifier as clf

    monkeypatch.setattr(clf, "_model", lambda: None)
    assert clf.classify("README").label == "docs"  # kural
    assert clf.classify("fatura sayfası").source == "belirsiz"  # model yok
