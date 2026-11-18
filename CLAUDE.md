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
- Android'de deneme: emülatör bu makinede (7,7 GB) bellek yetmediği için çöküyor; gerçek telefon kullanılır. Varsayılan APK buluttaki sunucuya bağlanır (`flutter build apk --release --target-platform android-arm64`; adres `mobile/lib/config.dart` `cloudApiUrl`). Bilgisayardaki sunucuyla denemek için `--dart-define=API_BASE_URL=http://127.0.0.1:8000` + `adb reverse tcp:8000 tcp:8000`. Web ve Android ayrı GitHub OAuth App kullanır (`GITHUB_ANDROID_CLIENT_ID/SECRET`). Telefonda demo ve GitHub girişi doğrulandı (13 Kas).
- Backend: Python, FastAPI, PostgreSQL. Docker Compose ile çalışır.
- Yayın (17 Kas kararı, 18 Kas'ta açıldı: https://devpulse-api-mvwt.onrender.com): backend Render'da (ücretsiz, Frankfurt, `render.yaml`, `backend/Dockerfile`), veritabanı Neon'da (ücretsiz, Frankfurt). `backend/` değişen her push kendiliğinden yayına çıkar; açılışta Alembic migration çalışır. Geliştirme ve testler yerelde kalır. APK bulut adresiyle derlenir; ücretsiz sunucu uyuyabildiği için uygulama açılışta "Sunucu uyanıyor" bekler. Ayrıntı `docs/dagitim.md`.
- Flutter web tuzağı (17 Kas): yeni bir eklenti (ör. `shared_preferences`) eklenince `flutter build web --release` eski eklenti kayıt dosyasını kullanabiliyor; tarayıcıda `MissingPluginException` çıkar, debug'da çıkmaz. Çözüm: `flutter clean`, sonra derle. Tarayıcı da eski derlemeyi önbellekten verebilir: servis çalışanını ve önbelleği temizleyip yeniden yükle.
- Şema yalnızca Alembic migration'larıyla değişir (`backend/migrations/`); `create_all` kullanılmaz. Model değişince: `py -m alembic revision --autogenerate -m "..."`, dosyayı gözden geçir, `py -m alembic upgrade head`. `py -m alembic check` model ile veritabanı arasındaki farkı yakalar.
- Backend'i geliştirmede `py -m uvicorn app.main:app --reload --reload-dir app` ile çalıştır (`.venv`'i izlemesin). Windows'ta `--reload` bazen "Reloading..." deyip takılıyor (eski süreç kapanmıyor); değişiklik canlıda görünmüyorsa log'a bak ve sunucuyu yeniden başlat. `.env` değişikliği her zaman yeniden başlatma ister.
- Metrik tanımları ve veri yeterliliği eşikleri: `docs/metrikler.md` (kod `backend/app/metrics/` buna uyar; önce belge güncellenir). Özet cümleleri şablondur; sayıdan sonra Türkçe ek kullanma (%12'si/%1'i ayrımı), ek gerektirmeyen cümle kur.
- Testler: `backend/` içinde `py -m pytest` (PostgreSQL açık olmalı). Testler ayrı `devpulse_test` veritabanını migration'larla kurar ve sonunda siler; gerçek veriye dokunmaz, GitHub'a gitmez (sahte HTTP). Gizlilik kuralı (`tests/test_app.py`) yasaklı sütunları denetler. Yeni özellik = yeni test.
- Sade tut: Redis, kuyruk sistemi ve karmaşık durum makinesi yok. Tek arka plan görevi yeter.
- ML: scikit-learn (ve gerekirse ruptures).
- Commit sınıflandırma (Türkçe): etiket kılavuzu `docs/etiketler.md` (7 ince sınıf); uygulamada 6 sade sınıf, refactor+chore = "Bakım ve düzenleme" (`app/classify/labels.py`, MERGE). Sistem: önek/kural (`app/classify/rules.py`, Türkçe kökler) önce, sonra model (harf parçası 3-5 TF-IDF + lojistik regresyon, yalnız ilk satır, eşik yok). Veri: GitHub aramasıyla 2479 Türkçe önekli commit (`ml/collect_tr.py`, önek = zayıf etiket, ağırlık 0,3) + geliştiricinin 200 insan etiketi (`ml.label --train`); Test referansı (geliştirici kararı, 13 Kas): altın kümenin yapay zekâ kör etiketleri (`tr_gold_llm_labels.jsonl`; yazarlarla %78 uyuşuyor, geliştirici etiketleri ~%40). Uygulama modeli yalnız yazar önekleriyle: `py -m ml.llm_ref save` (`ml.merge save` / `ml.human save` artık kullanılmaz); "Belirsiz" yalnız kurallardan. Sonuç: ref yapay zekâ 0,63 / kappa 0,53; ref geliştirici ~0,40. Artış referans değişiminden, sistemden değil (raporda açıkça yazılır). Test: 94 kör insan etiketi (`tr_gold_*`, test repoları; asla eğitimde/tasarımda kullanılmaz) ve geliştiricinin 33 commit'i (`own*.jsonl`, gitignore'da). Sonuçlar `docs/olcumler.md`: Türkçe ~%35-39, kendi ~%58; yazar öneki-insan uyuşması %40 (tanımlar belirsiz). Tasarım kararları yalnız eğitim verisinde CV ile verilir. Commit mesajları LLM'e gönderilmez. (İngilizce `pool.jsonl` ilk denemeydi, kullanılmıyor.)
- GitHub verisi: GraphQL API. Giriş: GitHub OAuth, yetki kodu akışı + PKCE; kod-token değişimi backend'de yapılır, client secret asla uygulamada durmaz.
- Token kullanıcının telefonunda güvenli depoda durur; sunucu yalnızca senkron sırasında kullanır, kalıcı saklamaz.
- Telefon backend'e kendi oturum belirteciyle bağlanır: HS256 JWT, 7 gün, yenileme yok; içinde yalnız kullanıcı id'si (sub). Süre dolunca GitHub ile yeniden giriş. (Uygulandı; onaylanırsa açık karardan çıkar.)
- Giriş uç noktaları: `GET /auth/config`, `POST /auth/github` (kod + PKCE verifier → GitHub token'ı telefona + JWT), `POST /auth/demo`. OAuth kapsamı `read:user` (yalnız herkese açık veri). `/sync` JWT ister; gönderilen GitHub token'ı oturumdaki hesaba ait değilse 403.
- LLM: ana yol şablon cümlelerdir; LLM isteğe bağlı ektir. LLM'e yalnızca hesaplanmış toplu sayılar gider; kullanıcı adı, repo adı, commit mesajı, kod gitmez. Sağlayıcı: Google Gemini API ücretsiz katman (16 Kas kararı; `GEMINI_API_KEY`, `GEMINI_MODEL` `.env`'de). Sözleşme `docs/ai_katmani.md`, kod `backend/app/ai/`. Onay sunucuda (`users.ai_consent_at`); yalnız hazır sorular, serbest metin yok.

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
- Basit sentetik demo kullanıcı (aynı kod yolundan geçer: veri çekme katmanının canlı ve demo istemcisi aynı arayüzü uygular). (Yapıldı: `backend/demo/demo_user.json` elle düzenlenmez, `py -m app.sync.demo_generator` ile deterministik üretilir; tarihler okunurken bugüne kaydırılır. Enjekte anomali `_injected` alanında. Son 6 ay yoğun, öncesinde ~1,5 yıllık daha seyrek geçmiş (`PAST_*`, ayrı tohum): yıl kıyası ve yıllık özet demoda dolu görünür; geçmiş, son 6 ayı ve anomaliyi değiştirmez (test_demo). Testler küçük `tests/fixtures/demo_small.json` kullanır.)
- Veri silme ve aydınlatma metni.

