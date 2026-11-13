import 'package:flutter/material.dart';

import '../overview/charts.dart';
import '../overview/metric_card.dart';
import '../overview/overview_controller.dart';
import '../overview/overview_models.dart';

/// Analiz → Teknoloji: dil sayısı, baskın dil, dil dağılımı, çeşitlilik ve araçlar.
class TechnologyView extends StatelessWidget {
  const TechnologyView({super.key, required this.controller});

  final OverviewController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final t = controller.technology;
        final Widget body;
        if (t == null) {
          body = controller.error != null
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(controller.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  TextButton(onPressed: controller.load, child: const Text('Tekrar dene')),
                ])
              : const Center(child: CircularProgressIndicator());
        } else {
          body = _content(context, t);
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
                    body, // başlık üstteki bölüm seçicide
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _content(BuildContext context, MetricSection t) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final languages = (t.raw['languages'] as List).cast<Map<String, dynamic>>();
    final tools = (t.raw['tools'] as List).cast<Map<String, dynamic>>();
    final share = t.raw['dominant_share'] as num?;
    final diversity = t.raw['diversity'] as num?;
    final enough = t.sufficiency != Sufficiency.none;

    Widget tile(String label, String value) => Expanded(
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(value, style: theme.textTheme.headlineSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(label, style: muted),
              ]),
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (enough) ...[
          Row(children: [
            tile('Dil', '${t.raw['language_count']}'),
            const SizedBox(width: 8),
            tile('Baskın dil${share == null ? '' : ' · %${(share * 100).round()}'}', '${t.raw['dominant'] ?? '-'}'),
          ]),
          const SizedBox(height: 12),
        ],
        MetricCard(
          title: 'Dil dağılımı',
          section: t,
          body: languages.isEmpty
              ? null
              : Column(children: [for (final l in languages) _LanguageRow(language: l)]),
        ),
        if (enough && diversity != null) ...[
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Çeşitlilik', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                Center(child: ScoreRing(score: (diversity * 100).round(), percent: true)),
                const SizedBox(height: 12),
                // Puan değil: yüksek ya da düşük olması iyi/kötü anlamına gelmez.
                Text('Dil dağılımının dengesi: %0 tek dil, %100 bütün diller eşit paylı. '
                    'Bir puan değildir; tek dilde derinleşmek de geçerli bir yoldur.', style: muted),
              ]),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Tespit edilen araçlar', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              if (tools.isEmpty)
                Text('Repolarının kök dizininde bilinen bir araç dosyası bulunamadı.', style: muted)
              else
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final tool in tools)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text('${tool['name']} · ${tool['repos']} repo'),
                    ),
                ]),
              const SizedBox(height: 8),
              Text('Kök dizindeki dosya adlarından bulunur (ör. Dockerfile → Docker); '
                  'dosya içeriği okunmaz.', style: muted),
            ]),
          ),
        ),
      ],
    );
  }
}

/// Dil satırı: ad, payı gösteren tek renkli çubuk, yazılı yüzde ve repo sayısı.
class _LanguageRow extends StatelessWidget {
  const _LanguageRow({required this.language});
  final Map<String, dynamic> language;

  @override
  Widget build(BuildContext context) {
    final share = (language['share'] as num).toDouble();
    final track = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(language['name'] as String)),
          Text('%${_pct(share)} · ${language['repos']} repo',
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: share, minHeight: 6, color: ChartColors.bar, backgroundColor: track),
        ),
      ]),
    );
  }

  /// %1'in altı "<1" yazılır ("Diğer" toplamı küçük olabilir), diğerleri tam sayı.
  static String _pct(double share) => share < 0.01 ? '<1' : '${(share * 100).round()}';
}
