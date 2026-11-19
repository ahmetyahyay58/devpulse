import 'package:flutter/material.dart';

import '../ai/ai_features.dart';

import '../overview/charts.dart';
import '../overview/metric_card.dart';
import '../overview/overview_controller.dart';
import '../overview/overview_models.dart';

/// Analiz → İşbirliği: açtığın PR'ların sonucu (kendi repon / başkasının reposu ayrı) ve
/// kod incelemeleri. Az sayıda değer olduğu için grafik yerine tablo (docs/metrikler.md).
class CollaborationView extends StatelessWidget {
  const CollaborationView({super.key, required this.controller});

  final OverviewController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller.collaboration;
        final Widget body;
        if (c == null) {
          body = controller.error != null
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(controller.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  TextButton(onPressed: controller.load, child: const Text('Tekrar dene')),
                ])
              : const Center(child: CircularProgressIndicator());
        } else {
          body = MetricCard(title: 'İşbirliği', section: c, body: _details(context, c));
        }
        return ListView(padding: tabPadding, children: [
          Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: body)),
        ]);
      },
    );
  }

  /// "%67" ya da "-"; süre 48 saatten kısaysa saat, değilse gün (ondalık virgül).
  static String rate(Object? r) => r == null ? '-' : '%${((r as num) * 100).round()}';

  static String duration(Object? hours) {
    if (hours == null) return '-';
    final h = (hours as num).toDouble();
    return h < 48 ? '${h.round()} saat' : '${(h / 24).toStringAsFixed(1).replaceAll('.', ',')} gün';
  }

  /// "Aylık merge süresi" (docs/metrikler.md): son 12 ay, medyan; boş ay boşluk, az PR'lı ay soluk.
  static List<Widget> _monthly(BuildContext context, MetricSection c) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final months = (c.raw['monthly'] as List? ?? const []).cast<Map<String, dynamic>>();
    if (months.every((m) => (m['merged'] as int? ?? 0) == 0)) return const [];
    // Çubuk yüksekliği dakika: bir saatten kısa medyanlar da görünsün. Merge yoksa 0 (boşluk).
    final minutes = [for (final m in months) (((m['median_merge_hours'] as num?) ?? 0) * 60).round()];
    String label(int i) {
      final parts = (months[i]['month'] as String).split('-');
      return '${monthShortTr[int.parse(parts[1]) - 1]} ${parts[0]}';
    }
    final group = c.raw['monthly_group'] == 'others' ? "başkalarının repolarına açtığın PR'lar" : "tüm PR'ların";
    return [
      const SizedBox(height: 16),
      Text('Aylık merge süresi (medyan)', style: theme.textTheme.titleSmall),
      Text('Son 12 ay, $group', style: muted),
      const SizedBox(height: 8),
      BarChart(
        values: minutes,
        colorFor: (i) => (months[i]['merged'] as int) < 3 ? ChartColors.bar.withValues(alpha: 0.4) : ChartColors.bar,
        labelFor: (i) => i == months.length - 1 ? 'bu ay' : (i % 3 == 0 ? label(i).split(' ').first : null),
        tooltipFor: (i, _) {
          final n = months[i]['merged'] as int;
          return n == 0 ? '${label(i)} · merge yok' : '${label(i)} · $n PR · medyan ${duration(months[i]['median_merge_hours'])}';
        },
      ),
      const SizedBox(height: 4),
      Text("PR'ın ayı merge edildiği aydır. Boş ay: o ay merge yok. Soluk çubuk: 3'ten az PR, "
          "medyan tek PR'a dayanabilir. Aylar UTC'ye göredir.", style: muted),
    ];
  }

  Widget _details(BuildContext context, MetricSection c) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final total = (c.raw['total'] as Map).cast<String, dynamic>();
    final own = (c.raw['own'] as Map).cast<String, dynamic>();
    final others = (c.raw['others'] as Map).cast<String, dynamic>();
    final years = (c.raw['years'] as List).cast<Map<String, dynamic>>();

    Widget tile(String label, String value) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: theme.textTheme.headlineSmall),
            Text(label, style: muted),
          ]),
        );
    TableRow row(List<String> cells, {bool header = false}) => TableRow(children: [
          for (final (i, s) in cells.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(s,
                  textAlign: i == 0 ? TextAlign.start : TextAlign.end,
                  style: header ? muted : (i == 0 ? null : const TextStyle(fontWeight: FontWeight.w600))),
            ),
        ]);
    final columns = {0: const FlexColumnWidth(2), 1: const FlexColumnWidth(1.3), 2: const FlexColumnWidth(1.3)};

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        tile('Açılan PR', '${total['opened']}'),
        tile('Merge edilen', '${total['merged']}'),
        tile('Kod incelemesi', '${c.raw['reviews_total']}'),
      ]),
      const SizedBox(height: 16),
      Table(columnWidths: columns, children: [
        row(['', 'Başkasının reposu', 'Kendi repon'], header: true),
        row(['Açılan', '${others['opened']}', '${own['opened']}']),
        row(['Merge edilen', '${others['merged']}', '${own['merged']}']),
        row(['Merge edilmeden kapatılan', '${others['closed_unmerged']}', '${own['closed_unmerged']}']),
        row(['Hâlâ açık', '${others['still_open']}', '${own['still_open']}']),
        row(['Merge oranı', rate(others['merge_rate']), rate(own['merge_rate'])]),
        row(['Merge süresi (medyan)', duration(others['median_merge_hours']), duration(own['median_merge_hours'])]),
      ]),
      const SizedBox(height: 6),
      Text('Kendi repona açtığın PR\'ları çoğunlukla kendin merge edersin; bu yüzden oranı yüksek görünür. '
          'İşbirliğini asıl başkasının reposu sütunu gösterir.', style: muted),
      if (c.sufficiency != Sufficiency.none) ..._monthly(context, c),
      if (years.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text('Yıl yıl', style: theme.textTheme.titleSmall),
        Table(columnWidths: columns, children: [
          row(['Yıl', 'Açılan PR', 'İnceleme'], header: true),
          for (final y in years.reversed) row(['${y['year']}', '${y['prs']}', '${y['reviews']}']),
        ]),
        const SizedBox(height: 4),
        Text('Bu yıl ${c.raw['reviews_this_year']} kod incelemesi. Yıllar UTC\'ye göredir (GitHub öyle verir).',
            style: muted),
      ],
      const SizedBox(height: 8),
    ]);
  }
}
