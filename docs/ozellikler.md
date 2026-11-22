# Özellik listesi ve kararlar

13 Kasım 2026. Geliştiricinin prototipteki ekran listesi, CLAUDE.md'deki kurallara göre değerlendirildi.
Önceden "Kesildi" listesinde olan özellikler kapsama geri alındı. Kurallarla çelişen maddeler
aşağıdaki "Çelişki çözümleri" bölümündeki gibi yeniden tasarlanarak yapılacak.

Durumlar 19 Kas'ta koda bakılarak güncellendi. Durum: **Var** = uygulamada çalışıyor · **Kısmen** = bir parçası var · **Yeni** = yapılacak.
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
| Aşamalı liste: dönen gösterge, bitince yeşil tik | Var | Mevcut | Gerçek aşamalar gösterilir (profil, repolar, commit'ler, takvim); `sync_jobs`'a `phase` alanı. Sayı 6'ya uydurulmaz. |
| Aşama altında canlı sayaç ("23 / 47 repo") | Var | Mevcut | `repos_done / repos_total` zaten var. |
| Kare kare dolan katkı takvimi | Var | Mevcut | Commit'ler geldikçe günlük sayılardan doldurulur. |
| Genel ilerleme çubuğu, yüzde, "Atla" | Var | Mevcut | "Atla": senkron arka planda sürer, kullanıcı uygulamaya geçer. |

### Genel Bakış
| Madde | Durum | Veri | Not |
|---|---|---|---|
| 4 KPI: toplam commit, aktif gün, en uzun seri, repo | Var | Mevcut | Büyük yazı boyutunda taşma düzeltildi (19 Kas, test var). |
| Son 30 hafta katkı takvimi, anomali günlerinde amber halka | Var | Mevcut | |
| Commit türleri halkası (Türkçe etiketler) | Var | Mevcut | |
| AI yorumu kartı: 3 hazır soru çipi, daktilo efekti | Kısmen | Mevcut | Kart ve çipler var; daktilo efekti eklenmedi. |
| Kapatılabilir "AI" rozetli ipucu satırı | Var | Mevcut | AI katmanı; ayarlardan kapatılabilir. |
| Grafik başlıklarında "Neden?" | Var | Mevcut | AI katmanı; LLM yoksa şablon açıklama. |

### Analiz → Metrikler
| Madde | Durum | Veri | Not |
|---|---|---|---|
| Oturumlar: ortalama süre, en uzun oturum, en sık başlangıç saati | Var | Mevcut | Oturum kuralı (2 saat boşluk) var; iki yeni alan. |
| Değişim noktaları: evre değişince renk değiştiren haftalık çubuklar | Var | Mevcut | `ruptures`; istatistik, ML değil. Önce `metrikler.md`. |
| Metrik kataloğu: tanım, birim, yorum, güvenilirlik koşulu | Var | Mevcut | Kaynak `docs/metrikler.md`. |
| Her kartta "Nasıl hesaplandı?" | Var | Mevcut | |

### Analiz → Teknoloji
| Madde | Durum | Veri | Not |
|---|---|---|---|
| Dil sayısı, baskın dil ve yüzdesi, dağılım çubukları | Var | Yeni veri | Repo başına `languages { edges { size } }` (bayt). `repos.languages` JSONB sütunu + migration (ayrı tablo gerekmedi). Yapıldı (13 Kas). |
| Çeşitlilik halkası | Var | Yeni veri | Betimleyici entropi ölçüsü (bkz. çelişki çözümleri). |
| Tespit edilen araçlar | Var | Yeni veri | Kök dizindeki bilinen dosyalar (package.json, requirements.txt, Dockerfile, pubspec.yaml, .github/workflows...). Tek GraphQL sorgusunda `object(expression:)` ile; senkron süresine etkisi ölçülecek. Dosya içeriği saklanmaz, yalnız araç adı. |

### Analiz → İşbirliği
| Madde | Durum | Veri | Not |
|---|---|---|---|
| Merge edilen PR, merge oranı, merge süresi, review sayısı | Yapıldı (16 Kas) | Yeni veri | `viewer.pullRequests` + yıl yıl `totalPullRequestReviewContributions` (takma adlarla tek istek, ~0,6 sn). Ortalama yerine medyan; kendi repon / başkasının reposu ayrı (kendi reponda oran şişkin). Tanım `docs/metrikler.md`. |
| Aylık merge süresi grafiği, katkı dengesi çubukları | Yapıldı (19 Kas) | Mevcut | Yeni veri gerekmedi (saklanan PR ve commit'lerden). Aylık: son 12 ay, merge ayına göre medyan, boş ay boşluk, az PR'lı ay soluk. Katkı dengesi: commit ve PR için kendi repoların / başkalarınınki, yalnız sayılar. Tanım `metrikler.md`. |
| "Aktif / Yeni kullanıcı" geçişi ve boş durum mesajı | Kısmen | — | Boş durum üç durumlu yeterlilik kuralıyla var; "Aktif / Yeni" geçişi prototipteki demo aracıdır, uygulamaya girmez. |

### Projeler
| Madde | Durum | Veri | Not |
|---|---|---|---|
| Liste: dil, durum etiketi (Aktif / Durağan / Arşiv), skor | Var | Yeni veri | Aktif/Durağan `pushed_at`'tan; Arşiv `isArchived`dan. |
| Detay: sağlık halkası, eksik listesi, topic çipleri | Var | Mevcut | 5 kontrol (README, README içeriği, açıklama, lisans, topic); tanım `metrikler.md`. |
| Son 12 hafta commit çubukları | Var | Mevcut | |
| Öneri cümlesi ("…kapatırsan skor 20 puan artar") | Var | Mevcut | Kontrol ağırlıklarından deterministik. |
| "Liste / Kümeler" geçişi, repo kümeleri | Yapıldı (17 Kas) | Mevcut | Gözetimsiz k-means (etkinlik + sağlık puanı; dil özellik değil, açıklamada); az repoda k = 2 sabit. Tanım `docs/metrikler.md` "Repo kümeleri"; raporda ML ayrım tablosuna gözetimsiz olarak eklenir. |

### Başarımlar
| Madde | Durum | Veri | Not |
|---|---|---|---|
| 29 rozet: kilitliler soluk, ilerleme çubuklu | Var | Mevcut | 9 temel + 20 alışkanlık rozeti (19-20 Kas; ikisi gizli, açılana kadar "???"; dördü bronz/gümüş/altın seviyeli). Kurallar `metrikler.md`'de tanımlanır. 20 Kas: her rozetin kendi SVG görseli (emaye rozet; şekil kategoriyi, metal kenar seviyeyi söyler; `mobile/tool/make_badges.py`, elle çizildi), dokununca ayrıntı sayfası, yeni açılan rozet ya da seviye için tek seferlik kutlama (görülenler yalnız cihazda). |
| Yıl kıyası: iki yıl yan yana, yüzde değişim | Var | Mevcut | Betimleyici dil. |
| Hedef koçu: 3 soru çipi | Çıkarıldı (17 Kas) | Mevcut | Yapıldı, sonra geliştirici kararıyla şimdilik kaldırıldı (geri alma commit'leri cb668d3, 5e759bf); ileride geri gelebilir. |

### CV
| Madde | Durum | Veri | Not |
|---|---|---|---|
| 5 format: Jake's Resume, Harvard tarzı, Europass düzeni (tek sütun), Türkiye klasik, Beceri odaklı | Yapıldı (17 Kas) | Mevcut + kullanıcı girdisi | Karar (16 Kas): piyasada tanınan üç format; 17 Kas: Türkiye'de yaygın düzen ve işlevsel düzen eklendi, tüm şablonlara Hakkımda (TR/EN), sertifikalar; ilgi alanları ikisinde. Uyarlamalar `docs/cv.md`. |
| Yerinde düzenlenebilen metinler, "Taslağa dön" | Yapıldı (17 Kas) | — | "Maddeleri düzenle": sayılar kilitli, metin 200 karakter, proje başına 2 ek madde, en çok 6 proje seçimi, beceri çıkar/ekle, "senin düzenlemen" işareti; yalnız cihazda. Kurallar `docs/cv.md`. |
| Maddelerin kaynağını gösterme | Var | Mevcut | Her madde hangi veriden üretildiğini söyler. |
| Etki cümlesinde sarı yer tutucu | Var | — | Rakamı yalnız kullanıcı yazar; uygulama sayı uydurmaz. |
| Biçim kontrolü kartı (ATS yerine) ve "PDF olarak indir" | Yapıldı | — | PDF yapıldı (17 Kas; telefonda, gömülü Noto yazı tipi). Biçim kontrolü yapıldı (17 Kas): sabit kurallar, eksik/öneri, PDF'in gerçek sayfa sayısı, "ATS" iddiası yok; `docs/cv.md`. |
| Türkçe / English geçişi | Var | — | |
| Mülakat koçu: proje seçince 3 soru ve kanıt önerisi | Yapıldı (17 Kas) | Mevcut | AI katmanı (`POST /ai/interview`); LLM'e repo adı değil, yalnız seçilen projenin sayıları gider. Kanıt önerisi veriden kurallı, LLM'e gitmez. `docs/ai_katmani.md`. Profil README reposu (`login/login`) proje listesinde yok (19 Kas). |

### Profil
| Madde | Durum | Veri | Not |
|---|---|---|---|
| Avatar ve "GitHub'a bağlı" etiketi | Var | Yeni veri | `avatarUrl`; aydınlatma metninde belirtilir. |
| Paylaşılabilir profil kartı, rozet vitrini, "Paylaş" | Yapıldı (17 Kas) | Mevcut | Profil'den ve yıllık özetin son slaytından. Kart telefonda PNG olarak üretilir (önizleme gösterilir); içinde yalnız kullanıcı adı, bu yılın toplu sayıları ve açılan rozet adları var. Android'de paylaşım menüsü, web'de indirme; kullanıcı paylaşmadıkça telefondan çıkmaz, sunucuya yeni veri gitmez. |
| Yıllık özet kartı, haftalık bildirim kartı | Yapıldı (17 Kas) | Mevcut | Yıllık özet Başarımlar'da; "Bu hafta" kartı Genel Bakış'ta (`GET /metrics/weekly`); haftalık bildirim yalnız Android, Profil'den açılır, varsayılan kapalı, yerel ve yaklaşık zamanlı (sunucu push yok, metinde sayı yok). |
| Ayarlar: AI ipuçları aç/kapa, veri kapsamı, indir/sil, senkronu yeniden oynat | Var (19 Kas) | Mevcut | Veri kapsamı kartı `GET /me` `scope` alanından (tanım `metrikler.md`); "Senkronu yeniden oynat" Profil'i kapatıp senkronu başlatır ve aşamalı ekranı açar. Tema seçimi (22 Kas): Sistem (varsayılan) / Açık / Koyu, cihazda tutulur; açık temada ısı haritası kendi doğrulanmış rampasını kullanır. |
| Verilerim kartı: saklanan/saklanmayan, 90 gün kuralı | Var | Mevcut | Silinme tarihi `GET /me`'den. |
| Model Laboratuvarı kartı | Var | Mevcut | Gerçek ölçümler (bkz. çelişki çözümleri). |

### Yıllık özet
| Madde | Durum | Veri | Not |
|---|---|---|---|
| Hikâye gibi otomatik slaytlar, üstte ilerleme çubukları, İleri/Kapat | Yapıldı (17 Kas) | Mevcut | Başarımlar'dan açılır; dokunarak ileri/geri. |
| Slaytlar: yıl toplamı, en yoğun ay, en çok dil, gece kuşu, en uzun seri, kodlama saati, dil yolculuğu, review sayısı, son kart | Yapıldı (17 Kas) | Mevcut | Dil yolculuğu Teknoloji verisine, review sayısı İşbirliği verisine bağlı. "Kodlama saati" oturum kuralından tahmindir; öyle yazılır. |
| Temalı animasyonlu arka planlar, "Rozet kazanıldı" parıltısı | Var (22 Kas) | — | Slayt başına renk geçişi ve her slaydın konusunu anlatan animasyonlu sahne (`lib/year/year_scenes.dart`: yükselen commit kareleri, ayların üzerinde gezip en yoğun ayda duran ışık, payına dolan dil halkası, doğan ay ve en yoğun saate dönen ibre, alev alan seri günleri, kum saati, dil zaman çizgisi, satır inceleyen büyüteç, rozet halkası ve konfeti); büyük sayılar sayarak gelir. Hepsi slayt zamanlayıcısından çizilir, sahnelerde yalnız özetin gerçek sayıları kullanılır. "Rozet kazanıldı" kutlaması Başarımlar'da var (20 Kas, tek seferlik ışın + büyüme). Sürekli dönen animasyon yok (pil ve test kararlılığı). |

### Sor balonu
| Madde | Durum | Veri | Not |
|---|---|---|---|
| Sağ altta yüzen düğme, alttan açılan panel, 5 hazır soru | Var | Mevcut | AI katmanı. |

## AI katmanı
Bağlı özellikler: AI yorumu ve soru çipleri, "Neden?" düğmeleri, ipucu satırı, hedef koçu, mülakat koçu, Sor balonu.
- Tek altyapı: backend toplu sayıları hesaplar → LLM'e yalnız onlar gider → cevap gelmezse şablon cümle.
- İsteğe bağlı: ilk kullanımda açık onay istenir (aydınlatma metni bunu zaten vaat ediyor); ayarlardan kapatılır.
- Gönderilen sayılar kullanıcıya gösterilebilir olmalı ("LLM'e giden veri" açılır notu).
- Sağlayıcı: Google Gemini API, ücretsiz katman (16 Kas). Ayrıntı: `docs/ai_katmani.md`.
- Faz 6 yapıldı (16 Kas): altyapı, onay, giden veri ekranı; Genel Bakış'ta AI yorumu kartı ve ipucu satırı; Süreklilik, Ritim, Oturum, Commit türleri ve Proje sağlığı kartlarında "Neden?"; her sekmede Sor balonu (5 soru); Profil'de onay ve ipucu anahtarları. Daktilo efekti eklenmedi.

## Önerilen sıra (13 Kas planı; hepsi yapıldı, 19 Kas)
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
