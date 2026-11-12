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
- **Kural tabanlıdır:** Bu sayfadaki metrikler makine öğrenmesi kullanmaz. Tek istisna
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

### Yoğunluk
- **Aktif gün başına commit:** Aktif günlerdeki commit sayısının medyanı.
- **Oturum başına commit:** Medyan.
- **Oturum süresi:** Medyan (dakika).
- **Commit başına değişen satır:** (eklenen + silinen) satırların medyanı. Satır bilgisi
  olmayan commit'ler bu hesaba girmez.

Ortalama yerine **medyan** kullanılır: tek bir dev commit (ör. bağımlılık klasörü) ortalamayı
bozar, medyanı bozmaz.

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

### Proje sağlığı (eksiklik takibi)
**Ne ölçer:** Reponun vitrin ve belgelendirme eksiksizliğini: repoyu açan biri ne olduğunu,
nasıl kullanılacağını ve hangi lisansla paylaşıldığını anlayabiliyor mu?
**Ne ölçmez:** Kod kalitesi, test, hata sayısı ya da projenin değeri.

| Kontrol | Ağırlık | Geçer sayılması |
|---|---|---|
| README | 35 | Varsayılan dalda `README.md`, `readme.md`, `README` ya da `README.rst` var |
| Açıklama | 25 | GitHub'daki "About" açıklaması boş değil |
| Lisans | 20 | GitHub bir lisans tanıyor (`licenseInfo`) |
| Topic | 20 | En az bir topic var |

- **Skor** = geçen kontrollerin ağırlık toplamı / bilinen kontrollerin ağırlık toplamı × 100.
  Durumu bilinmeyen kontrol (GitHub döndürmediyse) eksik sayılmaz, hesaptan çıkarılır.
- Ağırlıklar sezgiseldir (README en çok bilgi taşıdığı için en ağır); bir standarda dayanmaz.
- **Puanlanmaz:** Başkasına ait repolar (yalnızca katkı yapılan) ve fork'lar; vitrinleri
  kullanıcının elinde değildir. Listede ayrıca gösterilir.
- Bilinen sınırlama: README yalnızca dört yaygın dosya adına bakılarak aranır (ör. `Readme.md`
  ya da `docs/README.md` bulunmaz).
- Skora girmeyen bilgi: son push'tan bu yana geçen gün ve kullanıcının o repodaki commit sayısı.
