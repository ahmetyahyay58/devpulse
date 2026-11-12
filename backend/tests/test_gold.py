"""Altın küme örnekleme ve değerlendirme testleri (küçük modelle, ağ yok)."""
from ml.gold import evaluate_set, is_clear, predictions, sample, sample_train
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


def test_training_sample_never_touches_test_repos_or_gold():
    rows = sample_train()
    train, test = split(load())
    train_ids = {r["id"] for r in train}
    gold_ids = {r["id"] for r in sample()}
    assert len(rows) == 200
    assert all(r["id"] in train_ids for r in rows)  # yalnız eğitim repoları
    assert not ({r["id"] for r in rows} & gold_ids)  # test kümesiyle çakışma yok
    assert all(is_clear(r["message"]) and "\n" not in r["message"] for r in rows)


def test_is_clear():
    assert is_clear("giriş ekranındaki hata düzeltildi")
    assert not is_clear("v1.2.3")  # çok kısa / harf az
    assert not is_clear("düzeltme")  # tek kelime
    assert not is_clear("x " * 60)  # çok uzun


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
