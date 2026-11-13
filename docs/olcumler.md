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
- Gerçek doğruluk için tanımlarımıza göre elle etiketlenmiş Türkçe mesajlar gerekir; aşağıdaki
  bölümde yapıldı.

## Commit sınıflandırma: insan etiketleriyle değerlendirme (13 Kasım 2026)

Komut: `cd backend; py -m ml.gold evaluate`. Model yalnızca eğitim kısmıyla eğitildi (test
repoları eğitimde yok); tasarım seçenekleri eşiksizdir (model hep en olası sınıfı söyler).

**Kümeler.**
- Türkçe altın küme: test repolarından 98 mesaj, sınıflara dengeli seçildi; geliştirici
  `docs/etiketler.md` tanımlarına göre **kör** etiketledi (yazarın öneki ve repo adı gizli).
  94'ü etiketlendi (4'ü atlandı); 14'üne "Belirsiz" denildi.
- Kendi commit'leri: geliştiricinin 33 commit mesajı (Türkçe/İngilizce karışık, çoğu README).

| sistem | Türkçe (94) | Türkçe, "Belirsiz" hariç (80) | kendi (33) |
|---|---|---|---|
| Yalnız kurallar (karar veremezse Belirsiz) | 0.28 | 0.21 | 0.58 |
| Yalnız model | 0.36 | 0.42 | 0.55 |
| **Kural önce, sonra model** | **0.39** | **0.46** | **0.58** |
| Kesin kural önce, sonra model | 0.38 | 0.45 | 0.52 |

Karşılaştırma: 7 sınıfta rastgele tahmin ~0,14.

- Türkçe kümede kuralların karar verdiği 41 mesajda kural %41, model %34 doğru; kuralın karar
  veremediği 53 mesajda model %38 doğru.
- **Yazarın öneki ile insan etiketinin uyuşma oranı: %40 (94 mesaj).** En sık uyuşmazlıklar:
  Bakım→Kod düzenleme (4), Kod düzenleme→Belirsiz (4), Hata düzeltme→Kod düzenleme (4).
- En sık sistem hataları (insan → sistem): Belirsiz→Yeni özellik (7), Bakım→Hata düzeltme (4),
  Kod düzenleme→Hata düzeltme (4).

**Yorum.**
- Otomatik (önek) etiketlerle yapılan ölçüm kuralları kötü, modeli iyi gösteriyordu; insan
  etiketleriyle durum tersine döndü: kuralların karar verdiği mesajlarda kural modelden iyidir
  ve en iyi sistem "kural önce, sonra model"dir. Önek etiketleri model eğitimi için yararlıdır
  ama sistemin tanımlarımıza göre doğruluğunu ölçmek için yanıltıcıdır (uyuşma yalnız %40).
- Tür tanımları doğası gereği tartışmalıdır (özellikle Kod düzenleme / Bakım / Hata düzeltme);
  yazarların önekiyle insan etiketinin %40 uyuşması, bu görevin üst sınırının da düşük olduğunu
  gösterir.
- Uygulamada kullanılan tasarım: kural önce, sonra model, güven eşiği yok (olasılıklar 6 sınıfa
  yayıldığı için eşik işe yaramıyor); her kararın kaynağı ve model güveni gösterilir; commit türü
  grafiğinde doğruluğun yaklaşık %40-60 olduğu açıkça yazılır.
- Kurallar bu sonuçlara bakılarak yeniden ayarlanmamıştır (test kümesi tasarımda kullanılmadı).

### İnsan etiketli eğitim verisiyle ikinci tur (13 Kasım 2026)

Komutlar: `py -m ml.human select | evaluate | save`. Tüm sistemler yalnızca mesajın ilk
satırını kullanır.

