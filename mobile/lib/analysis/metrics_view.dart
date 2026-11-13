import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../overview/charts.dart';
import '../overview/metric_card.dart';
import '../overview/overview_controller.dart';
import '../overview/overview_models.dart';
import 'catalog_screen.dart';

/// Analiz → Metrikler: süreklilik, ritim, oturum, değişim noktaları, olağan dışı günler.
/// Veri Genel Bakış ile aynı controller'dan gelir (tek yükleme, senkron bitince yenilenir).
class MetricsView extends StatelessWidget {
  const MetricsView({super.key, required this.controller, required this.api});

  final OverviewController controller;
  final ApiClient api; // katalog ekranı için

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final o = controller.overview;
        final Widget body;
        if (o == null) {
          body = controller.error != null
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(controller.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  TextButton(onPressed: controller.load, child: const Text('Tekrar dene')),
                ])
              : const Center(child: CircularProgressIndicator());
        } else {
          body = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _continuity(o.continuity),
              const SizedBox(height: 12),
              _rhythm(o),
              const SizedBox(height: 12),
              _sessions(o.sessions),
              if (controller.changePoints != null) ...[
                const SizedBox(height: 12),
                ChangePointsCard(section: controller.changePoints!),
              ],
              if (controller.anomalies != null) ...[
                const SizedBox(height: 12),
                _anomalies(controller.anomalies!),
              ],
            ],
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Expanded(child: Text('Metrikler', style: Theme.of(context).textTheme.titleLarge)),
                      TextButton.icon(
                        icon: const Icon(Icons.menu_book_outlined, size: 18),
                        label: const Text('Metrik kataloğu'),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => CatalogScreen(api: api)),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    body,
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _continuity(MetricSection s) {
    final ratio = s.raw['active_ratio_90d'] as num?;
    return MetricCard(
      title: 'Süreklilik',
      section: s,
      body: Column(children: [
        StatRow('Güncel seri', '${s.raw['current_streak']} gün'),
        StatRow('En uzun seri', '${s.raw['longest_streak']} gün'),
        StatRow('Son 90 günde aktif gün', ratio == null ? '-' : '%${(ratio * 100).round()}'),
      ]),
    );
  }

  Widget _rhythm(Overview o) => MetricCard(
        title: 'Ritim',
        section: o.rhythm,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _chartTitle('Saate göre commit (${o.timezone})'),
            hourChart(o.rhythm.ints('by_hour')),
            const SizedBox(height: 16),
            _chartTitle('Haftanın gününe göre commit'),
            weekdayChart(o.rhythm.ints('by_weekday')),
          ],
        ),
      );

  Widget _sessions(MetricSection s) {
    // Tam sayıysa ondalıksız (2), değilse tek ondalık (4.5) yaz.
    String fmt(Object? v, [String unit = '']) {
      if (v is! num) return '-';
      return '${v % 1 == 0 ? v.toInt() : v.toStringAsFixed(1)}$unit';
    }

    final hour = s.raw['common_start_hour'] as int?;
    final longestDay = s.raw['longest_day'] as String?;
    final longest = s.raw['longest_minutes'] == null
        ? '-'
        : '${fmt((s.raw['longest_minutes'] as num).round(), ' dk')}'
            '${longestDay == null ? '' : ' · ${_date(longestDay)}'}';
    String two(int n) => n.toString().padLeft(2, '0');

    return MetricCard(
      title: 'Oturum ve yoğunluk',
      section: s,
      body: Column(children: [
        StatRow('Oturum sayısı', '${s.raw['count']}'),
        StatRow('Oturum süresi (medyan)', fmt(s.raw['session_minutes'], ' dk')),
        StatRow('En uzun oturum', longest),
        StatRow('Oturumların en sık başladığı saat', hour == null ? '-' : '${two(hour)}:00-${two(hour)}:59'),
        StatRow('Oturum başına commit (medyan)', fmt(s.raw['commits_per_session'])),
        StatRow('Aktif gün başına commit (medyan)', fmt(s.raw['commits_per_active_day'])),
        StatRow('Commit başına değişen satır (medyan)', fmt(s.raw['lines_per_commit'])),
      ]),
    );
  }

  Widget _anomalies(MetricSection s) {
    final flagged = (s.raw['flagged'] as List).cast<Map<String, dynamic>>();
    return MetricCard(
      title: 'Olağan dışı günler',
      section: s,
      // İşaretlenen gün yoksa gövde boş: özet cümle durumu zaten söyler.
      body: flagged.isEmpty
          ? null
          : Column(children: [
              for (final a in flagged)
                StatRow(
                  _date(a['day'] as String),
                  '${a['commits']} commit · z ${(a['robust_z'] as num).toStringAsFixed(1)}',
                ),
              const SizedBox(height: 4),
              Text(
                'Aktif günlerde medyan ${s.raw['median_commits']} commit. Bu bir yargı değil; '
                'yalnızca alışkanlığının dışında kalan günler.',
                style: const TextStyle(fontSize: 12),
              ),
            ]),
    );
  }

  static Widget _chartTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

