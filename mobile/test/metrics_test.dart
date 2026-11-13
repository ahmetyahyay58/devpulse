import 'package:devpulse/analysis/metrics_view.dart';
import 'package:devpulse/api/api_client.dart';
import 'package:devpulse/api/health_api.dart';
import 'package:devpulse/auth/session_store.dart';
import 'package:devpulse/overview/charts.dart';
import 'package:devpulse/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_backend.dart';

Future<void> _openMetrics(WidgetTester tester, FakeBackend backend) async {
  tester.view.physicalSize = const Size(1080, 5000); // uzun ekran: her şey görünür olsun
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
}

/// Oturum bölümü "normal" olan sahte backend (ayrıntı satırları görünsün).
FakeBackend _withSessions() {
  final b = FakeBackend();
  b.overview['sessions'] = {
    ...b.overview['sessions'] as Map<String, dynamic>,
    'sufficiency': 'normal',
    'summary': 'Bir oturumda genellikle 2 commit atıyorsun.',
  };
  return b;
}

void main() {
  testWidgets('Analiz → Metrikler: kartlar, durumlar ve özetler', (tester) async {
    await _openMetrics(tester, FakeBackend());
    expect(find.text('Metrikler'), findsOneWidget);
    expect(find.text('Güncel seri'), findsOneWidget);
    expect(find.textContaining('en uzun serin 7 gün'), findsOneWidget);
    expect(find.text('Ritim'), findsOneWidget);
    expect(find.text('Oturum ve yoğunluk'), findsOneWidget);
    expect(find.text('Değişim noktaları'), findsOneWidget);
    // Üç durum da ikon + yazıyla. Süreklilik ve olağan dışı: Normal; ritim ve değişim
    // noktaları: Düşük güven; oturum: Yeterli veri yok.
    expect(find.text('Normal'), findsNWidgets(2));
    expect(find.text('Düşük güven'), findsNWidgets(2));
    expect(find.text('Yeterli veri yok'), findsOneWidget);
  });

  testWidgets('veri yetersiz bölümde sayılar öne çıkarılmaz', (tester) async {
    await _openMetrics(tester, FakeBackend());
    expect(find.text('Oturum sayısı'), findsNothing);
    expect(find.textContaining('henüz yeterli veri yok (2 oturum)'), findsOneWidget);
    expect(find.text('Haftanın gününe göre commit'), findsOneWidget); // ritim düşük güven: grafik var
  });

  testWidgets('oturum kartında en uzun oturum ve en sık başlangıç saati', (tester) async {
    await _openMetrics(tester, _withSessions());
    expect(find.text('Oturum sayısı'), findsOneWidget);
    expect(find.text('95 dk · 02.10.2026'), findsOneWidget);
    expect(find.text('Oturumların en sık başladığı saat'), findsOneWidget);
    expect(find.text('14:00-14:59'), findsOneWidget);
  });

  testWidgets('değişim noktaları: evre renkli çubuklar ve yazılı lejant', (tester) async {
    await _openMetrics(tester, FakeBackend());
    final card = find.byType(ChangePointsCard);
    final chart = tester.widget<BarChart>(find.descendant(of: card, matching: find.byType(BarChart)));
    expect(chart.values, [1, 1, 1, 1, 5, 5, 5, 5]);
    // Renk evreyi izler: ilk 4 hafta Evre 1 rengi, son 4 hafta Evre 2 rengi.
    expect([for (var i = 0; i < 8; i++) chart.colorFor!(i)],
        [...List.filled(4, ChartColors.phases[0]), ...List.filled(4, ChartColors.phases[1])]);
    expect(find.text('Evre 1 · 21.09.2026-12.10.2026'), findsOneWidget);
    expect(find.text('Evre 2 · 19.10.2026-09.11.2026'), findsOneWidget);
    expect(find.text('haftada 5'), findsOneWidget);
    expect(find.textContaining("1 commit'ten 5 commit'e arttı"), findsOneWidget);
  });

  testWidgets('olağan dışı günler kartı işaretlenen günü gösterir', (tester) async {
    await _openMetrics(tester, FakeBackend());
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
    await _openMetrics(tester, backend);
    expect(find.textContaining('yoğun bir gün bulunmadı'), findsOneWidget);
    expect(find.textContaining('Bu bir yargı değil'), findsNothing);
  });

  testWidgets('metrik kataloğu açılır', (tester) async {
    await _openMetrics(tester, FakeBackend());
    await tester.tap(find.text('Metrik kataloğu'));
    await tester.pumpAndSettle();
    expect(find.text('Test tanımı.'), findsOneWidget);
    expect(find.text('Ne zaman güvenilir'), findsOneWidget);
    expect(find.text('En az 15 oturum.'), findsOneWidget);
  });

  test('ay etiketleri: ayın ilk haftası, birbirine çok yakın olan atlanır', () {
    // 17 Kas'tan başlayan haftalar: Kas (0), Ara (2), Oca (7)...
    final starts = [for (var i = 0; i < 10; i++) DateTime(2025, 11, 17 + 7 * i)];
    expect(monthLabelIndices(starts), {2, 7}); // Kas (0) Ara'ya 2 çubuk yakın: atlanır
    final fromFirst = [for (var i = 0; i < 10; i++) DateTime(2025, 12, 1 + 7 * i)];
    expect(monthLabelIndices(fromFirst), {0, 5, 9}); // Ara (0), Oca (5), Şub (9)
  });
}
