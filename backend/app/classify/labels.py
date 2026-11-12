"""Commit türü etiketleri: iç anahtar -> uygulamada görünen Türkçe ad (docs/etiketler.md).

Etiketleme kılavuzu ve kurallar 7 ince sınıfla çalışır; uygulama çıktısında "refactor" ve
"chore" tek sınıfta birleşir (MERGE). Gerekçe: bu ikisini insanlar da karıştırıyor; birleştirme
gerçek uyuşmayı (kappa) anlamlı artırmadı, anlaşılırlık için yapıldı (docs/olcumler.md).
"""

LABELS = ["feat", "fix", "docs", "refactor", "test", "chore", "diger"]  # etiketleme (ince)

# Uygulama çıktısı (sade): ince etiket -> görünen sınıf
MERGE = {"refactor": "bakim", "chore": "bakim"}
APP_LABELS = ["feat", "fix", "docs", "bakim", "test", "diger"]

LABEL_TR = {
    "feat": "Yeni özellik",
    "fix": "Hata düzeltme",
    "docs": "Belgelendirme",
    "refactor": "Kod düzenleme",
    "test": "Test",
    "chore": "Bakım",
    "bakim": "Bakım ve düzenleme",
    "diger": "Belirsiz",
}


def to_app_label(label: str) -> str:
    """İnce etiketi uygulamada gösterilen sade sınıfa çevirir."""
    return MERGE.get(label, label)


# Conventional commits önekleri altı sınıfa toplanır (style/perf -> refactor, build/ci -> chore).
PREFIX_TO_LABEL = {
    "feat": "feat", "fix": "fix", "docs": "docs", "test": "test", "tests": "test",
    "refactor": "refactor", "style": "refactor", "perf": "refactor",
    "chore": "chore", "build": "chore", "ci": "chore",
}
