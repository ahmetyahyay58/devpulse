import 'package:flutter/material.dart';

import 'theme_settings.dart';

/// Kısa bildirim balonu: ekranın üst ortasında belirir, birkaç saniye sonra kendiliğinden kaybolur.
/// Alttaki çubuk (SnackBar) yerine kullanılır (kullanıcı tercihi, 17 Kas). Başarı/hata hem simge hem
/// renkle söylenir; renk tek başına anlam taşımaz.
void showToast(BuildContext context, String message, {bool success = true}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Toast(message: message, success: success, onDone: () => entry.remove()),
  );
  overlay.insert(entry);
}

class _Toast extends StatefulWidget {
  const _Toast({required this.message, required this.success, required this.onDone});
  final String message;
  final bool success;
  final VoidCallback onDone;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  // Tek animasyon: belirme (ilk %10), bekleme, kaybolma (son %10). Zamanlayıcı (Timer) yok;
  // böylece testlerde bekleyen zamanlayıcı kalmaz.
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..forward().whenComplete(widget.onDone);

  late final Animation<double> _opacity = TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 10),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 80),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 10),
  ]).animate(_c);

  late final Animation<double> _scale = TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.0).chain(CurveTween(curve: Curves.easeOutBack)), weight: 10),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 90),
  ]).animate(_c);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.success ? successColor(context) : theme.colorScheme.error;
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 72,
      left: 24,
      right: 24,
      child: IgnorePointer(
        child: Center(
          child: FadeTransition(
            opacity: _opacity,
            child: ScaleTransition(
              scale: _scale,
              child: Material(
                elevation: 8,
                color: theme.colorScheme.surfaceContainerHigh,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(color: color.withValues(alpha: 0.6)),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(widget.success ? Icons.check_circle_rounded : Icons.error_rounded, color: color),
                      const SizedBox(width: 10),
                      Flexible(child: Text(widget.message, style: theme.textTheme.bodyMedium)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
