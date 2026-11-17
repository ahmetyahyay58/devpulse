"""Mülakat koçu (docs/ai_katmani.md, "Mülakat koçu"): seçilen bir proje için 3 soru ve kanıt önerileri.

Saf fonksiyonlar; veritabanı bilgisi yok. LLM'e yalnızca `interview_facts` çıktısı gider: repo adı,
açıklaması, README'si ve commit mesajları gitmez. Kanıt önerileri LLM'e hiç gitmez, telefona döner.
"""
from dataclasses import dataclass, field

from app.metrics.commit_types import CommitTypesOut
from app.metrics.sufficiency import Sufficiency

MAX_QUESTION_CHARS = 220

SYSTEM_INTERVIEW = (
    "Sen bir teknik mülakatçısın. Bir yazılım öğrencisinin GitHub'daki tek bir projesi hakkında, "
    "iş görüşmesinde sorulabilecek soruları hazırlıyorsun. Projenin adını ve içeriğini bilmiyorsun; "
    "yalnızca hesaplanmış sayılar JSON olarak verilir. Anahtarlar: ana_dil, araclar: kullanılan dil ve "
    "genel araç adları; commit_sayisi, aktif_gun: o repodaki commit ve commit atılan gün sayısı; "
    "sure_ay: oluşturma ile son güncelleme arası ay; saglik_puani: 0-100 belge puanı; eksik_belgeler: "
    "eksik olan belgeler; commit_turleri_yuzde: commit mesajlarından tahmin edilen türlerin payı; "
    "tur_guveni: yetersiz / dusuk / normal. "
    "Kurallar: 1) Projeye 'bu proje' de; ad, alan ya da özellik uydurma. 2) Sorular adayın kendi "
    "kararlarını anlatmasını istesin (neden, nasıl, neyi farklı yapardın); evet/hayır sorusu sorma. "
    "3) Sayıları yalnızca anlamlarıyla kullan; tur_guveni 'yetersiz' ise commit türlerinden söz etme. "
    "4) Commit sayısını başarı ölçüsü gibi sunma. saglik_puani ve commit türleri bu uygulamanın iç ölçüleridir; "
    "mülakatçı bunları bilmez, soruda 'sağlık puanı' ya da yüzde geçirme, yalnız konuyu seçmek için kullan. 5) Türkçe yaz. Tam 3 soru yaz, her biri ayrı satırda, "
    "numara, madde işareti ve markdown kullanma; her soru en fazla 200 karakter."
)


@dataclass(frozen=True)
class ProjectFacts:
    name: str
    url: str
    language: str | None
    tools: list[str] = field(default_factory=list)
    commit_count: int = 0
    active_days: int = 0
    months: int | None = None  # oluşturma - son push, ay; bilinmiyorsa None
    score: int | None = None
    missing: list[str] = field(default_factory=list)  # eksik belge adları ("README", "Lisans"...)


def _type_shares(types: CommitTypesOut) -> dict[str, int]:
    return {t.label_tr: round(t.share * 100) for t in types.types if t.count > 0}


def interview_facts(p: ProjectFacts, types: CommitTypesOut) -> dict:
    """LLM'e (ve uygulamadaki "giden veri" alanına) giden tek şey."""
    return {
        "ana_dil": p.language,
        "araclar": p.tools[:5],
        "commit_sayisi": p.commit_count,
        "aktif_gun": p.active_days,
        "sure_ay": p.months,
        "saglik_puani": p.score,
        "eksik_belgeler": p.missing,
        "commit_turleri_yuzde": _type_shares(types),
        "tur_guveni": types.sufficiency.value,
    }


def _dominant(types: CommitTypesOut) -> str | None:
    """En büyük paylı tür (Belirsiz hariç); veri yetersizse None."""
    if types.sufficiency == Sufficiency.NONE:
        return None
    known = [t for t in types.types if t.count > 0 and t.label != "diger"]
    return max(known, key=lambda t: t.count).label if known else None


