import 'package:devpulse/api/api_client.dart';
import 'package:devpulse/api/health_api.dart';
import 'package:devpulse/api/sync_api.dart';
import 'package:devpulse/auth/session_store.dart';
import 'package:devpulse/screens/home_screen.dart';
import 'package:devpulse/sync/sync_steps.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_backend.dart';

SyncJob _job(String status, String phase,
        {int? total, int done = 0, int commits = 0, int skipped = 0, double? progress}) =>
    SyncJob(
      id: 1, status: status, phase: phase, progress: progress, reposTotal: total,
      reposDone: done, reposSkipped: skipped, commitsSynced: commits, commitsInserted: commits,
      calendarDays: 116, requestCount: 3, totalDurationMs: 900, error: null, finishedAt: null,
    );

List<SyncStepState> _states(SyncJob j) => [for (final s in stepsFor(j)) s.state];

void main() {
  group('aşama listesi (stepsFor)', () {
    const done = SyncStepState.done, active = SyncStepState.active;
    const waiting = SyncStepState.waiting, failed = SyncStepState.failed;

    test('yeni açılmış iş: profil bitti, repo listesi sürüyor', () {
      expect(_states(_job('pending', 'profile')), [done, active, waiting, waiting]);
      expect(stepsFor(_job('pending', 'profile'))[1].detail, 'Repolar listeleniyor…');
    });

    test('commit aşamasında canlı sayaç', () {
      final j = _job('running', 'commits', total: 47, done: 23, commits: 312, skipped: 5);
      expect(_states(j), [done, done, active, waiting]);
      expect(stepsFor(j)[1].detail, '47 repo bulundu');
      expect(stepsFor(j)[2].detail, '23 / 47 repo · 312 commit · 5 değişmemiş');
    });

    test('hata, hatanın çıktığı aşamada gösterilir', () {
      expect(_states(_job('failed', 'calendar', total: 2, done: 2)), [done, done, done, failed]);
      expect(_states(_job('failed', 'repos')), [done, failed, waiting, waiting]);
    });

    test('bitmiş iş: hepsi tamam, takvim gün sayısı', () {
      final j = _job('done', 'done', total: 2, done: 2);
      expect(_states(j), [done, done, done, done]);
      expect(stepsFor(j)[3].detail, '116 gün');
    });

    test('yüzde metni', () {
      expect(percentText(0.416), '%42');
      expect(percentText(null), isNull); // repo sayısı henüz bilinmiyor
    });
  });

  group('gösterim hızı', () {
    const done = SyncStepState.done, active = SyncStepState.active;
    const waiting = SyncStepState.waiting, failed = SyncStepState.failed;
    final finished = stepsFor(_job('done', 'done', total: 7, done: 7, commits: 489));

    test('gerçekte bitmiş aşamalar birer birer gösterilir', () {
      List<SyncStepState> at(int shown) => [for (final s in pacedSteps(finished, shown)) s.state];
      expect(at(0), [active, waiting, waiting, waiting]);
      expect(at(2), [done, done, active, waiting]);
      expect(at(4), [done, done, done, done]);
      expect(pacedSteps(finished, 1)[2].detail, isNull); // bekleyen aşamanın sayacı gösterilmez
    });

    test('hata, sırası gelince gösterilir', () {
      final real = stepsFor(_job('failed', 'calendar', total: 2, done: 2));
      expect([for (final s in pacedSteps(real, 1)) s.state], [done, active, waiting, waiting]);
      expect([for (final s in pacedSteps(real, 3)) s.state], [done, done, done, failed]);
    });

    test('takvim soldan sağa açılır, sayılar değişmez', () {
      final days = [for (var i = 0; i < 10; i++) (DateTime(2026, 11, i + 1), i + 1)];
      expect([for (final d in revealDays(days, 0.3)) d.$2], [1, 2, 3, 0, 0, 0, 0, 0, 0, 0]);
      expect(revealDays(days, 1), days);
      expect([for (final d in revealDays(days, 0)) d.$2].every((c) => c == 0), isTrue);
    });
  });

  group('senkron ekranı', () {
    Future<FakeBackend> openHome(WidgetTester tester,
        {Duration poll = Duration.zero, bool firstLogin = false, bool syncOnOpen = false,
        Duration step = Duration.zero}) async {
      final backend = FakeBackend();
      if (firstLogin) backend.latestJob = null;
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
          session: const Session(sessionToken: 'jwt', githubToken: 'gho', userId: 1, login: 'ben'),
          api: ApiClient(baseUrl: 'http://test', client: backend.client),
          healthApi: HealthApi(baseUrl: 'http://test', client: backend.client),
          onLogout: () {},
          timezone: () async => 'Europe/Istanbul',
          pollInterval: poll,
          syncOnOpen: syncOnOpen,
          syncStepDuration: step,
        ),
      ));
      if (step == Duration.zero) await tester.pumpAndSettle();
      return backend;
    }

    testWidgets('girişten hemen sonra: önceki senkron olsa da ekran açılır, yeni senkron başlar',
        (tester) async {
      final backend = await openHome(tester, syncOnOpen: true); // latestJob: bitmiş eski iş
      expect(backend.called('/sync'), isTrue);
      expect(find.text('Senkron'), findsNothing); // bitince kendiliğinden kapandı
      expect(find.textContaining('Son senkron:'), findsOneWidget);
    });

    testWidgets('anında biten senkron da aşama aşama gösterilir', (tester) async {
      await openHome(tester, syncOnOpen: true, step: const Duration(milliseconds: 800));
      await tester.pump(); // ilk kare: ekran açılır
      await tester.pump(const Duration(milliseconds: 500)); // istekler + geçiş animasyonu
      // Sunucuda iş çoktan bitti (sahte backend 3 turda bitirir, tur süresi 0), ama ekran
      // ilk aşamada: "Senkron tamamlandı" henüz yok.
      expect(find.text('GitHub verin çekiliyor'), findsOneWidget);
      expect(find.text('Atla'), findsOneWidget);

      // 4 aşama x 0,8 sn sonra "tamamlandı" görünür.
      for (var i = 0; i < 30 && find.text('Senkron tamamlandı').evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.text('Senkron tamamlandı'), findsOneWidget);
      expect(find.text('%100'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNWidgets(4)); // dört aşama da tamam
      expect(find.textContaining('commit işlendi'), findsOneWidget);
      expect(find.text('Atla'), findsNothing); // bitince düğme yok

      // Kısa bir an sonra ekran kendiliğinden kapanır, ana ekran görünür.
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Senkron'), findsNothing);
      expect(find.textContaining('Son senkron:'), findsOneWidget);
    });

    testWidgets('ilk girişte ekran kendiliğinden açılır, takvim sorulur, bitince kapanır',
        (tester) async {
      final backend = await openHome(tester, firstLogin: true);
      expect(backend.called('/sync'), isTrue);
      expect(backend.commitDaysCalls, greaterThan(0));
      expect(find.text('Senkron'), findsNothing);
      expect(find.textContaining('Son senkron:'), findsOneWidget);
    });

    testWidgets('"Atla" ekranı kapatır, senkron arka planda sürer', (tester) async {
      await openHome(tester, poll: const Duration(seconds: 1));
      await tester.tap(find.text('Yeniden senkronla'));
      await tester.pump(); // istek
      await tester.pump(const Duration(milliseconds: 500)); // sayfa geçiş animasyonu
      expect(find.text('GitHub verin çekiliyor'), findsOneWidget);
      expect(find.text('0 / 2 repo · 0 commit'), findsOneWidget);

      await tester.tap(find.text('Atla'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500)); // kapanış animasyonu
      expect(find.text('Senkron'), findsNothing); // sayfa kapandı
      expect(find.textContaining('arka planda sürüyor'), findsOneWidget);
      expect(find.text('Ayrıntıları gör'), findsOneWidget); // kart hâlâ "sürüyor"

      // İzleme sürer: birkaç tur sonra iş biter ve kart özeti gösterir.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.textContaining('Son senkron:'), findsOneWidget);
    });

    testWidgets('daha önce senkron yapılmışsa ekran kendiliğinden açılmaz', (tester) async {
      final backend = await openHome(tester);
      expect(find.text('Senkron'), findsNothing);
      expect(backend.called('/sync'), isFalse); // yalnız /sync/jobs/latest soruldu
      expect(find.text('Yeniden senkronla'), findsOneWidget);
    });
  });
}
