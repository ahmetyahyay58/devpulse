# CV (Faz 8)

Bu belge CV taslağının nasıl üretildiğini tanımlar. Kod (`backend/app/cv/`) bu belgeye uyar.

## Kararlar (geliştirici, 16 Kas 2026)
- **Düzenlemeler telefonda saklanır.** CV başlığında gerçek ad, e-posta ve telefon olur; bunlar
  sunucuda saklanmaz (CLAUDE.md gizlilik kuralı). Sunucu yalnızca GitHub verisinden taslak üretir;
  kullanıcının yazdığı metin sunucuya gitmez. "Verilerimi sil" ve çıkış telefondaki CV
  düzenlemelerini de siler.
- **PDF telefonda üretilir** (Dart `pdf` paketi, Türkçe karakter için gömülü yazı tipi). Web'de
  doğrudan indirme, Android'de paylaşım menüsü.
- **CV alt çubukta 5. sekmedir.**
- **Şablonların hepsi tek sütundur.** Biçim kontrolü "tablo/sütun yok" kuralını içerir; uygulama
  kendi kuralına uymayan şablon sunmaz.

## Taslak (`GET /cv/draft?lang=tr|en`)
Taslak deterministiktir: aynı veri aynı taslağı verir. LLM kullanılmaz.

**Her madde kaynağını söyler** (`source`): hangi veriden üretildiği kısa bir cümleyle
(ör. "GitHub repo açıklaması", "dil dağılımı ve kök dizindeki dosyalar"). Arayüz bunu maddenin
altında gösterir.

**Sayı uydurulmaz.** Taslaktaki her sayı senkronlanmış veriden gelir (commit, aktif gün, seri,
PR). Etki gibi verinin bilemeyeceği bir sayı gerekiyorsa madde **yer tutucu** olarak işaretlenir
(`placeholder: true`); metindeki `[…]` kısmını kullanıcı doldurur. Doldurulmamış yer tutucu
biçim kontrolünde uyarı verir ve PDF'e basılmaz.

**Kararlı kimlikler:** Her maddenin `id`'si veriden türetilir (ör. `proj:<repo node id>:stack`);
konumdan değil. Yeniden senkronda sıra değişse de telefondaki düzenleme doğru maddeye bağlı kalır;
"Taslağa dön" tek maddeyi ya da tümünü sıfırlayabilir.

### Bölümler
1. **Başlık:** GitHub kullanıcı adı ve profil adresi. Ad, e-posta, telefon boş gelir; kullanıcı
   telefonda doldurur.
2. **Özet:** Verideki sayılardan tek cümle (en çok kullanılan dil, repo ve commit sayısı). Aktif
   gün ve en uzun seri "Etkinlik" bölümündedir; aynı sayı iki kez yazılmaz.
3. **Projeler (en çok 4):** Kullanıcının kendi, fork olmayan, arşivlenmemiş ve herkese açık
   repoları (CV başkalarına gösterilen bir belgedir; özel repo listelenmez); proje
   sağlık puanına, eşitlikte commit sayısına göre sıralanır. Her proje için:
   - `desc`: GitHub açıklaması (yoksa madde yok).
   - `stack`: ana dil ve tespit edilen araçlar.
   - `work`: kullanıcının o repodaki commit sayısı; README ve lisans varsa "belgelendi".
   - `impact`: yer tutucu, "Etki: […]" (kullanıcı yazar).
4. **Beceriler:** Dil dağılımında payı en büyük diller (%1 altı "Diğer" hariç) ve araçlar.
5. **Etkinlik:** Toplam commit ve aktif gün; başkalarının repolarına açılan ve merge edilen PR
   (varsa); kod incelemesi sayısı (varsa).

Veri yetersizse (ör. hiç commit yoksa) ilgili madde üretilmez; boş bölüm gönderilmez.

## Dil
Türkçe ve İngilizce aynı veriden, aynı kimliklerle üretilir; yalnız cümleler değişir. Sayıdan
sonra Türkçe ek kullanılmaz (metrikler.md genel kuralı).