MVP sonrası kapsam (geliştirici kararı, 13 Kas): prototip ekran listesi `docs/ozellikler.md`'de; eskiden kesilen özellikler (kümeler, koçlar, 5 şablon ve TR/EN CV, Sor balonu, İşbirliği, araç tespiti, bildirim, paylaşım kartı, yıllık özet animasyonları, çeşitlilik) geri alındı. Kurallarla çelişenler orada yazan çözümlerle yapılır: Model Laboratuvarı yalnız gerçek ölçümler; 90 gün kuralı gerçekten uygulanır; "ATS" yerine "Biçim kontrolü"; çeşitlilik puan değil betimleyici entropi; AI özellikleri tek katmandan, yalnız toplu sayılarla, onaylı. Sıra ve faz listesi o dosyada; zaman yetmezse sondan kısılır. Hâlâ kapsam dışı: README taslağı, prototipteki demo kaydırıcıları.

## Dürüstlük kuralları
- ML'i abartma: yalnızca commit sınıflandırma gözetimli ML'dir. Anomali gözetimsiz; değişim noktası istatistik; oturum kural. Raporda bu ayrım tabloyla verilir.
- Sentetik veri ML başarısını kanıtlamaz; yalnızca kodun çalıştığını gösterir.
- Commit sayısı üretkenliği ya da kaliteyi ölçmez; arayüz alışkanlığı betimler.
- Sahte veri, uydurma sayı, uydurma kaynak yok.

## Güvenlik ve gizlilik
- Token, `.env` ve `ham_veri/` klasörü asla commit edilmez (`.gitignore`'da).
- E-posta ve yazar adı veritabanında saklanmaz. Başka kişilerin kullanıcı adları saklanmaz, yalnızca sayılar.
- Aydınlatma metni: `backend/app/legal/aydinlatma_metni.md` (tek kaynak; `GET /privacy` sunar, uygulama oradan gösterir). Saklanan/saklanmayan veri, yetki kapsamı ya da veri akışı değişirse metin de aynı commit'te güncellenir. İletişim adresi yer tutucusu geliştirici tarafından doldurulacak.
- Veri indirme: `GET /me/export` saklanan her sütunu JSON olarak verir (sütunlar tablodan okunur; test her DB sütununun dosyada olduğunu denetler). Mobilde web'de doğrudan indirme, Android'de paylaşım menüsü (`share_plus`).
- 90 gün kuralı: `users.last_active_at` her girişte ve biten senkronda güncellenir; sunucu açılışta ve günde bir `app/retention.py` ile 90 günden eski hesapları siler (senkronu sürenlere dokunmaz). Silinme tarihi `GET /me` ile uygulamada görünür.
- Veri silme: `DELETE /me` tek SQL komutuyla siler (ON DELETE CASCADE), senkron sürerken 409; istenirse GitHub izni de kaldırılır (başarısız olsa da silme tamamlanır).

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
- Oturum belirteci için öneri uygulandı (bkz. Teknik kararlar), onay bekliyor. (Backend'in yeri kararlaştırıldı: Render + Neon, 17 Kas.)
- Verilerin yurt dışında (Frankfurt) saklanması KVKK açısından danışmana sorulacak.
- Değerlendirme verisi: gerçek test kullanıcısı olacak mı, kim, hangi onayla?
- Ortak yazar commit'leri sayılacak mı?
