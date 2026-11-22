import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Yıllık özet sahneleri: her slaydın konusunu anlatan küçük çizimler (Spotify Wrapped benzeri).
///
/// Hepsi tek bir değerden (t: slaydın ilerlemesi, 0-1) çizilir; ayrı bir animasyon döngüsü
/// yoktur. Slayt bitince hareket de biter. Sahnelerde yalnız özetteki gerçek sayılar kullanılır;
/// süs hareketleri (yükselen kareler, yıldızlar) veri gibi okunmaz.

/// [a, b] aralığında 0'dan 1'e, güçlü ease-out ile.
double seg(double t, double a, double b) {
  final x = ((t - a) / (b - a)).clamp(0.0, 1.0);
  return 1 - math.pow(1 - x, 3).toDouble();
}

const _white = Colors.white;
const _monthsShort = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];

TextPainter _text(String s, double size, {Color color = _white, FontWeight weight = FontWeight.w600}) =>
    TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: color, fontSize: size, fontWeight: weight)),
      textDirection: TextDirection.ltr,
    )..layout();

void _drawCentered(Canvas c, TextPainter p, Offset center) => p.paint(c, center - Offset(p.width / 2, p.height / 2));

/// Toplam commit: alttan yükselen küçük "commit kareleri" (süs) ve ortada büyüyen bir halka.
class CommitsScene extends CustomPainter {
  CommitsScene(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.Random(7);
    for (var i = 0; i < 46; i++) {
      final x = r.nextDouble() * size.width;
      final phase = r.nextDouble();
      final speed = 0.5 + r.nextDouble() * 0.8;
      final p = (phase + t * speed * 1.6) % 1; // aşağıdan yukarı
      final y = size.height * (1 - p);
      final s = 4 + r.nextDouble() * 8;
      final alpha = math.sin(p * math.pi) * seg(t, 0, 0.15);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y), width: s, height: s), Radius.circular(s / 4)),
        Paint()..color = (i % 4 == 0 ? const Color(0xFF7FD4FF) : _white).withValues(alpha: 0.65 * alpha),
      );
    }
    final c = size.center(Offset.zero);
    final grow = seg(t, 0.02, 0.35);
    canvas.drawCircle(c, 70 * grow, Paint()..color = _white.withValues(alpha: 0.12));
    canvas.drawCircle(
      c,
      70 * grow,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = _white.withValues(alpha: 0.7),
    );
    // Ortada commit simgesi: çizgi üstünde bir düğüm.
    final k = seg(t, 0.15, 0.4);
    final line = Paint()
      ..color = _white.withValues(alpha: k)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c - Offset(40 * k, 0), c + Offset(40 * k, 0), line);
    canvas.drawCircle(c, 16 * k, Paint()..color = _white.withValues(alpha: k));
    canvas.drawCircle(c, 8 * k, Paint()..color = const Color(0xFF1E3A8A));
  }

  @override
  bool shouldRepaint(CommitsScene o) => o.t != t;
}

/// En yoğun ay: 12 ay; ışık aylar üzerinde gezip en yoğun ayda durur, o ay büyür ve parlar.
class BusiestMonthScene extends CustomPainter {
  BusiestMonthScene(this.t, this.month);
  final double t;
  final int month; // 1-12

  @override
  void paint(Canvas canvas, Size size) {
    const cols = 4, rows = 3;
    final cw = size.width / cols, ch = size.height / rows;
    // Işık önce Ocak'tan en yoğun aya kadar yürür, sonra orada kalır.
    final walk = seg(t, 0.02, 0.4);
    final spot = (walk * (month - 1)).round(); // 0 tabanlı
    final landed = seg(t, 0.4, 0.55);
    for (var i = 0; i < 12; i++) {
      final center = Offset(cw * (i % cols + 0.5), ch * (i ~/ cols + 0.5));
      final isTarget = i == month - 1;
      final lit = i == spot;
      final appear = seg(t, i * 0.012, 0.12 + i * 0.012);
      var radius = math.min(cw, ch) * 0.34 * appear;
      if (isTarget) radius *= 1 + 0.35 * landed;
      final fill = isTarget && landed > 0
          ? Color.lerp(_white.withValues(alpha: 0.18), const Color(0xFFFFD25A), landed)!
          : _white.withValues(alpha: lit ? 0.45 : 0.14);
      if (isTarget && landed > 0) {
        canvas.drawCircle(center, radius * 1.5, Paint()..color = const Color(0xFFFFD25A).withValues(alpha: 0.25 * landed));
      }
      canvas.drawCircle(center, radius, Paint()..color = fill);
      final color = isTarget && landed > 0.5 ? const Color(0xFF4C1D95) : _white.withValues(alpha: appear);
      _drawCentered(canvas, _text(_monthsShort[i], 12 + (isTarget ? 4 * landed : 0), color: color), center);
    }
  }

