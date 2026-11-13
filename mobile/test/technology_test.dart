import 'package:devpulse/api/api_client.dart';
import 'package:devpulse/api/health_api.dart';
import 'package:devpulse/auth/session_store.dart';
import 'package:devpulse/overview/charts.dart';
import 'package:devpulse/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_backend.dart';

Future<void> _openTechnology(WidgetTester tester, FakeBackend backend) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: HomeScreen(
      session: const Session(sessionToken: 'jwt', githubToken: 'gho', userId: 1, login: 'ben'),
      api: ApiClient(baseUrl: 'http://test', client: backend.client),
      healthApi: HealthApi(baseUrl: 'http://test', client: backend.client),
      onLogout: () {},
      timezone: () async => 'Europe/Istanbul',
      pollInterval: Duration.zero,
      syncStepDuration: Duration.zero,
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Analiz'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Teknoloji'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Teknoloji: dil sayısı, baskın dil, dağılım, çeşitlilik, araçlar', (tester) async {
    await _openTechnology(tester, FakeBackend());
    expect(find.text('Baskın dil · %80'), findsOneWidget);
    expect(find.text('Python'), findsNWidgets(2)); // kutucuk + dağılım satırı
    expect(find.text('%80 · 2 repo'), findsOneWidget);
    expect(find.text('%10 · 1 repo'), findsOneWidget);
    expect(find.text('%<1 · 1 repo'), findsOneWidget); // Diğer
    final ring = tester.widget<ScoreRing>(find.byType(ScoreRing));
    expect((ring.score, ring.percent), (57, true));
    expect(find.textContaining('Bir puan değildir'), findsOneWidget);
    expect(find.text('Docker · 2 repo'), findsOneWidget);
    expect(find.text('GitHub Actions · 1 repo'), findsOneWidget);
    expect(find.text('Düşük güven'), findsOneWidget);
  });

  testWidgets('dil bilgisi yoksa sayılar ve halka gösterilmez', (tester) async {
    final backend = FakeBackend()
      ..technology = FakeBackend.section('yetersiz', 'Bu metrik için henüz yeterli veri yok (0 repo, 0 dil).', {
        'repo_count': 0, 'language_count': 0, 'dominant': null, 'dominant_share': null,
        'diversity': null, 'languages': <Map<String, dynamic>>[], 'tools': <Map<String, dynamic>>[],
      });
    await _openTechnology(tester, backend);
    expect(find.textContaining('yeterli veri yok (0 repo'), findsOneWidget);
    expect(find.byType(ScoreRing), findsNothing);
    expect(find.text('Baskın dil'), findsNothing);
    expect(find.textContaining('bilinen bir araç dosyası bulunamadı'), findsOneWidget);
  });

  testWidgets('Metrikler ile Teknoloji arasında geçiş', (tester) async {
    await _openTechnology(tester, FakeBackend());
    await tester.tap(find.text('Metrikler').first);
    await tester.pumpAndSettle();
    expect(find.text('Süreklilik'), findsOneWidget);
  });
}
