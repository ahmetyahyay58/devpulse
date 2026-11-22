import 'dart:io';

import 'package:devpulse/achievements/achievements_view.dart';
import 'package:devpulse/achievements/badge_art.dart';
import 'package:devpulse/api/api_client.dart';
import 'package:devpulse/api/health_api.dart';
import 'package:devpulse/auth/session_store.dart';
import 'package:devpulse/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_backend.dart';

Future<void> _open(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({}); // kutlama deposu her testte boş: taban kaydı, kutlama yok
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
  testWidgets('rozetler: açıklar tam, kilitliler soluk ve ilerlemeli', (tester) async {
    await _open(tester);
    expect(find.byType(BadgeTile), findsNWidgets(13));
    expect(find.text('Açılan rozet: 5 / 13'), findsOneWidget);
    expect(find.text('Açıldı'), findsNWidgets(2));
    expect(find.text('7 / 30'), findsOneWidget); // bir aylık seri ilerlemesi
    expect(find.text('180 dk / 240 dk'), findsOneWidget); // maraton: birimli ilerleme
    expect(find.byIcon(Icons.lock_outline), findsNWidgets(8));
    // Kilitli rozetin görseli gri tonlu ve soluk.
    final lockedArt = find.descendant(of: find.widgetWithText(BadgeTile, 'Lisanslı'), matching: find.byType(BadgeArt));
    expect(find.descendant(of: lockedArt, matching: find.byType(ColorFiltered)), findsOneWidget);
    final open = find.descendant(of: find.widgetWithText(BadgeTile, 'Bir haftalık seri'), matching: find.byType(BadgeArt));
    expect(find.descendant(of: open, matching: find.byType(ColorFiltered)), findsNothing);
    expect(find.textContaining('commit sayısını ödüllendirmez'), findsOneWidget);
  });

  testWidgets('seviyeli rozet: seviye adı yazılı, ilerleme sıradaki seviyeye; en üstte "en üst seviye"', (tester) async {
    await _open(tester);
    expect(find.text('Bronz'), findsOneWidget);
    expect(find.text('Bronz · sıradaki seviye: 18 / 50'), findsOneWidget);
    expect(find.text('Altın'), findsOneWidget);
    expect(find.text('Altın · en üst seviye'), findsOneWidget);
  });

  testWidgets('rozete dokununca ayrıntı: büyük görsel ve seviye merdiveni', (tester) async {
    await _open(tester);
    await tester.tap(find.widgetWithText(BadgeTile, 'İncelemeci'));
    await tester.pumpAndSettle();
    expect(find.byType(BadgeDetail), findsOneWidget);
    expect(find.descendant(of: find.byType(BadgeDetail), matching: find.text('Gümüş')), findsOneWidget);
    expect(find.descendant(of: find.byType(BadgeDetail), matching: find.text('50')), findsOneWidget);
  });

  testWidgets("backend'in gönderebileceği her rozet anahtarının görseli var", (tester) async {
    const keys = [
      'streak7', 'streak30', 'regular', 'showcase', 'docs', 'license', 'polyglot', 'contributor', 'topics',
      'hours24', 'night_owl', 'early_bird', 'new_year', 'leet', 'marathon', 'comeback', 'bug_hunter', 'all_types',
      'less_is_more', 'automation', 'first_merge', 'weekend', 'tester', 'small_steps', 'long_haul', 'fresh_start',
      'container', 'reviewer', 'twelve_months', 'secret',
    ];
    // Dosyalar diskten okunur: rootBundle önceki ekran testlerinin (sahte saat) bitmeyen okumalarını
    // önbellekte tutabilir. pubspec'te klasörün varlık olarak tanımlı olduğu da denetlenir.
    expect(File('pubspec.yaml').readAsStringSync(), contains('- assets/badges/'));
    for (final k in keys) {
      expect(File('assets/badges/$k.svg').readAsStringSync(), contains('<svg'), reason: k);
    }
  });

  test('gizli rozet açılmadan gerçek görsel seçilmez; açılınca seçilir', () {
    expect(artKeyFor({'key': 'gizli-1', 'hidden': true, 'unlocked': false}), 'secret');
    expect(artKeyFor({'key': 'new_year', 'hidden': true, 'unlocked': true}), 'new_year');
  });

  test('kenar seviyeye göre boyanır', () {
    const svg = '<stop stop-color="#8A93A8"/><stop stop-color="#3A4052"/>';
    expect(paintRim(svg, 'altin'), contains('#FFE58A'));
    expect(paintRim(svg, null), svg);
  });

  test('kutlama: ilk açılışta taban kaydı, sonra yalnız yeni açılan rozet ve yeni seviye', () async {
    SharedPreferences.setMockInitialValues({});
    final store = BadgeSeenStore();
    final a = {'key': 'streak7', 'unlocked': true};
    final b = {'key': 'reviewer', 'unlocked': true, 'tier': 'bronz'};
    expect(await store.takeNew([a, b]), isEmpty); // ilk açılış: kutlama yağmuru yok
    expect(await store.takeNew([a, b]), isEmpty);
    final c = {'key': 'marathon', 'unlocked': true};
    final b2 = {'key': 'reviewer', 'unlocked': true, 'tier': 'gumus'};
    expect((await store.takeNew([a, b2, c])).map((x) => x['key']), ['reviewer', 'marathon']);
  });

  testWidgets('yeni rozet kutlaması tek sefer gösterilir', (tester) async {
    SharedPreferences.setMockInitialValues({'badges_seen': ['streak7']});
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => TextButton(
      onPressed: () => showBadgeCelebration(context, [
        {'key': 'marathon', 'name': 'Maraton', 'description': 'Uzun oturum.', 'unlocked': true},
        {'key': 'streak30', 'name': 'Bir aylık seri', 'description': '30 gün.', 'unlocked': true},
      ]),
      child: const Text('aç'),
    ))));
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle(); // animasyon biter (sonsuz döngü yok)
    expect(find.text('Yeni rozet açıldı'), findsOneWidget);
    expect(find.text('Maraton'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    await tester.tap(find.text('Sıradaki')); // ikinci rozet kendi kutlamasıyla gelir
    await tester.pumpAndSettle();
    expect(find.text('Bir aylık seri'), findsOneWidget);
    expect(find.text('2 / 2'), findsOneWidget);
    await tester.tap(find.text('Harika'));
    await tester.pumpAndSettle();
    expect(find.text('Bir aylık seri'), findsNothing);
  });

  testWidgets('animasyonlar kapalıysa kutlama son haliyle anında görünür', (tester) async {
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) =>
          MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
      home: Builder(builder: (context) => TextButton(
        onPressed: () => showBadgeCelebration(context, [
          {'key': 'marathon', 'name': 'Maraton', 'description': 'Uzun oturum.', 'unlocked': true},
        ]),
        child: const Text('aç'),
      )),
    ));
    await tester.tap(find.text('aç'));
    await tester.pump();
    await tester.pump();
    final op = tester.widget<Opacity>(find.ancestor(of: find.text('Maraton'), matching: find.byType(Opacity)).first);
    expect(op.opacity, 1); // yazılar beklemeden tam görünür
  });

  testWidgets('gizli rozet: kilitliyken ??? ve soru işareti, ilerleme çubuğu yok; açılınca adı görünür', (tester) async {
    await _open(tester);
    expect(find.text('Gizli rozet'), findsOneWidget);
    expect(find.text('???'), findsOneWidget);
    // Gizli ve kilitli: anahtara bakılmadan hep "?" madalyonu.
    final art = tester.widget<BadgeArt>(
        find.descendant(of: find.widgetWithText(BadgeTile, 'Gizli rozet'), matching: find.byType(BadgeArt)));
    expect(artKeyFor(art.badge), 'secret');
    expect(find.descendant(of: find.widgetWithText(BadgeTile, 'Gizli rozet'),
        matching: find.byType(LinearProgressIndicator)), findsNothing);
    expect(find.text('Yılbaşı'), findsOneWidget);
    expect(find.text('Gizli rozet açıldı'), findsOneWidget);
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
