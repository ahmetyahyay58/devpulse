import 'package:devpulse/analysis/collaboration_view.dart';
import 'package:devpulse/api/api_client.dart';
import 'package:devpulse/overview/overview_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_backend.dart';

void main() {
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
