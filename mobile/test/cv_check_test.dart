import 'package:devpulse/api/api_client.dart';
import 'package:devpulse/cv/cv_check.dart';
import 'package:devpulse/cv/cv_controller.dart';
import 'package:devpulse/cv/cv_formats.dart';
import 'package:devpulse/cv/cv_profile.dart';
import 'package:devpulse/cv/cv_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_backend.dart';

Future<CvController> _controller({String lang = 'tr', CvProfileStore? store}) async {
  final c = CvController(api: ApiClient(baseUrl: 'http://test', client: FakeBackend().client), onUnauthorized: () {},
      store: store ?? MemoryCvProfileStore());
  await c.load();
  if (lang != 'tr') await c.setLang(lang);
  return c;
}

CvProfile _full() => CvProfile(
      fullName: 'Ayşe Kaya',
      email: 'ayse@example.com',
      phone: '0555',
      linkedin: 'linkedin.com/in/ayse',
      about: {'tr': 'Flutter ile mobil uygulama geliştiren, açık kaynağa katkı vermeyi seven bir öğrenciyim.'},
      interests: {'tr': 'satranç'},
      education: [Education(school: 'Harran Üniversitesi', dates: '2022 – 2026')],
      experience: [Experience(role: 'Stajyer', bullets: ['API yazdım.'])],
    );

List<String> _msgs(List<CvCheck> cs, CheckLevel l) => [for (final c in cs) if (c.level == l) c.message];

void main() {
  test('boş profil: ad, e-posta, Hakkımda, eğitim ve yer tutucu eksik; ötekiler öneri', () async {
    final c = await _controller();
    final cs = checkCv(draft: c.effective!, profile: CvProfile(), format: jakes);
    final missing = _msgs(cs, CheckLevel.missing);
    expect(missing, [
      'Ad soyad yazılmadı; başlıkta GitHub kullanıcı adı görünüyor.',
      'E-posta yok.',
      startsWith('Hakkımda: kendini tanıttığın metin yazılmadı (Türkçe CV)'),
      'Eğitim bilgisi yok.',
      'proje-a: doldurulmamış madde var ([…]); PDF\'e basılmaz.',
    ]);
    final tips = _msgs(cs, CheckLevel.suggestion);
    expect(tips, contains('Telefon yok.'));
    expect(tips, contains(contains('"Beceri odaklı" şablon')));
    expect(tips.where((m) => m.startsWith('İlgi alanları')), isEmpty); // Jake's bu bölümü göstermez
    expect(cs.first.level, CheckLevel.missing); // eksikler önce
  });

  test('dolu profil: yalnız doldurulmamış etki kalır', () async {
    final c = await _controller();
    final cs = checkCv(draft: c.effective!, profile: _full(), format: jakes, pages: 1);
    expect(_msgs(cs, CheckLevel.missing), ['proje-a: doldurulmamış madde var ([…]); PDF\'e basılmaz.']);
    expect(_msgs(cs, CheckLevel.suggestion), isEmpty);
  });

  test('sayfa sınırı formata göre: Jake\'s 1, Türkiye klasik 2', () async {
    final c = await _controller();
    String? pageMsg(CvFormat f, int pages) => [
          for (final x in checkCv(draft: c.effective!, profile: _full(), format: f, pages: pages))
            if (x.message.startsWith('PDF')) x.message,
        ].firstOrNull;
    expect(pageMsg(jakes, 2), "PDF 2 sayfa; Jake's için önerilen en çok 1 sayfa. Proje ya da madde sayısını azalt.");
    expect(pageMsg(turkish, 2), isNull);
    expect(pageMsg(turkish, 3), isNotNull);
  });

  test('ilgi alanları ve Beceri odaklı şablon önerisi formata göre', () async {
    final c = await _controller();
    final p = _full()
      ..interests = {}
      ..experience = [];
    final tr = _msgs(checkCv(draft: c.effective!, profile: p, format: turkish), CheckLevel.suggestion);
    expect(tr, contains('İlgi alanları boş (Türkçe CV).'));
    final sf = _msgs(checkCv(draft: c.effective!, profile: p, format: skillsFirst), CheckLevel.suggestion);
    expect(sf, contains('Deneyim yok: staj, gönüllülük ya da kulüp işi varsa ekle.')); // zaten o şablonda
  });

  test('İngilizce CV: Türkçe Hakkımda yetmez; kısa metin ve uzun madde öneri', () async {
    final c = await _controller(lang: 'en');
    final p = _full()
      ..experience = [Experience(role: 'Intern', bullets: ['x' * 250])];
    final cs = checkCv(draft: c.effective!, profile: p, format: harvard);
    expect(_msgs(cs, CheckLevel.missing), contains(startsWith('Hakkımda: kendini tanıttığın metin yazılmadı (İngilizce CV)')));
    expect(_msgs(cs, CheckLevel.suggestion), contains(contains('200 karakteri aşan madde')));
    p.about['en'] = 'Short.';
    expect(_msgs(checkCv(draft: c.effective!, profile: p, format: harvard), CheckLevel.suggestion),
        contains('Hakkımda çok kısa (6 karakter); 2-4 cümle önerilir.'));
  });

  testWidgets('CV sekmesi: düğmede eksik sayısı; ekranda sayfa, ATS uyarısı ve Düzelt', (tester) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final c = CvController(api: ApiClient(baseUrl: 'http://test', client: FakeBackend().client), onUnauthorized: () {},
        store: MemoryCvProfileStore())
      ..load();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: CvView(controller: c, saveFile: (_, _) async {}, countPages: (_) async => 2)),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Biçim kontrolü (5 eksik)'));
    await tester.pumpAndSettle();
    expect(find.text('6 eksik, 3 öneri'), findsOneWidget); // + sayfa kuralı (2 > 1)
    expect(find.text('PDF: 2 sayfa (bu format için önerilen en çok 1).'), findsOneWidget);
    expect(find.textContaining('garanti etmez'), findsOneWidget);
    expect(find.text('Eksik'), findsNWidgets(6)); // düzey yazıyla da söylenir

    await tester.tap(find.widgetWithText(TextButton, 'Düzelt').at(1)); // ad soyad
    await tester.pumpAndSettle();
    expect(find.text('Bilgilerim'), findsOneWidget);
  });
}
