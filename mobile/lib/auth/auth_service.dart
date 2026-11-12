import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../api/api_client.dart';
import 'pkce.dart';
import 'session_store.dart';

class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Tarayıcıda giriş sayfasını açıp dönüş adresini veren fonksiyon.
/// Testlerde sahtesi verilir; uygulamada FlutterWebAuth2.authenticate.
typedef BrowserAuth = Future<String> Function(String url, String callbackScheme);

Future<String> _flutterWebAuth(String url, String callbackScheme) =>
    FlutterWebAuth2.authenticate(url: url, callbackUrlScheme: callbackScheme);

/// GitHub girişi (yetki kodu + PKCE) ve oturum yönetimi.
class AuthService {
  AuthService({required this.api, required this.store, BrowserAuth? browserAuth})
      : _browserAuth = browserAuth ?? _flutterWebAuth;

  final ApiClient api;
  final SessionStore store;
  final BrowserAuth _browserAuth;

  // Web: uygulamanın kendi adresindeki auth.html. Android: devpulse:// şeması.
  static String get redirectUri =>
      kIsWeb ? '${Uri.base.origin}/auth.html' : 'devpulse://oauth-callback';
  static String get _callbackScheme => kIsWeb ? 'http' : 'devpulse';

  /// Uygulama açılırken: daha önce giriş yapılmışsa oturumu geri yükler.
  Future<Session?> restore() async {
    final session = await store.read();
    api.sessionToken = session?.sessionToken;
    return session;
  }

  Future<Session> loginDemo() async => _save(await api.post('/auth/demo'));

  Future<Session> loginWithGitHub() async {
    final config = await api.get('/auth/config');
    final pkce = Pkce.generate();
    final state = randomUrlSafe(32); // CSRF koruması: dönüşte aynısı gelmeli

    final authorizeUrl = Uri.parse(config['authorize_url'] as String).replace(queryParameters: {
      'client_id': config['client_id'] as String,
      'redirect_uri': redirectUri,
      'scope': config['scope'] as String,
      'state': state,
      'code_challenge': pkce.challenge, // GitHub'a yalnızca özet gider
      'code_challenge_method': 'S256',
    });

    final String result;
    try {
      result = await _browserAuth(authorizeUrl.toString(), _callbackScheme);
    } catch (_) {
      throw AuthException('Giriş penceresi kapatıldı.');
    }

    final params = Uri.parse(result).queryParameters;
    if (params['error'] != null) {
      throw AuthException(params['error'] == 'access_denied'
          ? 'GitHub girişi reddedildi.'
          : 'GitHub hatası: ${params['error']}');
    }
    if (params['state'] != state) {
      throw AuthException('Güvenlik kontrolü başarısız (state uyuşmuyor).');
    }
    final code = params['code'];
    if (code == null) throw AuthException('GitHub dönüşünde kod yok.');

    // Kod + verifier backend'e gider; backend client_secret ile token'a çevirir.
    return _save(await api.post('/auth/github', {
      'code': code,
      'code_verifier': pkce.verifier,
      'redirect_uri': redirectUri,
    }));
  }

  Future<void> logout() async {
    api.sessionToken = null;
    await store.clear();
  }

  Future<Session> _save(Map<String, dynamic> response) async {
    final session = Session.fromLoginResponse(response);
    await store.write(session);
    api.sessionToken = session.sessionToken;
    return session;
  }
}
