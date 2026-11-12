# Ölçüm sonuçları

Rapor için ölçümler. Her bölüm, sonucu yeniden üreten komutu ve tarihini içerir.

## Anomali: enjeksiyon testi (12 Kasım 2026)

Komut: `cd backend; py -m app.metrics.anomaly_eval` (scikit-learn 1.9.1).
Yöntem tanımları: `docs/metrikler.md` → "Olağan dışı günler".

**Kurulum.** Sentetik demo üreteci (`app/sync/demo_generator.py`) yaklaşık 6 aylık bir commit
geçmişine bilerek 3 günlük bir yoğunluk ("hackathon") ekler: günde 18–25 commit, 20:00'de
başlayıp gece yarısını geçen tek uzun oturum, satır sayısı 3 kat. Olay gece yarısını geçtiği
için son günün ertesi sabahı da olay penceresine dahildir (pencerede 4 aktif gün).
"Yanlış alarm": olay penceresi dışında işaretlenen gün.

**Demo kullanıcı (tohum 20261112):**

| yöntem | aktif gün | işaretlenen | olay bulundu | olay günü yakalanan | yanlış alarm |
|---|---|---|---|---|---|
| Robust z (MAD), z > 3.5 | 114 | 3 | evet | 3/4 | 0 |
| Isolation Forest (5 özellik, %5) | 114 | 6 | evet | 4/4 | 2 |

**30 farklı sentetik kişi (tohum 1–30):**

| yöntem | kişi (tohum) | olayı bulma oranı | olay günü yakalama | ort. yanlış alarm | en çok yanlış alarm |
|---|---|---|---|---|---|
| Robust z (MAD), z > 3.5 | 30 | 30/30 | %78 | 1.4 | 5 |
| Isolation Forest (5 özellik, %5) | 30 | 30/30 | %92 | 2.3 | 4 |

**Yorum.**
- İki yöntem de enjekte edilen olayı 30 kişinin 30'unda buldu.
- Isolation Forest olay günlerini daha eksiksiz yakaladı (%92'ye karşı %78), ama kişi başına
  daha çok yanlış alarm verdi (2,3'e karşı 1,4). MAD'in kaçırdığı günler çoğunlukla gece
  yarısından sonraki az commit'li "taşma" sabahlarıdır; tek değişkenli (yalnız commit sayısı)
  bir yöntem bu günleri sıradan görür, çok değişkenli Isolation Forest gece oranı ve oturum
  süresinden yakalar.
- Tek kişide (demo) MAD'in yanlış alarmı 0'dı; 30 kişide ortalama 1,4. Tek örnekten genelleme
  yapılmamalıdır.
- Arayüzde MAD kullanılmasının gerekçesi: daha az yanlış alarm ve açıklanabilirlik ("medyanın
  kaç katı" diye anlatılabilir). Isolation Forest'ın kararı tek bir sayıyla açıklanamaz.

**Sınırlamalar.**
- Veri sentetiktir; yöntemlerin gerçek kullanıcılardaki başarısını kanıtlamaz.
- Enjekte edilen olay bilerek çok belirgindir (normalde günde ~3 commit). Gerçek anomaliler daha
  silik olabilir; bu test yalnızca bariz bir olayın bulunduğunu gösterir.
- Isolation Forest'ın `contamination = 0,05` değeri bir varsayımdır; her kişide ~%5 gün
  işaretlemeye zorlar. Bu değer değişirse yanlış alarm/yakalama dengesi de değişir.
- Geliştiricinin kendi hesabında 10 aktif gün olduğu için anomali bölümü "Yeterli veri yok" der;
  gerçek veriyle değerlendirme yapılamadı.
