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
- **Üç yaygın format (geliştirici kararı, 16 Kas):** ilk taslak "gerçek bir CV gibi durmuyor"
  bulundu; prototipteki 5 serbest şablon yerine piyasada tanınan üç formatın düzeni izlenir.

## Formatlar
Hiçbiri "ATS'den geçer" diye sunulmaz. Hepsi tek sütun; tarihler satır sonunda sağa yaslanır
(sütun değildir). Düzen tek yerde, veri olarak tanımlıdır (`mobile/lib/cv/cv_formats.dart`);
ekrandaki önizleme ve PDF aynı tanımı okur.

| Format | Bölüm sırası | Notlar ve uyarlamalar |
|---|---|---|
| **Jake's Resume** | Eğitim → Deneyim → Projeler → Teknik beceriler | Yazılımcılar arasında yaygın tek sayfalık LaTeX şablonu (Overleaf). Proje satırı "Ad \| teknolojiler", tarih sağda. Özet yok. |
| **Harvard tarzı** | Eğitim → Deneyim → Projeler → Beceriler | Tek bir resmî Harvard şablonu yok; Harvard kariyer rehberlerindeki ters kronolojik düzen izlenir: eğitim önce, özet yok, madde başına tek cümle, serif yazı tipi. Rehberde "Projeler" yok; GitHub projeleri Deneyim'den sonra konur (uyarlama). |
| **Europass düzeni (tek sütun uyarlama)** | Kişisel bilgiler → Hakkımda → İş deneyimi → Eğitim → Dil becerileri → Dijital beceriler → Projeler | Resmî Europass, AB düzenleyicisinin ürettiği iki sütunlu bir formdur; burada aynı bölümler tek sütuna dizilir ve uygulamada "uyarlama" diye yazar. Dil düzeyi dil başına tek CEFR düzeyi (A1-C2) ya da "anadil" (resmî formdaki beş alt beceri sadeleştirildi). Özet ("Hakkımda") yalnız burada kullanılır. |

Kaynaklar: Overleaf "Jake's Resume" şablonu; Harvard FAS ve HSPH kariyer rehberleri; Europass
bölüm yapısını anlatan rehberler (europass.europa.eu resmî düzenleyicisi esastır).

**Kullanıcının girdiği bölümler** ("Bilgilerim": ad, iletişim, eğitim, deneyim, dil) GitHub'da
yoktur; telefonda saklanır (`shared_preferences`, anahtar `cv_profile`; web'de tarayıcının yerel
deposu), sunucuya gitmez. Çıkış ve "Verilerimi sil" `AuthService.logout` üzerinden bunu da siler.
Tarihler serbest metindir (ör. "Eyl 2022 – Haz 2026"); kayıtların kimliği kalıcıdır.
Değişiklikler "Kaydet" ile yazılır ve "Bilgilerin kaydedildi" mesajı gösterilir; kayıt başarısızsa
hata mesajı çıkar ve sayfa eski haliyle kalır. Kaydetmeden çıkılırsa sorulur (kaydet / kaydetmeden
çık / vazgeç).

## PDF
"PDF olarak indir" seçili format ve dilde PDF üretir (`mobile/lib/cv/cv_pdf.dart`, `pdf` paketi);
web'de indirilir, Android'de paylaşım menüsü açılır. Ekrandaki sayfayla aynı format tanımını okur.
- Yazı tipi: Noto Sans ve Noto Serif (normal, kalın, italik), `mobile/assets/fonts/` (SIL OFL,
  `OFL.txt`; kaynak notofonts GitHub). Varsayılan PDF yazı tiplerinde ş, ğ, ı, İ yok; test,
  gömülü yazı tiplerinin bu harfleri içerdiğini denetler. Ekrandaki önizleme de aynı yazı tiplerini
  kullanır (Harvard serif).
- Basılmayanlar: doldurulmamış yer tutucular (sayısı kullanıcıya söylenir) ve kaynak satırları.
- Dosya adı `cv-ad-format-dil.pdf`. Boşsa sayfada görünmez; yalnız düzenleme ekranında "ekle" önerisi
çıkar.

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
   - Ayrıca formatlar için: repo adresi, teknoloji listesi (ana dil + araçlar) ve tarih aralığı
     (GitHub'daki oluşturma ve son push tarihi; uydurulmaz, yoksa boş).
4. **Beceriler:** Dil dağılımında payı en büyük diller (%1 altı "Diğer" hariç) ve araçlar.
5. **Etkinlik:** Toplam commit ve aktif gün; başkalarının repolarına açılan ve merge edilen PR
   (varsa); kod incelemesi sayısı (varsa).

Veri yetersizse (ör. hiç commit yoksa) ilgili madde üretilmez; boş bölüm gönderilmez.

## Dil
Türkçe ve İngilizce aynı veriden, aynı kimliklerle üretilir; yalnız cümleler değişir. Sayıdan
sonra Türkçe ek kullanılmaz (metrikler.md genel kuralı).
