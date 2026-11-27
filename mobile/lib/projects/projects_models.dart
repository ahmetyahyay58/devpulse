/// GET /projects cevabının Dart karşılığı.
library;

class ProjectCheck {
  const ProjectCheck({required this.key, required this.label, required this.status, this.hint});
  final String key;
  final String label;
  final String status; // ok | missing | unknown
  final String? hint;

  factory ProjectCheck.fromJson(Map<String, dynamic> j) => ProjectCheck(
    key: j['key'] as String,
    label: j['label'] as String,
    status: j['status'] as String,
    hint: j['hint'] as String?,
  );
}

class Project {
  const Project({
    required this.name,
    required this.language,
    required this.isPrivate,
    required this.isFork,
    required this.scored,
    required this.notScoredReason,
    required this.score,
    required this.checks,
    required this.daysSincePush,
    required this.commitCount,
    this.state = 'durgun',
    this.topics = const [],
    this.weeklyCommits = const [],
    this.suggestion,
  });

  final String name;
  final String? language;
  final bool isPrivate;
  final bool isFork;
  final bool scored;
  final String? notScoredReason;
  final int? score;
  final List<ProjectCheck> checks;
  final int? daysSincePush;
  final int commitCount;
  final String state; // aktif | durgun | arsiv (skora girmez)
  final List<String> topics;
  final List<int> weeklyCommits; // son 12 hafta, eskiden yeniye
  final String? suggestion; // "Şu eksikleri kapatırsan skor N puan artar: ..."

  /// Durum etiketinin Türkçesi.
  String get stateLabel => switch (state) {
    'aktif' => 'Aktif',
    'arsiv' => 'Arşiv',
    _ => 'Durağan',
  };

  List<ProjectCheck> get missing => checks.where((c) => c.status == 'missing').toList();

  factory Project.fromJson(Map<String, dynamic> j) => Project(
    name: j['name'] as String,
    language: j['language'] as String?,
    isPrivate: j['is_private'] as bool,
    isFork: j['is_fork'] as bool,
    scored: j['scored'] as bool,
    notScoredReason: j['not_scored_reason'] as String?,
    score: j['score'] as int?,
    checks: [for (final c in j['checks'] as List) ProjectCheck.fromJson(c as Map<String, dynamic>)],
    daysSincePush: j['days_since_push'] as int?,
    commitCount: j['commit_count'] as int,
    state: j['state'] as String? ?? 'durgun',
    topics: [for (final t in j['topics'] as List? ?? const []) t as String],
    weeklyCommits: [for (final n in j['weekly_commits'] as List? ?? const []) n as int],
    suggestion: j['suggestion'] as String?,
  );
}

class ProjectsData {
  const ProjectsData({
    required this.projects,
    required this.scoredCount,
    required this.averageScore,
    required this.missingCounts,
    required this.summary,
    required this.how,
  });

  final List<Project> projects;
  final int scoredCount;
  final int? averageScore;
  final Map<String, int> missingCounts;
  final String summary;
  final String how;

  factory ProjectsData.fromJson(Map<String, dynamic> j) {
    final s = j['summary'] as Map<String, dynamic>;
    return ProjectsData(
      projects: [for (final p in j['projects'] as List) Project.fromJson(p as Map<String, dynamic>)],
      scoredCount: s['scored_count'] as int,
      averageScore: s['average_score'] as int?,
      missingCounts: (s['missing_counts'] as Map).cast<String, int>(),
      summary: s['summary'] as String,
      how: s['how'] as String,
    );
  }
}
