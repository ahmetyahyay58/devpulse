# Metrik tanımları

Bu belge, uygulamanın gösterdiği her metriğin nasıl hesaplandığını tanımlar.
Kod (`backend/app/metrics/`) bu belgeye uyar; tanım değişirse önce burası güncellenir.

## Genel ilkeler

- **Kaynak:** Yalnızca kullanıcının kendi commit'leri (`commits` tablosu; `history(author)` ile
  varsayılan daldan çekilir). Katkı takvimi (PR, issue, inceleme dahil) yalnızca takvim
  görünümünde kullanılır, metriklere karışmaz.
- **Zaman:** Her commit'in yazar zamanı (`authored_at`, UTC) kullanıcının saat dilimine
  (`users.timezone`) çevrilir. Saat dilimi bilinmiyorsa UTC kullanılır ve saat/gün
  metriklerinin güveni en fazla "Düşük güven" olur.
- **Bugün:** Kullanıcının saat dilimindeki bugünün tarihi.
- **Betimleme, puanlama değil:** Commit sayısı üretkenliği ya da kaliteyi ölçmez. Metrikler
  çalışma alışkanlığını betimler; "iyi/kötü" yargısı içermez.
- **Kural tabanlıdır:** Bu sayfadaki metrikler makine öğrenmesi kullanmaz (değişim noktaları
  istatistiksel bir bölütlemedir, öğrenme değildir). Tek istisna
  "Olağan dışı günler" bölümündeki Isolation Forest kıyasıdır: gözetimsiz bir yöntemdir
  (etiketli veri yok), arayüzdeki ana sonuç ise istatistiksel MAD kuralıdır. İkinci istisna
  "Repo kümeleri"dir (k-means, gözetimsiz; doğruluk iddiası yok).

## Veri yeterliliği (üç durum)

Her metrik şu üç durumdan biriyle gelir. Eşikler sezgisel seçilmiştir (istatistiksel bir
güç analizine dayanmaz) ve `backend/app/metrics/sufficiency.py` içinde tek yerde durur.

| Metrik grubu | Yeterli veri yok | Düşük güven | Normal |
|---|---|---|---|
| Süreklilik | < 3 aktif gün | < 10 aktif gün ya da ilk commit'ten bu yana < 30 gün | diğer |
| Ritim | < 10 commit | < 50 commit ya da saat dilimi bilinmiyor | diğer |
| Oturum ve yoğunluk | < 3 oturum | < 15 oturum | diğer |
| Olağan dışı günler | < 10 aktif gün | < 30 aktif gün | diğer |
| Commit türleri | < 10 commit | < 30 commit | diğer |
| Değişim noktaları | < 12 hafta ya da < 10 commit | < 26 hafta | diğer |
| Teknoloji | Dil bilgisi olan kendi reposu yok | < 3 repo | diğer |
| Yıl kıyası | İki dönemin birinde hiç commit yok | Dönemlerden birinde < 10 commit | diğer |
| İşbirliği | Sonuçlanmış (merge edilmiş ya da kapatılmış) PR < 3 | Sonuçlanmış PR < 10 | diğer |
| Yıllık özet | Dönemde < 10 commit | < 50 commit | diğer |
| Repo kümeleri | < 5 kendi repo | 5-9 repo | diğer |
| Haftalık özet | İki dönemde de commit yok | — | diğer |

"Yeterli veri yok" durumunda değer yine hesaplanır ama arayüz sayıyı öne çıkarmaz.

## Tanımlar

### Aktif gün
Kullanıcının yerel saatine göre en az bir commit içeren takvim günü.

### Süreklilik
- **Güncel seri:** Bugün ya da dün aktifse, o günden geriye doğru kesintisiz aktif gün sayısı.
  İkisi de aktif değilse 0. (Dün dahil edilir: gün henüz bitmemişken seri sıfırlanmasın diye.)
