import 'dart:convert';

import 'package:devpulse/api/api_client.dart';
import 'package:devpulse/api/sync_api.dart';
import 'package:devpulse/auth/session_store.dart';
import 'package:devpulse/sync/sync_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_backend.dart';

const _liveSession = Session(sessionToken: 'jwt', githubToken: 'gho_x', userId: 1, login: 'ben');

void main() {
  late FakeBackend backend;
  late bool loggedOut;

  SyncController controller() => SyncController(
        api: SyncApi(ApiClient(baseUrl: 'http://test', client: backend.client)),
        session: _liveSession,
        onUnauthorized: () => loggedOut = true,
        timezone: () async => 'Europe/Istanbul',
        pollInterval: Duration.zero, // testte bekleme yok
      );

  /// Denetleyicinin gördüğü durumları sırasıyla kaydeder.
  List<String> record(SyncController c) {
    final seen = <String>[];
    c.addListener(() {
      final s = c.job?.status;
      if (s != null && (seen.isEmpty || seen.last != s)) seen.add(s);
    });
    return seen;
  }

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 50));

  setUp(() {
    backend = FakeBackend();
    loggedOut = false;
  });

  test('başlat: token ve saat dilimi gönderilir, iş bitene kadar izlenir', () async {
    final c = controller();
    final seen = record(c);
    await c.start();
    await settle();

    final body = jsonDecode(backend.requests.firstWhere((r) => r.url.path == '/sync').body);
    expect(body, {'github_token': 'gho_x', 'timezone': 'Europe/Istanbul'});
    expect(seen, ['running', 'done']);
    expect(c.job!.commitsInserted, 6);
    expect(c.isRunning, isFalse);
  });

  test('açılışta süren iş varsa izlemeye kaldığı yerden devam eder', () async {
    backend.latestJob = FakeBackend.job(7, 'running', reposTotal: 2, reposDone: 1, progress: 1 / 3);
    final c = controller();
    await c.load();
    await settle();

    expect(c.job!.status, 'done');
    expect(backend.called('/sync'), isFalse); // yeni senkron başlatılmadı
  });

  test('hiç senkron yoksa iş null, yükleme biter', () async {
    final c = controller();
    await c.load();
    expect(c.job, isNull);
    expect(c.loading, isFalse);
  });

  test('zaten süren senkron (409) varsa yenisi açılmaz, o izlenir', () async {
    backend.runningJobId = 42;
    final c = controller();
    await c.start();
    await settle();

    expect(c.job!.id, 42);
    expect(c.job!.status, 'done');
    expect(c.error, isNull);
  });

  test('oturum süresi dolduysa (401) çıkış yaptırılır', () async {
    backend.sessionExpired = true;
    await controller().start();
    expect(loggedOut, isTrue);
  });

  test('başarısız iş hata mesajıyla gelir', () async {
    backend.jobStates = [FakeBackend.job(7, 'failed', error: 'GitHub 502 döndü.')];
    final c = controller();
    await c.start();
    await settle();
    expect(c.job!.status, 'failed');
    expect(c.job!.error, contains('502'));
  });
}
