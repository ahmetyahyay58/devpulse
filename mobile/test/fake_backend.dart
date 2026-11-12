import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Testler için sahte backend: istekleri kaydeder, yola göre hazır cevap döner.
class FakeBackend {
  final requests = <http.Request>[];
  Map<String, dynamic> health = {'status': 'ok', 'database': 'ok'};

  late final client = MockClient((request) async {
    requests.add(request);
    switch (request.url.path) {
      case '/health':
        return _json(health);
      case '/auth/config':
        return _json({
          'client_id': 'test-client',
          'scope': 'read:user',
          'authorize_url': 'https://github.com/login/oauth/authorize',
        });
      case '/auth/demo':
        return _json(_login('demo-gelistirici', githubToken: null));
      case '/auth/github':
        return _json(_login('ben', githubToken: 'gho_test'));
    }
    return http.Response('{"detail":"Not Found"}', 404);
  });

  Map<String, dynamic> bodyOf(String path) =>
      jsonDecode(requests.lastWhere((r) => r.url.path == path).body) as Map<String, dynamic>;

  bool called(String path) => requests.any((r) => r.url.path == path);

  static Map<String, dynamic> _login(String login, {String? githubToken}) => {
        'session_token': 'jwt-$login',
        'github_token': githubToken,
        'user': {'id': 1, 'login': login},
      };

  static http.Response _json(Map<String, dynamic> body) => http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
}
