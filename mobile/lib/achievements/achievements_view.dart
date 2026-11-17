import 'package:flutter/material.dart';

import '../ai/ai_features.dart';
import '../ai/ai_widgets.dart';

import '../overview/metric_card.dart';
import '../overview/overview_controller.dart';
import '../overview/overview_models.dart';

/// Başarımlar: 8 rozet (kilitliler soluk, ilerlemeli) ve yıl kıyası.
/// Rozetler alışkanlığı ve proje bakımını tanır; ham commit sayısını ödüllendirmez.
class AchievementsView extends StatelessWidget {
  const AchievementsView({super.key, required this.controller});

  final OverviewController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final a = controller.achievements;
        final theme = Theme.of(context);
        final Widget body;
        if (a == null) {
          body = controller.error != null
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(controller.error!, style: TextStyle(color: theme.colorScheme.error)),
                  TextButton(onPressed: controller.load, child: const Text('Tekrar dene')),
                ])
              : const Center(child: CircularProgressIndicator());
        } else {
          final badges = (a['badges'] as List).cast<Map<String, dynamic>>();
          body = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Açılan rozet: ${a['unlocked']} / ${badges.length}', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              _BadgeGrid(badges: badges),
              const SizedBox(height: 8),
              Text('Rozetler alışkanlığı ve proje bakımını tanır; commit sayısını ödüllendirmez.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              // Hedef koçu: rozet, haftalık hedef ve öncelikli proje için 3 hazır soru (docs/ai_katmani.md).
              if (AiScope.maybeOf(context) case final ai?) ...[
                const SizedBox(height: 16),
                AiCommentCard(
                  ai: ai,
                  kind: 'hedef',
                  title: 'Hedef koçu',
                  icon: Icons.flag_outlined,
                  subtitle: 'Verine göre küçük, ulaşılabilir bir sonraki adım.',
                ),
              ],
              const SizedBox(height: 16),
              _YearCard(year: a['year'] as Map<String, dynamic>),
            ],
          );
        }
        return ListView(
          padding: tabPadding,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('Başarımlar', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  body,
                ]),
              ),
            ),
          ],
        );
      },
    );
  }
}

const _icons = {
  'streak7': Icons.local_fire_department_outlined,
  'streak30': Icons.whatshot_outlined,
  'regular': Icons.event_repeat,
  'showcase': Icons.star_outline,
  'docs': Icons.description_outlined,
  'license': Icons.gavel_outlined,
  'polyglot': Icons.translate,
  'contributor': Icons.handshake_outlined,
};

/// İki sütunlu ızgara (Row + Expanded; GridView içerik yüksekliğine uymadığı için).
class _BadgeGrid extends StatelessWidget {
  const _BadgeGrid({required this.badges});
  final List<Map<String, dynamic>> badges;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      for (var i = 0; i < badges.length; i += 2)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: BadgeTile(badge: badges[i])),
              const SizedBox(width: 8),
              Expanded(child: i + 1 < badges.length ? BadgeTile(badge: badges[i + 1]) : const SizedBox()),
            ]),
          ),
        ),
    ]);
  }
}

/// Tek rozet: açıksa tam renk ve "Açıldı"; kilitliyse soluk, kilit ikonu ve ilerleme.
class BadgeTile extends StatelessWidget {
  const BadgeTile({super.key, required this.badge});
  final Map<String, dynamic> badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unlocked = badge['unlocked'] as bool;
    final current = badge['current'] as int;
    final target = badge['target'] as int;
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Opacity(
      opacity: unlocked ? 1 : 0.55, // kilitli rozet soluk
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(_icons[badge['key']] ?? Icons.emoji_events_outlined,
                  color: unlocked ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
              const Spacer(),
              // Durum ikonla ve yazıyla (renk tek başına anlam taşımaz).
              Icon(unlocked ? Icons.check_circle : Icons.lock_outline, size: 16,
                  color: unlocked ? const Color(0xFF0CA30C) : theme.colorScheme.onSurfaceVariant),
            ]),
            const SizedBox(height: 8),
            Text(badge['name'] as String, style: theme.textTheme.titleSmall),
            const SizedBox(height: 2),
            Text(badge['description'] as String, style: muted),
            const Spacer(),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: target == 0 ? 0 : current / target, minHeight: 4),
            ),
            const SizedBox(height: 4),
            Text(unlocked ? 'Açıldı' : '$current / $target', style: muted),
          ]),
        ),
      ),
    );
  }
}

class _YearCard extends StatelessWidget {
  const _YearCard({required this.year});
  final Map<String, dynamic> year;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = (year['stats'] as List).cast<Map<String, dynamic>>();
    final end = DateTime.parse(year['period_end'] as String);
    final period = '1 Oca - ${end.day} ${_monthShort[end.month - 1]}';
    final bold = const TextStyle(fontWeight: FontWeight.w600);

    String change(Object? pct) {
      if (pct is! int) return '-';
      if (pct == 0) return 'aynı';
      return pct > 0 ? '+%$pct' : '-%${-pct}';
    }

    TableRow row(List<String> cells, {TextStyle? style}) => TableRow(children: [
          for (var i = 0; i < cells.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(cells[i], textAlign: i == 0 ? TextAlign.start : TextAlign.end, style: style),
            ),
        ]);

    return MetricCard(
      title: 'Yıl kıyası',
      section: MetricSection.fromJson(year),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Her iki yıl için $period', style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        Table(
          columnWidths: const {0: FlexColumnWidth(2.2)},
          children: [
            row(['', '${year['last_year']}', '${year['this_year']}', 'Değişim'],
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            for (final s in stats)
              row([s['label'] as String, '${s['last_year']}', '${s['this_year']}', change(s['change_pct'])],
                  style: s == stats.first ? bold : null),
          ],
        ),
      ]),
    );
  }
}

const _monthShort = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
