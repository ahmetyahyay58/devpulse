import 'package:devpulse/analysis/collaboration_view.dart';
import 'package:devpulse/api/api_client.dart';
import 'package:devpulse/overview/overview_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_backend.dart';

Future<void> _pump(WidgetTester tester, {double width = 1080, double textScale = 1}) async {
  tester.view.physicalSize = Size(width, 5000);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  final controller = OverviewController(
    api: ApiClient(baseUrl: 'http://test', client: FakeBackend().client),
    onUnauthorized: () {},
  );
  await controller.load();
  await tester.pumpWidget(MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(body: CollaborationView(controller: controller)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('aylık merge süresi: 12 çubuk, grup adı, boş ay "merge yok"', (tester) async {
    await _pump(tester);
    expect(find.text('Aylık merge süresi (medyan)'), findsOneWidget);
    expect(find.textContaining("başkalarının repolarına açtığın PR'lar"), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is Tooltip && (w.message ?? '').contains('merge yok')), findsNWidgets(10));
    expect(find.byTooltip('Ağu 2026 · 3 PR · medyan 2,5 gün'), findsOneWidget);
    expect(find.text('bu ay'), findsOneWidget);
  });

  testWidgets('katkı dengesi: commit ve PR sayıları yazıyla, lejant var', (tester) async {
    await _pump(tester);
    expect(find.text('Katkı dengesi'), findsOneWidget);
    expect(find.text('Commit: kendi 30 · başkası 3 (başkası %9)'), findsOneWidget);
    expect(find.text('PR: kendi 5 · başkası 7 (başkası %58)'), findsOneWidget);
    expect(find.text('Başkalarının repoları'), findsOneWidget);
  });

  testWidgets('İşbirliği dar ekran ve büyük yazıda taşmaz', (tester) async {
    await _pump(tester, width: 900, textScale: 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('İşbirliği: özet, kendi/başkası tablosu ve yıllar', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final controller = OverviewController(
      api: ApiClient(baseUrl: 'http://test', client: FakeBackend().client),
      onUnauthorized: () {},
    );
    await controller.load();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: CollaborationView(controller: controller))));
    await tester.pumpAndSettle();

    expect(find.text('İşbirliği'), findsOneWidget);
    expect(find.textContaining('merge edilen: 4 (oran %67)'), findsOneWidget);
    expect(find.text('Başkasının reposu'), findsOneWidget);
    expect(find.text('%67'), findsOneWidget); // başkası
    expect(find.text('%100'), findsOneWidget); // kendi repon (şişkin oran ayrı gösterilir)
    expect(find.text('2,5 gün'), findsOneWidget); // 60 saat
    expect(find.text('2 saat'), findsOneWidget);
    expect(find.text('18'), findsOneWidget); // toplam inceleme
    expect(find.textContaining('Bu yıl 11 kod incelemesi'), findsOneWidget);
  });

  test('süre ve oran biçimi', () {
    expect(CollaborationView.duration(null), '-');
    expect(CollaborationView.duration(47.4), '47 saat');
    expect(CollaborationView.duration(72), '3,0 gün');
    expect(CollaborationView.rate(0.6666), '%67');
    expect(CollaborationView.rate(null), '-');
  });
}
