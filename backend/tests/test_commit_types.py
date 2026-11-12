"""Commit türleri dağılımı testleri."""
from datetime import datetime, timedelta, timezone

from app.metrics.commit_types import CommitText, build_commit_types

T0 = datetime(2026, 11, 1, tzinfo=timezone.utc)


def _commits(messages):
    return [CommitText(m, T0 + timedelta(hours=i), "repo") for i, m in enumerate(messages)]


def test_shares_sum_to_one_and_all_types_listed():
    msgs = ["README güncellendi"] * 6 + ["tarih hatası düzeltildi"] * 3 + ["testler eklendi"] * 3
    out = build_commit_types(_commits(msgs))
    assert out.total == 12
    assert len(out.types) == 6  # hiç olmayan türler de 0 ile listelenir
    assert abs(sum(t.share for t in out.types) - 1) < 1e-9
    first = out.types[0]
    assert (first.label, first.label_tr, first.count) == ("docs", "Belgelendirme", 6)
    assert out.summary == "Commit'lerin en çok 'Belgelendirme' türünde: 6 commit (%50)."
    assert out.by_source == {"kural": 12}
    assert "%63" in out.note  # doğruluk notu her zaman var


def test_examples_are_newest_first_with_reason_and_first_line_only():
    msgs = [f"fix: hata {i}\n\ngövde satırı" for i in range(8)]
    out = build_commit_types(_commits(msgs))
    fix = next(t for t in out.types if t.label == "fix")
    assert len(fix.examples) == 5
    assert fix.examples[0].headline == "fix: hata 7"  # en yeni önce, gövde yok
    assert fix.examples[0].source == "kural" and "önek" in fix.examples[0].reason


def test_refactor_and_chore_shown_as_one_type():
    out = build_commit_types(_commits(["refactor: x", "chore: y"] * 6))
    bakim = next(t for t in out.types if t.label == "bakim")
    assert (bakim.count, bakim.label_tr) == (12, "Bakım ve düzenleme")


def test_too_few_commits():
    out = build_commit_types(_commits(["README"] * 3))
    assert out.sufficiency == "yetersiz"
    assert "yeterli veri yok" in out.summary


def test_model_is_preloaded_at_startup():
    from fastapi.testclient import TestClient

    from app.classify import classifier
    from app.main import app

    classifier._model.cache_clear()
    with TestClient(app):  # "with": açılış (lifespan) kodu çalışır
        assert classifier._model.cache_info().currsize == 1  # model önbellekte


def test_api_requires_session_and_works_for_demo(api, demo_auth):
    assert api.get("/metrics/commit-types").status_code == 401
    api.post("/sync", json={}, headers=demo_auth)
    body = api.get("/metrics/commit-types", headers=demo_auth).json()
    assert body["total"] == 6
    assert sum(t["count"] for t in body["types"]) == 6
    assert body["sufficiency"] == "yetersiz"  # küçük demo: 6 < 10
