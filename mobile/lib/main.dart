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

  Future<void> _logout() async {
    await widget.auth.logout();
    setState(() => _session = null);
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
    return HomeScreen(session: session, healthApi: widget.healthApi, onLogout: _logout);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DevPulse',
      debugShowCheckedModeBanner: false,
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
