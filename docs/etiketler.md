# Commit türü etiketleri

Commit sınıflandırma (projedeki tek gözetimli ML bileşeni) için elle etiketleme kılavuzu.
Etiketlemeden önce okunur; kararsız kalınan her mesajda buraya dönülür. Tanım değişirse
o ana kadar etiketlenenler yeniden gözden geçirilir.

## Kategoriler

| Etiket | Ne zaman | Örnekler |
|---|---|---|
| `feat` | Kullanıcının fark edeceği yeni davranış/yetenek eklenir. | "Add dark mode", "arama özelliği eklendi", "Support Python 3.13" |
| `fix` | Yanlış çalışan bir şey düzeltilir (hata, çökme, yanlış çıktı). | "Fix crash on empty input", "tarih biçimi hatası düzeltildi" |
| `docs` | Yalnızca belge: README, yorum, docstring, kılavuz. | "Update README.md", "Fix typo in docs", "README" |
| `refactor` | Davranış değişmeden kod düzenlenir; biçim (style) ve performans iyileştirmesi de buraya. | "Extract service layer", "Rename variables", "Speed up parser" |
| `test` | Yalnızca test eklenir/düzenlenir. | "Add unit tests for parser", "Fix flaky test" |
| `chore` | Kodun davranışına dokunmayan bakım: bağımlılık, derleme, CI, sürüm, .gitignore, dosya silme/taşıma. | "Bump requests to 2.32", "Update CI", "Delete flutter_01.png", "Release 1.2.0" |
| `diger` | Mesajdan tür anlaşılamıyor ya da birden fazla türe eşit ağırlıkta giriyor. | "wip", "changes", "Merge branch 'dev'", "asdf" |

**Uygulamada gösterim:** Etiketleme 7 ince sınıfla yapılır; uygulama `refactor` ve `chore`
sınıflarını tek sınıfta birleştirip **"Bakım ve düzenleme"** olarak gösterir (bu ikisi insanlar
arasında da en sık karışan çiftti; bkz. `docs/olcumler.md` → "Sınıf sadeleştirme"). Uygulamadaki
6 sınıf: Yeni özellik, Hata düzeltme, Belgelendirme, Bakım ve düzenleme, Test, Belirsiz.

## Karar kuralları (kararsız kalınca)

1. **Mesaja göre etiketle, koda göre değil.** Kodu görmüyoruz; model de yalnızca mesajı görecek.
2. **Önek varsa (feat:, fix: ...) ama içerik çelişiyorsa içeriği esas al.** "chore: fix login bug" -> `fix`.
3. **"Fix typo"**: belgede ya da yorumda ise `docs`, kullanıcıya görünen metinde (arayüz yazısı) ise `fix`. Anlaşılmıyorsa `docs`.
4. **Test düzeltmesi** ("Fix failing test") -> `test` (asıl kod değil, test değişiyor).
5. **Bağımlılık güncellemesi** bir güvenlik açığını kapatsa da -> `chore` (mesaj bağımlılığı anlatıyor).
6. **GitHub web arayüzü mesajları**: "Create X" / "Add files via upload" -> X bir belge ise `docs`, kod dosyası ise `feat`, anlaşılmıyorsa `diger`. "Update X.md" -> `docs`. "Delete X" -> `chore`.
7. **Birden fazla iş** ("Add login and fix header"): ilk ve ana işi seç (`feat`). Eşitse `diger`.
8. **Geri alma** ("Revert ...") -> `diger` (geri alınan işin türü mesajdan genelde anlaşılmaz).
9. Etiket "en iyi tahmin"dir; emin değilsen `diger` seç ve etiketleme aracındaki not alanına kısa gerekçe yaz.

## Veri kaynakları ve gizlilik

- **Eğitim/ana test:** Herkese açık açık kaynak projelerin varsayılan dalındaki commit mesajları
  (`backend/ml/data/pool.jsonl`). Projeler farklı mesaj alışkanlıklarını kapsayacak şekilde seçildi
  (bkz. `backend/ml/collect.py`).
- **Saklanmayan:** yazar adı, e-posta, kullanıcı adı. GraphQL sorgusu yazar alanlarını hiç
  istemez. Mesajlardaki `Signed-off-by:`, `Co-authored-by:` gibi imza satırları ve e-posta içeren
  satırların tamamı silinir (otomatik "roll" commit'lerinde e-postanın yanında ad da durur);
  `@kullanıcı` bahisleri `@kullanici` olarak maskelenir.
- **Bilinen sınırlama:** Serbest metin içinde geçen bir kişi adı ("Thanks to ...") otomatik
  yakalanamaz. Etiketlerken görülürse not alanına yazılır ve havuzdan elle çıkarılır.
- **Alan dışı test:** Geliştiricinin kendi commit mesajları (Türkçe ve karışık); açık kaynak
  verisi neredeyse tamamen İngilizce olduğu için modelin bu veriye genellenmesi ayrıca ölçülür.
- Açık kaynak mesajlarının araştırmada kullanımı danışmana bildirilecektir.