- **En uzun seri:** Tüm geçmişteki en uzun kesintisiz aktif gün dizisi.
- **Son 90 günde aktif gün oranı:** Son 90 gündeki aktif gün sayısı / 90. İlk commit 90 günden
  yeniyse payda, ilk commit'ten bugüne geçen gün sayısıdır.

### Ritim
- **Saat dağılımı:** Commit'lerin yerel saate göre 24 saatlik dağılımı.
- **Gün dağılımı:** Haftanın günlerine (Pazartesi–Pazar) göre dağılım.
- **En yoğun saat:** En çok commit'in düştüğü saat (eşitlikte en erken saat).
- **Gece oranı:** Yerel saatle 00:00–05:59 arasındaki commit'lerin oranı.
- **Hafta sonu oranı:** Cumartesi ve Pazar commit'lerinin oranı.

### Oturum (kural, ML değil)
Commit'ler zamana göre sıralanır; iki ardışık commit arasındaki boşluk **2 saatten fazlaysa**
yeni oturum başlar. Oturum süresi = oturumdaki ilk ve son commit arasındaki süre (tek
commit'lik oturumun süresi 0'dır; gerçek çalışma süresi commit'lerden bilinemez, bu bir alt
sınırdır).
- **En uzun oturum:** Süresi en uzun oturum (dakika) ve başladığı gün. Eşitlikte en yenisi.
- **En sık başlangıç saati:** Oturumların ilk commit'inin yerel saatine göre en çok tekrarlanan
  saat (eşitlikte en erken saat). Commit'in saati değil, oturumun başladığı saattir.
- Ortalama süre gösterilmez, medyan gösterilir (bkz. Yoğunluk): tek bir uzun oturum ortalamayı
  bozar.

### Yoğunluk
- **Aktif gün başına commit:** Aktif günlerdeki commit sayısının medyanı.
- **Oturum başına commit:** Medyan.
- **Oturum süresi:** Medyan (dakika).
- **Commit başına değişen satır:** (eklenen + silinen) satırların medyanı. Satır bilgisi
  olmayan commit'ler bu hesaba girmez.

Ortalama yerine **medyan** kullanılır: tek bir dev commit (ör. bağımlılık klasörü) ortalamayı
bozar, medyanı bozmaz.

