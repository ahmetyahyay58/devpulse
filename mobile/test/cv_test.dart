import 'package:devpulse/api/api_client.dart';
import 'package:devpulse/cv/cv_controller.dart';
import 'package:devpulse/cv/cv_formats.dart';
import 'package:devpulse/cv/cv_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_backend.dart';

Future<FakeBackend> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 5000);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  final backend = FakeBackend();
  final c = CvController(api: ApiClient(baseUrl: 'http://test', client: backend.client), onUnauthorized: () {})
    ..load();
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
}
