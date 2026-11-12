"""Kural katmanı ve Türkçe veri toplama yardımcılarının testleri."""
import pytest

from app.classify.rules import classify_rules, normalize, parse_prefix
from ml.collect_tr import is_turkish, to_example


@pytest.mark.parametrize("message, label", [
    # Önek her şeyden önce gelir; içerik başka şey söylese de (öneki öncelikli kabul ediyoruz)
    ("fix(ios): Google girişi için Firebase URL şeması", "fix"),
    ("docs: kullanım ve test bölümü eklendi", "docs"),
    ("perf: sorgu hızlandırıldı", "refactor"),  # style/perf -> refactor
    ("ci: derleme adımı", "chore"),  # build/ci -> chore
    # GitHub web arayüzü mesajları
    ("Create README.md", "docs"),
    ("Update README.md", "docs"),
    ("README", "docs"),
    ("Delete flutter_01.png", "chore"),
    # Türkçe kökler, farklı eklerle
    ("tarih biçimi hatası düzeltildi", "fix"),
    ("giriş ekranındaki sorunu düzelttim", "fix"),
    ("Proje bağımlılıkları eklendi", "chore"),  # bakım, "eklendi"den önce gelir
    ("gitignore güncellendi", "chore"),
    ("servis katmanı sadeleştirildi", "refactor"),
    ("arama özelliği eklendi", "feat"),
    ("yeni giriş ekranı", "feat"),
    # Test: yalnız mesaj test hakkındaysa
    ("testler eklendi", "test"),
    ("boş değer kontrolü ve testi eklendi", "feat"),  # asıl iş kontrol (etiketler.md kural 7)
    # Belirsiz
    ("Revert \"arama özelliği\"", "diger"),
    ("Merge branch 'dev'", "diger"),
])
def test_rules(message, label):
    assert classify_rules(message).label == label


def test_rules_return_none_when_unsure():
    # Hiçbir kurala uymuyor: karar modele bırakılır.
    assert classify_rules("kullanıcı profili sayfası") is None
    assert classify_rules("") is None


def test_rule_reason_is_explainable():
    assert classify_rules("tarih biçimi hatası düzeltildi").reason == "hata kelimesi: 'hata'"
    assert classify_rules("fix: x").reason == "önek: 'fix'"


def test_giderler_is_not_a_fix():
    # "gider" kökü fazla genişti: "giderler" (masraflar) hata düzeltmesi değildir.
    assert classify_rules("aylık giderler sayfası eklendi").label == "feat"


def test_turkish_lowercase():
    assert normalize("IŞIK İZİ") == "ışık izi"


def test_parse_prefix():
    assert parse_prefix("feat(api)!: yeni uç nokta") == ("feat", "yeni uç nokta")
    assert parse_prefix("wip: bir şey") is None  # tanınmayan önek
    assert parse_prefix("düz metin") is None


def test_turkish_detection():
    assert is_turkish("Google girişi için Firebase URL şeması")
    assert is_turkish("api ve web arasinda cors")  # Türkçe harf yok ama "ve" var
    assert not is_turkish("restore Turkish letters in dashboard strings")


def test_to_example_strips_prefix_and_personal_data():
    ex = to_example("org/repo", "a" * 40,
                    "fix(ios): Google girişi için şema\n\nSigned-off-by: Ali <ali@x.com>")
    assert ex == {"id": "org/repo@aaaaaaaaaaaa", "repo": "org/repo", "label": "fix",
                  "text": "Google girişi için şema"}
    assert to_example("o/r", "b" * 40, "fix: restore Turkish letters") is None  # İngilizce
    assert to_example("o/r", "c" * 40, "Google girişi düzeltildi") is None  # önek yok
