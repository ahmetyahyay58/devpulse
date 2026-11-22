import 'package:flutter/material.dart';

import '../ui/theme_settings.dart';

import '../overview/charts.dart';
import 'projects_models.dart';

/// Tek bir projenin ayrıntısı: sağlık halkası, öneri cümlesi, kontroller, topic'ler ve
/// son 12 hafta commit çubukları. Veri listeden gelir; yeni istek atılmaz.
class ProjectDetailScreen extends StatelessWidget {
  const ProjectDetailScreen({super.key, required this.project, this.today});

  final Project project;
  final DateTime? today; // testlerde sabit tarih; yoksa bugün

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final p = project;
    final details = [
      ?p.language,
      if (p.isPrivate) 'özel',
      '${p.commitCount} commit',
      if (p.daysSincePush != null) 'son push ${p.daysSincePush} gün önce',
    ].join(' · ');

    return Scaffold(
      appBar: AppBar(title: Text(p.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    StateChip(project: p),
                    Text(details, style: muted),
                  ]),
                  const SizedBox(height: 12),
                  if (p.scored) _HealthCard(project: p) else _NotScoredCard(project: p),
                  if (p.topics.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _TopicsCard(topics: p.topics),
                  ],
                  if (p.weeklyCommits.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _WeeklyCard(weekly: p.weeklyCommits, today: today ?? DateTime.now()),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Durum etiketi: ikon + yazı (renk anlam taşımaz; durum bir değer yargısı değildir).
class StateChip extends StatelessWidget {
  const StateChip({super.key, required this.project});
  final Project project;

  @override
  Widget build(BuildContext context) {
    final icon = switch (project.state) {
      'aktif' => Icons.bolt,
      'arsiv' => Icons.inventory_2_outlined,
      _ => Icons.pause_circle_outline,
    };
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: scheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(project.stateLabel, style: Theme.of(context).textTheme.labelSmall),
      ]),
    );
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({required this.project});
  final Project project;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = project;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Proje sağlığı', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Center(child: ScoreRing(score: p.score ?? 0)),
            if (p.suggestion != null) ...[
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.lightbulb_outline, size: 18, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(child: Text(p.suggestion!)),
              ]),
            ],
            const SizedBox(height: 12),
            for (final c in p.checks) CheckRow(check: c),
            const SizedBox(height: 4),
            Text('Skor vitrin ve belgelendirme eksiksizliğini ölçer, kod kalitesini ölçmez.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _NotScoredCard extends StatelessWidget {
  const _NotScoredCard({required this.project});
  final Project project;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Puanlanmıyor', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(project.notScoredReason ?? ''),
          ]),
        ),
      );
}

class _TopicsCard extends StatelessWidget {
  const _TopicsCard({required this.topics});
  final List<String> topics;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Topic\'ler', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final t in topics) Chip(label: Text(t), visualDensity: VisualDensity.compact),
            ]),
          ]),
        ),
      );
}

class _WeeklyCard extends StatelessWidget {
  const _WeeklyCard({required this.weekly, required this.today});
  final List<int> weekly; // eskiden yeniye
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Her çubuğun haftası: bu haftanın Pazartesi'sinden geriye.
    final monday = DateTime(today.year, today.month, today.day - (today.weekday - 1));
    DateTime weekStart(int i) => DateTime(monday.year, monday.month, monday.day - 7 * (weekly.length - 1 - i));
    String dm(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
    final total = weekly.fold<int>(0, (a, b) => a + b);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Son 12 hafta', style: theme.textTheme.titleMedium),
          Text('$total commit', style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          if (total == 0)
            Text('Son 12 haftada bu repoya commit atmadın.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))
          else
            BarChart(
              values: weekly,
              // Etiket her 4 haftada bir (yer dar), son çubuk "bu hafta".
              labelFor: (i) => i == weekly.length - 1 ? 'bu hf' : (i % 4 == 0 ? dm(weekStart(i)) : null),
              tooltipFor: (i, v) => '${dm(weekStart(i))} haftası · $v commit',
            ),
        ]),
      ),
    );
  }
}

/// Kontrol satırı: ikon + "Ad: var/eksik" + eksikse öneri.
class CheckRow extends StatelessWidget {
  const CheckRow({super.key, required this.check});
  final ProjectCheck check;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color, word) = switch (check.status) {
      'ok' => (Icons.check_circle, successColor(context), 'var'),
      'missing' => (Icons.cancel, const Color(0xFFEC835A), 'eksik'),
      _ => (Icons.help_outline, theme.colorScheme.onSurfaceVariant, 'bilinmiyor'),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Durum ikonun yanında yazıyla da söylenir (renk tek başına anlam taşımaz).
              Text('${check.label}: $word'),
              if (check.hint != null)
                Text(check.hint!,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ]),
          ),
        ],
      ),
    );
  }
}
