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
  (etiketli veri yok), arayüzdeki ana sonuç ise istatistiksel MAD kuralıdır.

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

## Metrik kataloğu (uygulamada)
Uygulamadaki "Metrik kataloğu" ekranı her metriğin tanımını, birimini, nasıl yorumlanacağını ve
hangi koşulda güvenilir olduğunu kısaca gösterir. Metinler `backend/app/metrics/catalog.py`
içindedir; her girdinin bu belgede bir başlığı olduğu test edilir (`tests/test_catalog.py`).
