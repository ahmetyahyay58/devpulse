import 'dart:async';

import 'package:flutter/material.dart';
import 'ui/motion.dart';

import 'ui/theme_settings.dart';

import 'api/api_client.dart';
import 'api/health_api.dart';
import 'auth/auth_service.dart';
import 'auth/session_store.dart';
import 'config.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() {
  final api = ApiClient(baseUrl: apiBaseUrl);
  runApp(DevPulseApp(
    auth: AuthService(api: api, store: SecureSessionStore()),
    healthApi: HealthApi(baseUrl: apiBaseUrl),
  ));
}

class DevPulseApp extends StatefulWidget {
  const DevPulseApp({super.key, required this.auth, required this.healthApi});

  final AuthService auth;
  final HealthApi healthApi;

  @override
  State<DevPulseApp> createState() => _DevPulseAppState();
}

class _DevPulseAppState extends State<DevPulseApp> {
  Session? _session;
  bool _restoring = true; // açılışta kayıtlı oturum aranıyor
  // Sunucu uyandırma (docs/dagitim.md): ücretsiz bulut sunucusu boşta uyur, ilk istek ~1 dk sürer.
  // Bu sürede uygulama hata yerine "Sunucu uyanıyor" gösterir.
  bool _serverReady = false;
  bool _slowWake = false; // 2 sn'den uzun sürdü: bekleme ekranını göster
  String? _wakeError;
  Timer? _slowTimer;

  @override
  void dispose() {
    _slowTimer?.cancel();
    super.dispose();
  }
  // Giriş ekranından yeni mi gelindi? Öyleyse ana ekran senkronu başlatıp senkron ekranını
  // açar. Kayıtlı oturumla açılışta (uygulama yeniden açıldı) false kalır.
  bool _freshLogin = false;

  Future<void> _wakeServer() async {
    setState(() {
      _wakeError = null;
      _slowWake = false;
    });
    _slowTimer?.cancel();
    _slowTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _slowWake = true);
    });
    try {
      await widget.healthApi.check(timeout: const Duration(seconds: 90));
      _slowTimer?.cancel();
      if (mounted) setState(() => _serverReady = true);
    } catch (_) {
      _slowTimer?.cancel();
      if (mounted) {
        setState(() => _wakeError = 'Sunucuya ulaşılamadı. İnternet bağlantını kontrol edip tekrar dene.');
      }
    }
  }

  @override
  void initState() {
    super.initState();
    ThemeController.instance.load(); // kayıtlı tema tercihi (yoksa Sistem)
    _wakeServer();
    widget.auth.restore().then((session) {
      if (mounted) {
        setState(() {
          _session = session;
          _restoring = false;
        });
      }
    });
  }

  // Ekran değişse de bildirim gösterebilmek için uygulama düzeyinde tutulur.
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  Future<void> _logout() async {
    await widget.auth.logout();
    setState(() {
      _session = null;
      _freshLogin = false;
    });
  }

  /// Veri silindikten sonra (oturum zaten silindi): giriş ekranı + özet bildirimi.
  void _onDeleted(Map<String, dynamic> result) {
    setState(() => _session = null);
    final d = (result['deleted'] as Map).cast<String, int>();
    final revoked = switch (result['github_grant_revoked']) {
      true => ' GitHub izni kaldırıldı.',
      false => ' GitHub izni kaldırılamadı; GitHub ayarlarından kaldırabilirsin.',
      _ => '',
    };
    _messenger.currentState?.showSnackBar(SnackBar(
      duration: const Duration(seconds: 8),
      content: Text('Verilerin silindi: ${d['repos']} repo, ${d['commits']} commit, '
          '${d['contribution_days']} takvim günü, ${d['sync_jobs']} senkron kaydı.$revoked'),
    ));
  }

  Widget _home() {
    if (!_serverReady && (_slowWake || _wakeError != null)) {
      return WakeScreen(
        error: _wakeError,
        onRetry: _wakeServer,
        onContinue: () => setState(() => _serverReady = true), // çevrimdışı da açılabilsin
      );
    }
    if (_restoring || !_serverReady) return const Scaffold(body: PageLoader());
    final session = _session;
    if (session == null) {
      return LoginScreen(
        auth: widget.auth,
        onLoggedIn: (s) => setState(() {
          _session = s;
          _freshLogin = true;
        }),
      );
    }
    return HomeScreen(
      session: session,
      syncOnOpen: _freshLogin,
      api: widget.auth.api,
      healthApi: widget.healthApi,
      onLogout: _logout,
      auth: widget.auth,
      onDeleted: _onDeleted,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Tema: Sistem (varsayılan) / Açık / Koyu; Profil'den seçilir, cihazda tutulur.
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) => MaterialApp(
        title: 'DevPulse',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: _messenger,
        themeMode: ThemeController.instance.mode,
        theme: appTheme(Brightness.light),
        darkTheme: appTheme(Brightness.dark),
        home: _home(),
      ),
    );
  }
}

/// Açılışta sunucu geç cevap verirse: ücretsiz bulut sunucusu uyuyor olabilir (docs/dagitim.md).
class WakeScreen extends StatelessWidget {
  const WakeScreen({super.key, required this.error, required this.onRetry, required this.onContinue});
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (error == null) ...[
              const PulseLoader(),
              const SizedBox(height: 24),
              Text('Sunucu uyanıyor…', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Ücretsiz sunucu bir süre kullanılmayınca uyur; ilk açılış bir dakikayı bulabilir.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ] else ...[
              Icon(Icons.cloud_off, size: 40, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(error!, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Tekrar dene')),
              TextButton(onPressed: onContinue, child: const Text('Yine de devam et')),
            ],
          ]),
        ),
      ),
    );
  }
}
