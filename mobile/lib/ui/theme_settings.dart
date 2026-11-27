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

/// Logodan ölçülen renkler (assets/icon/app_icon.png): çivit-mor halka, lavanta parıltı,
/// neredeyse siyah zemin. Temanın geri kalanı bunlardan türer.
class Brand {
  static const violet = Color(0xFF6C5CE7); // halkanın ve "Pulse" yazısının ana tonu
  static const lavender = Color(0xFFA99CFF); // koyu zeminde birincil (okunur açık ton)
  static const ink = Color(0xFF090B14); // logonun zemini
  static const inkRaised = Color(0xFF121528); // kart: zeminden bir adım açık, mora çalan
  static const mist = Color(0xFFF6F5FF); // açık temanın zemini: lavantaya çalan beyaz

  /// "Dev" beyazdan "Pulse" morundan geçen logo geçişi (başlıklar, vurgular).
  static const gradient = LinearGradient(colors: [Color(0xFFB9B3FF), violet]);
  static const gradientOnLight = LinearGradient(colors: [violet, Color(0xFF4B3CC4)]);

  /// İkinci renk (Tema Laboratuvarı B2, nane): yalnız değişim ve vurgu noktalarında (haftalık fark,
  /// "N eksik" sayısı). Durum rengi değildir; "tamam/var" için [successColor] kullanılır.
  static const mintOnDark = Color(0xFF3DD6BB);
  static const mintOnLight = Color(0xFF0B8573); // beyaz zeminde ~4.6:1
}

/// Temaya göre nane vurgusu (koyu zeminde açık, açık zeminde koyu ton).
Color mintColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? Brand.mintOnDark : Brand.mintOnLight;

/// Uygulamanın iki teması; renkler logonun morundan türer, koyu temanın zemini logonun zemini.
ThemeData appTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  var scheme = ColorScheme.fromSeed(
    seedColor: Brand.violet,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
  );
  scheme = dark
      ? scheme.copyWith(
          primary: Brand.lavender,
          surface: Brand.ink,
          surfaceContainerLowest: const Color(0xFF06070D),
          surfaceContainerLow: const Color(0xFF0E1020),
          surfaceContainer: Brand.inkRaised,
          surfaceContainerHigh: const Color(0xFF191C33),
          surfaceContainerHighest: const Color(0xFF22253F),
          outlineVariant: const Color(0xFF2A2D4A),
        )
      : scheme.copyWith(
          primary: const Color(0xFF5546D6), // beyaz zeminde 4.5:1 üstü
          surface: Brand.mist,
          surfaceContainerLowest: Colors.white,
          surfaceContainerLow: Colors.white,
          surfaceContainer: const Color(0xFFEFEDFC),
          surfaceContainerHigh: const Color(0xFFE8E5FA),
          surfaceContainerHighest: const Color(0xFFE0DCF7),
          outlineVariant: const Color(0xFFDCD8F2),
        );
  // Cam kart (Tema Laboratuvarı C2): yarı saydam zemin + ince mor kenar. Arkasındaki ışık
  // (AuroraBackground) hafifçe görünür. Bulanıklık filtresi yok: kaydırmada telefonu yorar.
  final cardColor = dark ? Brand.inkRaised.withValues(alpha: 0.62) : Colors.white.withValues(alpha: 0.72);
  final cardEdge = Brand.lavender.withValues(alpha: dark ? 0.22 : 0.35);
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    cardTheme: CardThemeData(
      color: cardColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cardEdge),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: scheme.onSurface),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? const Color(0xFF0E1020) : Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Brand.violet.withValues(alpha: dark ? 0.35 : 0.16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Brand.violet,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: Brand.violet,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  );
}

/// Logodaki gibi "DevPulse": "Dev" düz, "Pulse" mor geçişli.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.style});
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = (style ?? Theme.of(context).textTheme.headlineMedium)?.copyWith(fontWeight: FontWeight.w800);
    return Semantics(
      label: 'DevPulse',
      excludeSemantics: true,
      // Dar ekranda ve büyük yazı boyutunda taşmasın: sığmazsa orantılı küçülür.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Dev', style: base),
            ShaderMask(
              // Açık zeminde lavanta soluk kalır: aynı geçişin koyu hali.
              shaderCallback: (Theme.of(context).brightness == Brightness.dark ? Brand.gradient : Brand.gradientOnLight)
                  .createShader,
              blendMode: BlendMode.srcIn,
              child: Text('Pulse', style: base),
            ),
          ],
        ),
      ),
    );
  }
}

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Tema', style: theme.textTheme.titleMedium),
              const SizedBox(height: 10),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto_outlined),
                    label: Text('Sistem'),
                  ),
                  ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Açık')),
                  ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Koyu')),
                ],
                selected: {controller.mode},
                showSelectedIcon: false,
                onSelectionChanged: (s) => controller.set(s.first),
              ),
              const SizedBox(height: 8),
              Text(
                'Sistem: telefonunun açık/koyu ayarını izler. Tercih yalnız bu cihazda tutulur.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