  @override
  bool shouldRepaint(BusiestMonthScene o) => o.t != t;
}

/// En çok kullanılan dil: payına kadar dolan halka, ortada yüzde sayacı.
class LanguageScene extends CustomPainter {
  LanguageScene(this.t, this.share);
  final double t;
  final double share; // 0-1

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) * 0.38;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r, ring..color = _white.withValues(alpha: 0.15 * seg(t, 0, 0.1)));
    final fill = share * seg(t, 0.05, 0.45);
    if (fill > 0) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, 2 * math.pi * fill, false,
          ring..color = const Color(0xFF5EEAD4));
    }
    _drawCentered(canvas, _text('%${(fill * 100).round()}', 34, weight: FontWeight.w800), c);
  }

  @override
  bool shouldRepaint(LanguageScene o) => o.t != t;
}

/// Gece kuşu: gökyüzüne doğan hilal, parıldayan yıldızlar; saat kadranında ibre en yoğun saate döner.
class NightScene extends CustomPainter {
  NightScene(this.t, this.peakHour);
  final double t;
  final int? peakHour;

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.Random(3);
    for (var i = 0; i < 28; i++) {
      final p = Offset(r.nextDouble() * size.width, r.nextDouble() * size.height * 0.9);
      final twinkle = 0.45 + 0.55 * math.sin(t * math.pi * 6 + i);
      final a = seg(t, i * 0.01, 0.2 + i * 0.01) * twinkle;
      canvas.drawCircle(p, 1 + r.nextDouble() * 1.8, Paint()..color = _white.withValues(alpha: a.clamp(0, 1)));
    }
    // Hilal: aşağıdan yükselir.
    final rise = seg(t, 0.0, 0.4);
    final moon = Offset(size.width * 0.28, size.height * (0.95 - 0.55 * rise));
    canvas.drawCircle(moon, 34, Paint()..color = const Color(0xFFFFE7A3).withValues(alpha: 0.25 * rise));
    final path = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: moon, radius: 26)),
      Path()..addOval(Rect.fromCircle(center: moon + const Offset(12, -8), radius: 22)),
    );
    canvas.drawPath(path, Paint()..color = const Color(0xFFFFE7A3).withValues(alpha: rise));

    if (peakHour == null) return;
    // Saat kadranı (24 saat): ibre gece yarısından en yoğun saate döner.
    final appear = seg(t, 0.15, 0.35);
    final c = Offset(size.width * 0.72, size.height * 0.5);
    final rad = math.min(size.width, size.height) * 0.3;
    canvas.drawCircle(c, rad, Paint()..color = _white.withValues(alpha: 0.12 * appear));
    canvas.drawCircle(
        c,
        rad,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = _white.withValues(alpha: 0.6 * appear));
    // Gece dilimi (00-06) vurgusu.
    canvas.drawArc(Rect.fromCircle(center: c, radius: rad - 6), -math.pi / 2, math.pi / 2, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..color = const Color(0xFF818CF8).withValues(alpha: 0.8 * appear));
    for (var h = 0; h < 24; h += 6) {
      final a = -math.pi / 2 + h / 24 * 2 * math.pi;
      _drawCentered(canvas, _text('$h', 10, color: _white.withValues(alpha: 0.7 * appear)),
          c + Offset(math.cos(a), math.sin(a)) * (rad - 18));
    }
    final sweep = seg(t, 0.25, 0.6);
    final angle = -math.pi / 2 + (peakHour! / 24) * 2 * math.pi * sweep;
    canvas.drawLine(c, c + Offset(math.cos(angle), math.sin(angle)) * (rad - 10),
        Paint()
          ..color = const Color(0xFFFFD25A).withValues(alpha: appear)
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round);
    canvas.drawCircle(c, 5, Paint()..color = const Color(0xFFFFD25A).withValues(alpha: appear));
  }

  @override
  bool shouldRepaint(NightScene o) => o.t != t;
}

