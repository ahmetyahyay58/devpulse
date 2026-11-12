import 'package:devpulse/api/api_client.dart';
import 'package:devpulse/api/health_api.dart';
import 'package:devpulse/auth/session_store.dart';
import 'package:devpulse/overview/charts.dart';
import 'package:devpulse/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_backend.dart';

Future<void> _pumpHome(WidgetTester tester, FakeBackend backend) async {
  tester.view.physicalSize = const Size(1080, 4000); // uzun ekran: her şey görünür olsun
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
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  test('ısı haritası düzeyi: 0 boş, en yüksek gün 4', () {
    expect(ContributionHeatmap.level(0, 10), 0);
    expect(ContributionHeatmap.level(1, 10), 1);
    expect(ContributionHeatmap.level(5, 10), 2);
    expect(ContributionHeatmap.level(8, 10), 4);
    expect(ContributionHeatmap.level(10, 10), 4);
  });

  testWidgets('KPI, takvim, rozetler ve özetler görünür', (tester) async {
    await _pumpHome(tester, FakeBackend());

    expect(find.text('Toplam commit'), findsOneWidget);
    expect(find.text('33'), findsOneWidget);
    expect(find.textContaining('üretkenliği ya da kaliteyi ölçmez'), findsOneWidget);
    expect(find.text('Son bir yılda 5 katkı'), findsOneWidget);
    expect(find.byType(ContributionHeatmap), findsOneWidget);

    // Üç durum da ikon + yazıyla gösterilir.
    expect(find.text('Normal'), findsNWidgets(2)); // süreklilik + olağan dışı günler
    expect(find.text('Düşük güven'), findsOneWidget);
    expect(find.text('Yeterli veri yok'), findsOneWidget);
    expect(find.textContaining('en uzun serin 7 gün'), findsOneWidget);
  });

  testWidgets('olağan dışı günler kartı işaretlenen günü gösterir', (tester) async {
    await _pumpHome(tester, FakeBackend());
    expect(find.text('Olağan dışı günler'), findsOneWidget);
    expect(find.text('02.10.2026'), findsOneWidget);
    expect(find.text('23 commit · z 8.1'), findsOneWidget);
    expect(find.textContaining('Bu bir yargı değil'), findsOneWidget);
  });

  testWidgets('olağan dışı gün yoksa yalnızca özet görünür', (tester) async {
    final backend = FakeBackend()
      ..anomalies = FakeBackend.section('normal', 'Alışkanlığının belirgin dışında yoğun bir gün bulunmadı.', {
        'flagged': <Map<String, dynamic>>[], 'active_days': 40, 'median_commits': 2.0,
        'mad': 1.0, 'threshold': 3.5,
      });
    await _pumpHome(tester, backend);
    expect(find.textContaining('yoğun bir gün bulunmadı'), findsOneWidget);
    expect(find.textContaining('Bu bir yargı değil'), findsNothing);
  });

  testWidgets('veri yetersiz bölümde sayılar öne çıkarılmaz', (tester) async {
    await _pumpHome(tester, FakeBackend());
    // Oturum bölümü "yetersiz": ayrıntı satırları gösterilmez, yalnızca özet.
    expect(find.text('Oturum sayısı'), findsNothing);
    expect(find.textContaining('henüz yeterli veri yok (2 oturum)'), findsOneWidget);
    // Ritim "düşük güven": grafik gösterilir.
    expect(find.text('Haftanın gününe göre commit'), findsOneWidget);
  });

  testWidgets('"Nasıl hesaplandı?" açılınca yöntem ve dayanak görünür', (tester) async {
    await _pumpHome(tester, FakeBackend());
    await tester.tap(find.text('Nasıl hesaplandı?').first);
    await tester.pumpAndSettle();
    expect(find.text('Test: nasıl hesaplandı metni.'), findsOneWidget);
    expect(find.textContaining('Dayanak: test dayanağı'), findsOneWidget);
  });

  testWidgets('commit yoksa senkrona yönlendirir', (tester) async {
    final backend = FakeBackend()..overview = FakeBackend.sampleOverview(totalCommits: 0);
    await _pumpHome(tester, backend);
    expect(find.textContaining('Henüz commit verin yok'), findsOneWidget);
    expect(find.text('Toplam commit'), findsNothing);
  });

  testWidgets('senkron bitince Genel Bakış yeniden yüklenir', (tester) async {
    final backend = FakeBackend();
    await _pumpHome(tester, backend);
    expect(backend.overviewCalls, 1);

    await tester.tap(find.text('Verimi çek'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Son senkron:'), findsOneWidget);
    expect(backend.overviewCalls, 2);
  });
}
