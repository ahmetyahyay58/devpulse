# DevPulse — proje bağlamı

Bu dosya Claude Code'un her oturumda okuduğu proje hafızasıdır. Kararlar değiştikçe güncelle.
Not: Buradaki kararlar şimdilik geçerli, ileride değişebilir. Haftalık yol haritası göstermeliktir; katı takvim olarak ele alınmaz.

## Proje
- Bilgisayar Mühendisliği bitirme projesi, Harran Üniversitesi. Tek geliştirici: Ahmet Yahya Yılmaz. Danışman: Doç. Dr. İbrahim Berkan Aydilek.
- Çalışma başlığı: "Kişiselleştirilmiş Geliştirici Etkinlik Analizi ve Eksiklik Takibi için Mobil Bir Uygulama".
- Ne yapar: Kullanıcı GitHub hesabını bağlar; uygulama herkese açık verisinden çalışma alışkanlıklarını, proje sağlığını ve eksiklerini gösterir. Her sonuç güveni, veri eşiği ve "nasıl hesaplandı" açıklamasıyla gelir.
- Hedef teslim: Ocak 2027 ortası (kesin değil, en geç Mayıs 2027).

## Geliştirici hakkında (Claude için çalışma şekli)
- Python, Go, Node.js, SQL biliyor. Flutter/Dart'ı ilk kez kullanıyor.
- Küçük adımlarla ilerle. Her adımda ne yaptığını ve neden yaptığını kısaca Türkçe açıkla.
- Geliştirici kodu anlamalı ve jüriye açıklayabilmeli: büyük kod blokları yerine parça parça ilerle, yeni bir kavram geldiğinde bir cümleyle anlat.
- Komutlar Windows PowerShell içindir. Python'u `py` ile çalıştır (`pip` değil `py -m pip`).
- Her anlamlı adımdan sonra küçük bir commit öner. Commit mesajları kısa, anlamlı, Türkçe ya da İngilizce olabilir; mesajda ne yapıldığını anlatan bir fiil olsun.

## Teknik kararlar
- Mobil: Flutter (Dart), yalnızca Android. iOS kapsam dışı. Geliştirme ortamı Windows. Yedek plan: aynı kodun Flutter web derlemesi.
- Backend: Python, FastAPI, PostgreSQL. Docker Compose ile çalışır.
- Şema yalnızca Alembic migration'larıyla değişir (`backend/migrations/`); `create_all` kullanılmaz. Model değişince: `py -m alembic revision --autogenerate -m "..."`, dosyayı gözden geçir, `py -m alembic upgrade head`. `py -m alembic check` model ile veritabanı arasındaki farkı yakalar.
- Backend'i geliştirmede `py -m uvicorn app.main:app --reload --reload-dir app` ile çalıştır (`.venv`'i izlemesin).
- Testler: `backend/` içinde `py -m pytest` (PostgreSQL açık olmalı). Testler ayrı `devpulse_test` veritabanını migration'larla kurar ve sonunda siler; gerçek veriye dokunmaz, GitHub'a gitmez (sahte HTTP). Gizlilik kuralı (`tests/test_app.py`) yasaklı sütunları denetler. Yeni özellik = yeni test.
- Sade tut: Redis, kuyruk sistemi ve karmaşık durum makinesi yok. Tek arka plan görevi yeter.
- ML: scikit-learn (ve gerekirse ruptures).
- GitHub verisi: GraphQL API. Giriş: GitHub OAuth, yetki kodu akışı + PKCE; kod-token değişimi backend'de yapılır, client secret asla uygulamada durmaz.
- Token kullanıcının telefonunda güvenli depoda durur; sunucu yalnızca senkron sırasında kullanır, kalıcı saklamaz.
- Telefon backend'e kendi oturum belirteciyle (ör. JWT) bağlanır. (Ayrıntısı açık karar.)
- LLM: ana yol şablon cümlelerdir; LLM isteğe bağlı ektir. LLM'e yalnızca hesaplanmış toplu sayılar gider; kullanıcı adı, repo adı, commit mesajı, kod gitmez.

