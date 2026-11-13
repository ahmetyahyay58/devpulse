# DevPulse Aydınlatma Metni

Son güncelleme: 13 Kasım 2026 · Taslak

Bu metin, Harran Üniversitesi Bilgisayar Mühendisliği bitirme projesi olarak geliştirilen DevPulse uygulamasının hangi verileri neden işlediğini açıklar. Bir öğrenci projesi için hazırlanmış taslaktır; hukuki danışmanlık niteliği taşımaz.

## Veri sorumlusu
Uygulamayı geliştiren öğrenci (Ahmet Yahya Yılmaz). İletişim: [iletişim adresi eklenecek]

## Uygulama ne yapar
GitHub hesabındaki herkese açık etkinlikten çalışma alışkanlıklarını (süreklilik, ritim, oturumlar) ve repolarının eksiklerini (README, açıklama, lisans, topic) gösterir. Sonuçlar betimleyicidir; üretkenliği ya da kod kalitesini ölçmez.

## GitHub'dan istenen yetki
Yalnızca "read:user" (profilini okuma). Uygulama özel repolarına ve koduna erişemez, GitHub hesabında hiçbir şeyi değiştiremez.

## Saklanan veriler
- Hesap: GitHub kullanıcı kimliğin (sayısal olmayan iç kimlik), kullanıcı adın, saat dilimin, ilk kayıt ve son senkron zamanı.
- Repolar: ad, açıklama, ana dil, topic'ler, lisans türü, README olup olmadığı, oluşturma ve son push zamanı, fork ya da özel olup olmadığı. Başkasına ait repolarda sahibin kullanıcı adı saklanmaz.
- Commit'lerin: kimliği (SHA), yazılma zamanı, mesajı, eklenen ve silinen satır sayısı, değişen dosya sayısı, birden fazla yazarı olup olmadığı.
- Katkı takvimi: gün başına toplam katkı sayısı.
- Senkron kayıtları: ne zaman yapıldığı, kaç istek sürdüğü, varsa hata mesajı.

## Saklanmayan veriler
- E-posta adresin, gerçek adın, commit yazarlarının ad ve e-postaları.
- Başka kişilerin kullanıcı adları (yalnızca sayılar tutulur).
- Kodunun içeriği.
- GitHub erişim anahtarın (token): yalnızca telefonunun güvenli deposunda durur; sunucu onu yalnızca senkron sırasında kullanır ve hiçbir yere yazmaz.

## Verinin işlenme amacı
Sana kendi alışkanlıklarını ve repolarının eksiklerini göstermek. Veriler satılmaz, reklam için kullanılmaz, başka kişilerle paylaşılmaz.

## Veri nereye gider
- GitHub: verinin kaynağıdır; uygulama GitHub API'sinden okur.
- Yapay zekâ hizmetleri: şu an hiçbirine veri gönderilmez. İleride isteğe bağlı bir yorum özelliği eklenirse yalnızca hesaplanmış toplu sayılar gönderilir (kullanıcı adı, repo adı, commit mesajı ya da kod gönderilmez) ve ayrıca onayın istenir.
- Sunucu, proje süresince geliştiricinin denetimindeki bir makinede çalışır.

## Verilerini indirme
Uygulamadaki "Verilerimi indir" seçeneği, sunucuda senin hakkında saklanan verilerin tamamını (yukarıdaki "Saklanan veriler" bölümünde sayılanlar) tek bir JSON dosyası olarak verir. Dosya yalnızca sana, oturumunla gönderilir; sunucuda ayrıca bir kopyası oluşturulmaz.

## Saklama süresi ve silme
Veriler sen silene kadar saklanır. Uygulamadaki "Verilerimi sil" seçeneği hesabını ve yukarıda sayılan bütün verileri sunucudan anında ve kalıcı olarak siler; ayrı bir yedek tutulmaz. İstersen aynı anda GitHub'daki DevPulse iznin de kaldırılır. Silmeden sonra yeniden giriş yaparsan veriler GitHub'dan yeniden çekilir.

## Hakların
6698 sayılı Kişisel Verilerin Korunması Kanunu'nun 11. maddesi kapsamında, verilerinin işlenip işlenmediğini öğrenme, düzeltilmesini ya da silinmesini isteme gibi hakların vardır. Verilerini görme ve silme işlemlerini uygulamadan kendin yapabilirsin; diğer talepler için yukarıdaki iletişim adresine yazabilirsin.
