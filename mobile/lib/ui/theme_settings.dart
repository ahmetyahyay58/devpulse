import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tema tercihi: Sistem (varsayılan, telefonun ayarını izler), Açık ya da Koyu.
/// Yalnız bu cihazda tutulur; sunucuya gitmez.
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final instance = ThemeController._();

  static const prefKey = 'theme_mode';
  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  /// Açılışta kayıtlı tercihi okur (yoksa Sistem).
  Future<void> load() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(prefKey);
      _mode = ThemeMode.values.firstWhere((m) => m.name == saved, orElse: () => ThemeMode.system);
      notifyListeners();
    } catch (_) {} // depo yoksa varsayılan kalır
  }

  Future<void> set(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance()).setString(prefKey, mode.name);
    } catch (_) {}
  }
}

const _seed = Color(0xFF4F8CFF);

/// Uygulamanın iki teması; renkler aynı tohum renkten türer.
ThemeData appTheme(Brightness brightness) => ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: brightness),
    );

/// "Tamam / var / bitti" yeşili: koyu zeminde açık, açık zeminde koyu ton (okunurluk).
Color successColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? const Color(0xFF4CD07D) : const Color(0xFF0B8A3A);

/// Profil'deki seçim: Sistem / Açık / Koyu.
class ThemeModeTile extends StatelessWidget {
  const ThemeModeTile({super.key, required this.controller});
  final ThemeController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Tema', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_outlined), label: Text('Sistem')),
                ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Açık')),
                ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Koyu')),
              ],
              selected: {controller.mode},
              showSelectedIcon: false,
              onSelectionChanged: (s) => controller.set(s.first),
            ),
            const SizedBox(height: 8),
            Text('Sistem: telefonunun açık/koyu ayarını izler. Tercih yalnız bu cihazda tutulur.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }
}
