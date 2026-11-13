import 'package:devpulse/api/api_client.dart';
import 'package:devpulse/api/health_api.dart';
import 'package:devpulse/auth/session_store.dart';
import 'package:devpulse/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_backend.dart';

Future<void> _openProjects(WidgetTester tester, FakeBackend backend) async {
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
  await tester.tap(find.text('Projeler'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Projeler sekmesi: özet ve eksik sayıları', (tester) async {
    await _openProjects(tester, FakeBackend());
    expect(find.text('Proje sağlığı'), findsOneWidget);
    expect(find.textContaining('ortalama skoru 70/100'), findsOneWidget);
    expect(find.text('Lisans eksik'), findsOneWidget);
    expect(find.text('2/2 repo'), findsOneWidget);
    expect(find.text('README eksik'), findsNothing); // hiçbir repoda eksik değil: satır yok
  });

  testWidgets('en eksikli repo önce; eksikler öneriyle', (tester) async {
    await _openProjects(tester, FakeBackend());
    final first = tester.getTopLeft(find.text('eksikli-repo')).dy;
    final second = tester.getTopLeft(find.text('iyi-repo')).dy;
    expect(first, lessThan(second));

    expect(find.text('60/100'), findsOneWidget);
    expect(find.text('Topic: eksik'), findsOneWidget);
    expect(find.text('Topic ekle.'), findsOneWidget);
    expect(find.text('README: var'), findsNWidgets(2));
  });

  testWidgets('puanlanmayan repolar gerekçesiyle ayrı listelenir', (tester) async {
    await _openProjects(tester, FakeBackend());
    expect(find.text('Puanlanmayan repolar'), findsOneWidget);
    expect(find.text('katki-repo · 4 commit'), findsOneWidget);
    expect(find.text('Başkasına ait repo.'), findsOneWidget);
  });

  testWidgets('senkron bitince Projeler de yenilenir', (tester) async {
    final backend = FakeBackend();
    await _openProjects(tester, backend);
    expect(backend.projectsCalls, 1);

    await tester.tap(find.text('Genel Bakış').last); // alt çubuktaki sekme
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yeniden senkronla'));
    await tester.pumpAndSettle();
    expect(backend.projectsCalls, 2);
  });
}
