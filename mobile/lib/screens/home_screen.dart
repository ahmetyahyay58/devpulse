import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/health_api.dart';
import '../api/sync_api.dart';
import '../auth/session_store.dart';
import '../overview/overview_controller.dart';
import '../overview/overview_section.dart';
import '../sync/sync_card.dart';
import '../sync/sync_controller.dart';
import 'health_card.dart';

/// Giriş sonrası ana ekran: senkron kartı, Genel Bakış ve sunucu durumu.
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

  late final OverviewController _overview = OverviewController(
    api: widget.api,
    onUnauthorized: widget.onLogout,
  )..load();

  bool _wasRunning = false;

  @override
  void initState() {
    super.initState();
    _sync.addListener(_reloadOverviewWhenSyncFinishes);
  }

  /// Senkron "sürüyor"dan "bitti"ye geçince metrikler yeni veriyle yeniden yüklenir.
  void _reloadOverviewWhenSyncFinishes() {
    final running = _sync.isRunning;
    if (_wasRunning && !running && _sync.job?.status == 'done') _overview.load();
    _wasRunning = running;
  }

  @override
  void dispose() {
    _sync.removeListener(_reloadOverviewWhenSyncFinishes);
    _sync.dispose();
    _overview.dispose();
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
                const SizedBox(height: 24),
                Text('Genel Bakış', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                OverviewSection(controller: _overview),
                const SizedBox(height: 24),
                HealthCard(api: widget.healthApi), // geliştirme amaçlı; en altta
              ],
            ),
          ),
        ),
      ),
    );
  }
}
