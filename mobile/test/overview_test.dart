import 'package:devpulse/api/api_client.dart';
import 'package:devpulse/api/health_api.dart';
import 'package:devpulse/auth/session_store.dart';
import 'package:devpulse/overview/charts.dart';
import 'package:devpulse/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_backend.dart';

Future<void> _pumpHome(WidgetTester tester, FakeBackend backend, {double textScale = 1, double width = 1080}) async {
  tester.view.physicalSize = Size(width, 4000); // uzun ekran: her şey görünür olsun
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
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
}

void main() {
  test('ısı haritası düzeyi: 0 boş, en yüksek gün 4', () {
    expect(ContributionHeatmap.level(0, 10), 0);
    expect(ContributionHeatmap.level(1, 10), 1);
    expect(ContributionHeatmap.level(5, 10), 2);
    expect(ContributionHeatmap.level(8, 10), 4);
    expect(ContributionHeatmap.level(10, 10), 4);
  });

  testWidgets('KPI, takvim ve commit türleri görünür; metrik kartları Analiz sekmesinde', (tester) async {
    await _pumpHome(tester, FakeBackend());

    // Dört KPI kartı; değer kartın içinde aranır (33 halka grafiğin ortasında da yazar).
    // "Repo" senkron kartında da geçer: içinde zengin metinli (değer) satır olan kart KPI'dır.
    String kpi(String label) {
      for (var i = 0; i < find.text(label).evaluate().length; i++) {
        final card = find.ancestor(of: find.text(label).at(i), matching: find.byType(Card)).first;
        final values = find
            .descendant(of: card, matching: find.byType(RichText))
            .evaluate()
            .map((e) => (e.widget as RichText).text.toPlainText())
            .where((t) => t != label)
            .toList();
        if (values.length == 1) return values.single;
      }
      return 'bulunamadı';
    }
    expect(kpi('Toplam commit'), '33');
    expect(kpi('Aktif gün'), '10');
    expect(kpi('En uzun seri'), '7 gün'); // Süreklilik bölümünden
    expect(kpi('Repo'), '4');
    expect(find.textContaining('üretkenliği ya da kaliteyi ölçmez'), findsOneWidget);
    expect(find.text('Son 30 haftada 5 katkı'), findsOneWidget);
    expect(find.byType(ContributionHeatmap), findsOneWidget);
    expect(find.text('Normal'), findsOneWidget); // yalnız commit türleri kartı
    // Süreklilik, ritim, oturum, olağan dışı günler Analiz sekmesinde (bkz. metrics_test).
    expect(find.text('Güncel seri'), findsNothing);
    expect(find.text('Ritim'), findsNothing);
  });

  testWidgets('commit türleri: oranlar, doğruluk notu; 0 olan tür gizli', (tester) async {
    await _pumpHome(tester, FakeBackend());
    expect(find.text('Commit türleri'), findsOneWidget);
    expect(find.text('Belgelendirme'), findsOneWidget);
    expect(find.text('19 · %58'), findsOneWidget);
    expect(find.text('Test'), findsNothing); // sayısı 0
    expect(find.textContaining('yaklaşık bir tahmindir'), findsOneWidget);
  });

  testWidgets('türe dokununca commit\'ler ve karar gerekçesi görünür', (tester) async {
    await _pumpHome(tester, FakeBackend());
    await tester.ensureVisible(find.text('Yeni özellik')); // halkanın altında kalabilir
    await tester.tap(find.text('Yeni özellik'));
    await tester.pumpAndSettle();
    expect(find.text("Yeni özellik · son commit'ler"), findsOneWidget);
    expect(find.text('profil sayfası'), findsOneWidget);
    expect(find.text('model, %72 güven'), findsOneWidget); // modelden karar
  });

  testWidgets('kural kararı "kural:" önekiyle gösterilir', (tester) async {
    await _pumpHome(tester, FakeBackend());
    await tester.ensureVisible(find.text('Belgelendirme'));
    await tester.tap(find.text('Belgelendirme'));
    await tester.pumpAndSettle();
    expect(find.text('kural: Markdown dosyası'), findsOneWidget);
  });

  testWidgets('commit türleri halka grafikle, her tür sabit renginde', (tester) async {
    await _pumpHome(tester, FakeBackend());
    final donut = tester.widget<DonutChart>(find.byType(DonutChart));
    expect(donut.centerValue, '33');
    // Görünen türler (sayısı 0 olan Test yok), renkleri türe bağlı.
    expect([for (final s in donut.slices) s.$2],
        [ChartColors.types['docs'], ChartColors.types['feat'], ChartColors.types['fix']]);
    expect([for (final s in donut.slices) s.$1], [19, 8, 6]);
  });

  testWidgets('olağan dışı gün takvimde halkayla ve lejantla gösterilir', (tester) async {
    final backend = FakeBackend()
      ..anomalies = FakeBackend.section('normal', '1 gün yoğundu.', {
        'flagged': [
          {'day': '2026-11-11', 'commits': 9, 'lines': 300, 'robust_z': 5.0}, // takvim aralığında
        ],
        'active_days': 40, 'median_commits': 2.0, 'mad': 1.0, 'threshold': 3.5,
      });
    await _pumpHome(tester, backend);
    final map = tester.widget<ContributionHeatmap>(find.byType(ContributionHeatmap));
    expect(map.highlighted, {DateTime(2026, 11, 11)});
    expect(find.text('Olağan dışı yoğun gün (1)'), findsOneWidget);
  });

  testWidgets('takvim aralığı dışındaki olağan dışı gün için lejant çıkmaz', (tester) async {
    await _pumpHome(tester, FakeBackend()); // işaretli gün 02.10.2026, takvim 06-12.11
    expect(find.textContaining('Olağan dışı yoğun gün ('), findsNothing);
  });

  testWidgets('"Nasıl hesaplandı?" açılınca yöntem ve dayanak görünür', (tester) async {
    await _pumpHome(tester, FakeBackend());
    final how = find.text('Nasıl hesaplandı?').first;
    // Sayfa uzun (AI kartı da var): alt çubuğun altında kalmasın diye ortaya kaydır.
    await tester.runAsync(() => Scrollable.ensureVisible(tester.element(how), alignment: 0.5));
    await tester.pumpAndSettle();
    await tester.tap(how);
    await tester.pumpAndSettle();
    expect(find.text('Test: nasıl hesaplandı metni.'), findsOneWidget);
    expect(find.textContaining('Dayanak: test dayanağı'), findsOneWidget);
  });

  testWidgets('dar ekran ve büyük yazı boyutunda Genel Bakış taşmaz', (tester) async {
    await _pumpHome(tester, FakeBackend(), textScale: 2, width: 900); // 360 dp genişlik, yazı 2 kat
    expect(tester.takeException(), isNull);
    expect(find.text('Toplam commit'), findsOneWidget);
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

    await tester.tap(find.text('Yeniden senkronla'));
    await tester.pumpAndSettle(); // senkron ekranı açılır, bitince kendiliğinden kapanır

    expect(find.textContaining('Son senkron:'), findsOneWidget);
    expect(backend.overviewCalls, 2);
  });
}
