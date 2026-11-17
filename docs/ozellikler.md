# Özellik listesi ve kararlar

13 Kasım 2026. Geliştiricinin prototipteki ekran listesi, CLAUDE.md'deki kurallara göre değerlendirildi.
Önceden "Kesildi" listesinde olan özellikler kapsama geri alındı. Kurallarla çelişen maddeler
aşağıdaki "Çelişki çözümleri" bölümündeki gibi yeniden tasarlanarak yapılacak.

Durum: **Var** = uygulamada çalışıyor · **Kısmen** = bir parçası var · **Yeni** = yapılacak.
Veri: **Mevcut** = senkronla zaten çekiliyor · **Yeni veri** = GitHub'dan ek alan/sorgu gerekir.

## Değişmeyen kurallar (karar: 13 Kas)
- LLM'e yalnızca hesaplanmış toplu sayılar gider; kullanıcı adı, repo adı, commit mesajı, kod gitmez.
- Commit sayısı üretkenliği ya da kaliteyi ölçmez; tüm metinler betimleyici dille yazılır.
- Uydurma sayı yok: ekrandaki her sayı gerçek veriden ya da `docs/olcumler.md`'deki ölçümden gelir.
- Saklanan veri ya da veri akışı değişirse aydınlatma metni aynı commit'te güncellenir.

## Çelişki çözümleri
| Madde | Çözüm |
|---|---|
| Model Laboratuvarı "örnek değerler" | Örnek değer yok; `docs/olcumler.md`'deki gerçek ölçümler gösterilir (doğruluk, kappa, kural/model payı, karışıklık matrisi). |
| "90 gün kuralı" | Gerçekten uygulanır: 90 gün boyunca senkron/giriş olmayan hesabın verileri otomatik silinir (tek arka plan görevi, günde bir kontrol). Aydınlatma metni aynı commit'te güncellenir. |
| Mülakat koçu, hedef koçu, Sor balonu | LLM'e yalnız toplu sayılar gider (ör. "Python, 3 repo, 120 commit, README eksik"). Repo adı ve commit mesajı gitmez; bu yüzden cevaplar sayılara dayalı genel öneriler olur. LLM yoksa hazır şablon cevaplar. |
| CV "ATS kontrol" | Adı "Biçim kontrolü": yalnız açıklanabilir kurallar (bölüm başlıkları var mı, uzunluk, tablo/sütun yok, iletişim satırı). "ATS'den geçer" iddiası yapılmaz. |
| Yıl kıyası, rozetler | Betimleyici dil ("geçen yıldan %40 daha fazla commit"; "daha üretken" yok). Rozetler çoğunlukla alışkanlık ve proje bakımını ödüllendirir (seri, README/lisans tamamlama), ham commit sayısını değil. |
| Çeşitlilik skoru | Puan değil, betimleyici ölçü: dil dağılımının dengesi (normalleştirilmiş Shannon entropisi, %0-100). "Yüksek = iyi" yorumu yapılmaz; "Nasıl hesaplandı?" notu bunu söyler. |
| Demo modu kaydırıcıları | Yalnız prototipte; uygulamaya girmez. Demo kullanıcı mevcut deterministik üreticiyle kalır. |

## Ekranlar

