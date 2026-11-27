import 'package:flutter/material.dart';

import 'theme_settings.dart';

/// Ana ekranın arkasındaki hareketsiz mor ışık (Tema Laboratuvarı C2 "cam + arka ışık").
/// Yarı saydam kartlar bunun üstünde durur. Yalnız ana ekranda kullanılır: açılan sayfaların
/// zemini düz kalır (geçişte alttaki sayfa görünmesin).
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = Theme.of(context).colorScheme.surface;
    Color glow(Color c, double a) => c.withValues(alpha: dark ? a : a * 0.45);
    return DecoratedBox(
      decoration: BoxDecoration(color: base),
      child: DecoratedBox(
        // Üç yumuşak ışık: sol üstte mor, sağ ortada nane, altta mor. Hiçbiri hareket etmez.
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.75, -0.9),
            radius: 0.9,
            colors: [glow(Brand.violet, 0.34), Colors.transparent],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(1.0, 0.0),
              radius: 0.7,
              colors: [glow(Brand.mintOnDark, 0.10), Colors.transparent],
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.2, 1.1),
                radius: 0.9,
                colors: [glow(Brand.violet, 0.24), Colors.transparent],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
