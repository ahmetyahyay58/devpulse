"""Model Laboratuvarı yalnız gerçek ölçümleri gösterir: her sayı docs/olcumler.md'de geçmeli."""
import re
from pathlib import Path

from app.classify.model_lab import MODEL_LAB

# Satır sonları boşluğa çevrilir: belgede bir ifade iki satıra bölünmüş olabilir.
DOC = " ".join((Path(__file__).resolve().parents[2] / "docs" / "olcumler.md").read_text(encoding="utf-8").split())


def test_scores_appear_in_measurement_doc():
    for s in MODEL_LAB.scores:
        assert f"{s.accuracy} / {s.kappa}" in DOC, s
        assert f"({s.messages})" in DOC, s


def test_every_number_in_texts_is_in_the_doc():
    texts = [MODEL_LAB.random_baseline, MODEL_LAB.human_check, MODEL_LAB.training,
             *MODEL_LAB.confusions, *MODEL_LAB.caveats]
    for text in texts:
        for number in re.findall(r"\d+(?:[.,]\d+)?(?:/\d+)?", text):
            if number in {"3-5", "1"}:  # tanım/genel ifade
                continue
            assert number in DOC or number.replace(".", ",") in DOC, (number, text)


def test_confusions_are_quoted_from_doc():
    for c in MODEL_LAB.confusions:
        assert c in DOC, c


def test_endpoint(api, demo_auth):
    assert api.get("/metrics/model-lab").status_code == 401
    body = api.get("/metrics/model-lab", headers=demo_auth).json()
    assert body["scores"][0]["accuracy"] == "0.63" and "olcumler.md" in body["source"]


def test_me_has_avatar_field(api, demo_auth):
    assert api.get("/me", headers=demo_auth).json()["avatar_url"] is None  # demo'da yok
