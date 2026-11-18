# Dağıtım: bulutta backend (geliştirici kararı, 17 Kas 2026)

Amaç: Android uygulaması bilgisayara bağlı olmadan, yalnızca internetle her yerde çalışsın.

## Düzen
| Parça | Nerede | Not |
|---|---|---|
| Backend (FastAPI) | **Render**, ücretsiz web servisi, Frankfurt | `render.yaml` + `backend/Dockerfile`. `main`'e gelen ve `backend/` altını değiştiren her commit kendiliğinden yayına alınır (2-5 dk). Açılışta `alembic upgrade head` çalışır. |
| Veritabanı (PostgreSQL) | **Neon**, ücretsiz, Frankfurt (AWS eu-central-1) | Render'ın ücretsiz veritabanı 30 günde silindiği için kullanılmaz. |
| Geliştirme | Geliştiricinin bilgisayarı (değişmedi) | Yerel Docker PostgreSQL ve `uvicorn`; testler yine yerel `devpulse_test` veritabanında. |

Seçim gerekçesi (17 Kas): kredi kartı istemeyen en basit seçenek. Bedeli: Render'ın ücretsiz
sunucusu 15 dakika istek almazsa uyur, ilk istek yaklaşık 1 dakika sürer. Uygulama açılışta
`/health`'i 90 saniyeye kadar bekler ve bu sürede "Sunucu uyanıyor…" gösterir (`mobile/lib/main.dart`,
`WakeScreen`). Kıyaslanan diğer seçenekler: Cloud Run + Neon (kart ister, birkaç saniyede uyanır),
Oracle sanal makine (uyumaz, bakım yükü), Supabase (yalnız veritabanı, backend'i çalıştırmaz).

## Ortam değişkenleri (Render paneli; repoya yazılmaz)
| Anahtar | Kim girer | Not |
|---|---|---|
| `DATABASE_URL` | Geliştirici | Neon "Connection string". `postgresql://` öneki kodda psycopg 3'e çevrilir (`app/config.py`). |
| `JWT_SECRET` | Render üretir | `generateValue: true`. |
| `GITHUB_ANDROID_CLIENT_ID`, `GITHUB_ANDROID_CLIENT_SECRET` | Geliştirici | Android OAuth App; geri dönüş adresi `devpulse://oauth-callback` olduğu için değişmez. |
| `GEMINI_API_KEY` | Geliştirici | Boşsa AI cevapları şablon olur. |

## Uygulama
APK bulut adresiyle derlenir; adres APK'nın içine yazılır, sabit kalmalıdır:

    flutter build apk --dart-define=API_BASE_URL=https://<servis-adı>.onrender.com --target-platform android-arm64

Yalnızca uygulama kodu değişince yeni APK kurulur; backend değişiklikleri sunucu güncellenince
telefona kendiliğinden yansır.

## Veri ve gizlilik
- Bulut veritabanı boş başlar; kullanıcı telefondan giriş yapıp senkron edince veri oraya çekilir.
  Yerel geliştirme veritabanı ayrıdır ve taşınmaz.
- Veriler Almanya'daki (Frankfurt) sunucularda saklanır; aydınlatma metni bunu ve hizmet
  sağlayıcıları yazar. Kişisel verinin yurt dışına aktarımı KVKK'da ayrıca düzenlenir; danışmana
  sorulacak.
- Buluttaki veriye geliştirici dışında erişim yoktur; Claude yalnız okumak için bağlanır, silme ya
  da toplu değişiklik geliştirici onayıyla yapılır.
