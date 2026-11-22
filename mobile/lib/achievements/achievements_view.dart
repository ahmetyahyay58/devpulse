import 'package:flutter/material.dart';

import '../ai/ai_features.dart';

import '../overview/metric_card.dart';
import '../overview/overview_controller.dart';
import '../overview/overview_models.dart';
import '../share/share_card.dart';
import '../year/year_summary_screen.dart';
import 'badge_art.dart';

/// Başarımlar: 29 rozet (kilitliler soluk, ilerlemeli; gizliler açılana kadar "???"; bazıları seviyeli) ve yıl kıyası.
/// Rozetler alışkanlığı ve proje bakımını tanır; ham commit sayısını ödüllendirmez.
class AchievementsView extends StatefulWidget {
  const AchievementsView({super.key, required this.controller, this.seenStore});

  final OverviewController controller;
  final BadgeSeenStore? seenStore; // yeni rozet kutlaması (cihazda); null: varsayılan depo

  @override
  State<AchievementsView> createState() => _AchievementsViewState();
}

class _AchievementsViewState extends State<AchievementsView> {
  late final BadgeSeenStore _seen = widget.seenStore ?? BadgeSeenStore();
  Object? _checked; // kutlama her yeni rozet verisi için bir kez denetlenir

  OverviewController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.addListener(_celebrateNew);
    _celebrateNew();
  }

  @override
  void dispose() {
    controller.removeListener(_celebrateNew);
    super.dispose();
  }

  Future<void> _celebrateNew() async {
    final a = controller.achievements;
    if (a == null || identical(a, _checked)) return;
    _checked = a;
    final fresh = await _seen.takeNew((a['badges'] as List).cast<Map<String, dynamic>>());
    if (fresh.isNotEmpty && mounted) await showBadgeCelebration(context, fresh);
  }

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
              const SizedBox(height: 16),
              _YearCard(year: a['year'] as Map<String, dynamic>),
              const SizedBox(height: 12),
              // Yıllık özet: hikâye gibi kayan slaytlar (docs/metrikler.md "Yıllık özet").
              FilledButton.tonalIcon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  fullscreenDialog: true,
                  builder: (_) => YearSummaryScreen(
                    api: controller.api,
                    onShare: (ctx, s) => Navigator.of(ctx).push(MaterialPageRoute<void>(
                      builder: (_) => ShareCardScreen(api: controller.api, summary: s),
                    )),
                  ),
                )),
                icon: const Icon(Icons.auto_stories_outlined),
                label: Text('${(a['year'] as Map)['this_year']} yıllık özetini aç'),
              ),
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

/// İlerleme birimi: sayı tek başına anlaşılmayan rozetler için.
const _units = {'marathon': ' dk', 'night_owl': '%', 'weekend': '%', 'long_haul': ' gün'};

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
    final secret = badge['hidden'] == true && !unlocked; // gizli: ad ve koşul sunucudan gelmez
    final unit = _units[badge['key']] ?? '';
    final progress = unit == '%' ? '%$current / %$target' : '$current$unit / $target$unit';
    final tier = tierLabels[badge['tier']]; // seviyeli rozette ulaşılan seviye (yoksa null)
    final tiers = (badge['tiers'] as List?)?.cast<int>();
    final maxed = tier != null && tiers != null && current >= tiers.last;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showBadgeDetail(context, badge, progressText: secret ? null : progress),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              BadgeArt(badge: badge, size: 64), // kilitliyse görsel kendisi gri ve soluk
              const Spacer(),
              // Durum ikonla ve yazıyla (renk tek başına anlam taşımaz).
              Icon(unlocked ? Icons.check_circle : Icons.lock_outline, size: 16,
                  color: unlocked ? const Color(0xFF0CA30C) : theme.colorScheme.onSurfaceVariant),
            ]),
            if (tier != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(border: Border.all(color: tier.$2), borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.military_tech, size: 14, color: tier.$2),
                  const SizedBox(width: 2),
                  Text(tier.$1, style: theme.textTheme.labelSmall),
                ]),
              ),
            ],
            const SizedBox(height: 8),
            Text(badge['name'] as String,
                style: theme.textTheme.titleSmall?.copyWith(color: unlocked ? null : theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 2),
            Text(badge['description'] as String, style: muted),
            const Spacer(),
            const SizedBox(height: 8),
            if (!secret) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: target == 0 ? 0 : current / target, minHeight: 4),
              ),
              const SizedBox(height: 4),
            ],
            Text(
                tier != null
                    ? (maxed ? '${tier.$1} · en üst seviye' : '${tier.$1} · sıradaki seviye: $progress')
                    : unlocked
                        ? (badge['hidden'] == true ? 'Gizli rozet açıldı' : 'Açıldı')
                        : (secret ? '???' : progress),
                style: muted),
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
