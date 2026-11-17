import 'package:devpulse/api/api_client.dart';
import 'package:devpulse/year/year_summary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_backend.dart';

Future<FakeBackend> _open(WidgetTester tester, {Map<String, dynamic>? override}) async {
  final backend = FakeBackend();
  if (override != null) backend.yearSummary = {...backend.yearSummary, ...override};
  await tester.pumpWidget(MaterialApp(
    home: YearSummaryScreen(
      api: ApiClient(baseUrl: 'http://test', client: backend.client),
      slideDuration: const Duration(seconds: 1),
    ),
  ));
  await tester.pump(); // yükleme
  await tester.pump(const Duration(milliseconds: 500)); // geçiş animasyonu
  return backend;
}

void main() {
  test('slaytlar: veriden, kaynaklı; inceleme 0 ise ve tek dil varsa ilgili slayt yok', () {
    final s = YearSummary(FakeBackend().yearSummary);
    final slides = buildSlides(s);
    expect(slides.map((x) => x.title), [
      '2026 yılında', 'En yoğun ay', 'En çok çalıştığın dil', 'Gece kuşu', 'En uzun seri',
      'Kodlama süresi (tahmin)', 'Dil yolculuğun', 'Kod incelemesi', '2026 böyle geçti',
    ]);
    expect(slides[3].value, 'Gece payı: %25'); // sayıdan sonra ek yok
    expect(slides[5].value, 'en az 18 saat');
    expect(slides[6].value, 'Python → Dart');
    final fewer = buildSlides(YearSummary({
      ...FakeBackend().yearSummary,
      'reviews': 0,
      'language_journey': [{'language': 'Dart', 'first_month': 3, 'commits': 72}],
    }));
    expect(fewer.map((x) => x.title), isNot(contains('Kod incelemesi')));
    expect(fewer.map((x) => x.title), isNot(contains('Dil yolculuğun')));
  });

  testWidgets('kendiliğinden ilerler, dokununca geri/ileri; son slaytta durur', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await _open(tester);
    expect(find.text('120 commit'), findsOneWidget);
    expect(find.textContaining('1 Ocak – 14 Kasım 2026'), findsOneWidget); // dönem yazılı

    await tester.pump(const Duration(seconds: 1)); // süre doldu
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Mart'), findsOneWidget);

    await tester.tapAt(const Offset(30, 400)); // sol: geri
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('120 commit'), findsOneWidget);

    for (var i = 0; i < 30; i++) { // her slayt: saat başlar + süre dolar
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Rozet: 2 / 8'), findsOneWidget); // son slaytta kaldı
    expect(find.text('Kapat'), findsOneWidget);
  });

  testWidgets('yetersiz veride tek kart', (tester) async {
    await _open(tester, override: {'sufficiency': 'yetersiz', 'commits': 4});
    expect(find.text('Yeterli veri yok'), findsOneWidget);
    expect(find.textContaining('4 commit var'), findsOneWidget);
  });
}
