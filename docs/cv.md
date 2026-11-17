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
Hiçbiri "ATS'den geçer" diye sunulmaz. Beşi de tek sütun; tarihler satır sonunda sağa yaslanır
(sütun değildir). Düzen tek yerde, veri olarak tanımlıdır (`mobile/lib/cv/cv_formats.dart`);
ekrandaki önizleme ve PDF aynı tanımı okur.

| Format | Bölüm sırası | Notlar ve uyarlamalar |
|---|---|---|
| **Jake's Resume** | Hakkımda → Eğitim → Deneyim → Projeler → Teknik beceriler → Sertifikalar | Yazılımcılar arasında yaygın tek sayfalık LaTeX şablonu (Overleaf). Proje satırı "Ad \| teknolojiler", tarih sağda. Özgün şablonda özet ve sertifika yok; ikisi de eklemedir (uyarlama), boşsa görünmez. |
| **Harvard tarzı** | Hakkımda → Eğitim → Deneyim → Projeler → Beceriler → Sertifikalar | Tek bir resmî Harvard şablonu yok; Harvard kariyer rehberlerindeki ters kronolojik düzen izlenir: eğitim önce, madde başına tek cümle, serif yazı tipi. Rehberde özet ve "Projeler" yok; ikisi eklemedir (uyarlama). |
| **Europass düzeni (tek sütun uyarlama)** | Kişisel bilgiler → Hakkımda → İş deneyimi → Eğitim → Dil becerileri → Dijital beceriler → Projeler → Sertifikalar ve kurslar → Hobiler ve ilgi alanları → Ek bilgiler | Resmî Europass, AB düzenleyicisinin ürettiği iki sütunlu bir formdur; burada aynı bölümler tek sütuna dizilir ve uygulamada "uyarlama" diye yazar. Dil düzeyi dil başına tek CEFR düzeyi (A1-C2) ya da "anadil" (resmî formdaki beş alt beceri sadeleştirildi). |
| **Türkiye klasik** | Hakkımda → Eğitim → İş deneyimi → Projeler → Sertifikalar ve kurslar → Yabancı diller → Bilgisayar bilgisi → İlgi alanları | Türkiye'deki özgeçmiş rehberlerinde yaygın bölüm düzeni (tek resmî şablon yok). Ad sola yaslı, bölüm başlıkları gri şerit içinde. Kişisel bilgiler (doğum tarihi, askerlik, ehliyet), fotoğraf ve referans bölümü yok (geliştirici kararı, 17 Kas). |
| **Beceri odaklı** | Hakkımda → Teknik beceriler → Öne çıkan projeler → Sertifikalar → Deneyim → Eğitim → Diller | İşlevsel (beceri temelli) özgeçmiş: beceriler ve projeler öne alınır; deneyimi az olan öğrenciye uyar. Bazı işe alımcıların kronolojik düzeni tercih ettiği notta söylenir. |

Kaynaklar: Overleaf "Jake's Resume" şablonu; Harvard FAS ve HSPH kariyer rehberleri; Europass
bölüm yapısını anlatan rehberler (europass.europa.eu resmî düzenleyicisi esastır); Türkiye'deki
özgeçmiş hazırlama rehberleri (kariyer siteleri ve üniversite açık ders notları; bölüm adları ve
sıraları kaynaktan kaynağa değişir, bu yüzden "standart" denmez).

**Eklenen bölümler (geliştirici kararı, 17 Kas 2026).** Hepsini kullanıcı "Bilgilerim"de yazar;
GitHub'da yoktur, yalnız cihazda kalır, LLM'e gitmez.

| Bölüm | Kural |
|---|---|
| Hakkımda | Türkçe ve İngilizce ayrı yazılır, en çok 600 karakter (2-4 cümle). Yazılmışsa o dilin CV'sinde veri özetinin **yerine geçer** ve kaynak satırında "Senin yazdığın" der; boşsa GitHub verisinden gelen özet cümlesi görünür (eskisi gibi kilitli, gizlenebilir). "Taslaktan başla" o dildeki veri özetini metin kutusuna koyar; sonrası kullanıcının metnidir. Beş şablonun hepsinde vardır. |
| Sertifikalar ve kurslar | Ad, veren kurum, tarih (serbest metin). Beş şablonda var; boşsa görünmez. |
| İlgi alanları | Türkçe ve İngilizce ayrı, tek satır, en çok 150 karakter. Yalnız Türkiye klasik ve Europass'ta görünür (Jake's, Harvard ve Beceri odaklı düzenlerde bu bölüm geleneksel değil). |