String _date(String iso) {
  final d = DateTime.parse(iso);
  return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

String _dm(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';

/// Değişim noktaları: haftalık commit çubukları, her evre kendi renginde; altında yazılı lejant
/// (renk tek başına anlam taşımaz: her evre tarih aralığı ve haftalık ortalamasıyla yazılır).
class ChangePointsCard extends StatelessWidget {
  const ChangePointsCard({super.key, required this.section});
  final MetricSection section;

  @override
  Widget build(BuildContext context) {
    final weeks = (section.raw['weeks'] as List).cast<Map<String, dynamic>>();
    final phases = (section.raw['phases'] as List).cast<Map<String, dynamic>>();
    final starts = [for (final w in weeks) DateTime.parse(w['start'] as String)];
    final labels = monthLabelIndices(starts);
    Color colorOf(int phase) => ChartColors.phases[phase % ChartColors.phases.length];
    String mean(num m) => m % 1 == 0 ? '${m.toInt()}' : m.toStringAsFixed(1);

    return MetricCard(
      title: 'Değişim noktaları',
      section: section,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Haftalık commit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          BarChart(
            values: [for (final w in weeks) w['commits'] as int],
            colorFor: (i) => colorOf(weeks[i]['phase'] as int),
            // Ay etiketi ayın ilk haftasının altına; birbirine çok yakın olanlar atlanır.
            labelFor: (i) => labels.contains(i) ? _monthShort[starts[i].month - 1] : null,
            tooltipFor: (i, v) => '${_dm(starts[i])} haftası · $v commit · Evre ${(weeks[i]['phase'] as int) + 1}',
          ),
          const SizedBox(height: 12),
          for (final p in phases)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: colorOf(p['index'] as int),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  // Yıl yazılır: 52 haftalık aralıkta "17.11-09.11" yanıltıcı olurdu.
                  child: Text('Evre ${(p['index'] as int) + 1} · '
                      '${_date(p['start'] as String)}-${_date(p['end'] as String)}'),
                ),
                Text('haftada ${mean(p['mean'] as num)}', style: const TextStyle(fontWeight: FontWeight.w600)),
              ]),
            ),
        ],
      ),
    );
  }
}

/// Ay etiketlerinin konacağı çubuklar: her ayın ilk haftası, ama bir öncekinden en az
/// [minGap] çubuk uzaktaysa (dar ekranda "Kas" ile "Ara" üst üste binmesin).
Set<int> monthLabelIndices(List<DateTime> starts, {int minGap = 3}) {
  final firsts = [
    for (var i = 0; i < starts.length; i++)
      if (i == 0 || starts[i].month != starts[i - 1].month) i,
  ];
  final result = <int>{};
  for (var k = 0; k < firsts.length; k++) {
    final i = firsts[k];
    // İlk sütun ayın ortasından başlıyorsa ve sonraki ay hemen geliyorsa ilk etiketi atla.
    if (k == 0 && firsts.length > 1 && firsts[1] - i < minGap) continue;
    if (result.isNotEmpty && i - result.reduce((a, b) => a > b ? a : b) < minGap) continue;
    result.add(i);
  }
  return result;
}

const _monthShort = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