/// En uzun seri: günler birer birer alev alır (en çok 30 gösterilir, fazlası "+"), sonra büyük alev.
class StreakScene extends CustomPainter {
  StreakScene(this.t, this.days);
  final double t;
  final int days;

  @override
  void paint(Canvas canvas, Size size) {
    final shown = math.min(days, 30);
    const perRow = 10;
    final rows = (shown / perRow).ceil().clamp(1, 3);
    final cell = math.min(size.width / perRow, 26.0);
    final top = size.height - rows * cell - 6;
    final left = (size.width - perRow * cell) / 2;
    final lit = seg(t, 0.03, 0.4) * shown;
    for (var i = 0; i < shown; i++) {
      final center = Offset(left + cell * (i % perRow + 0.5), top + cell * (i ~/ perRow + 0.5));
      final on = (lit - i).clamp(0.0, 1.0);
      canvas.drawCircle(center, cell * 0.32, Paint()..color = _white.withValues(alpha: 0.18));
      if (on > 0) {
        canvas.drawCircle(center, cell * (0.2 + 0.16 * on),
            Paint()..color = Color.lerp(const Color(0xFFFFC23D), const Color(0xFFFF7A1A), (i % 3) / 3)!.withValues(alpha: on));
      }
    }
    if (days > 30) {
      _drawCentered(canvas, _text('+${days - 30}', 14), Offset(size.width / 2, top - 14));
    }
    // Büyük alev: dizi dolunca yükselir; hafifçe titrer (slayt süresince).
    final grow = seg(t, 0.35, 0.6);
    if (grow <= 0) return;
    final base = Offset(size.width / 2, top - (days > 30 ? 30 : 12));
    final h = 92 * grow * (1 + 0.04 * math.sin(t * math.pi * 10));
    Path flame(double hh, double w) => Path()
      ..moveTo(base.dx, base.dy)
      ..cubicTo(base.dx - w, base.dy, base.dx - w * 1.1, base.dy - hh * 0.45, base.dx - w * 0.3, base.dy - hh * 0.75)
      ..cubicTo(base.dx - w * 0.35, base.dy - hh * 0.5, base.dx - w * 0.05, base.dy - hh * 0.5, base.dx, base.dy - hh)
      ..cubicTo(base.dx + w * 0.35, base.dy - hh * 0.7, base.dx + w * 1.1, base.dy - hh * 0.45, base.dx + w, base.dy - hh * 0.15)
      ..cubicTo(base.dx + w * 0.9, base.dy, base.dx + w * 0.4, base.dy, base.dx, base.dy)
      ..close();
    canvas.drawPath(flame(h, 38 * grow), Paint()..color = const Color(0xFFFF7A1A));
    canvas.drawPath(flame(h * 0.66, 24 * grow), Paint()..color = const Color(0xFFFFC23D));
    canvas.drawPath(flame(h * 0.33, 11 * grow), Paint()..color = const Color(0xFFFFF1B8));
  }

  @override
  bool shouldRepaint(StreakScene o) => o.t != t;
}

