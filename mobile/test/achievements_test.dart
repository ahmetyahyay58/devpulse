import 'package:devpulse/achievements/achievements_view.dart';
import 'package:devpulse/api/api_client.dart';
import 'package:devpulse/api/health_api.dart';
import 'package:devpulse/auth/session_store.dart';
import 'package:devpulse/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_backend.dart';

Future<void> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  final backend = FakeBackend();
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
  await tester.tap(find.text('Başarımlar').last); // alt çubuktaki sekme
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('8 rozet: açıklar tam, kilitliler soluk ve ilerlemeli', (tester) async {
    await _open(tester);
    expect(find.byType(BadgeTile), findsNWidgets(8));
    expect(find.text('Açılan rozet: 2 / 8'), findsOneWidget);
    expect(find.text('Açıldı'), findsNWidgets(2));
    expect(find.text('7 / 30'), findsOneWidget); // bir aylık seri ilerlemesi
    expect(find.byIcon(Icons.lock_outline), findsNWidgets(6));
    final locked = tester.widget<Opacity>(
        find.ancestor(of: find.text('Lisanslı'), matching: find.byType(Opacity)).first);
    expect(locked.opacity, lessThan(1));
    expect(find.textContaining('commit sayısını ödüllendirmez'), findsOneWidget);
  });

  testWidgets('yıl kıyası: aynı dönem, yüzde değişim, geçen yıl 0 ise yüzde yok', (tester) async {
    await _open(tester);
    expect(find.text('Yıl kıyası'), findsOneWidget);
    expect(find.text('Her iki yıl için 1 Oca - 14 Kas'), findsOneWidget);
    expect(find.text('+%50'), findsOneWidget);
    expect(find.text('aynı'), findsOneWidget);
    expect(find.text('+%133'), findsOneWidget);
    expect(find.text('-'), findsOneWidget); // repo: geçen yıl 0
    expect(find.textContaining('%50 daha fazla commit'), findsOneWidget);
  });
}