### Senkron ekranı
| Madde | Durum | Veri | Not |
|---|---|---|---|
| Aşamalı liste: dönen gösterge, bitince yeşil tik | Yeni | Mevcut | Gerçek aşamalar gösterilir (profil, repolar, commit'ler, takvim); `sync_jobs`'a `phase` alanı. Sayı 6'ya uydurulmaz. |
| Aşama altında canlı sayaç ("23 / 47 repo") | Kısmen | Mevcut | `repos_done / repos_total` zaten var. |
| Kare kare dolan katkı takvimi | Yeni | Mevcut | Commit'ler geldikçe günlük sayılardan doldurulur. |
| Genel ilerleme çubuğu, yüzde, "Atla" | Kısmen | Mevcut | "Atla": senkron arka planda sürer, kullanıcı uygulamaya geçer. |

### Genel Bakış
| Madde | Durum | Veri | Not |
|---|---|---|---|
| 4 KPI: toplam commit, aktif gün, en uzun seri, repo | Kısmen | Mevcut | En uzun seri hesaplanıyor; karta taşınacak. |
| Son 30 hafta katkı takvimi, anomali günlerinde amber halka | Kısmen | Mevcut | Takvim ve anomali ayrı ayrı var; birleştirilecek. |
| Commit türleri halkası (Türkçe etiketler) | Kısmen | Mevcut | Şu an çubuk; halka grafiğe çevrilecek. |
| AI yorumu kartı: 3 hazır soru çipi, daktilo efekti | Yeni | Mevcut | AI katmanına bağlı (aşağıda). |
| Kapatılabilir "AI" rozetli ipucu satırı | Yeni | Mevcut | AI katmanı; ayarlardan kapatılabilir. |
| Grafik başlıklarında "Neden?" | Yeni | Mevcut | AI katmanı; LLM yoksa şablon açıklama. |

### Analiz → Metrikler
| Madde | Durum | Veri | Not |
|---|---|---|---|
| Oturumlar: ortalama süre, en uzun oturum, en sık başlangıç saati | Kısmen | Mevcut | Oturum kuralı (2 saat boşluk) var; iki yeni alan. |
| Değişim noktaları: evre değişince renk değiştiren haftalık çubuklar | Yeni | Mevcut | `ruptures`; istatistik, ML değil. Önce `metrikler.md`. |
| Metrik kataloğu: tanım, birim, yorum, güvenilirlik koşulu | Yeni | Mevcut | Kaynak `docs/metrikler.md`. |
| Her kartta "Nasıl hesaplandı?" | Var | Mevcut | |

### Analiz → Teknoloji
| Madde | Durum | Veri | Not |
|---|---|---|---|
| Dil sayısı, baskın dil ve yüzdesi, dağılım çubukları | Yeni | Yeni veri | Repo başına `languages { edges { size } }` (bayt). `repos.languages` JSONB sütunu + migration (ayrı tablo gerekmedi). Yapıldı (13 Kas). |
| Çeşitlilik halkası | Yeni | Yeni veri | Betimleyici entropi ölçüsü (bkz. çelişki çözümleri). |
| Tespit edilen araçlar | Yeni | Yeni veri | Kök dizindeki bilinen dosyalar (package.json, requirements.txt, Dockerfile, pubspec.yaml, .github/workflows...). Tek GraphQL sorgusunda `object(expression:)` ile; senkron süresine etkisi ölçülecek. Dosya içeriği saklanmaz, yalnız araç adı. |

### Analiz → İşbirliği
| Madde | Durum | Veri | Not |
|---|---|---|---|
| Merge edilen PR, merge oranı, merge süresi, review sayısı | Yapıldı (16 Kas) | Yeni veri | `viewer.pullRequests` + yıl yıl `totalPullRequestReviewContributions` (takma adlarla tek istek, ~0,6 sn). Ortalama yerine medyan; kendi repon / başkasının reposu ayrı (kendi reponda oran şişkin). Tanım `docs/metrikler.md`. |
| Aylık merge süresi grafiği, katkı dengesi çubukları | Yeni | Yeni veri | Katkı dengesi: kendi repoların / başkalarınınki, yalnız sayılar; başka kişilerin adları saklanmaz. |
| "Aktif / Yeni kullanıcı" geçişi ve boş durum mesajı | Yeni | — | Veri yetersizse üç durumlu yeterlilik kuralı. |

### Projeler
| Madde | Durum | Veri | Not |
|---|---|---|---|
| Liste: dil, durum etiketi (Aktif / Durağan / Arşiv), skor | Kısmen | Yeni veri | Aktif/Durağan `pushed_at`'tan; Arşiv için `isArchived` çekilecek. |
| Detay: sağlık halkası, eksik listesi, topic çipleri | Kısmen | Mevcut | Şu an 4 kontrol; 5. kontrol önce `metrikler.md`'de tanımlanacak. |
| Son 12 hafta commit çubukları | Yeni | Mevcut | |
| Öneri cümlesi ("…kapatırsan skor 20 puan artar") | Yeni | Mevcut | Kontrol ağırlıklarından deterministik. |
| "Liste / Kümeler" geçişi, repo kümeleri | Yeni | Mevcut | Gözetimsiz (dil, topic, etkinlik özellikleri); raporda ML ayrım tablosuna eklenir. |

### Başarımlar
| Madde | Durum | Veri | Not |
|---|---|---|---|
| 8 rozet: kilitliler soluk, ilerleme çubuklu | Yeni | Mevcut | Kurallar `metrikler.md`'de tanımlanır. |
| Yıl kıyası: iki yıl yan yana, yüzde değişim | Yeni | Mevcut | Betimleyici dil. |
| Hedef koçu: 3 soru çipi | Çıkarıldı (17 Kas) | Mevcut | Yapıldı, sonra geliştirici kararıyla şimdilik kaldırıldı (geri alma commit'leri cb668d3, 5e759bf); ileride geri gelebilir. |

### CV
| Madde | Durum | Veri | Not |
|---|---|---|---|
| 5 format: Jake's Resume, Harvard tarzı, Europass düzeni (tek sütun), Türkiye klasik, Beceri odaklı | Yapıldı (17 Kas) | Mevcut + kullanıcı girdisi | Karar (16 Kas): piyasada tanınan üç format; 17 Kas: Türkiye'de yaygın düzen ve işlevsel düzen eklendi, tüm şablonlara Hakkımda (TR/EN), sertifikalar; ilgi alanları ikisinde. Uyarlamalar `docs/cv.md`. |
| Yerinde düzenlenebilen metinler, "Taslağa dön" | Yapıldı (17 Kas) | — | "Maddeleri düzenle": sayılar kilitli, metin 200 karakter, proje başına 2 ek madde, en çok 6 proje seçimi, beceri çıkar/ekle, "senin düzenlemen" işareti; yalnız cihazda. Kurallar `docs/cv.md`. |
| Maddelerin kaynağını gösterme | Yeni | Mevcut | Her madde hangi veriden üretildiğini söyler. |
| Etki cümlesinde sarı yer tutucu | Yeni | — | Rakamı yalnız kullanıcı yazar; uygulama sayı uydurmaz. |
| Biçim kontrolü kartı (ATS yerine) ve "PDF olarak indir" | Yapıldı | — | PDF yapıldı (17 Kas; telefonda, gömülü Noto yazı tipi). Biçim kontrolü yapıldı (17 Kas): sabit kurallar, eksik/öneri, PDF'in gerçek sayfa sayısı, "ATS" iddiası yok; `docs/cv.md`. |
| Türkçe / English geçişi | Yeni | — | |
| Mülakat koçu: proje seçince 3 soru ve kanıt önerisi | Yapıldı (17 Kas) | Mevcut | AI katmanı (`POST /ai/interview`); LLM'e repo adı değil, yalnız seçilen projenin sayıları gider. Kanıt önerisi veriden kurallı, LLM'e gitmez. `docs/ai_katmani.md`. |

### Profil
| Madde | Durum | Veri | Not |
|---|---|---|---|
| Avatar ve "GitHub'a bağlı" etiketi | Yeni | Yeni veri | `avatarUrl`; aydınlatma metninde belirtilir. |
| Paylaşılabilir profil kartı, rozet vitrini, "Paylaş" | Yapıldı (17 Kas) | Mevcut | Profil'den ve yıllık özetin son slaytından. Kart telefonda PNG olarak üretilir (önizleme gösterilir); içinde yalnız kullanıcı adı, bu yılın toplu sayıları ve açılan rozet adları var. Android'de paylaşım menüsü, web'de indirme; kullanıcı paylaşmadıkça telefondan çıkmaz, sunucuya yeni veri gitmez. |
| Yıllık özet kartı, haftalık bildirim kartı | Yeni | Mevcut | Bildirim: yerel bildirim (sunucu push yok). |
| Ayarlar: AI ipuçları aç/kapa, veri kapsamı, indir/sil, senkronu yeniden oynat | Kısmen | Mevcut | İndir/sil var. |
| Verilerim kartı: saklanan/saklanmayan, 90 gün kuralı | Kısmen | Mevcut | Aydınlatma metninden; 90 gün kuralı uygulanınca. |
| Model Laboratuvarı kartı | Yeni | Mevcut | Gerçek ölçümler (bkz. çelişki çözümleri). |

### Yıllık özet
| Madde | Durum | Veri | Not |
|---|---|---|---|
| Hikâye gibi otomatik slaytlar, üstte ilerleme çubukları, İleri/Kapat | Yapıldı (17 Kas) | Mevcut | Başarımlar'dan açılır; dokunarak ileri/geri. |
| Slaytlar: yıl toplamı, en yoğun ay, en çok dil, gece kuşu, en uzun seri, kodlama saati, dil yolculuğu, review sayısı, son kart | Yapıldı (17 Kas) | Mevcut | Dil yolculuğu Teknoloji verisine, review sayısı İşbirliği verisine bağlı. "Kodlama saati" oturum kuralından tahmindir; öyle yazılır. |
| Temalı animasyonlu arka planlar, "Rozet kazanıldı" parıltısı | Kısmen | — | Slayt başına renk geçişi var; sürekli dönen animasyon ve parıltı yok (pil ve test kararlılığı). |

### Sor balonu
| Madde | Durum | Veri | Not |
|---|---|---|---|
| Sağ altta yüzen düğme, alttan açılan panel, 5 hazır soru | Yeni | Mevcut | AI katmanı. |

## AI katmanı (ileride bağlanacak; unutulmasın)
Bağlı özellikler: AI yorumu ve soru çipleri, "Neden?" düğmeleri, ipucu satırı, hedef koçu, mülakat koçu, Sor balonu.
- Tek altyapı: backend toplu sayıları hesaplar → LLM'e yalnız onlar gider → cevap gelmezse şablon cümle.
- İsteğe bağlı: ilk kullanımda açık onay istenir (aydınlatma metni bunu zaten vaat ediyor); ayarlardan kapatılır.
- Gönderilen sayılar kullanıcıya gösterilebilir olmalı ("LLM'e giden veri" açılır notu).
- Sağlayıcı: Google Gemini API, ücretsiz katman (16 Kas). Ayrıntı: `docs/ai_katmani.md`.
- Faz 6 yapıldı (16 Kas): altyapı, onay, giden veri ekranı; Genel Bakış'ta AI yorumu kartı ve ipucu satırı; Süreklilik, Ritim, Oturum, Commit türleri ve Proje sağlığı kartlarında "Neden?"; her sekmede Sor balonu (5 soru); Profil'de onay ve ipucu anahtarları. Daktilo efekti eklenmedi.

## Önerilen sıra
Teslime (ocak ortası) yaklaşık 9 hafta var; son 2 hafta rapor ve sunuma ayrılır. Liste uzun olduğu için
zaman yetmezse sondaki fazlardan kısılır.
1. Senkron ekranı + Genel Bakış yenilemesi
2. Projeler: durum/arşiv, detay, öneri cümlesi
3. Analiz → Metrikler: oturum, değişim noktası, katalog
4. Analiz → Teknoloji: diller, çeşitlilik, araç tespiti
5. Profil + Başarımlar + Verilerim + 90 gün kuralı
6. AI katmanı → AI yorumu, "Neden?", ipucu, Sor balonu
7. Analiz → İşbirliği (yeni PR/review verisi)
8. CV (şablonlar, TR/EN, PDF, biçim kontrolü) + mülakat ve hedef koçu
9. Yıllık özet + paylaşım kartı + bildirim + repo kümeleri
