import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ui/motion.dart';
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
    sheetAnimationStyle: Motion.sheet(context),
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

/// Yeni açılan rozet kutlaması (tek seferlik, ~1,6 sn): rozet yukarıdan yaylanarak düşer ve
/// küçük bir sallanmayla oturur, üstünden bir parlama geçer, konfeti bir kez patlar, yazılar
/// sırayla belirir. Birden çok rozet açıldıysa "Sıradaki" ile her biri kendi kutlamasıyla gelir.
/// Sürekli dönen bir şey yoktur; animasyonlar kapalıysa son hal anında gösterilir.
Future<void> showBadgeCelebration(BuildContext context, List<Map<String, dynamic>> fresh) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.7),
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
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  int _index = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.value == 0 && !_c.isAnimating) _play();
  }

  void _play() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1; // animasyon kapalı: son hal
      return;
    }
    HapticFeedback.mediumImpact(); // telefonda küçük bir titreşim (web'de etkisiz)
    _c.forward(from: 0);
  }

  void _next() {
    setState(() => _index++);
    _play();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badge = widget.fresh[_index];
    final last = _index == widget.fresh.length - 1;
    final tier = tierLabels[badge['tier']];
    final accent = tier?.$2 ?? const Color(0xFFFFD25A);

    // Zaman dilimleri (0-1 arası, toplam 1,6 sn).
    final drop = CurvedAnimation(parent: _c, curve: const Interval(0, 0.45, curve: Curves.easeOutBack));
    final wobble = CurvedAnimation(parent: _c, curve: const Interval(0.3, 0.75, curve: Curves.easeOut));
    final shine = CurvedAnimation(parent: _c, curve: const Interval(0.45, 0.8, curve: Curves.easeInOut));
    final burst = CurvedAnimation(parent: _c, curve: const Interval(0.3, 1));
    final glow = CurvedAnimation(parent: _c, curve: const Interval(0.25, 1, curve: easeOutStrong));
    Animation<double> textIn(double start) =>
        CurvedAnimation(parent: _c, curve: Interval(start, math.min(start + 0.3, 1), curve: easeOutStrong));

    // Yazılar: aşağıdan 10 px yükselerek belirir.
    Widget reveal(Animation<double> a, Widget child) => AnimatedBuilder(
          animation: a,
          builder: (_, c) => Opacity(
            opacity: a.value.clamp(0, 1),
            child: Transform.translate(offset: Offset(0, 10 * (1 - a.value)), child: c),
          ),
          child: child,
        );

    return Dialog(
      backgroundColor: theme.colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 260,
            height: 240,
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, child) {
                // Düşüş: 60 px yukarıdan, %80 boydan; sallanma: söndükçe azalan küçük dönüş.
                final d = drop.value;
                final angle = math.sin(wobble.value * math.pi * 3) * 0.12 * (1 - wobble.value);
                return Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
                  // Arkada yumuşak bir hale (seviyenin ya da altın rengi).
                  Opacity(
                    opacity: 0.55 * glow.value,
                    child: Container(
                      width: 150 + 40 * glow.value,
                      height: 150 + 40 * glow.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [accent.withValues(alpha: 0.8), accent.withValues(alpha: 0)]),
                      ),
                    ),
                  ),
                  CustomPaint(size: const Size(260, 240), painter: _ConfettiPainter(burst.value, seed: _index)),
                  Opacity(
                    opacity: (d * 2).clamp(0, 1),
                    child: Transform.translate(
                      offset: Offset(0, -60 * (1 - d)),
                      child: Transform.rotate(
                        angle: angle,
                        child: Transform.scale(
                          scale: 0.8 + 0.2 * d,
                          child: _Shine(progress: shine.value, child: child!),
                        ),
                      ),
                    ),
                  ),
                ]);
              },
              child: BadgeArt(key: ValueKey(_index), badge: badge, size: 150),
            ),
          ),
          reveal(
            textIn(0.45),
            Text(tier == null ? 'Yeni rozet açıldı' : 'Yeni seviye: ${tier.$1}',
                style: theme.textTheme.labelLarge?.copyWith(color: accent)),
          ),
          const SizedBox(height: 4),
          reveal(
            textIn(0.52),
            Text(badge['name'] as String, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 6),
          reveal(
            textIn(0.6),
            Text(badge['description'] as String,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          if (widget.fresh.length > 1) ...[
            const SizedBox(height: 10),
            Text('${_index + 1} / ${widget.fresh.length}', style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 12),
          reveal(
            textIn(0.68),
            FilledButton(
              onPressed: last ? () => Navigator.of(context).pop() : _next,
              child: Text(last ? 'Harika' : 'Sıradaki'),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Rozetin üstünden çapraz geçen parlama. Yalnız rozetin boyalı yerlerine düşer (srcATop):
/// madalyon, altıgen, kalkan ve elmasın her birine kendi şeklinde uyar.
class _Shine extends StatelessWidget {
  const _Shine({required this.progress, required this.child});
  final double progress; // 0: başlamadı, 1: geçti
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (progress <= 0 || progress >= 1) return child;
    final x = -0.6 + 2.2 * progress; // bandın merkezi soldan sağa
    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0),
        ],
        stops: [(x - 0.15).clamp(0, 1), x.clamp(0, 1), (x + 0.15).clamp(0, 1)],
      ).createShader(rect),
      child: child,
    );
  }
}

/// Tek seferlik konfeti: merkezden dışa savrulur, yerçekimiyle düşer, döner ve söner.
/// Rastgelelik sabit tohumla: her açılışta aynı, testlerde kararlı.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t, {required int seed}) : _pieces = _make(seed);
  final double t;
  final List<_Piece> _pieces;

  static const _colors = [
    Color(0xFFFFD25A), Color(0xFFFF6FA8), Color(0xFF7FD4FF), Color(0xFF7FD49B), Color(0xFFB9A7FF), Color(0xFFFFB347),
  ];

  static List<_Piece> _make(int seed) {
    final r = math.Random(42 + seed);
    return [
      for (var i = 0; i < 36; i++)
        _Piece(
          angle: -math.pi / 2 + (r.nextDouble() - 0.5) * math.pi * 1.6, // çoğu yukarı ve yanlara
          speed: 110 + r.nextDouble() * 90,
          spin: (r.nextDouble() - 0.5) * 14,
          size: 5 + r.nextDouble() * 4,
          color: _colors[i % _colors.length],
          round: i % 3 == 0,
        ),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final c = Offset(size.width / 2, size.height / 2);
    final fade = t < 0.7 ? 1.0 : 1 - (t - 0.7) / 0.3;
    final e = 1 - (1 - t) * (1 - t); // ilk anda hızlı, sonra yavaşlar
    for (final p in _pieces) {
      final pos = c + Offset(math.cos(p.angle), math.sin(p.angle)) * p.speed * e + Offset(0, 160 * t * t);
      final paint = Paint()..color = p.color.withValues(alpha: fade);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.spin * t);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5), const Radius.circular(1.5)),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

class _Piece {
  const _Piece({
    required this.angle,
    required this.speed,
    required this.spin,
    required this.size,
    required this.color,
    required this.round,
  });
  final double angle, speed, spin, size;
  final Color color;
  final bool round;
}
