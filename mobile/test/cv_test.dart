import 'package:devpulse/api/api_client.dart';
import 'package:devpulse/cv/cv_controller.dart';
import 'package:devpulse/cv/cv_formats.dart';
import 'package:devpulse/cv/cv_profile.dart';
import 'package:devpulse/cv/cv_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
    );

Future<FakeBackend> _pump(WidgetTester tester, {CvProfile? profile, MemoryCvProfileStore? store}) async {
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
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: CvView(controller: c))));
  await tester.pumpAndSettle();
  return backend;
}

void main() {
  testWidgets("Jake's: büyük harf başlıklar, 'Ad | teknolojiler' satırı, sağda tarih, özet yok", (tester) async {
    await _pump(tester);
    expect(find.text('PROJELER'), findsOneWidget);
    expect(find.text('TEKNİK BECERİLER'), findsOneWidget);
    expect(find.text('proje-a | Dart, Docker', findRichText: true), findsOneWidget);
    expect(find.text('Mar 2025 – Şub 2026'), findsOneWidget);
    expect(find.textContaining('Dart ile geliştirildi'), findsNothing); // teknoloji başlıkta, tekrar yok
    expect(find.textContaining('Ağırlıklı olarak'), findsNothing); // Jake's'te özet yok
    expect(find.text('EĞİTİM'), findsNothing); // kullanıcı girmediyse boş bölüm görünmez
  });

  testWidgets('Harvard: teknoloji maddesi gövdede, serif yazı tipi', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Harvard'));
    await tester.pumpAndSettle();
    expect(find.text('BECERİLER'), findsOneWidget);
    expect(find.text('•  Dart ile geliştirildi; araçlar: Docker.'), findsOneWidget);
    final style = DefaultTextStyle.of(tester.element(find.text('proje-a'))).style;
    expect(style.fontFamily, 'serif');
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
    expect(find.text('GitHub repo açıklaması'), findsOneWidget);
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
    expect(find.text('Bilgilerim: ad, iletişim, eğitim, deneyim ekle'), findsOneWidget);
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

  testWidgets('Bilgilerim: eğitim eklenir, cihaza kaydedilir ve sayfada görünür', (tester) async {
    final store = MemoryCvProfileStore();
    await _pump(tester, store: store);
    await tester.tap(find.text('Bilgilerim: ad, iletişim, eğitim, deneyim ekle'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Ad soyad'), 'Ayşe Kaya');
    await tester.tap(find.widgetWithText(TextButton, 'Ekle').first); // Eğitim
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Okul'), 'Harran Üniversitesi');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(store.saved!.fullName, 'Ayşe Kaya');
    expect(store.saved!.education.single.school, 'Harran Üniversitesi');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Ayşe Kaya'), findsOneWidget);
    expect(find.text('EĞİTİM'), findsOneWidget);
  });

  test('profil JSON gidiş-dönüşü kimlikleri korur', () {
    final p = _sample();
    final back = CvProfile.fromJson(p.toJson());
    expect(back.education.single.id, p.education.single.id);
    expect(back.languages.last.level, 'B2');
    expect(CvProfile().isEmpty, isTrue);
  });
}