### Değişim noktaları (istatistik, ML değil)
**Ne gösterir:** Haftalık commit sayısının kalıcı olarak değiştiği haftaları; örneğin
"haftada ~1 commit"ten "haftada ~5 commit"e geçiş. Tek bir yoğun gün değil (o "Olağan dışı
günler"dir), haftalar süren düzey değişimi aranır.

- **Veri:** Son 52 hafta (ilk commit daha yeniyse ilk commit'in haftasından başlar), yerel
  saatle Pazartesi başlayan haftalık commit sayıları; commit'siz haftalar 0.
- **Yöntem:** `ruptures` kütüphanesinin PELT algoritması, `l1` maliyeti (her evre kendi
  medyanıyla temsil edilir), en kısa evre 4 hafta. Ceza = 2 · σ · ln(n); σ, ardışık
  haftaların farklarının MAD'iyle ölçülen gürültü (σ = 1,4826 · MAD / √2), n hafta sayısı.
  σ 0 çıkarsa 1 alınır.
- **Neden `l1`:** Ortalamaya dayalı `l2` maliyeti tek bir çok yoğun haftayı (ör. 25 commit'lik
  bir hafta) ayrı bir "evre" yapıyordu; geliştiricinin gerçek verisinde ve sentetik bir
  patlama senaryosunda bu görüldü (13 Kas). Tek haftalık patlama düzey değişimi değildir,
  "Olağan dışı günler"in konusudur. Medyana dayalı `l1` bunu evre saymaz; kalıcı düzey
  değişimlerini (ör. 1'den 6'ya çıkış, tamamen durma) aynı şekilde bulur. Evre sayısı 6'yı aşarsa ceza ikiye katlanarak yeniden aranır (en çok
  6 evre: renkler sabit sırayla verilir, döngüye girmez).
- **Çıktı:** Evreler (başlangıç ve bitiş haftası, haftalık ortalama commit; evreler medyana
  göre ayrılır, okunması kolay olsun diye ortalama gösterilir). Özet son iki
  evreyi karşılaştırır.
- **Sınır:** Ceza katsayısı ve en kısa evre sezgiseldir; yöntem değişimin *nedenini* bilmez.
  Gözetimli öğrenme değildir; etiketli veri yoktur.

| Yeterli veri yok | Düşük güven | Normal |
|---|---|---|
| < 12 hafta ya da < 10 commit | < 26 hafta | diğer |

### Olağan dışı günler (anomali, gözetimsiz)
**Ne arar:** Kullanıcının kendi alışkanlığına göre belirgin şekilde yoğun geçen günleri.
"İyi" ya da "kötü" yargısı içermez. Yalnızca **aktif günler** (en az bir commit) incelenir;
hiç commit olmayan günler dahil edilseydi seyrek çalışan birinin medyanı 0 olur ve her aktif
gün "olağan dışı" görünürdü. Yalnızca yukarı yönlü sapma aranır (düşük gün zaten sıradandır).

**Ana yöntem: robust z-skoru (medyan/MAD).** Aktif günlerin commit sayıları için
`z = 0,6745 × (x − medyan) / MAD`, MAD = |x − medyan| değerlerinin medyanı. `z > 3,5` olan
gün olağan dışıdır (eşik: Iglewicz ve Hoaglin, 1993, *How to Detect and Handle Outliers*).
MAD = 0 ise (günlerin yarıdan fazlası aynı sayıda commit) z hesaplanamaz; bu durumda
"olağan dışı gün yok" denir ve gerekçesi gösterilir.

**Kıyas yöntemi: Isolation Forest** (scikit-learn, `random_state` sabit). Her aktif gün beş
özellikle temsil edilir: commit sayısı, log(1 + değişen satır), gece (00–06) commit oranı,
oturum sayısı, gün içindeki ilk–son commit arası saat. `contamination = 0,05` (günlerin
yaklaşık %5'i işaretlenir; sabit bir varsayımdır). Arayüzde ana sonuç MAD'dir; Isolation
Forest yalnızca kıyas ve rapor içindir.

**Veri yeterliliği:** < 10 aktif gün "Yeterli veri yok", < 30 aktif gün "Düşük güven".

**Enjeksiyon testi:** Sentetik demo verisine bilerek eklenen 3 günlük yoğunluğun (bkz.
`demo_user.json` → `_injected`) iki yöntemce bulunup bulunmadığı ve kaç yanlış alarm
verildiği ölçülür: `py -m app.metrics.anomaly_eval`. Sonuçlar `docs/olcumler.md`'dedir.
Sentetik veri yöntemin genel başarısını kanıtlamaz; yalnızca bilinen bir olayı yakalayıp
yakalamadığını gösterir.

### Commit türleri (gözetimli ML + kural)
Her commit mesajının **ilk satırı** altı türden birine ayrılır: Yeni özellik, Hata düzeltme,
Belgelendirme, Bakım ve düzenleme, Test, Belirsiz (kılavuz: `docs/etiketler.md`). Önce önek ve
Türkçe/İngilizce kurallar denenir; karar verilemezse model (harf parçası TF-IDF + lojistik
regresyon) karar verir. Her commit için kaynak (kural/model) ve gerekçe gösterilir.
- **Doğruluk:** tutarlı bir test standardına göre %63, kappa 0,53 ("orta"); türler kesin bilgi
  değil, yaklaşık bir dağılımdır (ayrıntı `docs/olcumler.md`). Bu not arayüzde de gösterilir.
- **Veri yeterliliği:** < 10 commit "Yeterli veri yok", < 30 commit "Düşük güven".
- Commit mesajları hiçbir dış hizmete gönderilmez; sınıflandırma sunucuda yereldir.

### Teknoloji (diller, çeşitlilik, araçlar)
**Kaynak:** Kendi (fork olmayan) repoların. Başkasına ait repolarda kodun çoğu başkasınındır;
fork'larda kod asıl repodan gelir. Bu yüzden ikisi de sayılmaz.

- **Dil dağılımı:** GitHub'ın her repo için verdiği dil başına bayt (`languages`, Linguist
  tespiti) repolar üzerinden toplanır; pay = dilin baytı / toplam bayt. HTML/CSS gibi
  biçimlendirme dilleri de GitHub'ın saydığı şekliyle dahildir. Bayt, emeği ölçmez: tek bir
  büyük repo dağılımı belirler (bu yüzden her dilin kaç repoda geçtiği de gösterilir).
- **Dil sayısı:** En az bir kendi reposunda görülen farklı dil sayısı.
- **Baskın dil:** Payı en yüksek dil ve payı.
- **Çeşitlilik (puan değil):** Bayt paylarının normalleştirilmiş Shannon entropisi,
  H / ln(k) (H = −Σ pᵢ ln pᵢ, k = dil sayısı), %0-100. Tek dil = %0; bütün diller eşit paylı
  = %100. Yalnız *dengeyi* betimler; "yüksek = iyi" değildir (tek dilde derinleşmek de geçerli
  bir yoldur). Payı %1'in altındaki diller hesaba girer ama listede "Diğer" altında toplanır.
- **Tespit edilen araçlar:** Varsayılan dalın kök dizinindeki dosya ve klasör adlarından
  (ör. `Dockerfile` → Docker, `pubspec.yaml` → Flutter/Dart, `.github/workflows` → GitHub
  Actions). Tablo `backend/app/sync/tools.py` içindedir. Dosya içeriği okunmaz; dosya adları
  saklanmaz, yalnız araç adı saklanır. Alt klasördeki dosyalar görülmez (bilinen sınırlama).
- **Bilinen sınırlama:** Linguist, çatıların otomatik ürettiği dosyaları da sayabilir. Örneğin
  bir Flutter projesinin `windows/`, `linux/`, `ios/` klasörlerindeki şablon kodu C++, CMake,
  Swift, Kotlin olarak görünür (geliştiricinin kendi hesabında 10 dilin birkaçı böyle, 13 Kas).
  Bu diller genelde küçük paylıdır; dil sayısı bu yüzden gerçekte yazılan dilden fazla olabilir.

| Yeterli veri yok | Düşük güven | Normal |
|---|---|---|
| Dil bilgisi olan kendi reposu yok | < 3 repo | diğer |

### Başarımlar (rozetler)
**İlke:** Rozetler alışkanlığı ve proje bakımını tanır; ham commit sayısını ödüllendirmez
(çok commit atmak kendi başına bir başarı değildir). Her rozetin ilerlemesi gösterilir
(mevcut / hedef); hedefe ulaşınca açılır. Hepsi deterministik kurallardır.

| Rozet | Koşul | İlerleme |
|---|---|---|
| Bir haftalık seri | En uzun seri ≥ 7 gün | en uzun seri / 7 |
| Bir aylık seri | En uzun seri ≥ 30 gün | en uzun seri / 30 |
| Düzenli | Son 90 günde ≥ 27 aktif gün (%30) | son 90 gündeki aktif gün / 27 |
| Vitrin | En az bir kendi reposunun proje sağlığı 100 | en yüksek skor / 100 |
| Belgelendirici | Puanlanan bütün repolarda README var (en az 1 repo) | README'si olan / puanlanan repo |
| Lisanslı | Puanlanan bütün repolarda lisans var (en az 1 repo) | lisanslı / puanlanan repo |
| Çok dilli | Kendi repolarında payı ≥ %5 olan en az 3 dil | bu koşuldaki dil sayısı / 3 |
| Katkıcı | Başkasına ait en az bir repoya commit | katkı yapılan repo / 1 |

Seri ve aktif gün tanımları "Süreklilik", repo koşulları "Proje sağlığı", dil payı
"Teknoloji" ile aynıdır; rozet yeni bir hesap yapmaz, var olanları eşikle karşılaştırır.
Eşikler sezgiseldir.

### Yıl kıyası
**Dönem:** Bu yılın 1 Ocak'ından bugüne (yerel saat) ile geçen yılın aynı dönemi (1 Ocak'tan
geçen yılın bugünkü tarihine; 29 Şubat yoksa 28 Şubat). Tam geçen yıl ile yarım bu yıl
kıyaslanmaz; bu yanıltıcı olurdu.

