import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Uygulamanın hareket dili (Tema Laboratuvarı F2 "canlı"): tek yerden süre ve eğri.
///
/// Kural: yaylanan eğri ([spring]) yalnız konum ve ölçekte kullanılır. Sayılar, saydamlık ve
/// oranlar (halka, çubuk) [out] ile ilerler; böylece ekranda hiçbir an gerçek değerden büyük
/// bir sayı görünmez. Telefonun "animasyonları azalt" ayarı açıksa her şey son halinde çizilir.
class Motion {
  /// Testler animasyonsuz çalışır (test/flutter_test_config.dart açar); hareket testleri kapatır.
  static bool testMode = false;

  static const spring = Cubic(0.34, 1.56, 0.64, 1); // hafif taşar, geri oturur (ölçek/konum)
  static const out = Cubic(0.23, 1, 0.32, 1); // güçlü yavaşlayan, taşmaz (sayı/saydamlık/oran)
  static const speed = 1.25; // "canlı": sakin sürelerin 1,25 katı

  static bool off(BuildContext context) => testMode || MediaQuery.disableAnimationsOf(context);

  static Duration of(BuildContext context, int ms) =>
      off(context) ? Duration.zero : Duration(milliseconds: (ms * speed).round());

  /// Kademeli girişte iki öğe arası gecikme (ms).
  static const stagger = 70;

  /// Alt sayfaların açılış/kapanışı: taşmayan eğri (yaylanırsa sayfa alt kenardan kalkar).
  static AnimationStyle sheet(BuildContext context) => off(context)
      ? AnimationStyle.noAnimation
      : AnimationStyle(
          curve: out,
          duration: of(context, 420),
          reverseCurve: Curves.easeInCubic,
          reverseDuration: of(context, 220),
        );
}

/// t (0..1) içinde [a, b] aralığının [Motion.out] ile ilerlemesi (0..1, taşmaz).
double seg(double t, double a, double b) => t <= a ? 0 : (t >= b ? 1 : Motion.out.transform((t - a) / (b - a)));

/// Sekme girişleri: ana ekran her sekmeyi bununla sarar. Sekme görünür olunca [epoch] artar ve
/// içindeki [OnEnter] animasyonları yeniden oynar. Gizli sekmeler (IndexedStack) oynamaz.
class EntranceScope extends InheritedWidget {
  const EntranceScope({super.key, required this.epoch, required this.active, required super.child});
  final int epoch;
  final bool active;

  static EntranceScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<EntranceScope>();

  @override
  bool updateShouldNotify(EntranceScope old) => old.epoch != epoch || old.active != active;
}

/// Bir kez oynayan animasyon: ilerlemeyi (0..1, doğrusal) [builder]'a verir. Eğriyi kullanan seçer.
/// Kapsam dışında (açılan sayfalar) ilk çizimde bir kez oynar.
class OnEnter extends StatefulWidget {
  const OnEnter({super.key, required this.builder, this.ms = 420, this.delayMs = 0, this.child});
  final Widget Function(BuildContext context, double t, Widget? child) builder;
  final int ms;
  final int delayMs;
  final Widget? child;

  @override
  State<OnEnter> createState() => _OnEnterState();
}

class _OnEnterState extends State<OnEnter> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, value: 1);
  int? _epoch;
  Timer? _delay;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = EntranceScope.maybeOf(context);
    final epoch = scope?.epoch ?? 0;
    if (epoch == _epoch) return;
    _epoch = epoch;
    if (scope != null && !scope.active) return; // gizli sekme: son halinde bekler
    _play();
  }

  void _play() {
    _delay?.cancel();
    if (Motion.off(context)) {
      _c.value = 1;
      return;
    }
    _c.duration = Motion.of(context, widget.ms);
    _c.value = 0;
    final wait = Motion.of(context, widget.delayMs);
    if (wait == Duration.zero) {
      _c.forward();
    } else {
      _delay = Timer(wait, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, child) => widget.builder(context, _c.value, child),
    child: widget.child,
  );
}

/// Kartların kademeli girişi: aşağıdan 14 px yükselir, hafif büyüyerek belirir. [index] sırası.
class Rise extends StatelessWidget {
  const Rise({super.key, this.index = 0, required this.child});
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) => OnEnter(
    ms: 480,
    delayMs: index * Motion.stagger,
    child: child,
    builder: (context, t, child) {
      final move = Motion.spring.transform(t); // konum/ölçek: yaylanabilir
      return Opacity(
        opacity: seg(t, 0, 0.5), // saydamlık: taşmaz
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - move)),
          child: Transform.scale(scale: 0.98 + 0.02 * move, child: child),
        ),
      );
    },
  );
}

