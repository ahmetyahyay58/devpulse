import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/health_api.dart';
import '../api/sync_api.dart';
import '../auth/auth_service.dart';
import '../auth/session_store.dart';
import '../overview/overview_controller.dart';
import '../overview/overview_section.dart';
import '../projects/projects_controller.dart';
import '../projects/projects_view.dart';
import '../sync/sync_card.dart';
import '../sync/sync_controller.dart';
import 'account_screen.dart';
import 'health_card.dart';

/// Giriş sonrası ana ekran: alt gezinme çubuğuyla Genel Bakış ve Projeler sekmeleri.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.session,
    required this.api,
    required this.healthApi,
    required this.onLogout,
    this.auth,
    this.onDeleted,
    this.timezone,
    this.pollInterval = const Duration(milliseconds: 1500),
  });

  final Session session;
  final ApiClient api;
  final HealthApi healthApi;
  final VoidCallback onLogout;
  final AuthService? auth; // verilirse Hesap ekranı (veri silme) açılabilir
  final ValueChanged<Map<String, dynamic>>? onDeleted;
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

  late final ProjectsController _projects = ProjectsController(
    api: widget.api,
    onUnauthorized: widget.onLogout,
  )..load();

  bool _wasRunning = false;
  int _tab = 0; // 0: Genel Bakış, 1: Projeler

  @override
  void initState() {
    super.initState();
    _sync.addListener(_reloadWhenSyncFinishes);
  }

  /// Senkron "sürüyor"dan "bitti"ye geçince iki sekme de yeni veriyle yeniden yüklenir.
  void _reloadWhenSyncFinishes() {
    final running = _sync.isRunning;
    if (_wasRunning && !running && _sync.job?.status == 'done') {
      _overview.load();
      _projects.load();
    }
    _wasRunning = running;
  }

  @override
  void dispose() {
    _sync.removeListener(_reloadWhenSyncFinishes);
    _sync.dispose();
    _overview.dispose();
    _projects.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DevPulse'),
        actions: [
          if (widget.auth != null)
            IconButton(
              tooltip: 'Hesap',
              icon: const Icon(Icons.account_circle_outlined),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => AccountScreen(
                  session: widget.session,
                  auth: widget.auth!,
                  onLogout: widget.onLogout,
                  onDeleted: widget.onDeleted ?? (_) {},
                ),
              )),
            ),
          IconButton(
            tooltip: 'Çıkış yap',
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      // IndexedStack: iki sekme de bellekte kalır; sekme değişince kaydırma/veri kaybolmaz.
      body: IndexedStack(
        index: _tab,
        children: [_overviewTab(context), ProjectsView(controller: _projects)],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.insights), label: 'Genel Bakış'),
          NavigationDestination(icon: Icon(Icons.folder_outlined), label: 'Projeler'),
        ],
      ),
    );
  }

  Widget _overviewTab(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
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
    );
  }
}