- Kıyaslananlar: commit sayısı, aktif gün, dönem içindeki en uzun seri, commit atılan repo sayısı.
- **Değişim:** (bu yıl − geçen yıl) / geçen yıl × 100, tam sayıya yuvarlanır. Geçen yıl 0 ise
  yüzde hesaplanmaz ("geçen yıl aynı dönemde yoktu" yazılır).
- **Dil:** Betimleyicidir: "geçen yılın aynı dönemine göre %40 daha fazla commit". "Daha
  üretken", "daha iyi" gibi yargı kullanılmaz.

| Yeterli veri yok | Düşük güven | Normal |
|---|---|---|
| İki dönemin birinde hiç commit yok | Dönemlerden birinde < 10 commit | diğer |

### Yıllık özet (Faz 9)
Hikâye gibi kayan slaytlar; yeni bir hesap yapmaz, var olan tanımları tek yıla uygular. Kod
`backend/app/metrics/year_summary.py`, uç nokta `GET /metrics/year-summary?year=YYYY`.

**Dönem:** Bu yıl için 1 Ocak'tan bugüne (yerel saat), geçmiş bir yıl için 1 Ocak – 31 Aralık.
Dönem her slaytta yazılır. Kaynak: senkronlanan commit'ler (kendi ve katkı verilen repolar).

