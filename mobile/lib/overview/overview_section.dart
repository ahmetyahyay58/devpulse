import 'package:flutter/material.dart';

import 'charts.dart';
import 'commit_types_card.dart';
import 'overview_controller.dart';
import 'overview_models.dart';

/// Genel Bakış: KPI'lar, katkı takvimi ve commit türleri.
/// (Süreklilik, ritim, oturum ve olağan dışı günler Analiz → Metrikler'de.)
class OverviewSection extends StatelessWidget {
  const OverviewSection({super.key, required this.controller});

  final OverviewController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final o = controller.overview;
        if (o == null) {
          if (controller.error != null) return _error(context);
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (o.kpi['total_commits'] == 0) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Henüz commit verin yok. Yukarıdan senkronu başlatınca Genel Bakış burada görünecek.'),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _KpiGrid(kpi: o.kpi, longestStreak: o.continuity.raw['longest_streak']),
            const SizedBox(height: 12),
            if (controller.calendar != null)
              _CalendarCard(data: controller.calendar!, anomalyDays: _anomalyDays()),
            if (controller.commitTypes != null) ...[
              const SizedBox(height: 12),
              CommitTypesCard(section: controller.commitTypes!),
            ],
          ],
        );
      },
    );
  }

  /// Olağan dışı yoğun günler (anomali kartındaki işaretli günler); takvimde halkayla gösterilir.
  Set<DateTime> _anomalyDays() {
    final flagged = controller.anomalies?.raw['flagged'] as List? ?? const [];
    return {for (final a in flagged) DateTime.parse((a as Map)['day'] as String)};
  }

  Widget _error(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Text(controller.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            TextButton(onPressed: controller.load, child: const Text('Tekrar dene')),
          ]),
        ),
      );
}

/// Dört KPI kartı, 2x2 ızgara: toplam commit, aktif gün, en uzun seri, repo.
/// (Güncel seri ve son 30 gün Süreklilik kartında.)
class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.kpi, required this.longestStreak});
  final Map<String, int> kpi;
  final Object? longestStreak; // Süreklilik bölümünden (gün)

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget tile(String label, Object? value, [String unit = '']) => Expanded(
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text.rich(TextSpan(children: [
                  TextSpan(text: '${value ?? '-'}', style: theme.textTheme.headlineSmall),
                  if (unit.isNotEmpty) TextSpan(text: ' $unit', style: theme.textTheme.bodyMedium),
                ])),
                Text(label,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ]),
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          tile('Toplam commit', kpi['total_commits']),
          const SizedBox(width: 8),
          tile('Aktif gün', kpi['active_days']),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          tile('En uzun seri', longestStreak, 'gün'),
          const SizedBox(width: 8),
          tile('Repo', kpi['repos']),
        ]),
        const SizedBox(height: 8),
        Text(
          'Commit sayısı üretkenliği ya da kaliteyi ölçmez; yalnızca çalışma alışkanlığını betimler.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({required this.data, this.anomalyDays = const {}});
  final CalendarData data;
  final Set<DateTime> anomalyDays;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = data.days.where((d) => anomalyDays.contains(d.$1)).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Katkı takvimi', style: theme.textTheme.titleMedium),
            Text('Son 30 haftada ${data.total} katkı', style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            ContributionHeatmap(days: data.days, highlighted: anomalyDays),
            if (shown > 0) ...[
              const SizedBox(height: 4),
              // Halka tek başına anlam taşımasın: lejantta yazıyla açıklanır.
              Row(children: [
                Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    border: Border.all(color: ChartColors.anomaly, width: 1.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Text('Olağan dışı yoğun gün ($shown)', style: theme.textTheme.bodySmall),
              ]),
            ],
            const SizedBox(height: 8),
            Text(data.note, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
