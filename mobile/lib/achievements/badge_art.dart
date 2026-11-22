import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Rozet görselleri (assets/badges/*.svg, tool/make_badges.py üretir).
///
/// Emaye rozet tarzı: metal kenar + küçük sahne. Kenar dosyada çelik renkle çizilir; seviyeli
/// rozette bronz, gümüş ya da altınla değiştirilir. Kilitli rozet gri ve karanlık; gizli ve kilitli
/// rozet ne olursa olsun aynı "?" madalyonu (gerçek görseli sunucu da göndermez).

/// SVG'deki çelik kenar renkleri (make_badges.py RIM_LIGHT / RIM_DARK).
const _rimLight = '#8A93A8';
const _rimDark = '#3A4052';

/// Seviye → (açık, koyu) metal tonu. Renk tek başına anlam taşımaz: seviyenin adı da yazılır.
const tierMetals = {
  'bronz': ('#E8A672', '#7A4019'),
  'gumus': ('#F4F6FA', '#848C99'),
  'altin': ('#FFE58A', '#A8730E'),
};

/// Seviye adı ve vurgu rengi (etiketlerde).
const tierLabels = {
  'bronz': ('Bronz', Color(0xFFCD7F32)),
  'gumus': ('Gümüş', Color(0xFFB4B8BE)),
  'altin': ('Altın', Color(0xFFE0B020)),
};

/// Ayrıntı sayfası ve kutlamadaki güçlü ease-out (cubic-bezier(0.23, 1, 0.32, 1)).
const easeOutStrong = Cubic(0.23, 1, 0.32, 1);

/// Gri tonlama: kilitli rozetin sahnesi seçilir ama renksizdir.
const _greyscale = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0, 0, 0, 1, 0,
]);

/// Hangi görsel: gizli ve kilitliyse her zaman "secret" (anahtara bakılmaz).
String artKeyFor(Map<String, dynamic> badge) {
  final secret = badge['hidden'] == true && badge['unlocked'] != true;
  return secret ? 'secret' : badge['key'] as String;
}

final _cache = <String, Future<String?>>{};

/// SVG metnini bir kez okur; dosya yoksa null (yeni bir rozet anahtarı görselsiz gelirse).
Future<String?> loadBadgeSvg(String artKey, {AssetBundle? bundle}) =>
    _cache.putIfAbsent(artKey, () async {
      try {
        return await (bundle ?? rootBundle).loadString('assets/badges/$artKey.svg');
      } catch (_) {
        _cache.remove(artKey);
        return null;
      }
    });

/// Kenar rengini seviyeye göre değiştirir.
String paintRim(String svg, String? tier) {
  final metal = tierMetals[tier];
  if (metal == null) return svg;
  return svg.replaceAll(_rimLight, metal.$1).replaceAll(_rimDark, metal.$2);
}

class BadgeArt extends StatelessWidget {
  const BadgeArt({super.key, required this.badge, this.size = 64});
  final Map<String, dynamic> badge;
  final double size;

  @override
  Widget build(BuildContext context) {
    final key = artKeyFor(badge);
    final unlocked = badge['unlocked'] == true;
    final fallback = Icon(key == 'secret' ? Icons.help_outline : Icons.emoji_events_outlined, size: size * 0.6);
    final art = FutureBuilder<String?>(
      future: loadBadgeSvg(key),
      builder: (context, snap) {
        final svg = snap.data;
        if (svg == null) return snap.connectionState == ConnectionState.done ? fallback : const SizedBox();
        return SvgPicture.string(paintRim(svg, badge['tier'] as String?), width: size, height: size);
      },
    );
    return Semantics(
      image: true,
      label: '${badge['name']} rozeti${unlocked ? '' : ', kilitli'}',
      child: SizedBox(
        width: size,
        height: size,
        child: unlocked || key == 'secret'
            ? art
            : Opacity(opacity: 0.55, child: ColorFiltered(colorFilter: _greyscale, child: art)),
      ),
    );
  }
}

/// Rozet ayrıntısı: büyük görsel, koşul, ilerleme ve seviye merdiveni. Dokununca açılır.
Future<void> showBadgeDetail(BuildContext context, Map<String, dynamic> badge, {String? progressText}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => BadgeDetail(badge: badge, progressText: progressText),
  );
}

class BadgeDetail extends StatelessWidget {
  const BadgeDetail({super.key, required this.badge, this.progressText});
  final Map<String, dynamic> badge;
  final String? progressText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final unlocked = badge['unlocked'] == true;
    final tiers = (badge['tiers'] as List?)?.cast<int>();
    final current = badge['current'] as int;
    final still = MediaQuery.disableAnimationsOf(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Açılış: %94 ve saydamdan tam boya (250 ms, güçlü ease-out). Animasyon kapalıysa anında.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: still ? 1 : 0, end: 1),
            duration: still ? Duration.zero : const Duration(milliseconds: 250),
            curve: easeOutStrong,
            builder: (_, t, child) => Opacity(
              opacity: t,
              child: Transform.scale(scale: 0.94 + 0.06 * t, child: child),
            ),
            child: BadgeArt(badge: badge, size: 160),
          ),
          const SizedBox(height: 16),
          Text(badge['name'] as String, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(badge['description'] as String, style: muted, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          if (tiers != null)
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (final (i, name) in ['bronz', 'gumus', 'altin'].indexed) ...[
                if (i > 0) const SizedBox(width: 12),
                _TierStep(name: name, threshold: tiers[i], reached: current >= tiers[i]),
              ],
            ])
          else if (progressText != null)
            Text(unlocked ? 'Açıldı' : progressText!, style: theme.textTheme.titleSmall),
        ]),
      ),
    );
  }
}

class _TierStep extends StatelessWidget {
  const _TierStep({required this.name, required this.threshold, required this.reached});
  final String name;
  final int threshold;
  final bool reached;

  @override
  Widget build(BuildContext context) {
    final (label, color) = tierLabels[name]!;
    final theme = Theme.of(context);
    return Opacity(
      opacity: reached ? 1 : 0.45,
      child: Column(children: [
        Icon(reached ? Icons.military_tech : Icons.lock_outline, color: reached ? color : null),
        Text(label, style: theme.textTheme.labelMedium),
        Text('$threshold', style: theme.textTheme.bodySmall),
      ]),
    );
  }
}

/// Görülen rozetler cihazda tutulur (yalnız anahtarlar; sunucuya gitmez). İlk açılışta mevcut açık
/// rozetler sessizce kaydedilir; sonradan açılanlar için bir kez kutlama gösterilir.
class BadgeSeenStore {
  static const _key = 'badges_seen';

  /// Yeni açılan rozetleri döner ve hepsini görüldü olarak kaydeder.
  Future<List<Map<String, dynamic>>> takeNew(List<Map<String, dynamic>> badges) async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getStringList(_key);
    final open = badges.where((b) => b['unlocked'] == true).toList();
    // Seviyeli rozette yeni seviye de yeni sayılır: anahtar + seviye.
    String id(Map<String, dynamic> b) => b['tier'] == null ? b['key'] as String : '${b['key']}:${b['tier']}';
    await prefs.setStringList(_key, {...?seen, for (final b in open) id(b)}.toList());
    if (seen == null) return const []; // ilk açılış: taban kaydı, kutlama yok
    return [for (final b in open) if (!seen.contains(id(b))) b];
  }
}

/// Yeni açılan rozet kutlaması: rozet hafif yaylanarak büyür, arkasında ışınlar bir kez parlar.
Future<void> showBadgeCelebration(BuildContext context, List<Map<String, dynamic>> fresh) {
  return showDialog<void>(
    context: context,
    builder: (_) => _Celebration(fresh: fresh),
  );
}

class _Celebration extends StatefulWidget {
  const _Celebration({required this.fresh});
  final List<Map<String, dynamic>> fresh;

  @override
  State<_Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<_Celebration> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1; // animasyon kapalı: son hal
    } else if (!_c.isAnimating && _c.value == 0) {
      _c.forward(); // tek sefer
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = widget.fresh.first;
    final more = widget.fresh.length - 1;
    final tier = tierLabels[first['tier']];
    // Rozet: ilk %55'te büyür (hafif yay); ışınlar: parlayıp söner.
    final pop = CurvedAnimation(parent: _c, curve: const Interval(0, 0.55, curve: Curves.easeOutBack));
    final rays = CurvedAnimation(parent: _c, curve: const Interval(0.1, 1, curve: easeOutStrong));
    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 200,
          height: 200,
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, child) => Stack(alignment: Alignment.center, children: [
              Opacity(
                opacity: (1 - rays.value).clamp(0, 1) * (rays.value > 0 ? 1 : 0),
                child: Transform.scale(
                  scale: 0.7 + 0.5 * rays.value,
                  child: CustomPaint(size: const Size(200, 200), painter: _RaysPainter(tier?.$2 ?? const Color(0xFFFFD25A))),
                ),
              ),
              Opacity(
                opacity: pop.value.clamp(0, 1),
                child: Transform.scale(scale: 0.9 + 0.1 * pop.value, child: child),
              ),
            ]),
            child: BadgeArt(badge: first, size: 150),
          ),
        ),
        const SizedBox(height: 8),
        Text(tier == null ? 'Yeni rozet açıldı' : 'Yeni seviye: ${tier.$1}', style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(first['name'] as String, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(first['description'] as String, textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        if (more > 0) ...[
          const SizedBox(height: 8),
          Text('ve $more rozet daha', style: theme.textTheme.bodySmall),
        ],
      ]),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Harika'))],
    );
  }
}

/// Rozetin arkasındaki 12 ışın (tek renk, yumuşak uçlu).
class _RaysPainter extends CustomPainter {
  _RaysPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final paint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + d * 70, c + d * (i.isEven ? 98 : 88), paint);
    }
  }

  @override
  bool shouldRepaint(_RaysPainter old) => old.color != color;
}
