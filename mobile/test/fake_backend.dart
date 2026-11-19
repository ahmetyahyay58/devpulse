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
    job(7, 'running', phase: 'commits', reposTotal: 2, reposDone: 0, progress: 0.0),
    job(7, 'running', phase: 'calendar', reposTotal: 2, reposDone: 2, progress: 2 / 3),
    job(7, 'done', phase: 'done', reposTotal: 2, reposDone: 2, progress: 1.0, commitsInserted: 6),
  ];
  int commitDaysCalls = 0;
  /// Varsayılan: daha önce senkron yapmış kullanıcı. null: hiç senkron yok (404) = ilk giriş;
  /// ana ekran o zaman senkronu kendiliğinden başlatır.
  Map<String, dynamic>? latestJob =
      job(5, 'done', reposTotal: 4, reposDone: 4, progress: 1.0, commitsInserted: 12);
  int? runningJobId; // doluysa POST /sync 409 döner (zaten süren iş)
  bool sessionExpired = false; // doluysa /sync uçları 401 döner
  bool exportFails = false; // doluysa /me/export 500 döner
  // AI katmanı: sunucuda anahtar var mı ve kullanıcının onayı (POST /ai/consent değiştirir).
  bool aiLlmReady = true;
  bool aiConsent = false;
  bool aiStatusFails = false;

  static const aiFacts = {'toplam_commit': 33, 'aktif_gun': 12, 'gece_payi_yuzde': 22, 'baskin_dil': 'Dart',
      'cesitlilik': 0.41, 'yil_degisim_yuzde': null, 'eksik_proje': {'lisans': 2}};

  Map<String, dynamic> aiStatus() => {
        'consent': aiConsent, 'consent_at': null, 'llm_ready': aiLlmReady, 'provider': 'Google Gemini',
        'model': 'gemini-flash-latest',
        'questions': [
          {'id': 'ozet', 'kind': 'sor', 'text': 'Çalışma alışkanlığımı kısaca özetler misin?'},
          {'id': 'guclu', 'kind': 'sor', 'text': 'Güçlü yanım ne?'},
          {'id': 'gelistir', 'kind': 'sor', 'text': 'Neyi geliştirebilirim?'},
          {'id': 'projeler', 'kind': 'sor', 'text': 'Projelerimi nasıl iyileştiririm?'},
          {'id': 'ritim', 'kind': 'sor', 'text': 'Genelde ne zaman çalışıyorum?'},
          {'id': 'neden_sureklilik', 'kind': 'neden', 'text': 'Süreklilik sonucum neden böyle?'},
          {'id': 'ipucu', 'kind': 'ipucu', 'text': 'Bana tek cümlelik bir öneri verir misin?'},
        ],
      };
  /// Yıllık özet (GET /metrics/year-summary); testler alanları değiştirebilir.
  Map<String, dynamic> yearSummary = {
    'year': 2026, 'period_start': '2026-01-01', 'period_end': '2026-11-14', 'commits': 120, 'active_days': 40,
    'busiest_month': 3, 'busiest_month_commits': 30, 'top_language': 'Dart', 'top_language_share': 0.6,
    'night_share': 0.25, 'peak_hour': 23, 'longest_streak': 7, 'coding_hours': 18, 'sessions': 50,
    'language_journey': [
      {'language': 'Python', 'first_month': 1, 'commits': 40},
      {'language': 'Dart', 'first_month': 3, 'commits': 72},
    ],
    'reviews': 4, 'badges_unlocked': 2, 'badges_total': 8, 'sufficiency': 'normal',
  };
  int _jobReads = 0;

  static Map<String, dynamic> job(int id, String status,
          {String? phase, int? reposTotal, int reposDone = 0, double? progress, int commitsInserted = 0,
          String? error}) =>
      {
        'id': id, 'status': status, 'phase': phase ?? (status == 'done' ? 'done' : 'repos'),
        'progress': progress, 'repos_total': reposTotal,
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
          'longest_minutes': 95.0, 'longest_day': '2026-10-02', 'common_start_hour': 14,
        }),
      };

  int overviewCalls = 0;
  int projectsCalls = 0;

  static Map<String, dynamic> typeShare(String label, String tr, int count, double share,
          [List<Map<String, dynamic>> examples = const []]) =>
      {'label': label, 'label_tr': tr, 'count': count, 'share': share, 'examples': examples};

  Map<String, dynamic> commitTypes = section(
    'normal',
    "Commit'lerin en çok 'Belgelendirme' türünde: 19 commit (%58).",
    {
      'total': 33,
      'types': [
        typeShare('docs', 'Belgelendirme', 19, 19 / 33, [
          {'headline': 'Update README.md', 'repo': 'proje', 'authored_at': '2026-11-11T10:00:00Z',
           'source': 'kural', 'reason': 'Markdown dosyası'},
        ]),
        typeShare('feat', 'Yeni özellik', 8, 8 / 33, [
          {'headline': 'profil sayfası', 'repo': 'proje', 'authored_at': '2026-11-10T10:00:00Z',
           'source': 'model', 'reason': 'model, %72 güven'},
        ]),
        typeShare('fix', 'Hata düzeltme', 6, 6 / 33),
        typeShare('test', 'Test', 0, 0),
      ],
      'by_source': {'kural': 30, 'model': 3},
      'note': 'Türler yaklaşık bir tahmindir: %63 doğru (kappa 0,53).',
    },
  );

  /// 8 hafta: ilk 4 hafta ~1 commit (Evre 1), son 4 hafta ~5 commit (Evre 2).
  Map<String, dynamic> changePoints = section(
    'dusuk',
    "1 değişim noktası bulundu. Son değişim 19.10.2026 haftasında: haftalık ortalama 1 commit'ten 5 commit'e arttı.",
    {
      'weeks': [
        for (var i = 0; i < 8; i++)
          {
            'start': DateTime(2026, 9, 21).add(Duration(days: 7 * i)).toIso8601String().substring(0, 10),
            'commits': i < 4 ? 1 : 5,
            'phase': i < 4 ? 0 : 1,
          },
      ],
      'phases': [
        {'index': 0, 'start': '2026-09-21', 'end': '2026-10-12', 'weeks': 4, 'mean': 1.0},
        {'index': 1, 'start': '2026-10-19', 'end': '2026-11-09', 'weeks': 4, 'mean': 5.0},
      ],
    },
  );

  Map<String, dynamic> technology = section(
    'dusuk',
    '3 dil kullanıyorsun; en çok Python (kodun %80 kadarı). Dil dağılımının dengesi %57.',
    {
      'repo_count': 2, 'language_count': 3, 'dominant': 'Python', 'dominant_share': 0.8,
      'diversity': 0.5693,
      'languages': [
        {'name': 'Python', 'bytes': 8000, 'share': 0.8, 'repos': 2},
        {'name': 'Dart', 'bytes': 1000, 'share': 0.1, 'repos': 1},
        {'name': 'Diğer', 'bytes': 50, 'share': 0.005, 'repos': 1},
      ],
      'tools': [
        {'name': 'Docker', 'repos': 2},
        {'name': 'GitHub Actions', 'repos': 1},
      ],
    },
  );

  Map<String, dynamic> anomalies = section(
    'normal',
    '1 gün alışkanlığının belirgin dışında yoğundu. En yoğunu 02.10.2026: 23 commit.',
    {
      'flagged': [
        {'day': '2026-10-02', 'commits': 23, 'lines': 900, 'robust_z': 8.09},
      ],
      'active_days': 114, 'median_commits': 3.0, 'mad': 1.0, 'threshold': 3.5,
    },
  );

  static Map<String, dynamic> check(String key, String label, String status, [String? hint]) =>
      {'key': key, 'label': label, 'weight': 25, 'status': status, 'hint': hint};

  static Map<String, dynamic> project(String name, int? score, List<Map<String, dynamic>> checks,
          {bool owner = true, String? reason, String state = 'aktif', List<String> topics = const [],
          List<int>? weekly, String? suggestion}) =>
      {
        'name': name, 'language': 'Python', 'is_private': false, 'is_fork': false, 'is_owner': owner,
        'scored': reason == null, 'not_scored_reason': reason, 'score': score, 'checks': checks,
        'days_since_push': 3, 'commit_count': 4, 'state': state, 'topics': topics,
        'weekly_commits': weekly ?? [0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 2, 1], 'suggestion': suggestion,
      };

  Map<String, dynamic> projects = {
    'summary': {
      'scored_count': 2, 'average_score': 70,
      'missing_counts': {'readme': 0, 'description': 0, 'license': 2, 'topics': 1},
      'summary': 'Puanlanan 2 reponun ortalama skoru 70/100. En sık eksik: Lisans (2/2 repoda).',
      'how': 'Test: proje sağlığı nasıl hesaplandı.',
    },
    'projects': [
      project('eksikli-repo', 60, topics: ['flutter', 'dart'],
          suggestion: 'Şu eksikleri kapatırsan skor 40 puan artar: Lisans, Topic.', [
        check('readme', 'README', 'ok'), check('description', 'Açıklama', 'ok'),
        check('license', 'Lisans', 'missing', 'LICENSE dosyası ekle.'),
        check('topics', 'Topic', 'missing', 'Topic ekle.'),
      ]),
      project('iyi-repo', 80, state: 'arsiv', weekly: List.filled(12, 0), [
        check('readme', 'README', 'ok'), check('description', 'Açıklama', 'ok'),
        check('license', 'Lisans', 'missing', 'LICENSE dosyası ekle.'),
        check('topics', 'Topic', 'ok'),
      ]),
      project('katki-repo', null, [], owner: false, reason: 'Başkasına ait repo.', state: 'durgun'),
    ],
  };

  late final client = MockClient((request) async {
    requests.add(request);
    final path = request.url.path;
    if (path == '/privacy') {
      return http.Response.bytes(
        utf8.encode('# DevPulse Aydınlatma Metni\n\n## Saklanmayan veriler\n- E-posta adresin.\n'),
        200,
        headers: {'content-type': 'text/plain; charset=utf-8'},
      );
    }
    if (path == '/me/export') {
      if (exportFails) return _json({'detail': 'Sunucuda bir hata oluştu.'}, 500);
      return _json({'user': {'github_login': 'ben'}, 'repos': [], 'commits': []});
    }
    if (path == '/ai/status') {
      if (aiStatusFails) return _json({'detail': 'Sunucuda bir hata oluştu.'}, 500);
      return _json(aiStatus());
    }
    if (path == '/ai/consent') {
      aiConsent = (jsonDecode(request.body) as Map)['enabled'] as bool;
      return _json(aiStatus());
    }
    if (path == '/ai/facts') return _json({'facts': aiFacts, 'note': 'Yalnızca bu sayılar gider.'});
    if (path == '/ai/ask') {
      final id = (jsonDecode(request.body) as Map)['question'] as String;
      final llm = aiConsent && aiLlmReady;
      return _json({
        'question_id': id, 'question': id,
        'answer': llm ? 'LLM cevabı: $id' : 'Şablon cevabı: $id',
        'source': llm ? 'llm' : 'sablon',
        'reason': llm ? null : (aiLlmReady ? 'Yapay zekâ yorumlarına onay vermedin.' : 'Sunucuda yapay zekâ anahtarı tanımlı değil.'),
        'facts': aiFacts,
      });
    }
    if (path == '/ai/interview') {
      final id = (jsonDecode(request.body) as Map)['project_id'] as String;
      return _json({
        'project_id': id,
        'questions': ['Soru 1 ($id)', 'Soru 2', 'Soru 3'],
        'evidence': ['Bağlantıyı hazır tut: github.com/ben/proje-a', 'README ekle.'],
        'source': 'sablon',
        'reason': 'Yapay zekâ yorumlarına onay vermedin.',
        'facts': {'ana_dil': 'Dart', 'araclar': ['Docker'], 'commit_sayisi': 12, 'eksik_belgeler': <String>[]},
      });
    }
    if (path == '/metrics/model-lab') {
      return _json({
        'system': 'Önce kurallar, sonra model.',
        'training': '2479 Türkçe commit mesajı.',
        'classes': ['Yeni özellik', 'Hata düzeltme'],
        'scores': [
          {'reference': 'Yapay zekânın kör etiketleri (test standardı)', 'messages': 98, 'accuracy': '0.63', 'kappa': '0.53'},
          {'reference': 'Geliştiricinin kör etiketleri', 'messages': 94, 'accuracy': '0.39', 'kappa': '0.24'},
        ],
        'random_baseline': '~0,14', 'human_check': '19/20',
        'confusions': ['Bakım → Kod düzenleme (5)'],
        'caveats': ['0,41 → 0,63 artışı sistemin iyileşmesinden değil, referansın değişmesinden kaynaklanır.'],
        'source': 'docs/olcumler.md',
      });
    }
    if (path == '/me' && request.method == 'GET') {
      return _json({
        'login': 'ben', 'avatar_url': null, 'created_at': '2026-11-01T10:00:00Z', 'last_synced_at': '2026-11-13T17:05:00Z',
        'last_active_at': '2026-11-13T17:05:00Z', 'delete_after': '2027-02-11T17:05:00Z',
        'retention_days': 90,
        'counts': {'repos': 4, 'commits': 33, 'contribution_days': 1048, 'sync_jobs': 12},
        'scope': {
          'first_commit_at': '2025-03-02T09:00:00Z', 'last_commit_at': '2026-11-13T16:00:00Z',
          'owned_repos': 3, 'contributed_repos': 1, 'forks': 1, 'archived': 0,
        },
      });
    }
    if (path == '/me' && request.method == 'DELETE') {
      final hasToken = (jsonDecode(request.body) as Map).containsKey('github_token');
      return _json({
        'deleted': {'repos': 4, 'commits': 33, 'contribution_days': 1047, 'sync_jobs': 12},
        'github_grant_revoked': hasToken ? true : null,
      });
    }
    if (path == '/projects') {
      projectsCalls++;
      return _json(projects);
    }
    if (path == '/metrics/overview') {
      overviewCalls++;
      return _json(overview);
    }
    if (path == '/metrics/commit-types') {
      return _json(commitTypes);
    }
    if (path == '/metrics/anomalies') {
      return _json(anomalies);
    }
    if (path == '/metrics/year-summary') return _json(yearSummary);
    if (path == '/metrics/weekly') {
      return _json({
        'this_week': {'start': '2026-11-09', 'end': '2026-11-11', 'commits': 5, 'active_days': 2, 'repos': 1},
        'last_week': {'start': '2026-11-02', 'end': '2026-11-04', 'commits': 3, 'active_days': 3, 'repos': 2},
        'difference': 2, 'sufficiency': 'normal',
        'summary': 'Bu hafta 5 commit, 2 aktif gün; geçen haftanın aynı günlerine göre 2 commit fazla.',
      });
    }
    if (path == '/projects/clusters') {
      return _json({
        'sufficiency': 'dusuk', 'repo_count': 6, 'k': 2, 'silhouette': null,
        'summary': '6 kendi repo, benzerliklerine göre 2 gruba ayrıldı.',
        'how': 'Gözetimsiz k-means; doğruluk ölçülmez.',
        'clusters': [
          {'name': 'Aktif, belgeli', 'repos': ['hava-durumu', 'blog'], 'top_language': 'Dart',
           'median_commits': 40.0, 'median_days_since_push': 3.0, 'median_score': 85.0},
          {'name': 'Durağan, belgesi eksik', 'repos': ['eski-odev'], 'top_language': null,
           'median_commits': 5.0, 'median_days_since_push': 400.0, 'median_score': null},
        ],
      });
    }
    if (path == '/metrics/achievements') {
      Map<String, dynamic> badge(String key, String name, int current, int target) => {
            'key': key, 'name': name, 'description': '$name açıklaması.',
            'current': current, 'target': target, 'unlocked': current >= target,
          };
      return _json({
        'badges': [
          badge('streak7', 'Bir haftalık seri', 7, 7),
          badge('streak30', 'Bir aylık seri', 7, 30),
          badge('regular', 'Düzenli', 4, 27),
          badge('showcase', 'Vitrin', 80, 100),
          badge('docs', 'Belgelendirici', 2, 2),
          badge('license', 'Lisanslı', 0, 2),
          badge('polyglot', 'Çok dilli', 2, 3),
          badge('contributor', 'Katkıcı', 0, 1),
        ],
        'unlocked': 2,
        'year': {
          'this_year': 2026, 'last_year': 2025, 'period_end': '2026-11-14',
          'stats': [
            {'label': 'Commit', 'this_year': 33, 'last_year': 22, 'change_pct': 50},
            {'label': 'Aktif gün', 'this_year': 10, 'last_year': 10, 'change_pct': 0},
            {'label': 'En uzun seri (gün)', 'this_year': 7, 'last_year': 3, 'change_pct': 133},
            {'label': 'Commit atılan repo', 'this_year': 3, 'last_year': 0, 'change_pct': null},
          ],
          'sufficiency': 'normal', 'basis': 'bu yıl 33, geçen yıl 22 commit',
          'summary': 'Yılbaşından bu yana geçen yılın aynı dönemine göre %50 daha fazla commit; aktif gün 10 (geçen yıl 10).',
          'how': 'Test: yıl kıyası.',
        },
      });
    }
    if (path == '/cv/draft') {
      final en = request.url.queryParameters['lang'] == 'en';
      Map<String, dynamic> item(String id, String text, String source, {bool placeholder = false}) =>
          {'id': id, 'text': text, 'source': source, 'placeholder': placeholder};
      return _json({
        'lang': en ? 'en' : 'tr', 'login': 'ben', 'profile_url': 'https://github.com/ben',
        'summary': item('summary', en ? 'Mostly working with Dart.' : 'Ağırlıklı olarak Dart ile çalışıyorum.',
            'Genel Bakış sayıları'),
        'projects': [
          {
            'id': 'proj:R_a', 'name': 'proje-a', 'url': 'https://github.com/ben/proje-a',
            'tech': ['Dart', 'Docker'], 'start': '2025-03-01', 'end': '2026-02-07',
            'items': [
              item('proj:R_a:desc', 'Hava durumu servisi', 'GitHub repo açıklaması'),
              item('proj:R_a:stack', 'Dart ile geliştirildi; araçlar: Docker.', 'Dil dağılımı'),
              item('proj:R_a:work', 'Commit sayısı: 12; README ile belgelendi.', 'Senkronlanan commit\'ler'),
              item('proj:R_a:impact', 'Etki: [ör. kullanıcı sayısı]', 'Bu sayıyı sen yazarsın', placeholder: true),
            ],
          },
          // Seçim listesi için: varsayılan seçili değil (sağlık puanına göre ilk 6 dışında kaldı).
          for (final n in ['b', 'c', 'd', 'e', 'f', 'g'])
            {
              'id': 'proj:R_$n', 'name': 'proje-$n', 'url': 'https://github.com/ben/proje-$n', 'tech': ['Python'],
              'start': null, 'end': null, 'default_selected': n == 'b',
              'items': [item('proj:R_$n:desc', 'Proje $n açıklaması', 'GitHub repo açıklaması')],
            },
        ],
        'skills': [item('skills:languages', 'Diller: Dart, Python', 'Dil dağılımı')],
        'activity': [item('act:commits', 'Toplam commit: 33; aktif gün: 12; en uzun seri: 7 gün.', "Commit'ler")],
        'languages': ['Dart', 'Python'], 'tools': ['Docker'],
      });
    }
    if (path == '/metrics/collaboration') {
      Map<String, dynamic> group(int o, int m, int c, int open, double? rate, double? hours) => {
            'opened': o, 'merged': m, 'closed_unmerged': c, 'still_open': open,
            'merge_rate': rate, 'median_merge_hours': hours,
          };
      return _json({
        'total': group(12, 9, 2, 1, 0.818, 6.0),
        'own': group(5, 5, 0, 0, 1.0, 2.0),
        'others': group(7, 4, 2, 1, 0.667, 60.0),
        'reviews_total': 18, 'reviews_this_year': 11,
        'years': [
          {'year': 2025, 'prs': 4, 'reviews': 7},
          {'year': 2026, 'prs': 8, 'reviews': 11},
        ],
        'monthly_group': 'others',
        'monthly': [
          for (var i = 0; i < 12; i++)
            {
              'month': '${i < 2 ? 2025 : 2026}-${((i + 10) % 12 + 1).toString().padLeft(2, '0')}',
              'merged': i == 9 ? 3 : (i == 11 ? 1 : 0),
              'median_merge_hours': i == 9 ? 60.0 : (i == 11 ? 5.0 : null),
            },
        ],
        'sufficiency': 'normal', 'basis': '11 sonuçlanmış PR, 18 inceleme',
        'summary': 'Başkalarının repolarına açılan PR: 7, merge edilen: 4 (oran %67).',
        'how': 'Test: işbirliği nasıl hesaplandı.',
      });
    }
    if (path == '/metrics/technology') {
      return _json(technology);
    }
    if (path == '/metrics/change-points') {
      return _json(changePoints);
    }
    if (path == '/metrics/catalog') {
      return _json({
        'entries': [
          {
            'name': 'Oturum', 'section': 'Oturum', 'definition': 'Test tanımı.', 'unit': 'oturum',
            'interpretation': 'Test yorumu.', 'reliable_when': 'En az 15 oturum.',
          },
        ],
      });
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
      if (path == '/sync/commit-days') {
        // Her soruluşta bir gün daha dolu: takvimin "dolması"nı taklit eder.
        commitDaysCalls++;
        final start = DateTime(2026, 11, 6);
        return _json({
          'days': [
            for (var k = 0; k < 7; k++)
              {'day': start.add(Duration(days: k)).toIso8601String().substring(0, 10),
               'count': k < commitDaysCalls ? 2 : 0},
          ],
        });
      }
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
