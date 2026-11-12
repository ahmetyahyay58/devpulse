import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Testler için sahte backend: istekleri kaydeder, yola göre hazır cevap döner.
class FakeBackend {
  final requests = <http.Request>[];
  Map<String, dynamic> health = {'status': 'ok', 'database': 'ok'};

  // --- Senkron taklidi ---
  /// GET /sync/jobs/{id} her sorulduğunda sıradaki durum döner; sonuncusu tekrarlanır.
  List<Map<String, dynamic>> jobStates = [
    job(7, 'running', reposTotal: 2, reposDone: 0, progress: 0.0),
    job(7, 'running', reposTotal: 2, reposDone: 2, progress: 2 / 3),
    job(7, 'done', reposTotal: 2, reposDone: 2, progress: 1.0, commitsInserted: 6),
  ];
  Map<String, dynamic>? latestJob; // null: hiç senkron yapılmamış (404)
  int? runningJobId; // doluysa POST /sync 409 döner (zaten süren iş)
  bool sessionExpired = false; // doluysa /sync uçları 401 döner
  int _jobReads = 0;

  static Map<String, dynamic> job(int id, String status,
          {int? reposTotal, int reposDone = 0, double? progress, int commitsInserted = 0, String? error}) =>
      {
        'id': id, 'status': status, 'progress': progress, 'repos_total': reposTotal,
        'repos_done': reposDone, 'repos_skipped': 0, 'commits_synced': commitsInserted,
        'commits_inserted': commitsInserted, 'calendar_days': 7, 'request_count': 5,
        'total_cost': 0, 'total_duration_ms': 1200, 'error': error,
        'created_at': '2026-11-12T10:00:00Z', 'started_at': '2026-11-12T10:00:00Z',
        'finished_at': status == 'done' || status == 'failed' ? '2026-11-12T10:00:02Z' : null,
      };

  late final client = MockClient((request) async {
    requests.add(request);
    final path = request.url.path;
    if (path.startsWith('/sync')) {
      if (sessionExpired) return _json({'detail': 'Oturumun süresi doldu'}, 401);
      if (path == '/sync' && runningJobId != null) {
        return _json({'detail': {'message': 'zaten sürüyor', 'job_id': runningJobId}}, 409);
      }
      if (path == '/sync') return _json({'job_id': 7, 'status': 'pending'}, 202);
      if (path == '/sync/jobs/latest') {
        return latestJob == null ? _json({'detail': 'yok'}, 404) : _json(latestJob!);
      }
      final state = jobStates[_jobReads < jobStates.length ? _jobReads : jobStates.length - 1];
      _jobReads++;
      return _json({...state, 'id': int.parse(path.split('/').last)});
    }
    switch (path) {
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

  static http.Response _json(Map<String, dynamic> body, [int status = 200]) => http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
}
