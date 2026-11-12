import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
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
    setState(() => _session = null);
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
    if (_restoring) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final session = _session;
    if (session == null) {
      return LoginScreen(
        auth: widget.auth,
        onLoggedIn: (s) => setState(() => _session = s),
      );
    }
    return HomeScreen(
      session: session,
      api: widget.auth.api,
      healthApi: widget.healthApi,
      onLogout: _logout,
      auth: widget.auth,
      onDeleted: _onDeleted,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DevPulse',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messenger,
      // Yalnızca koyu tema; renkler tek bir "tohum" renkten türetilir.
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F8CFF),
          brightness: Brightness.dark,
        ),
      ),
      home: _home(),
    );
  }
}
