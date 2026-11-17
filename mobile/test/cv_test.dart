import 'dart:typed_data';

import 'package:devpulse/api/api_client.dart';
import 'package:devpulse/cv/cv_controller.dart';
import 'package:devpulse/cv/cv_formats.dart';
import 'package:devpulse/cv/cv_pdf.dart';
import 'package:devpulse/cv/cv_profile.dart';
import 'package:devpulse/cv/cv_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart' show TtfParser;

import 'fake_backend.dart';

CvProfile _sample() => CvProfile(
      fullName: 'Ahmet Yılmaz',
      email: 'ahmet@example.com',
      phone: '0555 000 00 00',
      location: 'Şanlıurfa',
      education: [
        Education(school: 'Harran Üniversitesi', degree: 'Bilgisayar Mühendisliği, Lisans', dates: 'Eyl 2022 – Haz 2026'),
      ],
      experience: [
        Experience(role: 'Stajyer Geliştirici', org: 'Örnek A.Ş.', dates: 'Tem 2025 – Ağu 2025', bullets: ['API yazdım.']),
      ],
      languages: [SpokenLanguage(name: 'Türkçe', level: 'Anadil'), SpokenLanguage(name: 'İngilizce', level: 'B2')],
      certificates: [Certificate(name: 'Python ile Veri Bilimi', issuer: 'BTK Akademi', date: 'Mar 2025')],
      about: {'tr': 'Flutter ile mobil uygulama geliştiren bir öğrenciyim.'},
      interests: {'tr': 'satranç, açık kaynak'},
    );

Future<FakeBackend> _pump(WidgetTester tester,
    {CvProfile? profile, MemoryCvProfileStore? store, List<(Uint8List, String)>? saved}) async {
  tester.view.physicalSize = const Size(1080, 5000);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  final backend = FakeBackend();
  store ??= MemoryCvProfileStore();
  if (profile != null) await store.write(profile);
  final c = CvController(
    api: ApiClient(baseUrl: 'http://test', client: backend.client),
    onUnauthorized: () {},
    store: store,
  )..load();
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: CvView(controller: c, saveFile: (bytes, name) async => saved?.add((bytes, name))),
    ),
  ));
  await tester.pumpAndSettle();
  return backend;
}

