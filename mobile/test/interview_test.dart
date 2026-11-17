import 'package:devpulse/api/api_client.dart';
import 'package:devpulse/cv/cv_controller.dart';
import 'package:devpulse/cv/cv_profile.dart';
import 'package:devpulse/cv/cv_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_backend.dart';

void main() {
  testWidgets('Mülakat koçu: proje seçilince 3 soru, kaynak, kanıt önerileri ve giden veri', (tester) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final backend = FakeBackend();
    final c = CvController(api: ApiClient(baseUrl: 'http://test', client: backend.client), onUnauthorized: () {},
        store: MemoryCvProfileStore())
      ..load();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: CvView(controller: c, saveFile: (_, _) async {}))));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mülakat koçu'));
    await tester.pumpAndSettle();
    expect(find.textContaining('yalnız sayıları gider'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'proje-a'));
    await tester.pumpAndSettle();

    expect(backend.requests.last.url.path, '/ai/interview');
    expect(find.text('Soru 1 (proj:R_a)'), findsOneWidget); // CV kimliği gönderilir, proje adı değil
    expect(find.text('Soru 3'), findsOneWidget);
    expect(find.text('Kaynak: Şablon (Yapay zekâ yorumlarına onay vermedin.)'), findsOneWidget);
    expect(find.text('README ekle.'), findsOneWidget);

    await tester.tap(find.text('Yapay zekâya giden veri'));
    await tester.pumpAndSettle();
    expect(find.text('Commit sayısı'), findsOneWidget);
    expect(find.text('Eksik belgeler'), findsOneWidget);
    expect(find.text('yok'), findsOneWidget);
  });
}