| Slayt | Tanım |
|---|---|
| Yıl toplamı | Dönemdeki commit sayısı ve aktif gün sayısı. |
| En yoğun ay | En çok commit atılan ay (eşitlikte erken olan). |
| En çok dil | Commit'ler, atıldıkları reponun **ana diline** göre gruplanır; en çok commit'li dil (eşitlikte alfabetik) ve payı. Teknoloji sekmesindeki bayt payı değildir (o tüm zamanlar içindir); slayt bunu söyler. Ana dili bilinmeyen repolardaki commit'ler bu slayta girmez. |
| Gece payı | Ritim tanımındaki gece (00:00-06:00) commit oranı ve en yoğun saat. |
| En uzun seri | Dönem içindeki en uzun art arda aktif gün. |
| Kodlama süresi (tahmin) | Oturum kuralıyla (2 saat boşluk) bulunan oturumların sürelerinin toplamı, saate yuvarlanır. Tek commit'lik oturum 0 dakikadır; bu yüzden **alt sınırdır** ve slaytta "tahmin, en az" diye yazar. |
| Dil yolculuğu | Dönemde commit atılan ana diller, o dilde ilk commit'in tarihine göre sıralı (ilk ay ile). |
| Kod incelemesi | GitHub'ın o yıl için saydığı inceleme katkısı (`review_years`); veri yoksa slayt gösterilmez. |
| Son kart | Açılan rozet sayısı; "Paylaş" düğmesi. |

| Yeterli veri yok | Düşük güven | Normal |
|---|---|---|
| Dönemde < 10 commit | < 50 commit | diğer |

"Yeterli veri yok"ta slaytlar yerine tek bir "bu yıl için yeterli veri yok" kartı gösterilir.
Metinler betimleyicidir; sayıdan sonra Türkçe ek kullanılmaz ("Gece payı: %12").

### İşbirliği (PR ve kod incelemeleri)
**Ne ölçer:** Kullanıcının açtığı pull request'lerin (PR) nasıl sonuçlandığını ve başkalarının
PR'larını ne kadar incelediğini. **Ne ölçmez:** PR'ların büyüklüğünü, kalitesini ya da ekip
içindeki rolü.

