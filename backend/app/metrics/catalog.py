"""Metrik kataloğu: her metriğin kısa tanımı, birimi, yorumu ve güvenilirlik koşulu.

Kaynak docs/metrikler.md'dir; buradaki her girdinin `section` alanı o belgedeki bir "###"
başlığıyla başlar (tests/test_catalog.py denetler). Tanım değişirse önce belge güncellenir.
"""
from pydantic import BaseModel


class CatalogEntry(BaseModel):
    name: str
    section: str  # docs/metrikler.md'deki başlık
    definition: str
    unit: str
    interpretation: str
    reliable_when: str


class CatalogOut(BaseModel):
    entries: list[CatalogEntry]


CATALOG = [
    CatalogEntry(
        name="Aktif gün", section="Aktif gün",
        definition="Yerel saatine göre en az bir commit içeren takvim günü.",
        unit="gün",
        interpretation="Ne kadar sık çalıştığını betimler; günün ne kadar verimli geçtiğini söylemez.",
        reliable_when="Saat dilimin biliniyorsa (yoksa UTC'ye göre sayılır).",
    ),
    CatalogEntry(
        name="Güncel seri ve en uzun seri", section="Süreklilik",
        definition="Kesintisiz aktif gün dizisi. Güncel seri bugün ya da dün aktifse sayılır.",
        unit="gün",
        interpretation="Alışkanlığın düzenini gösterir; ara vermek kötü bir şey değildir.",
        reliable_when="En az 10 aktif gün ve ilk commit'ten bu yana 30 gün.",
    ),
    CatalogEntry(
        name="Son 90 günde aktif gün oranı", section="Süreklilik",
        definition="Son 90 gündeki aktif gün / 90 (ilk commit daha yeniyse geçen gün sayısı).",
        unit="%",
        interpretation="Son dönemde ne kadar düzenli commit attığını betimler.",
        reliable_when="En az 10 aktif gün ve ilk commit'ten bu yana 30 gün.",
    ),
    CatalogEntry(
        name="Saat ve gün dağılımı", section="Ritim",
        definition="Commit'lerin yerel saate (0-23) ve haftanın gününe göre dağılımı; en yoğun saat.",
        unit="commit",
        interpretation="Ne zaman çalışmayı sevdiğini gösterir; commit zamanı çalışma zamanının tamamı değildir.",
        reliable_when="En az 50 commit ve saat dilimin biliniyor.",
    ),
    CatalogEntry(
        name="Gece ve hafta sonu oranı", section="Ritim",
        definition="00:00-05:59 arasındaki ve Cumartesi-Pazar commit'lerinin oranı.",
        unit="%",
        interpretation="Betimleyicidir; gece çalışmak iyi ya da kötü sayılmaz.",
        reliable_when="En az 50 commit ve saat dilimin biliniyor.",
    ),
    CatalogEntry(
        name="Oturum", section="Oturum",
        definition="Aralarında 2 saatten uzun boşluk olmayan ardışık commit'ler bir oturumdur (kural).",
        unit="oturum, dakika, saat",
        interpretation="Süre ilk ve son commit arasıdır; gerçek çalışma süresi daha uzun olabilir.",
        reliable_when="En az 15 oturum.",
    ),
    CatalogEntry(
        name="Yoğunluk", section="Yoğunluk",
        definition="Aktif gün ve oturum başına commit, oturum süresi, commit başına değişen satır (medyan).",
        unit="commit, dakika, satır",
        interpretation="Medyan kullanılır: tek bir dev commit sonucu bozmaz. Satır sayısı emeği ölçmez.",
        reliable_when="En az 15 oturum.",
    ),
    CatalogEntry(
        name="Değişim noktaları", section="Değişim noktaları",
        definition="Haftalık commit sayısının kalıcı olarak değiştiği haftalar (PELT, istatistik).",
        unit="hafta, haftalık ortalama commit",
        interpretation="Dönemsel değişimi betimler (ör. sınav dönemi); nedenini bilmez.",
        reliable_when="En az 26 hafta ve 10 commit.",
    ),
    CatalogEntry(
        name="Olağan dışı günler", section="Olağan dışı günler",
        definition="Commit sayısı kendi medyanından belirgin saptığı günler (robust z > 3,5).",
        unit="gün, robust z",
        interpretation="Alışkanlığının dışında kalan günlerdir; bir yargı değildir.",
        reliable_when="En az 30 aktif gün.",
    ),
    CatalogEntry(
        name="Commit türleri", section="Commit türleri",
        definition="Commit mesajının ilk satırından tür tahmini: önce kurallar, sonra model.",
        unit="commit, %",
        interpretation="Yaklaşık bir tahmindir; ölçülen doğruluk docs/olcumler.md'de.",
        reliable_when="En az 30 commit.",
    ),
    CatalogEntry(
        name="Dil dağılımı ve çeşitlilik", section="Teknoloji",
        definition="Kendi repolarındaki dil başına bayt payları; çeşitlilik = normalleştirilmiş entropi.",
        unit="%, dil",
        interpretation="Çeşitlilik puan değildir: dağılımın dengesini betimler. Bayt emeği ölçmez.",
        reliable_when="Dil bilgisi olan en az 3 kendi reposu.",
    ),
    CatalogEntry(
        name="Tespit edilen araçlar", section="Teknoloji",
        definition="Repo kök dizinindeki bilinen dosya adlarından araç tespiti (ör. Dockerfile → Docker).",
        unit="repo",
        interpretation="Yalnız kök dizine bakılır; alt klasörlerdeki araçlar görülmez.",
        reliable_when="Kendi repoların için; dosya içeriği okunmaz.",
    ),
    CatalogEntry(
        name="Başarımlar", section="Başarımlar",
        definition="Seri, düzen, proje bakımı, katkı ve çalışma alışkanlıkları için 20 rozet (ikisi gizli); her biri ilerlemesiyle.",
        unit="rozet",
        interpretation="Alışkanlığı ve bakımı tanır; ham commit sayısını ödüllendirmez.",
        reliable_when="Her zaman; rozetler var olan metriklerin eşikleridir.",
    ),
    CatalogEntry(
        name="Yıl kıyası", section="Yıl kıyası",
        definition="Yılbaşından bugüne ile geçen yılın aynı dönemi: commit, aktif gün, seri, repo.",
        unit="%, commit, gün",
        interpretation="Betimleyicidir; artış ya da azalış iyi/kötü anlamına gelmez.",
        reliable_when="İki dönemde de en az 10 commit.",
    ),
    CatalogEntry(
        name="Proje sağlığı", section="Proje sağlığı",
        definition="README, README içeriği, açıklama, lisans ve topic kontrollerinin ağırlıklı skoru.",
        unit="0-100",
        interpretation="Vitrin ve belgelendirme eksiksizliğini ölçer; kod kalitesini ölçmez.",
        reliable_when="Kendi repoların için (fork'lar ve katkı yapılan repolar puanlanmaz).",
    ),
]
