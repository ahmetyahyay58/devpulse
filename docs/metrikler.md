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
- **Kural tabanlıdır:** Bu sayfadaki hiçbir metrik makine öğrenmesi kullanmaz.

## Veri yeterliliği (üç durum)

Her metrik şu üç durumdan biriyle gelir. Eşikler sezgisel seçilmiştir (istatistiksel bir
güç analizine dayanmaz) ve `backend/app/metrics/sufficiency.py` içinde tek yerde durur.

| Metrik grubu | Yeterli veri yok | Düşük güven | Normal |
|---|---|---|---|
| Süreklilik | < 3 aktif gün | < 10 aktif gün ya da ilk commit'ten bu yana < 30 gün | diğer |
| Ritim | < 10 commit | < 50 commit ya da saat dilimi bilinmiyor | diğer |
| Oturum ve yoğunluk | < 3 oturum | < 15 oturum | diğer |

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