/// Kodlama süresi: kum saati; üst hazne boşalır, alt dolar, kum akar.
class HourglassScene extends CustomPainter {
  HourglassScene(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    const w = 66.0, h = 84.0;
    final appear = seg(t, 0, 0.15);
    final flow = seg(t, 0.1, 0.9); // slayt boyunca akar
    final glass = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = _white.withValues(alpha: 0.8 * appear);
    final top = Path()
      ..moveTo(c.dx - w, c.dy - h)
      ..lineTo(c.dx + w, c.dy - h)
      ..quadraticBezierTo(c.dx + w, c.dy - 18, c.dx + 6, c.dy)
      ..lineTo(c.dx - 6, c.dy)
      ..quadraticBezierTo(c.dx - w, c.dy - 18, c.dx - w, c.dy - h);
    final bottom = Path()
      ..moveTo(c.dx - 6, c.dy)
      ..lineTo(c.dx + 6, c.dy)
      ..quadraticBezierTo(c.dx + w, c.dy + 18, c.dx + w, c.dy + h)
      ..lineTo(c.dx - w, c.dy + h)
      ..quadraticBezierTo(c.dx - w, c.dy + 18, c.dx - 6, c.dy);
    const sand = Color(0xFFFFD27A);
    // Üstteki kum: azalır.
    canvas.save();
    canvas.clipPath(top);
    final topLevel = c.dy - h + (h * 0.85) * flow;
    canvas.drawRect(Rect.fromLTRB(c.dx - w, topLevel, c.dx + w, c.dy), Paint()..color = sand.withValues(alpha: appear));
    canvas.restore();
    // Alttaki kum: tepe şeklinde birikir.
    canvas.save();
    canvas.clipPath(bottom);
    final pile = h * 0.85 * flow;
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - w, c.dy + h)
        ..lineTo(c.dx + w, c.dy + h)
        ..lineTo(c.dx + w, c.dy + h - pile * 0.6)
        ..quadraticBezierTo(c.dx, c.dy + h - pile * 1.3, c.dx - w, c.dy + h - pile * 0.6)
        ..close(),
      Paint()..color = sand.withValues(alpha: appear),
    );
    canvas.restore();
    // Akan kum çizgisi.
    if (flow > 0 && flow < 1) {
      canvas.drawLine(c, c + Offset(0, h - pile * 0.9), Paint()
        ..color = sand
        ..strokeWidth = 3);
    }
    canvas.drawPath(top, glass);
    canvas.drawPath(bottom, glass);
    final cap = Paint()..color = _white.withValues(alpha: 0.9 * appear);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c - const Offset(0, h + 6), width: w * 2 + 20, height: 10), const Radius.circular(5)), cap);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c + const Offset(0, h + 6), width: w * 2 + 20, height: 10), const Radius.circular(5)), cap);
  }

  @override
  bool shouldRepaint(HourglassScene o) => o.t != t;
}

/// Dil yolculuğu: Ocak-Aralık zaman çizgisi; her dil ilk commit'inin ayında belirir.
class JourneyScene extends CustomPainter {
  JourneyScene(this.t, this.steps);
  final double t;
  final List<({String language, int firstMonth})> steps;

  static const _colors = [Color(0xFF5EEAD4), Color(0xFFFFD25A), Color(0xFFFF6FA8), Color(0xFF7FD4FF), Color(0xFFB9A7FF)];

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * 0.62;
    final left = 18.0, right = size.width - 18;
    final draw = seg(t, 0.02, 0.45);
    final x = left + (right - left) * draw;
    canvas.drawLine(Offset(left, y), Offset(right, y), Paint()
      ..color = _white.withValues(alpha: 0.2)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round);
    canvas.drawLine(Offset(left, y), Offset(x, y), Paint()
      ..color = _white
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round);
    for (final m in [1, 4, 7, 10, 12]) {
      final mx = left + (right - left) * (m - 1) / 11;
      _drawCentered(canvas, _text(_monthsShort[m - 1], 10, color: _white.withValues(alpha: 0.7)), Offset(mx, y + 18));
    }
    for (final (i, s) in steps.take(5).indexed) {
      final mx = left + (right - left) * (s.firstMonth - 1) / 11;
      if (x < mx) continue; // çizgi oraya varınca belirir
      final pop = seg(t, 0.02 + 0.43 * (s.firstMonth - 1) / 11, 0.1 + 0.43 * (s.firstMonth - 1) / 11);
      final color = _colors[i % _colors.length];
      canvas.drawCircle(Offset(mx, y), 9 * pop, Paint()..color = color);
      final up = i.isEven ? -1 : 1;
      final labelY = y + up * (40 + 0.0) * pop - (up > 0 ? -6 : 0);
      canvas.drawLine(Offset(mx, y), Offset(mx, labelY), Paint()
        ..color = color.withValues(alpha: pop)
        ..strokeWidth = 2);
      _drawCentered(canvas, _text(s.language, 14, color: _white.withValues(alpha: pop)),
          Offset(mx.clamp(40, size.width - 40), labelY + up * 12));
    }
  }

  @override
  bool shouldRepaint(JourneyScene o) => o.t != t;
}