- **Kaynak:** Kullanıcının açtığı PR'lar (`viewer.pullRequests`; GitHub'ın kullanıcıya
  gösterdiği, `read:user` kapsamında görünenler) ve yıl yıl `totalPullRequestReviewContributions`
  (GitHub'ın saydığı kod incelemesi katkıları). Saklanan: PR'ın açılış, merge ve kapanış zamanı,
  durumu, kendi reposuna mı açıldığı. PR başlığı, repo adı, PR kimliği ve karşı tarafın kullanıcı
  adı saklanmaz; her senkronda kayıtlar baştan yazılır.
- **Merge oranı** = merge edilen / (merge edilen + merge edilmeden kapatılan). Açık PR'lar
  henüz sonuçlanmadığı için paydaya girmez.
- **Merge süresi:** Açılıştan merge'e geçen süre; merge edilenlerin **medyanı** (saat ya da gün).
  Ortalama yerine medyan: aylarca açık kalan tek bir PR ortalamayı bozar.
- **Kendi repon / başkasının reposu ayrı gösterilir.** Kendi reposuna açılan PR'ı çoğu zaman
  kişi kendisi merge eder; bu, oranı şişirir. Asıl işbirliği göstergesi başkasının reposuna
  açılan PR'ların sonucudur.
- **İnceleme sayısı:** Tüm yılların toplamı ve bu yıl (1 Ocak'tan bugüne, UTC yıl sınırı:
  GitHub yıl aralıklarını UTC verir).
- **Yıl yıl:** Açılan PR ve inceleme sayıları yıllara göre (çubuk grafik).
- **Aylık merge süresi (19 Kas):** Bu ay dahil son 12 ay (UTC ay sınırı, yıl satırlarıyla aynı).
  Her ay için o ay merge edilen PR sayısı ve açılıştan merge'e sürenin medyanı; PR'ın ayı
  **merge zamanına** göre belirlenir. O ay merge yoksa medyan yoktur (boş bırakılır, 0 çizilmez).
  Grup özet cümlesindeki kuralla seçilir: başkalarının repolarında sonuçlanmış PR varsa onlar,
  yoksa toplam; grafik hangi grubu gösterdiğini yazar (kendi reponda PR çoğunlukla dakikalar içinde
  kendin merge ettiğin için süreyi kısa gösterir). Tek PR'lık ayın medyanı gürültüdür: 3'ten az
  PR'lı aylar soluk çizilir ve PR sayısı her çubukta yazar. Genel yeterlilik "Yeterli veri yok"
  ise grafik gösterilmez.
- **Katkı dengesi (19 Kas):** Commit'lerin ve açtığın PR'ların kendi repoların ile başkalarına ait
  repolar arasındaki dağılımı; yalnız iki sayı ve başkalarının payı (%). Repo adı ve karşı tarafın
  adı yoktur. Commit tarafı `commits` tablosundan (`repos.is_owner`), PR tarafı yukarıdaki kendi /
  başkası gruplarından gelir. Betimleyicidir: payın yüksek ya da düşük olması iyi/kötü değildir.
  Sınırlama: başkalarının repolarındaki commit'ler yalnız GitHub'ın katkı listesinde
  (`commitContributionsByRepository`, yıl başına en çok 100 repo) görünen repolardan, o reponun
  varsayılan dalından ve yalnız senin yazar olduğun commit'lerden gelir. Başka bir dala atılıp
  birleştirilmemiş, ya da ortak yazar olarak eklendiğin commit'ler sayılmaz; katkı takviminde
  görünüp burada görünmeyen katkıların nedeni budur. Toplam (commit + PR) 0 ise çubuk gösterilmez.
- Bilinen sınırlama: Özel repolardaki PR'lar `read:user` kapsamıyla görünmeyebilir; sayılar
  yalnızca herkese açık etkinliği betimler.

| Yeterli veri yok | Düşük güven | Normal |
|---|---|---|
| Sonuçlanmış PR < 3 | Sonuçlanmış PR < 10 | diğer |

### Haftalık özet (Faz 9)
Genel Bakış'taki "Bu hafta" kartı ve haftalık bildirimin içeriği. Kod
`backend/app/metrics/weekly.py`, uç nokta `GET /metrics/weekly`.

- **Dönem:** Bu haftanın Pazartesi'sinden bugüne (yerel saat). Kıyas: geçen haftanın aynı günleri
  (Pazartesi'den geçen haftanın bugününe). Yarım hafta tam haftayla kıyaslanmaz.
- **Değerler:** commit sayısı, aktif gün, commit atılan repo sayısı (iki dönem için).
- Dil betimleyicidir: "geçen haftanın aynı günlerine göre 3 commit fazla". Yüzde verilmez (küçük
  sayılarda yüzde yanıltıcıdır).

| Yeterli veri yok | Düşük güven | Normal |
|---|---|---|
| İki dönemde de hiç commit yok | — | diğer |

**Haftalık bildirim (yalnız Android, isteğe bağlı):** Profil'den açılır (varsayılan kapalı;
tercih yalnız telefonda). Açılınca Android 13+ bildirim izni sorulur; her Pazartesi 10:00 civarı
(yaklaşık zamanlı, tam zamanlı alarm izni istenmez) "Yeni hafta başladı; geçen haftanın özeti
DevPulse'ta" bildirimi gösterilir. Bildirim telefonda planlanır; sunucu push yoktur ve bildirim
metninde sayı yoktur (sayılar uygulama açılınca güncel hesaplanır).

### Repo kümeleri (gözetimsiz, k-means; Faz 9)
Projeler sekmesindeki "Liste / Kümeler" geçişi. Benzer repoları gruplar; **gözetimsizdir**
(etiket yok), bu yüzden doğruluk ölçülmez ve "doğru küme" iddiası yoktur. Kod
`backend/app/metrics/clusters.py`, uç nokta `GET /projects/clusters`.

- **Hangi repolar:** Kullanıcının kendi, fork olmayan repoları (arşivliler dahil). Başkasına ait
  repolar alınmaz: onlar için yalnız kullanıcının commit'leri bilinir, sağlık puanı yoktur.
- **Özellikler (4):** log(1 + commit sayısı), log(1 + son push'tan bu yana gün), son 12 haftada
  commit atılan hafta sayısı / 12, sağlık puanı / 100 (puanlanmayan repo için 0). Önce
  `StandardScaler` ile ölçeklenir. **Dil özellik değildir:** az repoda tek-sıcak (one-hot) dil
  sütunları kümeleri tek başına belirliyordu; dil, kümenin açıklamasında (en sık dil) gösterilir.
- **Küme sayısı (k):** Az repoda siluet puanı anlamsız olduğu için sabit kural: 5-9 repo → k = 2;
  10 ve üstü → k ∈ {2, 3, 4} içinden siluet puanı en yüksek olan (k ≤ repo sayısı / 3).
  `KMeans(n_init=10, random_state=0)`: aynı veri her zaman aynı kümeleri verir.
- **Adlandırma (şablon, LLM yok):** Küme merkezinin özgün birimlerdeki medyanlarından:
  son push medyanı ≤ 90 gün → "Aktif", değilse "Durağan"; sağlık puanı medyanı ≥ 70 → "belgeli",
  değilse "belgesi eksik". İki küme aynı adı alırsa commit medyanına göre "çok commit'li" /
  "az commit'li" eklenir. Her kümede repo listesi, medyanlar ve en sık dil gösterilir.

| Yeterli veri yok | Düşük güven | Normal |
|---|---|---|
| < 5 repo (kümeleme yapılmaz) | 5-9 repo (k = 2 sabit) | 10 ve üstü |

### Proje sağlığı (eksiklik takibi)
**Ne ölçer:** Reponun vitrin ve belgelendirme eksiksizliğini: repoyu açan biri ne olduğunu,
nasıl kullanılacağını ve hangi lisansla paylaşıldığını anlayabiliyor mu?
**Ne ölçmez:** Kod kalitesi, test, hata sayısı ya da projenin değeri.

| Kontrol | Ağırlık | Geçer sayılması |
|---|---|---|
| README | 30 | Varsayılan dalda `README.md`, `readme.md`, `README` ya da `README.rst` var |
| README içeriği | 15 | Bulunan README en az 300 bayt (GitHub'ın "Add a README" ile oluşturduğu yalnız başlıklı dosya geçmez) |
| Açıklama | 20 | GitHub'daki "About" açıklaması boş değil |
| Lisans | 20 | GitHub bir lisans tanıyor (`licenseInfo`) |
| Topic | 15 | En az bir topic var |

- **Skor** = geçen kontrollerin ağırlık toplamı / bilinen kontrollerin ağırlık toplamı × 100.
  Durumu bilinmeyen kontrol (GitHub döndürmediyse) eksik sayılmaz, hesaptan çıkarılır.
- Ağırlıklar ve 300 bayt eşiği sezgiseldir (README en çok bilgi taşıdığı için en ağır); bir
  standarda dayanmaz. README yoksa içerik kontrolü de geçmez. README boyutu yalnızca bayt
  sayısıdır; içerik okunmaz ve saklanmaz. Boyut bilinmiyorsa (eski senkron) kontrol hesaptan çıkar.
- **Öneri cümlesi:** Eksik kontrollerden ağırlığı en büyük en çok iki tanesi seçilir; ikisi
  kapatılınca skorun kaç puan artacağı aynı formülle hesaplanır ("Şu eksikleri kapatırsan skor
  N puan artar: README, Lisans."). Deterministiktir; tahmin değildir.
- **Durum etiketi** (skora girmez): GitHub'da arşivlenmişse *Arşiv*; değilse son push son 90 gün
  içindeyse *Aktif*, daha eskiyse ya da hiç push yoksa *Durağan*. Durağan bir değer yargısı
  değildir; bitmiş projeler de durağandır.
- **Son 12 hafta commit:** Kullanıcının o repodaki commit'leri, kendi saat dilimine göre
  Pazartesi başlayan haftalara sayılır; içinde bulunulan hafta dahil son 12 hafta.
- **Puanlanmaz:** Başkasına ait repolar (yalnızca katkı yapılan) ve fork'lar; vitrinleri
  kullanıcının elinde değildir. Listede ayrıca gösterilir.
- Bilinen sınırlama: README yalnızca dört yaygın dosya adına bakılarak aranır (ör. `Readme.md`
  ya da `docs/README.md` bulunmaz).
- Skora girmeyen bilgi: son push'tan bu yana geçen gün, durum etiketi ve kullanıcının o
  repodaki commit sayısı.

### Veri kapsamı (Profil)
Analizlerin hangi veriye dayandığını söyler; yeni metrik değildir, saklanan veriden sayılır
(`GET /me`, `scope` alanı).
- **Commit aralığı:** senkronlanan ilk ve son commit'in yazar zamanı (`authored_at`). Commit yoksa boş.
- **Repolar:** kendi repoların (`is_owner`) ve katkı verdiğin başkalarına ait repolar ayrı sayılır;
  kendi repolarından kaçının fork, kaçının arşivlenmiş olduğu da yazılır. Fork ve arşiv repolar
  metriklere girer, CV'ye ve proje sağlığı önerilerine girmez.
- **Sabit notlar (koddan, sayı değil):** yalnız herkese açık veri (`read:user`); commit'ler her
  reponun varsayılan dalından ve yalnız senin yazdığın commit'ler (ortak yazar olarak eklendiğin
  commit'ler sayılmaz, açık karar); katkı takvimi GitHub'ın kendi sayımıdır ve metriklere karışmaz.

## Metrik kataloğu (uygulamada)
Uygulamadaki "Metrik kataloğu" ekranı her metriğin tanımını, birimini, nasıl yorumlanacağını ve
hangi koşulda güvenilir olduğunu kısaca gösterir. Metinler `backend/app/metrics/catalog.py`
içindedir; her girdinin bu belgede bir başlığı olduğu test edilir (`tests/test_catalog.py`).
