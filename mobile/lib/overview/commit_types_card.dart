import 'package:flutter/material.dart';

import 'charts.dart';
import 'metric_card.dart';
import 'overview_models.dart';

/// Commit türleri: tek renkli yatay çubuklar (tür adı yazıyla, renk tek başına anlam taşımaz).
/// Bir türe dokununca o türdeki son commit'ler ve nasıl karar verildiği gösterilir.
class CommitTypesCard extends StatelessWidget {
  const CommitTypesCard({super.key, required this.section});

  final MetricSection section;

  @override
  Widget build(BuildContext context) {
    final types = (section.raw['types'] as List).cast<Map<String, dynamic>>();
    final visible = types.where((t) => (t['count'] as int) > 0).toList();
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
    return MetricCard(
      title: 'Commit türleri',
      section: section,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final t in visible) _TypeRow(type: t),
          const SizedBox(height: 8),
          Text(section.raw['note'] as String, style: muted),
        ],
      ),
    );
  }
}

class _TypeRow extends StatelessWidget {
  const _TypeRow({required this.type});
  final Map<String, dynamic> type;

  @override
  Widget build(BuildContext context) {
    final share = (type['share'] as num).toDouble();
    final track = Theme.of(context).colorScheme.surfaceContainerHighest;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => _showExamples(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(type['label_tr'] as String)),
            Text('${type['count']} · %${(share * 100).round()}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const Icon(Icons.chevron_right, size: 18),
          ]),
          const SizedBox(height: 4),
          // Oranı gösteren tek renkli çubuk; sayı yanında yazılıdır.
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: share,
              minHeight: 8,
              color: ChartColors.bar,
              backgroundColor: track,
            ),
          ),
        ]),
      ),
    );
  }

  void _showExamples(BuildContext context) {
    final examples = (type['examples'] as List).cast<Map<String, dynamic>>();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              Text('${type['label_tr']} · son commit\'ler', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              for (final e in examples)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e['headline'] as String),
                    Text('${e['repo']} · ${_date(e['authored_at'] as String)}', style: muted),
                    // Nasıl karar verildi: "kural: ..." ya da "model, %72 güven"
                    Text('${e['source'] == 'kural' ? 'kural: ' : ''}${e['reason']}', style: muted),
                  ]),
                ),
            ],
          ),
        );
      },
    );
  }
}

String _date(String iso) {
  final d = DateTime.parse(iso).toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}.${two(d.month)}.${d.year}';
}
