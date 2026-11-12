"""Veri toplama temizliği ve etiketleme aracının testleri (ağ ve klavye yok)."""
from ml.collect import clean_message
from ml.label import (
    append_label, format_message, next_item, parse_key, read_jsonl, undo_last,
)


# --- Gizlilik temizliği -------------------------------------------------------------------

def test_trailers_are_removed():
    msg = "Fix crash\n\nSigned-off-by: Ali Veli <ali@ornek.com>\nCo-authored-by: X <x@y.z>\nChange-Id: I123"
    assert clean_message(msg) == "Fix crash"


def test_lines_with_emails_are_dropped_entirely():
    # Yalnız maskelemek yetmez: satırda ad da var.
    msg = "Roll engine\n\n2026-11-04 Ayse Yilmaz <ayse@ornek.com> Fix shader\nkeep this line"
    out = clean_message(msg)
    assert "Ayse" not in out and "@" not in out
    assert out == "Roll engine\n\nkeep this line"


def test_mentions_are_masked_but_decorators_kept():
    out = clean_message("Thanks @john-doe for the review; use @property here")
    assert "@john-doe" not in out and "@kullanici" in out
    # Python dekoratörü de @ ile başlar: maskelenmesi kabul edilebilir bir yan etki.
    assert out.startswith("Thanks @kullanici")


def test_long_message_is_truncated():
    assert len(clean_message("x" * 5000)) == 1000


# --- Etiketleme aracı ------------------------------------------------------------------------

POOL = [{"id": "a", "repo": "r", "message": "m1"}, {"id": "b", "repo": "r", "message": "m2"},
        {"id": "c", "repo": "r", "message": "m3"}]


def test_parse_key():
    assert parse_key("2") == ("label", "fix")
    assert parse_key(" 7 ") == ("label", "diger")
    assert parse_key("U") == ("undo", None)
    assert parse_key("x") == ("unknown", None)
    assert parse_key("﻿q") == ("quit", None)  # PowerShell'in eklediği BOM


def test_resume_skip_and_undo(tmp_path):
    labels_path = tmp_path / "labels.jsonl"
    assert next_item(POOL, [], set())["id"] == "a"

    append_label(labels_path, "a", "feat")
    append_label(labels_path, "b", "fix", note="kararsızdım")
    labels = read_jsonl(labels_path)
    assert [r["label"] for r in labels] == ["feat", "fix"] and labels[1]["note"] == "kararsızdım"
    assert next_item(POOL, labels, set())["id"] == "c"  # kaldığı yerden
    assert next_item(POOL, labels, {"c"}) is None  # atlanan gelmez

    assert undo_last(labels_path)["id"] == "b"
    assert next_item(POOL, read_jsonl(labels_path), set())["id"] == "b"  # geri alınan yeniden gelir
    assert undo_last(tmp_path / "yok.jsonl") is None


def test_format_message_limits_body():
    msg = "subject\n\n" + "\n".join(f"line {i}" for i in range(20))
    out = format_message(msg)
    assert out.startswith(">>> subject")
    assert "line 11" in out and "line 12" not in out
    assert "(+8 satır)" in out