/// 0'dan [value]'ya sayarak gelen sayı. Ekran okuyucu yalnız son değeri okur; ara değer hiçbir
/// an [value]'yu geçmez.
class CountUp extends StatelessWidget {
  const CountUp({
    super.key,
    required this.value,
    this.style,
    this.suffix = '',
    this.suffixStyle,
    this.ms = 900,
    this.delayMs = 0,
  });
  final int value;
  final TextStyle? style;
  final String suffix; // birim ("gün"): sayıyla aynı satırda, daha küçük
  final TextStyle? suffixStyle;
  final int ms;
  final int delayMs;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$value$suffix',
    excludeSemantics: true,
    child: OnEnter(
      ms: ms,
      delayMs: delayMs,
      builder: (context, t, _) => Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '${(value * seg(t, 0, 1)).round()}', style: style),
            if (suffix.isNotEmpty) TextSpan(text: suffix, style: suffixStyle),
          ],
        ),
      ),
    ),
  );
}

/// Basınca hafifçe (%3) küçülen ve dokununca hafif titreşim veren sarmalayıcı.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final off = Motion.off(context);
    return Listener(
      onPointerDown: (_) => setState(() => _down = true),
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                widget.onTap!();
              },
        child: AnimatedScale(
          scale: _down && !off ? 0.97 : 1,
          duration: const Duration(milliseconds: 140),
          curve: Motion.out,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Logodaki nabız çizgisi: düz gider, bir tepe yapar, düz devam eder. 0..1 genişlikte noktalar.
Path pulsePath(Size s) {
  final y = s.height * 0.62;
  final x = s.width;
  return Path()
    ..moveTo(0, y)
    ..lineTo(x * 0.46, y)
    ..lineTo(x * 0.50, y)
    ..lineTo(x * 0.525, s.height * 0.12)
    ..lineTo(x * 0.555, s.height * 0.95)
    ..lineTo(x * 0.585, s.height * 0.35)
    ..lineTo(x * 0.605, y)
    ..lineTo(x, y);
}

/// Nabız çizgisinin [from]..[to] (0..1, yol uzunluğuna göre) parçasını çizer.
class PulsePainter extends CustomPainter {
  PulsePainter({required this.color, this.from = 0, this.to = 1, this.width = 2.2});
  final Color color;
  final double from, to, width;

  @override
  void paint(Canvas canvas, Size size) {
    if (to <= from) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final m in pulsePath(size).computeMetrics()) {
      canvas.drawPath(m.extractPath(m.length * from, m.length * to), paint);
    }
  }

  @override
  bool shouldRepaint(PulsePainter old) => old.from != from || old.to != to || old.color != color;
}

/// Uygulamanın imzası: selamlamanın altında nabız çizgisi soldan sağa kendini çizer (bir kez).
class PulseSignature extends StatelessWidget {
  const PulseSignature({super.key, this.height = 22});
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: OnEnter(
          ms: 1100,
          delayMs: 120,
          builder: (context, t, _) => CustomPaint(
            painter: PulsePainter(color: color, to: Curves.easeInOutCubic.transform(t)),
          ),
        ),
      ),
    );
  }
}

/// Dönen halka yerine: nabız çizgisinin üstünden kısa bir parıltı akar (yüklenirken tekrar eder;
/// yükleme bitince kaybolur). Animasyonlar kapalıysa sabit çizgi görünür.
class PulseLoader extends StatefulWidget {
  const PulseLoader({super.key, this.width = 120, this.height = 28, this.color});
  final double width, height;
  final Color? color;

  @override
  State<PulseLoader> createState() => _PulseLoaderState();
}

class _PulseLoaderState extends State<PulseLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.off(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return Semantics(
      label: 'Yükleniyor',
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final head = Curves.easeInOutCubic.transform(_c.value) * 1.3;
            return CustomPaint(
              painter: _LoaderPainter(color: color, head: head, still: Motion.off(context)),
            );
          },
        ),
      ),
    );
  }
}

class _LoaderPainter extends CustomPainter {
  _LoaderPainter({required this.color, required this.head, required this.still});
  final Color color;
  final double head;
  final bool still;

  @override
  void paint(Canvas canvas, Size size) {
    PulsePainter(color: color.withValues(alpha: 0.22)).paint(canvas, size); // iz
    if (still) return;
    PulsePainter(color: color, from: math.max(0, head - 0.3), to: math.min(1, head), width: 2.6).paint(canvas, size);
  }

  @override
  bool shouldRepaint(_LoaderPainter old) => old.head != head || old.color != color || old.still != still;
}

/// Sayfa ortasında bekleme göstergesi (eski `Center(child: CircularProgressIndicator())` yerine).
class PageLoader extends StatelessWidget {
  const PageLoader({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(padding: EdgeInsets.all(24), child: PulseLoader()),
  );
}
