"""Altın küme örnekleme ve değerlendirme testleri (küçük modelle, ağ yok)."""
from ml.gold import evaluate_set, predictions, sample
from ml.train import char_model, load, split

TRAIN = [("profil sayfası", "feat"), ("sepet sayfası", "feat"), ("ödeme sayfası", "feat"),
         ("sepette patlama", "fix"), ("ödemede patlama", "fix"), ("profilde patlama", "fix")]


def _model():
    texts, labels = zip(*TRAIN)
    return char_model().fit(list(texts), list(labels))


def test_sample_comes_only_from_test_repos_and_is_blind():
    rows = sample()
    _, test = split(load())
    test_ids = {r["id"] for r in test}
    assert rows and all(r["id"] in test_ids for r in rows)  # eğitim repolarından hiçbiri yok
    assert all(r["repo"] == "türkçe örnek" for r in rows)  # repo adı gizli
    # Yazarın öneki metinde yok (yalnızca değerlendirme için ayrı alanda).
    assert all(not r["message"].lower().startswith(r["author_label"] + ":") for r in rows)


def test_predictions_compare_systems():
    preds = predictions(["README güncellendi", "fatura sayfası"], _model())
    assert preds["Yalnız kurallar (karar veremezse Belirsiz)"] == ["docs", "diger"]
    assert preds["Kural önce, sonra model"][0] == "docs"
    assert preds["Kural önce, sonra model"][1] in ("feat", "fix")  # model karar verir


def test_evaluate_set_uses_only_labeled_items():
    pool = [{"id": "a", "message": "README güncellendi"}, {"id": "b", "message": "x"}]
    labels = [{"id": "a", "label": "docs"}]  # b henüz etiketlenmemiş
    rows = evaluate_set("deneme", pool, labels, _model())
    assert rows[0]["küme"] == "deneme (1)"
    assert rows[0]["doğruluk"] == "1.00"  # kurallar README'yi doğru bilir
