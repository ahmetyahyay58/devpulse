import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'motion.dart';
import 'theme_settings.dart';

class CapsuleItem {
  const CapsuleItem(this.icon, this.label);
  final IconData icon;
  final String label;
}

/// Yüzen kapsül alt menü (Tema Laboratuvarı G2): ekranın altında, kenarlardan ayrık duran yuvarlak
/// çubuk. Seçili sekmenin arkasında mor bir zemin kayar; yazı yalnız seçili sekmede görünür, diğerleri
/// ipucu (tooltip) ve ekran okuyucu etiketiyle tanınır.
class CapsuleNavBar extends StatelessWidget {
  const CapsuleNavBar({super.key, required this.items, required this.selected, required this.onSelect});
  final List<CapsuleItem> items;
  final int selected;
  final ValueChanged<int> onSelect;

  /// Kapsülün kapladığı yükseklik (kaydırılan içeriğin altına bu kadar boşluk bırakılır).
  static const height = 64.0;
  static const margin = 14.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final dur = Motion.of(context, 340);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(margin, 0, margin, margin),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          // Menü yazısı en çok 1,3 kat büyür (Material alt menüsü gibi); kapsül gerekirse uzar.
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: Container(
              constraints: const BoxConstraints(minHeight: height),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: (dark ? const Color(0xFF14172B) : Colors.white).withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: Brand.lavender.withValues(alpha: dark ? 0.22 : 0.35)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: dark ? 0.35 : 0.10),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Kayan zemin: yaylanarak seçili sekmeye gider (konum: yaylanabilir).
                  Positioned.fill(
                    child: AnimatedAlign(
                      duration: dur,
                      curve: Motion.spring,
                      alignment: Alignment(items.length == 1 ? 0 : -1 + 2 * selected / (items.length - 1), 0),
                      child: FractionallySizedBox(
                        widthFactor: 1 / items.length,
                        heightFactor: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Brand.violet.withValues(alpha: dark ? 0.34 : 0.16),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(children: [for (var i = 0; i < items.length; i++) Expanded(child: _tab(context, i, dur))]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(BuildContext context, int i, Duration dur) {
    final theme = Theme.of(context);
    final on = i == selected;
    final color = on ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant;
    final item = items[i];
    return Tooltip(
      message: item.label,
      child: Semantics(
        selected: on,
        button: true,
        label: item.label,
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            if (!on) HapticFeedback.selectionClick();
            onSelect(i);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  scale: on ? 1.08 : 1,
                  duration: dur,
                  curve: Motion.spring,
                  child: Icon(item.icon, size: 22, color: color),
                ),
                // Yazı yalnız seçili sekmede: yükseklik ve saydamlık birlikte açılır.
                AnimatedSwitcher(
                  duration: dur,
                  switchInCurve: Motion.out,
                  switchOutCurve: Motion.out,
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: SizeTransition(sizeFactor: a, axisAlignment: -1, child: child),
                  ),
                  child: on
                      ? Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
                          ),
                        )
                      : const SizedBox(width: 0, height: 0),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
