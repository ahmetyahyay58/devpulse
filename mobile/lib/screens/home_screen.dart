import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/health_api.dart';
import '../api/sync_api.dart';
import '../auth/session_store.dart';
import '../sync/sync_card.dart';
import '../sync/sync_controller.dart';
import 'health_card.dart';

/// Giriş sonrası ana ekran: senkron kartı ve sunucu durumu. (Genel Bakış sonra gelecek.)
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.session,
    required this.api,
    required this.healthApi,
    required this.onLogout,
    this.timezone,
    this.pollInterval = const Duration(milliseconds: 1500),
  });

  final Session session;
  final ApiClient api;
  final HealthApi healthApi;
  final VoidCallback onLogout;
  final TimezoneProvider? timezone; // testlerde sabit saat dilimi vermek için
  final Duration pollInterval;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Denetleyicinin sahibi bu ekran: açılışta kurulur, kapanışta kapatılır.
  late final SyncController _sync = SyncController(
    api: SyncApi(widget.api),
    session: widget.session,
    onUnauthorized: widget.onLogout, // oturum süresi dolduysa giriş ekranına dön
    timezone: widget.timezone,
    pollInterval: widget.pollInterval,
  )..load();

  @override
  void dispose() {
    _sync.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('DevPulse'),
        actions: [
          IconButton(
            tooltip: 'Çıkış yap',
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Merhaba, ${widget.session.login}', style: theme.textTheme.headlineSmall),
                if (widget.session.isDemo) ...[
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(label: Text('Demo kullanıcı · sentetik veri')),
                  ),
                ],
                const SizedBox(height: 16),
                SyncCard(controller: _sync),
                const SizedBox(height: 16),
                HealthCard(api: widget.healthApi),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
