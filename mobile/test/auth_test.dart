import 'package:devpulse/api/api_client.dart';
import 'package:devpulse/auth/auth_service.dart';
import 'package:devpulse/auth/pkce.dart';
import 'package:devpulse/auth/session_store.dart';
import 'package:devpulse/cv/cv_profile.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_backend.dart';

void main() {
  late FakeBackend backend;
  late MemorySessionStore store;

  AuthService service(BrowserAuth browser) => AuthService(
        api: ApiClient(baseUrl: 'http://test', client: backend.client),
        store: store,
        browserAuth: browser,
      );

  setUp(() {
    backend = FakeBackend();
    store = MemorySessionStore();
  });

  test('GitHub girişi: challenge GitHub\'a, eşleşen verifier backend\'e gider', () async {
    late Uri authorizeUrl;
    final auth = service((url, scheme) async {
      authorizeUrl = Uri.parse(url);
      final state = authorizeUrl.queryParameters['state'];
      return '${AuthService.redirectUri}?code=kod123&state=$state';
    });

    final session = await auth.loginWithGitHub();

    final q = authorizeUrl.queryParameters;
    expect(q['client_id'], 'test-client');
    // Testler web dışında (VM) koşar: Android OAuth App'i istenir, dönüş devpulse:// olur.
    final configReq = backend.requests.firstWhere((r) => r.url.path == '/auth/config');
    expect(configReq.url.queryParameters['platform'], 'android');
    expect(q['redirect_uri'], 'devpulse://oauth-callback');
    expect(q['scope'], 'read:user');
    expect(q['code_challenge_method'], 'S256');

    final sent = backend.bodyOf('/auth/github');
    expect(sent['code'], 'kod123');
    // PKCE'nin özü: backend'e giden verifier, GitHub'a giden özetle eşleşmeli.
    expect(Pkce.challengeFor(sent['code_verifier'] as String), q['code_challenge']);
    expect(q.containsKey('code_verifier'), isFalse); // verifier GitHub'a hiç gitmez

    expect(session.login, 'ben');
    expect(session.githubToken, 'gho_test');
    expect((await store.read())?.sessionToken, 'jwt-ben');
    expect(auth.api.sessionToken, 'jwt-ben');
  });

  test('state uyuşmazsa giriş reddedilir ve backend\'e kod gönderilmez', () async {
    final auth = service((url, scheme) async => 'x://cb?code=kod&state=SALDIRGAN');
    await expectLater(auth.loginWithGitHub(), throwsA(isA<AuthException>()));
    expect(backend.called('/auth/github'), isFalse);
    expect(await store.read(), isNull);
  });

  test('kullanıcı GitHub\'da reddederse anlaşılır hata', () async {
    final auth = service((url, scheme) async => 'x://cb?error=access_denied');
    await expectLater(
      auth.loginWithGitHub(),
      throwsA(predicate((e) => '$e'.contains('reddedildi'))),
    );
  });

  test('giriş penceresi kapatılırsa anlaşılır hata', () async {
    final auth = service((url, scheme) async => throw Exception('CANCELED'));
    await expectLater(
      auth.loginWithGitHub(),
      throwsA(predicate((e) => '$e'.contains('kapatıldı'))),
    );
  });

  test('restore kayıtlı oturumu yükler, logout siler', () async {
    final auth = service((url, scheme) async => '');
    await auth.loginDemo();

    final fresh = service((url, scheme) async => '');
    final restored = await fresh.restore();
    expect(restored?.login, 'demo-gelistirici');
    expect(restored?.isDemo, isTrue);
    expect(fresh.api.sessionToken, 'jwt-demo-gelistirici');

    await fresh.logout();
    expect(await store.read(), isNull);
    expect(fresh.api.sessionToken, isNull);
  });

  test('çıkış ve hesap silme telefondaki CV bilgilerini de siler', () async {
    for (final deleteAccount in [false, true]) {
      final cv = MemoryCvProfileStore();
      await cv.write(CvProfile(fullName: 'Ad Soyad', email: 'a@example.com'));
      await store.write(const Session(sessionToken: 'jwt', githubToken: null, userId: 1, login: 'ben'));
      final s = AuthService(
        api: ApiClient(baseUrl: 'http://test', client: backend.client)..sessionToken = 'jwt',
        store: store,
        cvStore: cv,
      );
      if (deleteAccount) {
        await s.deleteAccount(revokeGitHub: false);
      } else {
        await s.logout();
      }
      expect(cv.saved, isNull, reason: deleteAccount ? 'Verilerimi sil' : 'çıkış');
    }
  });
}
