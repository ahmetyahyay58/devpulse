"""Model Laboratuvarı: commit sınıflandırmasının GERÇEK ölçümleri (örnek değer yok).

Kaynak: docs/olcumler.md, "Yapay zekâ etiketli test standardı (13 Kasım 2026)" ve önceki
bölümler. Buradaki her sayı o belgede yazılı olduğu biçimiyle geçer; tests/test_model_lab.py
bunu denetler (belge değişip burası unutulursa test kırılır). Yeni ölçüm yapılınca önce belge,
sonra burası güncellenir.
"""
from pydantic import BaseModel

SOURCE = "docs/olcumler.md · Yapay zekâ etiketli test standardı (13 Kasım 2026)"


class Score(BaseModel):
    reference: str  # neye göre ölçüldü
    messages: int
    accuracy: str  # belgede yazıldığı gibi ("0.63")
    kappa: str


class ModelLabOut(BaseModel):
    system: str
    training: str
    classes: list[str]
    scores: list[Score]
    random_baseline: str
    human_check: str
    confusions: list[str]  # en sık karışan çiftler (karışıklık matrisinin özeti)
    caveats: list[str]
    source: str = SOURCE


MODEL_LAB = ModelLabOut(
    system="Önce kurallar (Türkçe kökler, önekler), kural karar veremezse model. Model: harf "
           "parçası (3-5) TF-IDF + lojistik regresyon; yalnız mesajın ilk satırı; güven eşiği yok.",
    training="2479 herkese açık Türkçe commit mesajı; etiket yazarın kendi öneki (fix:, feat: ...). "
             "Test repoları eğitimde yok.",
    classes=["Yeni özellik", "Hata düzeltme", "Belgelendirme", "Bakım ve düzenleme", "Test", "Diğer"],
    scores=[
        Score(reference="Yapay zekânın kör etiketleri (test standardı)", messages=98,
              accuracy="0.63", kappa="0.53"),
        Score(reference="Geliştiricinin kör etiketleri", messages=94, accuracy="0.39", kappa="0.24"),
    ],
    random_baseline="~0,14",
    human_check="19/20",
    confusions=[
        "Bakım → Kod düzenleme (5)",
        "Belgelendirme → Bakım (4)",
        "Kod düzenleme → Bakım (4)",
    ],
    caveats=[
        "0,41 → 0,63 artışı sistemin iyileşmesinden değil, referansın değişmesinden kaynaklanır.",
        "Test referansı bir yapay zekânın etiketleridir; insan kontrolü 20 örnekle sınırlıdır ve "
        "etiket gösterilerek yapıldı (kabul edilebilirlik, bağımsız doğrulama değil).",
        "Küçük kümeler: tek bir yüzde puanı yaklaşık 1 mesajdır.",
        "Kappa 0,53 \"orta\" düzey uyuşmadır; commit türleri yaklaşık bir dağılımdır.",
    ],
)
