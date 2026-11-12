"""Kural katmanı: önek + Türkçe/İngilizce anahtar kelimeler (makine öğrenmesi değil).

Kurallar sırayla denenir, ilk eşleşen kazanır; sıranın gerekçesi docs/etiketler.md'deki karar
kurallarıdır. Türkçe sondan eklemeli olduğundan kelimeler kök başlangıcıyla aranır:
"düzelt" kökü "düzeltildi", "düzeltme", "düzelttim" hepsini yakalar.
"""
import re
from dataclasses import dataclass

from app.classify.labels import PREFIX_TO_LABEL

PREFIX = re.compile(r"^(?P<type>[a-z]+)(\([^)]*\))?!?:\s*(?P<rest>.+)", re.IGNORECASE | re.DOTALL)


@dataclass(frozen=True)
class RuleResult:
    label: str
    reason: str  # kullanıcıya gösterilecek kısa gerekçe


def parse_prefix(text: str) -> tuple[str, str] | None:
    """("fix", "önek sonrası metin") ya da önek yoksa/tanınmıyorsa None."""
    m = PREFIX.match(text.strip())
    if not m:
        return None
    label = PREFIX_TO_LABEL.get(m.group("type").lower())
    return (label, m.group("rest").strip()) if label else None


def normalize(text: str) -> str:
    """Türkçe büyük harfleri doğru küçült (Python 'I'yı 'i' yapar, 'İ'yı iki karaktere böler)."""
    return text.replace("I", "ı").replace("İ", "i").lower()


def tokens(text: str) -> list[str]:
    return re.findall(r"[\w.]+", normalize(text))


def _has_root(toks: list[str], roots: tuple[str, ...]) -> str | None:
    """Kelimelerden biri verilen köklerden biriyle başlıyorsa o kökü döner."""
    for t in toks:
        for r in roots:
            if t.startswith(r):
                return r
    return None


# (etiket, kökler, gerekçe şablonu) — sırası önemli
KEYWORD_RULES: list[tuple[str, tuple[str, ...], str]] = [
    ("docs", ("readme", "belge", "doküman", "dokuman", "döküman", "dokümantasyon", "kılavuz",
              "rehber", "docs", "typo", "yazım"), "belge kelimesi"),
    ("chore", ("bağımlılık", "bagimlilik", "gitignore", ".gitignore", "requirements", "sürüm",
               "versiyon", "dockerfile", "workflow", "pipeline", "bump", "dependency",
               "dependencies"), "bakım kelimesi"),
    # "gider" değil "giderildi": "giderler" (masraflar) yakalanmasın.
    ("fix", ("düzelt", "duzelt", "hata", "giderildi", "çökme", "sorun", "fix", "bug"),
     "hata kelimesi"),
    ("refactor", ("refactor", "sadeleştir", "yeniden", "iyileştir", "optimiz", "temizle",
                  "temizli", "rename"), "düzenleme kelimesi"),
    ("feat", ("ekle", "eklendi", "yeni", "oluştur", "add", "create", "destek", "implement"),
     "ekleme kelimesi"),
]

TEST_START = re.compile(r"^(unit\s+)?test(ler|leri|i|s)?\b", re.IGNORECASE)


def classify_rules(message: str) -> RuleResult | None:
    """Kuralla karar verilebiliyorsa sonucu, verilemiyorsa None döner (model devreye girer)."""
    headline = message.strip().splitlines()[0] if message.strip() else ""
    if not headline:
        return None

    # 1) Önek: "fix(ios): ..." -> doğrudan tür
    parsed = parse_prefix(headline)
    if parsed:
        return RuleResult(parsed[0], f"önek: '{headline.split(':')[0]}'")

    low = normalize(headline)
    toks = tokens(headline)

    # 2) Geri alma ve birleştirme: tür mesajdan anlaşılmaz
    if low.startswith(("revert", "geri al", "merge")):
        return RuleResult("diger", "geri alma/birleştirme")
    # 3) GitHub arayüzünün "Delete X" mesajı
    if low.startswith("delete "):
        return RuleResult("chore", "dosya silme")
    # 4) Test: yalnızca mesaj test hakkındaysa ("testler eklendi"); "kontrol ve testi eklendi"
    #    gibi mesajlarda asıl iş kontroldür (ana iş seçilir, docs/etiketler.md kural 7).
    if TEST_START.match(low):
        return RuleResult("test", "test ile başlıyor")
    # 5-9) Anahtar kelimeler; ".md" uzantılı dosya adı da belgedir
    if any(t.endswith(".md") for t in toks):
        return RuleResult("docs", "Markdown dosyası")
    for label, roots, reason in KEYWORD_RULES:
        root = _has_root(toks, roots)
        if root:
            return RuleResult(label, f"{reason}: '{root}'")
    return None
