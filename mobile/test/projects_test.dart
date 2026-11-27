import 'package:devpulse/api/api_client.dart';
import 'package:devpulse/api/health_api.dart';
import 'package:devpulse/auth/session_store.dart';
import 'package:devpulse/overview/charts.dart';
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
  await tester.tap(find.byTooltip('Projeler'));
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

  testWidgets('liste: en eksikli önce, skor, durum etiketi ve eksik sayısı', (tester) async {
    await _openProjects(tester, FakeBackend());
    final first = tester.getTopLeft(find.text('eksikli-repo')).dy;
    final second = tester.getTopLeft(find.text('iyi-repo')).dy;
    expect(first, lessThan(second));

    expect(find.text('60/100'), findsOneWidget);
    expect(find.text('Python · 4 commit · 2 eksik'), findsOneWidget);
    expect(find.text('Aktif'), findsOneWidget);
    expect(find.text('Arşiv'), findsOneWidget);
    expect(find.text('Durağan'), findsOneWidget); // katki-repo
    expect(find.text('Topic: eksik'), findsNothing); // kontroller detayda
  });

  testWidgets('repoya dokununca detay: halka, öneri, kontroller, topic, 12 hafta', (tester) async {
    await _openProjects(tester, FakeBackend());
    await tester.tap(find.text('eksikli-repo'));
    await tester.pumpAndSettle();

    expect(find.byType(ScoreRing), findsOneWidget);
    expect(tester.widget<ScoreRing>(find.byType(ScoreRing)).score, 60);
    expect(find.text('Şu eksikleri kapatırsan skor 40 puan artar: Lisans, Topic.'), findsOneWidget);
    expect(find.text('Topic: eksik'), findsOneWidget);
    expect(find.text('Topic ekle.'), findsOneWidget);
    expect(find.text('README: var'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'flutter'), findsOneWidget);
    expect(find.text('Son 12 hafta'), findsOneWidget);
    expect(find.text('4 commit'), findsOneWidget); // 12 haftalık toplam
    expect(tester.widget<BarChart>(find.byType(BarChart)).values.length, 12);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Proje sağlığı'), findsOneWidget); // listeye dönüldü
  });

  testWidgets('12 haftada commit yoksa çubuk yerine yazı', (tester) async {
    await _openProjects(tester, FakeBackend());
    await tester.tap(find.text('iyi-repo'));
    await tester.pumpAndSettle();
    expect(find.byType(BarChart), findsNothing);
    expect(find.text('Son 12 haftada bu repoya commit atmadın.'), findsOneWidget);
    expect(find.byType(Chip), findsNothing); // topic yok: kart gösterilmez
  });

  testWidgets('puanlanmayan repo gerekçesiyle ayrı listelenir, detayda halka yok', (tester) async {
    await _openProjects(tester, FakeBackend());
    expect(find.text('Puanlanmayan repolar'), findsOneWidget);
    expect(find.text('Python · 4 commit'), findsOneWidget);
    await tester.tap(find.text('katki-repo'));
    await tester.pumpAndSettle();
    expect(find.text('Puanlanmıyor'), findsOneWidget);
    expect(find.text('Başkasına ait repo.'), findsOneWidget);
    expect(find.byType(ScoreRing), findsNothing);
  });

  testWidgets('senkron bitince Projeler de yenilenir', (tester) async {
    final backend = FakeBackend();
    await _openProjects(tester, backend);
    expect(backend.projectsCalls, 1);

    await tester.tap(find.byTooltip('Genel Bakış')); // alt menüdeki sekme
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yeniden senkronla'));
    await tester.pumpAndSettle();
    expect(backend.projectsCalls, 2);
  });

  testWidgets('Liste / Kümeler: kümeler adıyla, repolarıyla ve yöntem notuyla', (tester) async {
    final backend = FakeBackend();
    await _openProjects(tester, backend);
    await tester.tap(find.text('Kümeler'));
    await tester.pumpAndSettle();
    expect(backend.requests.last.url.path, '/projects/clusters');
    expect(find.text('Aktif, belgeli'), findsOneWidget);
    expect(find.text('Durağan, belgesi eksik'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'eski-odev'), findsOneWidget);
    expect(find.textContaining('son push 400 gün önce · puan -'), findsOneWidget);
    expect(find.textContaining('az repo olduğu için'), findsOneWidget);
    expect(find.text('Proje sağlığı'), findsNothing); // liste görünümü gizli

    await tester.tap(find.text('Liste'));
    await tester.pumpAndSettle();
    expect(find.text('Proje sağlığı'), findsOneWidget);
  });
}