Bilinçli olarak eklenmeyenler: fotoğraf, doğum tarihi, askerlik, ehliyet, medeni durum ve
referanslar (başkasının adı ve telefonu kişisel veridir). Bölümler uzadıkça Jake's tek sayfayı
aşabilir; bunu "Biçim kontrolü" uyaracak, şablon kendisi kesmez.

**Kullanıcının girdiği bölümler** ("Bilgilerim": ad, iletişim, eğitim, deneyim, dil) GitHub'da
yoktur; telefonda saklanır (`shared_preferences`, anahtar `cv_profile`; web'de tarayıcının yerel
deposu), sunucuya gitmez. Çıkış ve "Verilerimi sil" `AuthService.logout` üzerinden bunu da siler.
Tarihler serbest metindir (ör. "Eyl 2022 – Haz 2026"); kayıtların kimliği kalıcıdır.
Değişiklikler "Kaydet" ile yazılır ve "Bilgilerin kaydedildi" mesajı gösterilir; kayıt başarısızsa
hata mesajı çıkar ve sayfa eski haliyle kalır. Kaydetmeden çıkılırsa sorulur (kaydet / kaydetmeden
çık / vazgeç).

## Maddeleri düzenleme (geliştirici kararı, 17 Kas 2026)
GitHub'dan gelen taslak çıktıdan önce düzenlenebilir; sınırlar "uydurma sayı yok" ilkesini korur.
Düzenlemeler yalnızca cihazda saklanır (anahtar `cv_edits`), "Kaydet" ile yazılır; çıkış ve
"Verilerimi sil" bunları da siler.

| Konu | Kural |
|---|---|
| Veriden gelen sayılar | **Kilitli.** Sayı içeren maddeler (`work` commit sayısı, özet, etkinlik satırları) ve proje tarihleri düzenlenemez; yalnızca gizlenebilir. Uygulama CV'deki her sayının GitHub'dan geldiğini garanti eder. |
| Serbest metin | Açıklama (`desc`), teknoloji (`stack`) ve etki (`impact`) düzenlenebilir; madde başına en çok **200 karakter** (Harvard rehberi: madde başına tek cümle). Etki "[…]" haliyle kalırsa PDF'e basılmaz. |
| Ek madde | Proje başına en çok **2**; kaynak satırında "Senin eklemen". |
| Projeler | Kullanıcının kendi, fork olmayan, arşivsiz, herkese açık repolarından **en çok 4** seçilir (varsayılan: sağlık puanına göre ilk 4). GitHub'da olmayan proje eklenemez; o tür işler "Deneyim"e yazılır. |
| Beceriler | Diller ve araçlar listeden çıkarılabilir (ör. Flutter'ın ürettiği C++/CMake); elle eklenen beceri "Senin eklemen" diye işaretlenir. |
| Şeffaflık | Düzenlenen madde "Senin düzenlemen" diye işaretlenir (kaynakları göster açıkken görünür); tek madde ve tümü için "Taslağa dön". Uygulama düzenlenen metindeki sayıları doğrulayamaz; "doğrulandı" demez, yalnız "düzenlendi" der. |

Metin düzenlemeleri dile göre ayrı tutulur (Türkçe CV'de Türkçe, İngilizce CV'de İngilizce metin);
gizleme, proje seçimi ve beceri değişiklikleri iki dilde ortaktır.

**Bildirimler:** Kaydetme ve PDF sonuçları alttaki çubuk yerine ekranın üst ortasında beliren
kısa bir mesaj balonuyla gösterilir (`mobile/lib/ui/toast.dart`; geliştirici tercihi, 17 Kas).
Başarı ve hata hem simge hem renkle söylenir.

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
3. **Projeler (uygun repoların hepsi, sıralı; ilk 4 varsayılan seçili):** Kullanıcının kendi, fork olmayan, arşivlenmemiş ve herkese açık
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
