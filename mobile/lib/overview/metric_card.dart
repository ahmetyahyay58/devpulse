import 'package:flutter/material.dart';

import '../ui/theme_settings.dart';

import '../ai/ai_features.dart';
import 'overview_models.dart';

/// Veri yeterliliği rozeti: ikon + yazı (renk tek başına anlam taşımaz).
/// "Yeterli veri yok" bir hata değildir; kırmızı değil gri gösterilir.
class SufficiencyBadge extends StatelessWidget {
  const SufficiencyBadge(this.sufficiency, {super.key});
  final Sufficiency sufficiency;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final (icon, color) = switch (sufficiency) {
      Sufficiency.normal => (Icons.check_circle, successColor(context)),
      Sufficiency.low => (Icons.warning_amber_rounded, const Color(0xFFFAB219)),
      Sufficiency.none => (Icons.info_outline, muted),
    };
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 4),
      // Yazı nötr renkte; anlamı ikon + kelime birlikte taşır.
      Text(sufficiency.label, style: TextStyle(fontSize: 12, color: muted)),
    ]);
  }
}

/// Bir metrik kartı: başlık, rozet, şablon özet, grafik/sayılar, "Nasıl hesaplandı?".
class MetricCard extends StatelessWidget {
  const MetricCard({super.key, required this.title, required this.section, this.body, this.whyId});

  final String title;
  final MetricSection section;
  final Widget? body; // veri yetersizse gösterilmez
  final String? whyId; // "Neden?" düğmesinin hazır sorusu (AI katmanı); yoksa düğme yok

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enough = section.sufficiency != Sufficiency.none;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
              SufficiencyBadge(section.sufficiency),
            ]),
            if (whyId != null) Align(alignment: Alignment.centerLeft, child: WhyButton(questionId: whyId!)),
            const SizedBox(height: 12),
            Text(section.summary),
            if (enough && body != null) ...[const SizedBox(height: 16), body!],
            Theme(
              // ExpansionTile'ın varsayılan ayırıcı çizgilerini kaldır.
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 12),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                title: Text('Nasıl hesaplandı?', style: theme.textTheme.bodySmall),
                children: [
                  Text(section.how, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 6),
                  Text(
                    'Dayanak: ${section.basis} · Güven: ${section.sufficiency.label}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Etiket + değer satırı.
class StatRow extends StatelessWidget {
  const StatRow(this.label, this.value, {super.key});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      );
}
