import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Giriş yapmış kullanıcının oturumu.
class Session {
  const Session({
    required this.sessionToken,
    required this.githubToken,
    required this.userId,
    required this.login,
  });

  final String sessionToken; // backend'e bağlanmak için JWT
  final String? githubToken; // senkron için; demo kullanıcıda null
  final int userId;
  final String login;

  bool get isDemo => githubToken == null;

  factory Session.fromLoginResponse(Map<String, dynamic> json) => Session(
        sessionToken: json['session_token'] as String,
        githubToken: json['github_token'] as String?,
        userId: (json['user'] as Map)['id'] as int,
        login: (json['user'] as Map)['login'] as String,
      );

  Map<String, dynamic> toJson() => {
        'session_token': sessionToken,
        'github_token': githubToken,
        'user': {'id': userId, 'login': login},
      };
}

/// Oturumu saklayan arayüz: uygulamada güvenli depo, testlerde bellek.
abstract class SessionStore {
  Future<Session?> read();
  Future<void> write(Session session);
  Future<void> clear();
}

/// Android'de şifreli Keystore'u kullanır. (Web'de tarayıcı deposu kullanılır;
/// telefondaki kadar güvenli değildir, yalnızca geliştirme yedeği olarak.)
class SecureSessionStore implements SessionStore {
  SecureSessionStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _key = 'devpulse_session';

  @override
  Future<Session?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    try {
      return Session.fromLoginResponse(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      await clear(); // bozuk kayıt: yok say
      return null;
    }
  }

  @override
  Future<void> write(Session session) =>
      _storage.write(key: _key, value: jsonEncode(session.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

class MemorySessionStore implements SessionStore {
  Session? _session;

  @override
  Future<Session?> read() async => _session;

  @override
  Future<void> write(Session session) async => _session = session;

  @override
  Future<void> clear() async => _session = null;
}