# Sürece dair soru: o repodaki baskın commit türüne göre.
PROCESS = {
    "fix": "Bu projede çözdüğün en zor hata neydi? Nasıl buldun ve bir daha olmaması için ne yaptın?",
    "feat": "Bu projeye eklediğin en önemli özellik hangisiydi? Nasıl tasarladın, bugün neyi farklı yapardın?",
    "bakim": "Bu projede kodu yeniden düzenlediğin bir anı anlat: neyi neden değiştirdin, ne kazandın?",
    "docs": "Belgelendirmeye zaman ayırmışsın: projeyi hiç görmemiş bir geliştirici nasıl başlar, neyi açıklamak zordu?",
    "test": "Bu projeyi nasıl test ettin? Neyi test etmedin ve neden?",
}


def template_questions(p: ProjectFacts, types: CommitTypesOut) -> list[str]:
    # 1) Teknoloji seçimi
    if p.language and p.tools:
        q1 = f"Teknoloji seçimini anlat: {p.language} ve {', '.join(p.tools[:3])} neden bu projeye uygundu, alternatifler neydi?"
    elif p.language:
        q1 = f"Bu projede neden {p.language} kullandın? Hangi alternatifleri düşündün?"
    else:
        q1 = "Bu projede hangi teknolojileri kullandın ve neden onları seçtin?"
    # 2) Süreç
    dom = _dominant(types)
    if dom in PROCESS:
        q2 = PROCESS[dom]
    elif p.months and p.months >= 2:
        q2 = f"Proje yaklaşık {p.months} aya yayılıyor. Başta planladığınla bugünkü hali arasında ne değişti?"
    else:
        q2 = "Bu projede karşılaştığın en büyük teknik zorluk neydi ve nasıl aştın?"
    # 3) Anlatma / yeniden yapma
    if "README" in p.missing or "Açıklama" in p.missing:
        q3 = "Projeyi hiç görmemiş birine iki dakikada anlat: kim için, hangi sorunu çözüyor, sen ne yaptın?"
    else:
        q3 = "Bu projeyi bugün sıfırdan yapsan neyi farklı yapardın?"
    return [q1, q2, q3]


def evidence(p: ProjectFacts, types: CommitTypesOut) -> list[str]:
    """Görüşmeye hazırlık için kanıt önerileri; veriden kurallı, LLM'e gitmez."""
    out = [f"Bağlantıyı hazır tut: {p.url.replace('https://', '')}"]
    if "README" in p.missing:
        out.append("README ekle: ne yaptığı, nasıl kurulduğu ve bir ekran görüntüsü. Görüşmede ilk açılan dosya odur.")
    elif "README içeriği" in p.missing:
        out.append("README'yi genişlet: kurulum, kullanım ve kısa bir örnek ekle.")
    if "Açıklama" in p.missing:
        out.append("Repo sayfasına tek cümlelik açıklama yaz.")
    if "Lisans" in p.missing:
        out.append("Lisans dosyası ekle (ör. MIT).")
    numbers = [f"{p.commit_count} commit", f"{p.active_days} aktif gün"]
    if p.months:
        numbers.append(f"yaklaşık {p.months} ay")
    out.append("Konuşurken veriyle söyleyebileceklerin: " + ", ".join(numbers) + ".")
    if _dominant(types) == "fix":
        out.append("Kapattığın bir hatanın commit'ini seç; öncesini ve sonrasını gösterebil.")
    else:
        out.append("En çok emek verdiğin commit'i seç; ne değiştirdiğini bir dakikada anlatabil.")
    out.append("CV'deki etki cümlesini doldur (kullanıcı sayısı, hız, süre gibi gerçek bir rakamla).")
    return out


def parse_questions(text: str) -> list[str] | None:
    """LLM cevabı: tam 3 dolu satır, her biri sınır içinde; numara/madde işareti temizlenir."""
    lines = [l.strip().lstrip("-*•0123456789.) ").strip() for l in text.splitlines()]
    lines = [l for l in lines if l]
    if len(lines) != 3 or any(len(l) > MAX_QUESTION_CHARS for l in lines):
        return None
    return lines