/// Kod incelemesi: kod satırlarının üstünde gezen büyüteç; geçtiği satırlar onay alır.
class ReviewScene extends CustomPainter {
  ReviewScene(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    const lines = 6;
    final left = size.width * 0.15, w = size.width * 0.7;
    final rowH = size.height / (lines + 1);
    final scan = seg(t, 0.05, 0.75);
    for (var i = 0; i < lines; i++) {
      final y = rowH * (i + 1);
      final len = w * [0.8, 0.55, 0.7, 0.4, 0.65, 0.5][i];
      final appear = seg(t, i * 0.02, 0.1 + i * 0.02);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(left, y - 5, len * appear, 10), const Radius.circular(5)),
        Paint()..color = _white.withValues(alpha: 0.35),
      );
      final checked = scan * lines > i + 0.5;
      if (checked) {
        final cx = left + w + 4;
        canvas.drawPath(
          Path()
            ..moveTo(cx - 6, y)
            ..lineTo(cx - 1, y + 5)
            ..lineTo(cx + 8, y - 6),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round
            ..color = const Color(0xFF86EFAC),
        );
      }
    }
    final ly = rowH * (1 + scan * (lines - 1));
    final lx = left + w * (0.3 + 0.4 * math.sin(scan * math.pi * 3).abs());
    final glass = Offset(lx, ly);
    canvas.drawCircle(glass, 26, Paint()..color = _white.withValues(alpha: 0.18));
    canvas.drawCircle(glass, 26, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = _white);
    canvas.drawLine(glass + const Offset(18, 18), glass + const Offset(38, 38), Paint()
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = _white);
  }

  @override
  bool shouldRepaint(ReviewScene o) => o.t != t;
}

/// Kapanış: açılan rozet oranına kadar dolan halka ve bir kez patlayan konfeti.
class FinaleScene extends CustomPainter {
  FinaleScene(this.t, this.unlocked, this.total);
  final double t;
  final int unlocked, total;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final burst = seg(t, 0.1, 0.7);
    if (burst > 0 && burst < 1) {
      final r = math.Random(11);
      const colors = [Color(0xFFFFD25A), Color(0xFFFF6FA8), Color(0xFF7FD4FF), Color(0xFF86EFAC), Color(0xFFB9A7FF)];
      for (var i = 0; i < 40; i++) {
        final a = r.nextDouble() * 2 * math.pi;
        final d = (60 + r.nextDouble() * 90) * burst;
        final p = c + Offset(math.cos(a), math.sin(a)) * d + Offset(0, 50 * burst * burst);
        canvas.save();
        canvas.translate(p.dx, p.dy);
        canvas.rotate(a + burst * 6);
        canvas.drawRect(const Rect.fromLTWH(-4, -2, 8, 4),
            Paint()..color = colors[i % colors.length].withValues(alpha: 1 - burst));
        canvas.restore();
      }
    }
    final rad = math.min(size.width, size.height) * 0.34;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, rad, ring..color = _white.withValues(alpha: 0.18));
    final fill = total == 0 ? 0.0 : unlocked / total * seg(t, 0.05, 0.45);
    if (fill > 0) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: rad), -math.pi / 2, 2 * math.pi * fill, false,
          ring..color = const Color(0xFFFFD25A));
    }
    // Ortada madalya.
    final m = seg(t, 0.3, 0.55);
    canvas.drawCircle(c, rad * 0.55 * m, Paint()..color = const Color(0xFFFFD25A).withValues(alpha: m));
    canvas.drawCircle(c, rad * 0.42 * m, Paint()..color = const Color(0xFFE0A100).withValues(alpha: m));
    final star = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final rr = (i.isEven ? rad * 0.3 : rad * 0.13) * m;
      final p = c + Offset(math.cos(a), math.sin(a)) * rr;
      i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(star..close(), Paint()..color = const Color(0xFFFFF6D6).withValues(alpha: m));
  }

  @override
  bool shouldRepaint(FinaleScene o) => o.t != t;
}