**Veri.** Eğitim repolarından (test repoları hariç) seçilen 200 kısa, anlaşılır mesaj (15-90
karakter, tek satır); geliştirici tanımlarımıza göre kör etiketledi (32'si "Belirsiz"). Bu
kısa mesajlarda da yazar öneki ile insan etiketinin uyuşması **%40**: uyuşmazlığın kaynağı
mesajın karmaşıklığı değil, tür tanımlarının kendisidir.

**Seçim (yalnız bu 200 etiket üzerinde, repo bazında 5 katlı CV; test kümesine bakılmadı):**
en iyi "insan + yazar öneki (ağırlık 0,3), kural önce" 0,45 ± 0,08; eski sistem (yalnız yazar
önekleri, kural önce) 0,42 ± 0,09; yalnız insan etiketleri 0,40-0,41. Fark sapmanın içindedir.

**Test (bir kez):**

| model | sistem | Türkçe test (94) | kendi (33) |
|---|---|---|---|
| Eski (yazar önekleri) | yalnız model | 0.36 | 0.67 |
| Eski (yazar önekleri) | kural önce | 0.36 | 0.58 |
| Yeni (insan + yazar 0,3) | yalnız model | 0.34 | 0.79 |
| **Yeni (insan + yazar 0,3)** | **kural önce (seçilen)** | **0.35** | **0.58** |

**Yorum.**
- Genel Türkçe mesajlarda 200 ek insan etiketi anlamlı bir iyileşme getirmedi (0,36 → 0,35,
  gürültü düzeyinde). Darboğaz veri miktarı değil, tanımların belirsizliğidir.
- Geliştiricinin kendi commit'lerinde yeni model tek başına belirgin daha iyi (0,67 → 0,79;
  33'te 22 → 26 doğru): model geliştiricinin tanımlarını öğrenmiştir. "Kural önce" düzeninde
  bu kazanç kaybolur (0,58). Bu bir gözlemdir; sistem test sonucuna göre değil CV'ye göre
  seçildiği için uygulamada "kural önce" kullanılır.
- Yalnız ilk satırı kullanmanın bedeli: eski sistem Türkçe testte tam mesajla 0,39, ilk
  satırla 0,36.
- Uygulamaya alınan model: insan + yazar (0,3), "Belirsiz" sınıfını da öğrenmiş; test
  repolarını görmeden eğitildi (altın küme ileride yeniden ölçüm için temiz kalır).

### Sınıf sadeleştirme (13 Kasım 2026)

Komut: `py -m ml.merge select | evaluate | save`. Sınıf azalınca doğruluk kendiliğinden artar
(şans eseri tutma olasılığı büyür); bu yüzden şansı düzelten **Cohen's kappa** da raporlandı.

**Seçim (200 insan eğitim etiketi, 5 katlı CV, test kümesine bakılmadan):**

| birleştirme | sınıf | doğruluk | kappa | en sık sınıf tabanı |
|---|---|---|---|---|
| 7 sınıf | 7 | 0.45 ± 0.08 | 0.33 ± 0.09 | 0.32 |
| 6: Kod düzenleme + Bakım | 6 | 0.47 ± 0.08 | 0.35 ± 0.09 | 0.32 |
| 5: + Test | 5 | 0.50 ± 0.08 | 0.34 ± 0.10 | 0.27 |
| 4: + Hata düzeltme | 4 | 0.57 ± 0.08 | 0.36 ± 0.11 | 0.40 |

**Test (bir kez):**

| birleştirme | Türkçe test (94) doğruluk / kappa | kendi (33) doğruluk / kappa |
|---|---|---|
| 7 sınıf | 0.35 / 0.24 | 0.58 / 0.32 |
| **6: Kod düzenleme + Bakım (seçilen)** | **0.41 / 0.27** | **0.58 / 0.31** |

**Yorum.**
- Birleştirmeler doğruluğu artırıyor (0,45 → 0,57) ama kappa neredeyse sabit (0,33 → 0,36,
  sapmanın içinde): artışın çoğu sınıf sayısının azalmasından gelir, sistem gerçekten
  "keskinleşmez".
- 6 sınıf (Kod düzenleme + Bakım → "Bakım ve düzenleme") **anlaşılırlık** için seçildi: bu iki
  sınıf insanlar arasında da en sık karışan çiftti. 4 sınıf en yüksek doğruluğu verse de "Hata
  düzeltme"yi ayırmadığı için kullanıcıya az bilgi verir.
- Uygulamadaki son sistem: kural önce, sonra model; 6 sınıf; insan etiketleri + yazar önekleri
  (0,3). Türkçe testte 0,41 doğruluk / 0,27 kappa; kendi commit'lerde 0,58 / 0,31.
- Kappa 0,27-0,35 "zayıf-orta" uyuşmadır; arayüz commit türlerini kesin bilgi gibi değil,
  yaklaşık bir dağılım olarak sunmalıdır.

### Etiketleyiciler arası uyuşma (13 Kasım 2026)

Komut: `py -m ml.agreement`. Altın kümedeki 98 mesaj yapay zekâ (Claude Opus 5.5) tarafından
da etiketlendi: **kör** (geliştiricinin etiketleri ve yazarın öneki görülmeden), aynı kılavuza
(`docs/etiketler.md`) göre. Bu etiketler (`tr_gold_llm_labels.jsonl`) yalnızca uyuşma ölçümü
içindir; eğitimde ve tasarım kararlarında kullanılmadı.

| çift | mesaj | 7 sınıf uyuşma / kappa | 6 sınıf uyuşma / kappa |
|---|---|---|---|
| Yapay zekâ – geliştirici | 94 | %37 / 0.26 | %47 / 0.33 |
| Yazar öneki – geliştirici | 94 | %40 / 0.30 | %48 / 0.34 |
| Yapay zekâ – yazar öneki | 98 | %78 / 0.73 | %79 / 0.72 |

En sık uyuşmazlıklar (geliştirici → yapay zekâ): Bakım → Kod düzenleme (5), Belgelendirme →
Bakım (4), Kod düzenleme → Bakım (4).

**Yorum.**
- İki bağımsız kaynak (mesajın yazarları ve kör etiketleyen yapay zekâ) %78 uyuşuyor (kappa
  0,73, "iyi"); geliştiricinin etiketleri ikisiyle de ~%40 uyuşuyor. Test kümesinin tek
  etiketleyicisi diğer kaynaklardan belirgin ayrışmaktadır.
- Sistemin geliştirici etiketleriyle uyuşması (6 sınıf %41), iki dikkatli etiketleyicinin
  geliştiriciyle uyuşmasına (%47-48, 6 sınıf) yakındır: bu test kümesiyle ölçülebilecek üst
  sınıra yaklaşılmıştır. Daha fazla eğitim verisi bu sınırı aşmaz.
- Yapay zekâ etiketleri yazar öneklerine çok benzediğinden, eğitim verisini yapay zekâya
  etiketletmek mevcut 2479 önekli örneğe yeni bilgi eklemez; bu yüzden yapılmadı.
- Önerilen sonraki adım: test kümesinde ikinci tur gözden geçirme (adjudication).

### Yapay zekâ etiketli test standardı (13 Kasım 2026)

Komut: `py -m ml.llm_ref evaluate | save | check`.

**Karar (sonuçlar görülmeden verildi, geliştirici onayıyla).** Test referansı olarak altın
kümenin yapay zekâ (kör) etiketleri kullanılır; gerekçe: bu etiketler mesajların yazarlarıyla
bağımsız biçimde %78 uyuşur (kappa 0,73), tek insan etiketleyicinin etiketleri iki kaynakla da
~%40 uyuşuyordu. Bu standarda uyumlu olarak model yalnız yazar önekleriyle eğitilir
(geliştiricinin 200 etiketi farklı bir yorumu yansıttığından eğitime alınmaz); kural önce,
sonra model; 6 sade sınıf. Yapay zekâ etiketleri eğitimde/tasarımda kullanılmaz.

| sistem (6 sınıf) | ref: yapay zekâ (98) doğruluk / kappa | ref: geliştirici (94) doğruluk / kappa |
|---|---|---|
| **Yeni: yazar önekleri, kural önce (uygulamada)** | **0.63 / 0.53** | 0.39 / 0.24 |
| Yeni model, yalnız model | 0.62 / 0.52 | 0.40 / 0.26 |
| Önceki: insan + yazar (0,3), kural önce | 0.63 / 0.53 | 0.41 / 0.27 |

**Yorum (rapora aynen girmeli).**
- 0,41 → 0,63 artışı **sistemin iyileşmesinden değil, referansın değişmesinden** kaynaklanır:
  aynı sistemler yapay zekâ referansıyla 0,63, geliştirici referansıyla ~0,40 alır; yeni ve
  önceki sistem yapay zekâ referansında aynıdır.
- Tutarlı bir standarda (yazarlar ve yapay zekânın ortak görüşü) karşı kappa 0,53 "orta" düzey
  uyuşmadır.
- Yeni model yazar önekleriyle eğitildiği için "Belirsiz" sınıfını öğrenmez; "Belirsiz" yalnızca
  kurallardan (Revert, Merge) gelir.
- **İnsan kabul edilebilirlik kontrolü (13 Kasım 2026):** geliştirici, yapay zekâ
  etiketlerinden rastgele 20'sini etiket görünür biçimde inceledi (`py -m ml.llm_ref check`,
  tohum 20261113): **19/20'sine (%95) katıldı.** Katılmadığı tek örnek: "RPM ve DEB paketlerini
  uygulama olarak açabilen hale getir" (yapay zekâ: Yeni özellik).
