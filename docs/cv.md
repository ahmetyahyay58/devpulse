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
- **Şablonların hepsi tek sütundur.** Tablo ve sütun kullanılmadığı tasarımla garanti edildiği için
  biçim kontrolünde ayrıca denetlenmez; uygulama bu kurala uymayan şablon sunmaz.
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
| Hakkımda | Kullanıcının kendini tanıttığı bölüm. Türkçe ve İngilizce ayrı yazılır, en çok 600 karakter. **Varsayılan (boşken):** telefonda yalnız GitHub verisinden kurulan birkaç cümle: backend'in özet cümlesi (sayılar buradan), en çok 3 programlama dili, en çok 3 araç, ilk 2 seçili proje; ardından sarı bir yer tutucu "[Kendini tanıt: ilgi alanların, hedefin ve aradığın fırsat.]" (PDF'e basılmaz). Yeni sayı üretilmez; değişkenlerden sonra ek kullanılmaz. Özet maddesi gizlenirse varsayılan metin de çıkmaz. **Kullanıcı yazarsa** o dilin CV'sinde varsayılanın yerine geçer ve kaynak satırında "Senin yazdığın" der. "Taslaktan başla" varsayılan metni kutuya koyar; sonrası kullanıcının metnidir (17 Kas, geliştirici isteği: "dolu ama değiştirilebilir"). Beş şablonun hepsinde vardır. |
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
| Projeler | Kullanıcının kendi, fork olmayan, arşivsiz, herkese açık repolarından **en çok 6** seçilir (varsayılan: sağlık puanına göre ilk 6; 17 Kas'ta 4'ten 6'ya çıkarıldı). GitHub'da olmayan proje eklenemez; o tür işler "Deneyim"e yazılır. |
| Beceriler | Diller ve araçlar listeden çıkarılabilir (ör. Flutter'ın ürettiği C++/CMake); elle eklenen beceri "Senin eklemen" diye işaretlenir. |
| Şeffaflık | Düzenlenen madde "Senin düzenlemen" diye işaretlenir (kaynakları göster açıkken görünür); tek madde ve tümü için "Taslağa dön". Uygulama düzenlenen metindeki sayıları doğrulayamaz; "doğrulandı" demez, yalnız "düzenlendi" der. |

Metin düzenlemeleri dile göre ayrı tutulur (Türkçe CV'de Türkçe, İngilizce CV'de İngilizce metin);
gizleme, proje seçimi ve beceri değişiklikleri iki dilde ortaktır.

**Bildirimler:** Kaydetme ve PDF sonuçları alttaki çubuk yerine ekranın üst ortasında beliren
kısa bir mesaj balonuyla gösterilir (`mobile/lib/ui/toast.dart`; geliştirici tercihi, 17 Kas).
Başarı ve hata hem simge hem renkle söylenir.

## Biçim kontrolü (Faz 8c, 17 Kas 2026)
CV sekmesindeki "Biçim kontrolü" seçili format ve dildeki CV'yi (düzenlemeler uygulanmış hal +
Bilgilerim) denetler. Tamamen telefonda çalışır; LLM ve sunucu kullanılmaz. Kod
`mobile/lib/cv/cv_check.dart` (saf fonksiyon, testli). **"ATS'den geçer" denmez:** ekranda
"Bu kontrol düzen ve eksiklikler içindir; işe alım yazılımlarından (ATS) geçeceğini garanti etmez."
yazar. Kurallar sabittir ve iki düzeydedir: **Eksik** (CV'de açık bir boşluk) ve **Öneri**.

| Kural | Düzey | Ne zaman |
|---|---|---|
| Ad soyad | Eksik | Ad yazılmamış (başlıkta GitHub kullanıcı adı görünür). |
| E-posta | Eksik | E-posta yok. |
| Telefon, LinkedIn | Öneri | Yoksa. |
| Eğitim | Eksik | Hiç eğitim kaydı yok. Kayıtta tarih yoksa Öneri. |
| Deneyim | Öneri | Hiç kayıt yoksa: staj, gönüllülük, kulüp işi eklenebilir ya da "Beceri odaklı" şablon önerilir (zaten o şablondaysa önerilmez). |
| Doldurulmamış yer tutucu | Eksik | "[…]" kalan maddesi olan her proje (etki cümleleri); PDF'e basılmadıkları söylenir. Hakkımda yer tutucusu Hakkımda kuralında. |
| Hakkımda | Eksik / Öneri | O dilde kullanıcı metni yoksa Eksik (hazır metin kullanılıyor, "kendini tanıt" yer tutucusu PDF'e basılmaz); hazır metin de gizlenmişse "bölüm boş" Eksik; 80 karakterden kısaysa Öneri. |
| Projeler | Öneri / Eksik | Hiç proje yoksa Eksik; 2'den azsa Öneri; açıklaması olmayan proje için Öneri. |
| Deneyim maddeleri | Öneri | Hiç madde yoksa; 200 karakteri aşan madde varsa (madde başına tek cümle). |
| İlgi alanları | Öneri | Format bu bölümü gösteriyor ve o dilde boşsa. |
| Sayfa sayısı | Eksik | PDF gerçekten üretilip sayfaları sayılır (tahmin değil). Sınır: Jake's, Harvard ve Beceri odaklı 1 sayfa (öğrenci ve 5 yıldan az deneyim için yaygın öneri); Europass ve Türkiye klasik 2 sayfa. Aşılırsa Eksik. |

Mesajlarda değişkenden sonra Türkçe ek kullanılmaz ("proje-a: açıklama yok"). Her maddenin
yanında ilgili ekrana götüren düğme vardır (Bilgilerim ya da Maddeleri düzenle). Kontrol bir
puan vermez; yalnız liste ve sayı ("2 eksik, 3 öneri") gösterir.

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
3. **Projeler (uygun repoların hepsi, sıralı; ilk 6 varsayılan seçili):** Kullanıcının kendi, fork olmayan, arşivlenmemiş ve herkese açık
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
