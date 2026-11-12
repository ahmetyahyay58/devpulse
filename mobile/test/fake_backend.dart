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

  // --- Metrik taklidi ---
  Map<String, dynamic> overview = sampleOverview();

  static Map<String, dynamic> section(String sufficiency, String summary, Map<String, dynamic> extra) => {
        'sufficiency': sufficiency, 'basis': 'test dayanağı', 'summary': summary,
        'how': 'Test: nasıl hesaplandı metni.', ...extra,
      };

  static Map<String, dynamic> sampleOverview({int totalCommits = 33}) => {
        'timezone': 'Europe/Istanbul', 'timezone_known': true, 'today': '2026-11-12',
        'kpi': {
          'total_commits': totalCommits, 'active_days': 10, 'repos': 4,
          'current_streak': 1, 'commits_last_30_days': 5,
        },
        'continuity': section('normal', 'Son 90 günde aktif gün oranın %1; en uzun serin 7 gün.', {
          'current_streak': 1, 'longest_streak': 7, 'active_ratio_90d': 0.011,
        }),
        'rhythm': section('dusuk', "Commit'lerin en çok 13:00-13:59 arasında.", {
          'by_hour': List.generate(24, (h) => h == 13 ? 18 : 1),
          'by_weekday': [4, 9, 7, 2, 7, 2, 2],
          'peak_hour': 13, 'night_share': 0.0, 'weekend_share': 0.12,
        }),
        'sessions': section('yetersiz', 'Bu metrik için henüz yeterli veri yok (2 oturum).', {
          'count': 2, 'commits_per_session': 2.0, 'session_minutes': 4.5,
          'commits_per_active_day': 2.0, 'lines_per_commit': 14.0,
        }),
      };

  int overviewCalls = 0;

  late final client = MockClient((request) async {
    requests.add(request);
    final path = request.url.path;
    if (path == '/metrics/overview') {
      overviewCalls++;
      return _json(overview);
    }
    if (path == '/metrics/calendar') {
      final start = DateTime(2026, 11, 6);
      return _json({
        'days': [
          for (var k = 0; k < 7; k++)
            {'day': start.add(Duration(days: k)).toIso8601String().substring(0, 10), 'count': k == 5 ? 5 : 0},
        ],
        'total': 5,
        'note': 'Takvim PR ve issue da sayar.',
      });
    }
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