- Kör etiketlemede geliştirici ile yapay zekâ %37 uyuşurken, yapay zekâ etiketi gösterildiğinde
  geliştirici %95 katılıyor. İkisi çelişmez: mesajların çoğu için birden fazla tür makuldür
  (tanım belirsizliği bulgusunu destekler). Etiket gösterilerek yapılan kontrol bağımsız
  değildir (gösterilen cevaba katılma eğilimi); bu yüzden "doğrulama" değil "kabul
  edilebilirlik kontrolü" olarak raporlanır.

**Sınırlamalar.**
- Test referansı bir yapay zekânın etiketleridir; insan kontrolü 20 örnekle sınırlıdır ve
  etiket gösterilerek yapıldı (bağımsız değil, kabul edilebilirlik niteliğindedir; %95).
- Yapay zekâ, bu sistemin kurallarını tasarlayan aynı model ailesindendir; kör etiketlemede
  kurallar ve sistem çıktıları görülmemiş olsa da tanım yorumu ortak olabilir.
- Test kümesini tek kişi etiketledi; ikinci insan etiketleyici yoktur (yapay zekâ ve yazar
  önekleri insan yerine geçmez).
- Küçük kümeler: 94 ve 33 mesaj; tek bir yüzde puanı yaklaşık 1 mesajdır.
- Eğitim etiketleri yazarlara aittir ve tanımımızdan farklıdır (gürültülü/zayıf denetim).
- Model "Belirsiz" sınıfını öğrenmez; insanın "Belirsiz" dediği 14 mesaj her sistemde hata sayılır.

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

## Senkron: dil ve araç alanlarının süreye etkisi (13 Kasım 2026)
Repo sorgusuna `languages`, kök dizin ağacı (`HEAD:`) ve `.github/workflows` eklendi.
Geliştiricinin hesabı (4 repo, yeni commit yok, istek sayısı her seferinde 8). Süreler
`sync_jobs.requests` alanından, milisaniye.

| Senkron | Alanlar | repos | contributed_repos (3 istek) | Toplam |
|---|---|---|---|---|
| #29, #30 | eski alanlar | 565 / 936 | 1967 / 1839 | - |
| #33 | + README boyutu, arşiv | 1186 | 2441 | 6,6 sn |
| #34 | + diller, kök ağaç, workflows | 1309 | 3083 | 7,2 sn |

Sonuç: repo başına sorgu ağırlaştı, istek sayısı değişmedi. Bu küçük hesapta toplam artış
yaklaşık 0,5-1 sn ve ölçüm gürültüsüyle (aynı alanlarla #32'de profil isteği 2 sn sürdü)
karşılaştırılabilir. Çok repolu hesaplarda (50'lik sayfalar) etkisi ayrıca ölçülmeli.