void main() {
  testWidgets("Jake's: büyük harf başlıklar, 'Ad | teknolojiler' satırı, sağda tarih, veri özeti", (tester) async {
    await _pump(tester);
    expect(find.text('PROJELER'), findsOneWidget);
    expect(find.text('TEKNİK BECERİLER'), findsOneWidget);
    expect(find.text('proje-a | Dart, Docker', findRichText: true), findsOneWidget);
    expect(find.text('Mar 2025 – Şub 2026'), findsOneWidget);
    expect(find.textContaining('Dart ile geliştirildi'), findsNothing); // teknoloji başlıkta, tekrar yok
    expect(find.text('HAKKIMDA'), findsOneWidget); // Hakkımda yazılmadıysa veri özeti görünür
    expect(find.text('Ağırlıklı olarak Dart ile çalışıyorum.'), findsOneWidget);
    expect(find.text('EĞİTİM'), findsNothing); // kullanıcı girmediyse boş bölüm görünmez
  });

  testWidgets('Harvard: teknoloji maddesi gövdede, serif yazı tipi', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Harvard'));
    await tester.pumpAndSettle();
    expect(find.text('BECERİLER'), findsOneWidget);
    expect(find.text('•  Dart ile geliştirildi; araçlar: Docker.'), findsOneWidget);
    final style = DefaultTextStyle.of(tester.element(find.text('proje-a'))).style;
    expect(style.fontFamily, 'NotoSerif');
  });

  testWidgets('Europass: özet "Hakkımda"da, etkinlik "Ek bilgiler"de, uyarlama notu', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Europass'));
    await tester.pumpAndSettle();
    expect(find.text('Kişisel bilgiler'), findsOneWidget);
    expect(find.text('Hakkımda'), findsOneWidget);
    expect(find.text('Ağırlıklı olarak Dart ile çalışıyorum.'), findsOneWidget);
    expect(find.text('Ek bilgiler'), findsOneWidget);
    expect(find.textContaining('tek sütun uyarlama'), findsOneWidget); // resmî form değil, söylenir
  });

  testWidgets('kaynaklar isteğe bağlı; yer tutucu sayfada', (tester) async {
    await _pump(tester);
    expect(find.text('GitHub repo açıklaması'), findsNothing);
    await tester.tap(find.text('Maddelerin kaynağını göster'));
    await tester.pumpAndSettle();
    expect(find.text('GitHub repo açıklaması'), findsWidgets); // iki seçili projenin açıklaması
    expect(find.text('•  Etki: [ör. kullanıcı sayısı]'), findsOneWidget);
  });

  testWidgets('English seçilince taslak İngilizce istenir', (tester) async {
    final backend = await _pump(tester);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(backend.requests.last.url.queryParameters['lang'], 'en');
    expect(find.text('PROJECTS'), findsOneWidget);
    expect(find.text('Mar 2025 – Feb 2026'), findsOneWidget);
  });

  test('Türkçe büyük harf', () {
    expect(upper('Teknik beceriler', 'tr'), 'TEKNİK BECERİLER');
    expect(upper('Kişisel bilgiler', 'tr'), 'KİŞİSEL BİLGİLER');
    expect(upper('Technical Skills', 'en'), 'TECHNICAL SKILLS');
  });

  test('tarih aralığı: bilinmiyorsa boş, aynı ay tek', () {
    expect(dateRange(null, null, 'tr'), '');
    expect(dateRange(DateTime(2026, 2, 1), DateTime(2026, 2, 20), 'tr'), 'Şub 2026');
    expect(dateRange(DateTime(2025, 12, 1), DateTime(2026, 1, 3), 'en'), 'Dec 2025 – Jan 2026');
  });

  testWidgets('boş profilde eğitim/deneyim bölümü yok; düğme neyin eksik olduğunu söyler', (tester) async {
    await _pump(tester);
    expect(find.text('Bilgilerim: ad, iletişim, hakkımda, eğitim, deneyim ekle'), findsOneWidget);
    expect(find.text('EĞİTİM'), findsNothing);
    expect(find.text('ben'), findsOneWidget); // ad yoksa GitHub kullanıcı adı
  });

  testWidgets("Jake's: ad, iletişim satırı, eğitim ve deneyim", (tester) async {
    await _pump(tester, profile: _sample());
    expect(find.text('Ahmet Yılmaz'), findsOneWidget);
    expect(find.text('0555 000 00 00  |  ahmet@example.com  |  Şanlıurfa  |  github.com/ben'), findsOneWidget);
    expect(find.text('EĞİTİM'), findsOneWidget);
    expect(find.text('DENEYİM'), findsOneWidget);
    expect(find.text('Harran Üniversitesi'), findsOneWidget);
    expect(find.text('Eyl 2022 – Haz 2026'), findsOneWidget);
    expect(find.text('Stajyer Geliştirici'), findsOneWidget); // Jake's: pozisyon üstte
    expect(find.text('•  API yazdım.'), findsOneWidget);
    expect(find.text('Bilgilerimi düzenle'), findsOneWidget);
  });

  testWidgets('Harvard: kurum üstte, konuşulan diller becerilerde', (tester) async {
    await _pump(tester, profile: _sample());
    await tester.tap(find.text('Harvard'));
    await tester.pumpAndSettle();
    final org = tester.getTopLeft(find.text('Örnek A.Ş.'));
    final role = tester.getTopLeft(find.text('Stajyer Geliştirici'));
    expect(org.dy < role.dy, isTrue);
    expect(find.text('Yabancı dil ve anadil: Türkçe (Anadil), İngilizce (B2)', findRichText: true), findsOneWidget);
  });

  testWidgets('Europass: kişisel bilgiler ve dil becerileri bölümü; İngilizcede Native', (tester) async {
    await _pump(tester, profile: _sample());
    await tester.tap(find.text('Europass'));
    await tester.pumpAndSettle();
    expect(find.text('E-posta: ahmet@example.com', findRichText: true), findsOneWidget);
    expect(find.text('Dil becerileri'), findsOneWidget);
    expect(find.text('İngilizce: B2', findRichText: true), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Türkçe: Native', findRichText: true), findsOneWidget);
  });

  Future<void> openProfile(WidgetTester tester) async {
    await tester.tap(find.text('Bilgilerim: ad, iletişim, hakkımda, eğitim, deneyim ekle'));
    await tester.pumpAndSettle();
  }

  // Formun sonundaki Kaydet düğmesi (üst çubukta da aynısı var).
  Finder saveButton() => find.widgetWithText(FilledButton, 'Kaydet').last;

  testWidgets('Bilgilerim: Kaydet ile cihaza yazılır, başarı mesajı çıkar, sayfa güncellenir', (tester) async {
    final store = MemoryCvProfileStore();
    await _pump(tester, store: store);
    await openProfile(tester);
    expect(find.widgetWithText(FilledButton, 'Kaydedildi'), findsWidgets); // değişiklik yokken pasif

    await tester.enterText(find.widgetWithText(TextFormField, 'Ad soyad'), 'Ayşe Kaya');
    await tester.tap(find.widgetWithText(TextButton, 'Ekle').first); // Eğitim
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Okul'), 'Harran Üniversitesi');
    await tester.tap(find.widgetWithText(FilledButton, 'Kaydet').last); // penceredeki Kaydet
    await tester.pumpAndSettle();
    expect(store.saved, isNull); // "Kaydet"e basılmadan cihaza yazılmaz

    await tester.tap(saveButton());
    await tester.pump();
    expect(find.text('Bilgilerin kaydedildi.'), findsOneWidget);
    expect(store.saved!.fullName, 'Ayşe Kaya');
    expect(store.saved!.education.single.school, 'Harran Üniversitesi');

    await tester.pumpAndSettle(const Duration(seconds: 5)); // mesaj kapansın
    await tester.pageBack(); // kaydedildiği için soru sorulmadan döner
    await tester.pumpAndSettle();
    expect(find.text('Ayşe Kaya'), findsOneWidget);
    expect(find.text('EĞİTİM'), findsOneWidget);
  });

  testWidgets('kaydetmeden çıkılırsa sorulur; "Kaydetmeden çık" değişikliği atar', (tester) async {
    final store = MemoryCvProfileStore();
    await _pump(tester, store: store);
    await openProfile(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Ad soyad'), 'Geçici Ad');
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Kaydedilmemiş değişiklikler var'), findsOneWidget);

    await tester.tap(find.text('Kaydetmeden çık'));
    await tester.pumpAndSettle();
    expect(store.saved, isNull);
    expect(find.text('Geçici Ad'), findsNothing);
    expect(find.text('ben'), findsOneWidget); // sayfa eski haliyle
  });

  testWidgets('"Kaydet ve çık" kaydedip döner', (tester) async {
    final store = MemoryCvProfileStore();
    await _pump(tester, store: store);
    await openProfile(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Ad soyad'), 'Kalıcı Ad');
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaydet ve çık'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(store.saved!.fullName, 'Kalıcı Ad');
    expect(find.text('Kalıcı Ad'), findsOneWidget);
  });

  testWidgets('kayıt başarısızsa hata mesajı, sayfa değişmez', (tester) async {
    await _pump(tester, store: _FailingStore());
    await openProfile(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Ad soyad'), 'Yazılamayan');
    await tester.pump();
    await tester.tap(saveButton());
    await tester.pump();
    expect(find.text('Kaydedilemedi. Lütfen tekrar dene.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Kaydet'), findsWidgets); // hâlâ kaydedilmemiş
  });

  test('profil JSON gidiş-dönüşü kimlikleri ve yeni bölümleri korur', () {
    final p = _sample();
    final back = CvProfile.fromJson(p.toJson());
    expect(back.education.single.id, p.education.single.id);
    expect(back.languages.last.level, 'B2');
    expect(back.certificates.single.issuer, 'BTK Akademi');
    expect(back.aboutFor('tr'), startsWith('Flutter ile'));
    expect(back.aboutFor('en'), '');
    expect(back.interestsFor('tr'), 'satranç, açık kaynak');
    expect(CvProfile().isEmpty, isTrue);
    expect(CvProfile(about: {'tr': 'x'}).isEmpty, isFalse);
    // Eski kayıt (yeni alanlar yok) sorunsuz okunur.
    expect(CvProfile.fromJson({'fullName': 'A'}).certificates, isEmpty);
  });

  test('beş format; ilgi alanları yalnız Türkiye klasik ve Europass\'ta', () {
    expect(cvFormats.map((f) => f.id), ['jakes', 'harvard', 'europass', 'turkiye', 'beceri']);
    for (final f in cvFormats) {
      expect(f.sections, contains(CvSection.about), reason: f.id);
      expect(f.sections, contains(CvSection.certificates), reason: f.id);
      expect(f.sections.contains(CvSection.interests), f.id == 'turkiye' || f.id == 'europass', reason: f.id);
    }
    final s = skillsFirst.sections;
    expect(s.indexOf(CvSection.skills), lessThan(s.indexOf(CvSection.experience))); // beceriler önde
  });

  testWidgets('Türkiye klasik: şeritli başlıklar, sertifika, yabancı dil, ilgi alanları', (tester) async {
    await _pump(tester, profile: _sample());
    await tester.tap(find.text('Türkiye klasik'));
    await tester.pumpAndSettle();
    expect(find.text('Ahmet Yılmaz'), findsOneWidget);
    expect(find.text('0555 000 00 00  ·  ahmet@example.com  ·  Şanlıurfa  ·  github.com/ben'), findsOneWidget);
    expect(find.text('İŞ DENEYİMİ'), findsOneWidget);
    expect(find.text('SERTİFİKALAR VE KURSLAR'), findsOneWidget);
    expect(find.text('Python ile Veri Bilimi'), findsOneWidget);
    expect(find.text('BTK Akademi'), findsOneWidget);
    expect(find.text('YABANCI DİLLER'), findsOneWidget);
    expect(find.text('BİLGİSAYAR BİLGİSİ'), findsOneWidget);
    expect(find.text('İLGİ ALANLARI'), findsOneWidget);
    expect(find.text('satranç, açık kaynak'), findsOneWidget);
    // Kullanıcının Hakkımda metni veri özetinin yerine geçer.
    expect(find.textContaining('Flutter ile mobil'), findsOneWidget);
    expect(find.textContaining('Ağırlıklı olarak'), findsNothing);
  });

  testWidgets('Beceri odaklı: beceriler projelerden önce; ilgi alanı yok; İngilizce Hakkımda ayrı', (tester) async {
    await _pump(tester, profile: _sample());
    await tester.tap(find.text('Beceri odaklı'));
    await tester.pumpAndSettle();
    final skills = tester.getTopLeft(find.text('TEKNİK BECERİLER')).dy;
    final projects = tester.getTopLeft(find.text('ÖNE ÇIKAN PROJELER')).dy;
    expect(skills, lessThan(projects));
    expect(find.text('satranç, açık kaynak'), findsNothing);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('ABOUT ME'), findsOneWidget);
    expect(find.textContaining('Flutter ile mobil'), findsNothing); // Türkçe metin İngilizce CV'ye geçmez
  });

  testWidgets('Bilgilerim: "Taslaktan başla" veri özetini Hakkımda kutusuna koyar; sertifika eklenir', (tester) async {
    final store = MemoryCvProfileStore();
    await _pump(tester, store: store);
    await openProfile(tester);
    await tester.tap(find.text('Taslaktan başla (GitHub özet cümlesi)'));
    await tester.pump();
    expect(find.widgetWithText(TextField, 'Ağırlıklı olarak Dart ile çalışıyorum.'), findsOneWidget);

    final add = find.widgetWithText(TextButton, 'Ekle').at(2); // Eğitim, Deneyim, Sertifikalar
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Ad'), 'Git ve GitHub');
    await tester.enterText(find.widgetWithText(TextField, 'Veren kurum'), 'BTK Akademi');
    await tester.tap(find.widgetWithText(FilledButton, 'Kaydet').last);
    await tester.pumpAndSettle();

    await tester.tap(saveButton());
    await tester.pump();
    expect(store.saved!.aboutFor('tr'), 'Ağırlıklı olarak Dart ile çalışıyorum.');
    expect(store.saved!.certificates.single.name, 'Git ve GitHub');
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  test('gömülü yazı tipleri Türkçe harfleri içerir', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final f in ['NotoSans-Regular', 'NotoSans-Bold', 'NotoSans-Italic', 'NotoSerif-Regular', 'NotoSerif-Bold', 'NotoSerif-Italic']) {
      final font = TtfParser(await rootBundle.load('assets/fonts/$f.ttf'));
      for (final ch in 'şŞğĞıİöÖüÜçÇ'.runes) {
        expect(font.charToGlyphIndexMap.containsKey(ch), isTrue, reason: '$f: ${String.fromCharCode(ch)}');
      }
    }
  });

  test('PDF: geçerli dosya; doldurulmamış yer tutucu basılmaz ve sayılır', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final backend = FakeBackend();
    final c = CvController(api: ApiClient(baseUrl: 'http://test', client: backend.client), onUnauthorized: () {},
        store: MemoryCvProfileStore());
    await c.load();
    for (final f in cvFormats) {
      final r = await buildCvPdf(draft: c.draft!, format: f, profile: _sample());
      expect(String.fromCharCodes(r.bytes.take(5)), '%PDF-');
      expect(r.skippedPlaceholders, 1); // sahte taslakta tek "Etki: [...]" var
    }
  });

  test('PDF dosya adı Türkçe harfleri sadeleştirir', () {
    expect(cvFileName('Ayşe Kaya', harvard, 'en'), 'cv-ayse-kaya-harvard-en.pdf');
    expect(cvFileName('İlkay Öztürk', jakes, 'tr'), 'cv-ilkay-ozturk-jakes-tr.pdf');
    expect(cvFileName('', europass, 'tr'), 'cv-devpulse-europass-tr.pdf');
  });

  testWidgets('"PDF olarak indir": dosya verilir, sonuç mesajı çıkar', (tester) async {
    final saved = <(Uint8List, String)>[];
    await _pump(tester, profile: _sample(), saved: saved);
    await tester.runAsync(() async {
      await tester.tap(find.text('PDF olarak indir'));
      // PDF üretimi gerçek zamanlı iş: bitene kadar bekle.
      for (var i = 0; i < 100 && saved.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    await tester.pump();
    expect(saved.single.$2, 'cv-ahmet-yilmaz-jakes-tr.pdf');
    expect(String.fromCharCodes(saved.single.$1.take(5)), '%PDF-');
    expect(find.text('PDF hazır: cv-ahmet-yilmaz-jakes-tr.pdf. Doldurulmamış 1 etki cümlesi dosyaya eklenmedi.'),
        findsOneWidget);
  });
}

class _FailingStore extends MemoryCvProfileStore {
  @override
  Future<void> write(CvProfile p) async => throw Exception('depo dolu');
}
