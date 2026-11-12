"""Commit türü etiketleri: iç anahtar -> uygulamada görünen Türkçe ad (docs/etiketler.md)."""

LABELS = ["feat", "fix", "docs", "refactor", "test", "chore", "diger"]

LABEL_TR = {
    "feat": "Yeni özellik",
    "fix": "Hata düzeltme",
    "docs": "Belgelendirme",
    "refactor": "Kod düzenleme",
    "test": "Test",
    "chore": "Bakım",
    "diger": "Belirsiz",
}

# Conventional commits önekleri altı sınıfa toplanır (style/perf -> refactor, build/ci -> chore).
PREFIX_TO_LABEL = {
    "feat": "feat", "fix": "fix", "docs": "docs", "test": "test", "tests": "test",
    "refactor": "refactor", "style": "refactor", "perf": "refactor",
    "chore": "chore", "build": "chore", "ci": "chore",
}
