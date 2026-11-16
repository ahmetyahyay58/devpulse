import 'package:devpulse/api/api_client.dart';
import 'package:devpulse/cv/cv_controller.dart';
import 'package:devpulse/cv/cv_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_backend.dart';

Future<FakeBackend> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 4000);
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
  testWidgets('CV taslağı: bölümler, kaynaklar ve sarı yer tutucu', (tester) async {
    await _pump(tester);
    expect(find.text('ben'), findsOneWidget);
    expect(find.text('Projeler'), findsOneWidget);
    expect(find.text('proje-a'), findsOneWidget);
    expect(find.text('GitHub repo açıklaması'), findsOneWidget); // madde kaynağını söyler
    expect(find.text('Doldurulacak'), findsOneWidget); // yer tutucu etiketli (yalnız renk değil)
    expect(find.text('• Etki: [ör. kullanıcı sayısı]'), findsOneWidget);
  });

  testWidgets('English seçilince taslak İngilizce istenir', (tester) async {
    final backend = await _pump(tester);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(backend.requests.last.url.queryParameters['lang'], 'en');
    expect(find.text('Projects'), findsOneWidget);
    expect(find.text('Mostly working with Dart.'), findsOneWidget);
    expect(find.text('To fill in'), findsOneWidget); // rozet de CV'nin dilinde
    expect(find.text('Doldurulacak'), findsNothing);
  });
}
