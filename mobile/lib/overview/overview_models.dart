/// GET /metrics/overview ve /metrics/calendar cevaplarının Dart karşılıkları.
library;

/// Üç durumlu veri yeterliliği (backend: yetersiz / dusuk / normal).
enum Sufficiency {
  none('Yeterli veri yok'),
  low('Düşük güven'),
  normal('Normal');

  const Sufficiency(this.label);
  final String label;

  static Sufficiency parse(String v) => switch (v) {
        'normal' => Sufficiency.normal,
        'dusuk' => Sufficiency.low,
        _ => Sufficiency.none,
      };
}

/// Her metrik bölümünün ortak alanları: yeterlilik, dayanak, özet, "nasıl hesaplandı".
class MetricSection {
  const MetricSection({
    required this.sufficiency,
    required this.basis,
    required this.summary,
    required this.how,
    required this.raw,
  });

  final Sufficiency sufficiency;
  final String basis; // ör. "33 commit"
  final String summary; // şablon cümle
  final String how;
  final Map<String, dynamic> raw; // bölüme özgü sayılar

  factory MetricSection.fromJson(Map<String, dynamic> j) => MetricSection(
        sufficiency: Sufficiency.parse(j['sufficiency'] as String),
        basis: j['basis'] as String,
        summary: j['summary'] as String,
        how: j['how'] as String,
        raw: j,
      );

  List<int> ints(String key) => (raw[key] as List).cast<int>();
}

class Overview {
  const Overview({
    required this.timezone,
    required this.timezoneKnown,
    required this.kpi,
    required this.continuity,
    required this.rhythm,
    required this.sessions,
  });

  final String timezone;
  final bool timezoneKnown;
  final Map<String, int> kpi;
  final MetricSection continuity;
  final MetricSection rhythm;
  final MetricSection sessions;

  factory Overview.fromJson(Map<String, dynamic> j) => Overview(
        timezone: j['timezone'] as String,
        timezoneKnown: j['timezone_known'] as bool,
        kpi: (j['kpi'] as Map).cast<String, int>(),
        continuity: MetricSection.fromJson(j['continuity'] as Map<String, dynamic>),
        rhythm: MetricSection.fromJson(j['rhythm'] as Map<String, dynamic>),
        sessions: MetricSection.fromJson(j['sessions'] as Map<String, dynamic>),
      );
}

class CalendarData {
  const CalendarData({required this.days, required this.total, required this.note});

  final List<(DateTime, int)> days; // eskiden yeniye
  final int total;
  final String note;

  factory CalendarData.fromJson(Map<String, dynamic> j) => CalendarData(
        days: [
          for (final d in j['days'] as List)
            (DateTime.parse((d as Map)['day'] as String), d['count'] as int),
        ],
        total: j['total'] as int,
        note: j['note'] as String,
      );
}
