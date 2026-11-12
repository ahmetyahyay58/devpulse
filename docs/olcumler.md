# Ölçüm sonuçları

Rapor için ölçümler. Her bölüm, sonucu yeniden üreten komutu ve tarihini içerir.

## Commit sınıflandırma: ara sonuç (12 Kasım 2026)

Komutlar: `cd backend; py -m ml.collect_tr` (veri), `py -m ml.train` (test), `py -m ml.tune`
(tasarım seçimi; yalnız eğitim verisinde 5 katlı çapraz doğrulama). scikit-learn 1.9.1.

**Veri.** GitHub commit aramasıyla toplanan, herkese açık 2479 Türkçe commit mesajı, 1474 repo
(repo başına en çok 5). Etiket = yazarın kullandığı conventional commits öneki (`fix:` vb.),
önek metinden silinmiştir. Arama, sınıfa ipucu vermemek için her sınıfta aynı bağlaçlarla
("için", "ile", "ve") yapıldı. Sınıflar: feat 704, fix 540, refactor 439, chore 427, docs 310,
test 59. İngilizce sızıntısı %0,4 (11 örnek). Çift önekli 9 örnek (cevabı sızdırdığı için)
çıkarıldı.

**Test (repo bazında ayırma: test repoları eğitimde hiç yok; 1980 eğitim / 499 test):**

| yöntem | doğruluk | macro-F1 | karar verilen |
|---|---|---|---|
| Taban: hep 'feat' | 0.26 | 0.07 | %100 |
| Kelime TF-IDF + LR | 0.59 | 0.56 | %100 |
| Harf parçası (3-5) TF-IDF + LR | 0.64 | 0.60 | %100 |
| Yalnız kurallar | 0.18 | 0.23 | %37 |
| Hibrit (kural → model, eşik 0,5) | 0.22 | 0.27 | %41 |

Harf parçası modeli sınıf başına F1: feat 0.66, fix 0.66, docs 0.59, refactor 0.64, test 0.43
(yalnız 12 test örneği), chore 0.64.

**Yorum.**
- Model en basit tabanın çok üstünde (0,64'e karşı 0,26); test repoları eğitimde görülmediği
  için bu ezber değil genellemedir.
- Harf parçası, kelime tabanlı modelden 5 puan iyi: Türkçe eklerin ("düzelt-ildi/-me/-tim")
  ortak kökü harf parçalarında yakalanır.
- Kurallar ve hibrit bu ölçümde kötü görünüyor; ancak buradaki "doğru cevap" yazarın kendi
  önek alışkanlığıdır, `docs/etiketler.md`'deki tanımlarımız değil (ör. "Android entegrasyonu
  düzeltildi" yazar tarafından `docs` etiketlenmiş; kural tanımımız gereği `fix` der). Bu veri
  modeli eğitmek için uygundur, hibrit sistemin tanımımıza göre doğruluğunu ölçmek için değil.
- Modelin olasılıkları 6 sınıfa yayılır (en yüksek olasılık çoğunlukla 0,3-0,4); 0,5 güven eşiği
  neredeyse hiç karar verdirmez. Çapraz doğrulamada en iyi sonuç eşiksiz alındı (0,61).
- Gerçek doğruluk için tanımlarımıza göre elle etiketlenmiş Türkçe mesajlar gerekir (açık konu).

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
- Gerçek veri: geliştiricinin kendi hesabında 10 aktif gün var ("Düşük güven"). MAD tek bir günü
  işaretledi: 28.07.2026, 9 commit (aktif günlerde medyan 2, z = 4,72). Bu gün, hesaptaki 7 günlük
  serinin en yoğun günüdür. Olayın "gerçekten" olağan dışı olup olmadığına dair bir etiket
  olmadığından bu bir doğrulama değil, yalnızca yöntemin gerçek veride çalıştığının gösterimidir.
- Demo kullanıcıda (canlı API, 12.11.2026) MAD tam olarak enjekte edilen 3 günü işaretledi
  (03-05.10.2026), başka gün işaretlemedi.
