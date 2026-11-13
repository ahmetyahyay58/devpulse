import 'api_client.dart';

/// Backend'deki bir senkron işinin durumu (GET /sync/jobs/...).
class SyncJob {
  const SyncJob({
    required this.id,
    required this.status,
    this.phase = 'profile',
    required this.progress,
    required this.reposTotal,
    required this.reposDone,
    required this.reposSkipped,
    this.commitsSynced = 0,
    required this.commitsInserted,
    required this.calendarDays,
    required this.requestCount,
    required this.totalDurationMs,
    required this.error,
    required this.finishedAt,
  });

  final int id;
  final String status; // pending | running | done | failed
  final String phase; // profile | repos | commits | calendar | done (hata: hatanın aşaması)
  final double? progress; // 0-1; repo sayısı henüz bilinmiyorsa null
  final int? reposTotal;
  final int reposDone;
  final int reposSkipped;
  final int commitsSynced; // GitHub'dan gelen (yeni + zaten var olan)
  final int commitsInserted;
  final int calendarDays;
  final int requestCount;
  final int totalDurationMs;
  final String? error;
  final DateTime? finishedAt;

  bool get isActive => status == 'pending' || status == 'running';

  factory SyncJob.fromJson(Map<String, dynamic> j) => SyncJob(
        id: j['id'] as int,
        status: j['status'] as String,
        phase: j['phase'] as String? ?? 'profile',
        progress: (j['progress'] as num?)?.toDouble(),
        reposTotal: j['repos_total'] as int?,
        reposDone: j['repos_done'] as int,
        reposSkipped: j['repos_skipped'] as int,
        commitsSynced: j['commits_synced'] as int? ?? 0,
        commitsInserted: j['commits_inserted'] as int,
        calendarDays: j['calendar_days'] as int,
        requestCount: j['request_count'] as int,
        totalDurationMs: j['total_duration_ms'] as int,
        error: j['error'] as String?,
        finishedAt: j['finished_at'] == null ? null : DateTime.parse(j['finished_at'] as String),
      );
}

class SyncApi {
  SyncApi(this.api);
  final ApiClient api;

  /// Senkronu başlatır, iş numarasını döner. Zaten süren iş varsa (409) onun numarasını döner.
  Future<int> start({String? githubToken, String? timezone}) async {
    try {
      // '?değer': değer null ise o anahtar hiç eklenmez (Dart 3.8 null-aware öğe).
      final r = await api.post('/sync', {
        'github_token': ?githubToken,
        'timezone': ?timezone,
      });
      return r['job_id'] as int;
    } on ApiException catch (e) {
      final detail = e.detail;
      if (e.statusCode == 409 && detail is Map && detail['job_id'] is int) {
        return detail['job_id'] as int; // yenisini başlatma, süreni izle
      }
      rethrow;
    }
  }

  Future<SyncJob> job(int id) async => SyncJob.fromJson(await api.get('/sync/jobs/$id'));

  /// Şu ana kadar yazılmış commit'lerin günlük sayısı (son [weeks] hafta, eskiden yeniye).
  Future<List<(DateTime, int)>> commitDays({int weeks = 30}) async {
    final r = await api.get('/sync/commit-days?weeks=$weeks');
    return [
      for (final d in r['days'] as List)
        (DateTime.parse(d['day'] as String), d['count'] as int),
    ];
  }

  /// En son iş; hiç senkron yapılmadıysa null.
  Future<SyncJob?> latest() async {
    try {
      return SyncJob.fromJson(await api.get('/sync/jobs/latest'));
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }
}
