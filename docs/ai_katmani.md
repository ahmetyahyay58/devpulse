# AI katmanı (Faz 6)

Bu belge, LLM'e neyin gidip neyin gitmediğini ve LLM olmadığında ne olduğunu tanımlar.
Kod `backend/app/ai/` bu belgeye uyar; sözleşme değişirse önce burası güncellenir.

## İlkeler
- **Ana yol şablondur.** Her soru için şablon bir cevap vardır (`app/ai/questions.py`). LLM yalnızca
  isteğe bağlı bir ektir: anahtar yoksa, kullanıcı onay vermediyse, istek zaman aşımına uğrarsa,
  kota dolarsa (429) ya da cevap boş/uzun gelirse şablon gösterilir. Kullanıcı hata görmez; cevabın
  altında kaynağı yazar ("Yapay zekâ" ya da "Şablon").
- **LLM'e yalnızca toplu sayılar gider.** Kullanıcı adı, repo adı, commit mesajı, kod, dosya adı,
  e-posta gitmez. Giden veri `app/ai/facts.py` içinde tek yerde kurulur; uygulamadaki
  "LLM'e giden veri" ekranı aynı fonksiyonun çıktısını gösterir (`GET /ai/facts`).
- **Onay sunucuda tutulur.** `users.ai_consent_at` boşsa sunucu LLM'i hiç çağırmaz. Onay Profil
  ekranından kapatılabilir (`POST /ai/consent`).
- **LLM yorumlar, hesaplamaz.** Sayılar metrik katmanından gelir; LLM'den yalnızca onları kısa,
  yargısız Türkçe cümlelere çevirmesi istenir. Commit sayısı üretkenlik ya da kalite ölçmez
  kuralı istemde de yazar.

## Sağlayıcı
- Google Gemini API, ücretsiz katman (geliştirici kararı, 16 Kas 2026). Anahtar `GEMINI_API_KEY`.
  İstek REST ile atılır (`generateContent`, `httpx`); ek SDK yok.
- Model: ana `gemini-flash-lite-latest`, yedek `gemini-flash-latest` (`GEMINI_MODEL`,
  `GEMINI_FALLBACK_MODEL`). Seçim ölçüme dayanır (16 Kas): Flash "yoğun talep" diyerek 503 ve
  zaman aşımı verdi, Lite 1,3-3,2 sn'de cevap verdi. Yedeğe yalnızca yoğunluk (503), kota (429) ya
  da zaman aşımında (12 sn) bir kez geçilir; geçersiz anahtar gibi hatalarda doğrudan şablon.
- Ücretsiz katman koşulu: Google, ücretsiz kotada gönderilen içeriği ve cevapları ürünlerini
  geliştirmek için kullanabilir, insan inceleyiciler okuyabilir. Bu yüzden zaten yalnız toplu
  sayılar gönderilir; aydınlatma metni bunu açıkça yazar.
- Kota düşüktür (dakikada birkaç istek). Aynı kullanıcı, aynı soru ve aynı sayılar için cevap
  sunucu belleğinde saklanır (önbellek; sunucu yeniden başlayınca boşalır, diske yazılmaz).

## Giden sayılar (`facts`)
Hepsi var olan metriklerden okunur (tanımlar `docs/metrikler.md`). Yüzdeler tam sayıya yuvarlanır.
Her grubun güven durumu (`yetersiz` / `dusuk` / `normal`) da gider; istem "yetersiz" konuda yorum
yapmamasını, "dusuk"ta temkinli olmasını söyler.

| Anahtar | Kaynak |
|---|---|
| `toplam_commit`, `aktif_gun`, `repo_sayisi` | Genel Bakış KPI |
| `guncel_seri_gun`, `en_uzun_seri_gun`, `sureklilik_guveni` | Süreklilik |
| `en_yogun_saat`, `gece_payi_yuzde`, `hafta_sonu_payi_yuzde`, `ritim_guveni` | Ritim |
| `oturum_sayisi`, `oturum_basi_commit`, `ortalama_oturum_dk`, `oturum_guveni` | Oturum |
| `commit_turleri_yuzde` (tür adı → yüzde), `tur_guveni` | Commit türleri |
| `olagan_disi_gun` | Anomali (işaretlenen gün sayısı) |
| `puanlanan_proje`, `ortalama_saglik`, `eksik_proje` (eksik adı → repo sayısı) | Proje sağlığı |
| `dil_sayisi`, `baskin_dil`, `baskin_dil_yuzde`, `cesitlilik`, `teknoloji_guveni` | Teknoloji |
| `yil_degisim_yuzde`, `yil_guveni` | Yıl kıyası |

Dil adı (ör. "Python") ve tür adı ("Hata düzeltme") genel kategorilerdir, kişiyi tanımlamaz.

**Soruya göre alt küme (en az veri):** Her hazır soru yalnızca kendi konusunun sayılarını gönderir
(ör. "Ritim neden böyle?" yalnız ritim sayılarını). Özet, güçlü yan ve geliştirilecek yan tümünü
gönderir. Alakasız sayıların gitmemesi hem gizliliği hem doğruluğu artırır: ilk denemede model,
ritim sorusunda yıl değişimini ritimle ilişkilendirmişti.

**İstem:** Sistem talimatı her anahtarın anlamını verir (ör. `toplam_commit` tüm geçmiştir, bir yıl
değil; `baskin_dil_yuzde` bayt payıdır, commit payı değil) ve öneriyi somut bir sayıya bağlar
("daha çok dil öğren" gibi genel tavsiye yok). Bu iki kural, ilk denemede görülen bağlam
hatalarından sonra eklendi (`app/ai/gemini.py`, `SYSTEM`).

## Sorular
Serbest metin soru yoktur: kullanıcı yalnızca hazır sorulardan birini seçer (istem enjeksiyonu ve
kişisel veri riski olmaz). Soru kimlikleri `app/ai/questions.py` içindedir.
- **Sor balonu (5):** özet, güçlü yan, geliştirilecek yan, projeler, çalışma saatleri.
  İlk üçü Genel Bakış'taki AI yorumu kartında çip olarak da görünür.
- **"Neden?" (5):** süreklilik, ritim, oturum, commit türleri, proje sağlığı. Şablon cevabı o
  metriğin "nasıl hesaplandı" özetidir.
- **İpucu (1):** tek cümlelik öneri; Profil'den kapatılabilir (telefonda tutulan bir tercih).

## Doğrulama
- LLM cevabı 600 karakteri aşarsa ya da boşsa atılır, şablon gösterilir.
- Testler gerçek Gemini'ye gitmez (sahte HTTP); onaysız ve anahtarsız durumda dış istek
  atılmadığı test edilir; giden gövdede repo adı ve commit mesajı olmadığı test edilir.
