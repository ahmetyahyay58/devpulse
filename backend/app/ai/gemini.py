"""Google Gemini API istemcisi (REST, generateContent). Ek SDK yok, httpx yeterli.

Hata olursa GeminiError fırlatır; çağıran taraf şablon cevaba düşer (docs/ai_katmani.md).
"""
import httpx

URL = "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
MAX_ANSWER_CHARS = 600

SYSTEM = (
    "Sen DevPulse adlı mobil uygulamada bir geliştiricinin GitHub çalışma alışkanlıklarını yorumluyorsun. "
    "Sana yalnızca hesaplanmış toplu sayılar JSON olarak verilir. Anahtarların anlamı: "
    "toplam_commit, aktif_gun, repo_sayisi: hesabın tüm geçmişi (bir yıl değil); "
    "guncel_seri_gun, en_uzun_seri_gun: art arda commit atılan gün sayısı; "
    "en_yogun_saat: en çok commit atılan saat (0-23); gece_payi_yuzde: 00-06 arası commit oranı; "
    "hafta_sonu_payi_yuzde: hafta sonu commit oranı; oturum: aralarında 2 saatten az boşluk olan commit'ler; "
    "commit_turleri_yuzde: commit mesajlarından tahmin edilen türlerin payı; olagan_disi_gun: alışılmadık yoğun gün sayısı; "
    "ortalama_saglik: projelerin 0-100 belge puanı ortalaması; eksik_proje: o belgesi eksik proje sayısı; "
    "baskin_dil, baskin_dil_yuzde: kodun bayt olarak en büyük dili ve payı (commit payı değil); "
    "cesitlilik: 0-1 arası dil çeşitliliği (betimleyici, puan değil); "
    "yil_degisim_yuzde: bu yıl ile geçen yılın aynı dönemindeki commit sayısı farkı; "
    "*_guveni: yetersiz / dusuk / normal veri yeterliliği. "
    "Kurallar: "
    "1) Yalnızca verilen sayılara dayan; sayı uydurma, verilmeyen bir bilgiden söz etme, sayıları anlamları dışında birbirine bağlama. "
    "2) Commit sayısı üretkenliği ya da kod kalitesini ölçmez; yargılama, betimle. "
    "3) Öneri yalnızca somut bir sayıdan çıksın (ör. eksik_proje, güncel seri); 'daha çok dil öğren', 'daha uzun çalış' gibi genel tavsiye verme. "
    "4) Bir konunun güveni 'yetersiz' ise o konuda yorum yapma; 'dusuk' ise temkinli konuş. Null değerler bilinmiyor demektir. "
    "5) Türkçe, samimi ama kısa yaz: en fazla 3 cümle, madde işareti ve markdown kullanma."
)


class GeminiError(Exception):
    """Ağ hatası, kota (429), geçersiz anahtar ya da kullanılamaz cevap."""

    def __init__(self, message: str, retryable: bool = False):
        super().__init__(message)
        self.retryable = retryable  # yoğunluk/kota/zaman aşımı: başka modelle denemeye değer


def generate(prompt: str, *, api_key: str, model: str, transport: httpx.BaseTransport | None = None) -> str:
    body = {
        "systemInstruction": {"parts": [{"text": SYSTEM}]},
        "contents": [{"role": "user", "parts": [{"text": prompt}]}],
        # Düşük sıcaklık: aynı sayılara benzer cevap. Sınır cömert: "düşünen" modeller payı kullanır.
        "generationConfig": {"temperature": 0.3, "maxOutputTokens": 1024},
    }
    try:
        with httpx.Client(timeout=12, transport=transport) as http:
            r = http.post(URL.format(model=model), json=body, headers={"x-goog-api-key": api_key})
    except httpx.HTTPError as exc:
        raise GeminiError(f"bağlantı hatası: {type(exc).__name__}", retryable=True) from exc
    if r.status_code in (429, 503):
        raise GeminiError(f"kota doldu ya da model yoğun ({r.status_code})", retryable=True)
    if r.status_code != 200:
        raise GeminiError(f"HTTP {r.status_code}")
    try:
        parts = r.json()["candidates"][0]["content"]["parts"]
        text = "".join(p.get("text", "") for p in parts if not p.get("thought")).strip()
    except (KeyError, IndexError, TypeError, ValueError) as exc:
        raise GeminiError("cevap biçimi beklenmedik") from exc
    if not text or len(text) > MAX_ANSWER_CHARS:
        raise GeminiError("cevap boş ya da çok uzun")
    return text


def generate_with_fallback(prompt: str, *, api_key: str, models: list[str],
                           transport: httpx.BaseTransport | None = None) -> tuple[str, str]:
    """Modelleri sırayla dener; yalnızca yoğunluk/kota/zaman aşımında bir sonrakine geçer.
    (cevap, kullanılan model) döner; hepsi başarısızsa son hatayı fırlatır."""
    last: GeminiError | None = None
    for model in dict.fromkeys(m for m in models if m):  # sırayı koruyarak tekrarları at
        try:
            return generate(prompt, api_key=api_key, model=model, transport=transport), model
        except GeminiError as exc:
            last = exc
            if not exc.retryable:
                break
    raise last or GeminiError("model tanımlı değil")