## Doğrulanmış bulgular (11 Kasım 2026, geliştiricinin kendi hesabıyla)
- `authoredDate` ve `committedDate` API'den UTC (`Z`) gelir, commit'in kendi saat farkı gelmez. Gece kuşu, aktif gün, seri hesapları için kullanıcının saat dilimi ayrıca gerekir. Hesaplarda yazar zamanı (`authoredDate`) kullanılır.
- Kota sorun değil (6 istek = 6 puan), süre sorun olabilir: istek başına yaklaşık 2 saniye. Büyük hesaplarda senkron dakikalar sürer; senkron ekranı buna göre tasarlanmalı.
- `history(author: {id})` ile çekilen commit sayısı GitHub katkı takviminden az çıkabiliyor (bu hesapta 33'e karşı 41). Fark büyük olasılıkla ortak yazar (Co-authored-by) commit'lerinden. Bunların sayılıp sayılmayacağı açık karar. İnceleme betiği: `scripts/inceleme.py`.
- Başkasına ait repolara atılan commit'ler kendi repo listesinde görünmez; `contributionsCollection.commitContributionsByRepository` (yıl yıl) ile bulunur.

## MVP (olmazsa olmaz)
- GitHub ile giriş; senkron (profil, repolar, commit'ler, katkı takvimi); PostgreSQL ve basit FastAPI.
- Genel Bakış: KPI, katkı takvimi, commit türleri.
- Projeler: sağlık skoru ve eksiklik takibi (README, açıklama, topic, lisans).
- Metrikler: süreklilik, ritim, yoğunluk, proje sağlığı.
- Commit sınıflandırma (kural + TF-IDF ve lojistik regresyon), ölçümlü.
- Anomali (önce basit yöntem: medyan/MAD; Isolation Forest kıyas için).
- Oturum (sabit 2 saatlik boşluk eşiği; kural, ML değil).
- Üç durumlu veri yeterliliği: "Yeterli veri yok", "Düşük güven", "Normal".
- Basit sentetik demo kullanıcı (aynı kod yolundan geçer: veri çekme katmanının canlı ve demo istemcisi aynı arayüzü uygular).
- Veri silme ve aydınlatma metni.

Zaman kalırsa: değişim noktası, tek şablonlu CV ve PDF, Teknoloji sayfası (yalnız dil dağılımı), rozetler, LLM yorumu ve "Neden?", Model Laboratuvarı, basit yıllık özet.

Kesildi: repo kümeleme, mülakat ve hedef koçu, iki dilli CV ve 5 şablon, "Sor" balonu, README taslağı, İşbirliği sayfası, araç tespiti, bildirim, paylaşım kartı, temalı yıllık özet animasyonları, çeşitlilik skoru.

## Dürüstlük kuralları
- ML'i abartma: yalnızca commit sınıflandırma gözetimli ML'dir. Anomali gözetimsiz; değişim noktası istatistik; oturum kural. Raporda bu ayrım tabloyla verilir.
- Sentetik veri ML başarısını kanıtlamaz; yalnızca kodun çalıştığını gösterir.
- Commit sayısı üretkenliği ya da kaliteyi ölçmez; arayüz alışkanlığı betimler.
- Sahte veri, uydurma sayı, uydurma kaynak yok.

## Güvenlik ve gizlilik
- Token, `.env` ve `ham_veri/` klasörü asla commit edilmez (`.gitignore`'da).
- E-posta ve yazar adı veritabanında saklanmaz. Başka kişilerin kullanıcı adları saklanmaz, yalnızca sayılar.

## Repo yapısı (planlanan)
- `scripts/` — deneme ve ölçüm betikleri (ilk_senkron.py, fark.py, sayaç.py, inceleme.py)
- `backend/` — FastAPI, senkron, ML
- `mobile/` — Flutter uygulaması
- `docs/` — rapor için notlar, ölçüm tabloları

## Yol haritası (MVP, ocak ortası hedefi — göstermelik, esnek)
1. Hafta (11–17 Kas): kararların kesinleşmesi; Python betiğiyle GitHub verisi çekme ve ölçüm. (Başladı: scripts/ilk_senkron.py çalışıyor.)
2. Hafta (18–24 Kas): PostgreSQL şeması, sayfalamalı ve tekrar çalıştırılabilir senkron, FastAPI'de üç uç nokta. Paralelde Flutter: Android'de GitHub girişi ve tek ekran. Giriş çalışmazsa Flutter web'e geçiş kararı.
3. Hafta: senkron ekranı ve Genel Bakış, gerçek veriyle; saat dilimi kuralı.
4. Hafta: Projeler, sağlık skoru, eksiklik takibi, metrikler, veri yeterliliği; basit demo kullanıcı.
5. Hafta: etiket tanımları, ~300 elle etiket, kural ve model, LLM kıyası, ölçüm.
6. Hafta: anomali (basit + Isolation Forest), enjeksiyon testi, oturum, "Nasıl hesaplandı?" metinleri.
7. Hafta: silme/indirme, aydınlatma metni, hata ve limit durumları, görsel düzeltmeler.
8. Hafta: tampon; rapor şekilleri ve tabloları.
9. Hafta: rapor, sunum, prova, yedek video. 8 Ocak'tan sonra yalnızca hata düzeltme.

## Açık kararlar (kodlamadan önce netleşmeli)
- Teslim tarihi: ocak ortası mı, mayıs mı? (danışmana sorulacak)
- MVP listesinin onayı.
- Backend nerede çalışacak (yerel makine + aynı Wi-Fi ya da bulut) ve oturum belirteci tasarımı.
- Değerlendirme verisi: gerçek test kullanıcısı olacak mı, kim, hangi onayla?
- Ortak yazar commit'leri sayılacak mı?
