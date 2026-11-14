import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/health_api.dart';
import '../api/sync_api.dart';
import '../auth/auth_service.dart';
import '../auth/session_store.dart';
import '../overview/overview_controller.dart';
import '../achievements/achievements_view.dart';
import '../analysis/analysis_view.dart';
import '../overview/overview_section.dart';
import '../projects/projects_controller.dart';
import '../projects/projects_view.dart';
import '../sync/sync_card.dart';
import '../sync/sync_controller.dart';
import '../sync/sync_screen.dart';
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
    this.syncOnOpen = false,
    this.syncStepDuration = const Duration(milliseconds: 800),
  });

  /// true: girişten hemen sonra; senkron başlar ve senkron ekranı açılır.
  final bool syncOnOpen;

  /// Senkron ekranında her aşamanın en az gösterilme süresi (testlerde sıfır).
  final Duration syncStepDuration;

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
  );

  late final OverviewController _overview = OverviewController(
    api: widget.api,
    onUnauthorized: widget.onLogout,
  )..load();

  late final ProjectsController _projects = ProjectsController(
    api: widget.api,
    onUnauthorized: widget.onLogout,
  )..load();

  bool _wasRunning = false;
  int _tab = 0; // 0: Genel Bakış, 1: Analiz, 2: Projeler, 3: Başarımlar

  @override
  void initState() {
    super.initState();
    _sync.addListener(_reloadWhenSyncFinishes);
    if (widget.syncOnOpen) {
      // İlk kare çizildikten sonra (Navigator hazır olunca) ekranı aç ve senkronu başlat.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openSyncScreen();
        _sync.loadAndStart();
      });
    } else {
      _loadSync();
    }
  }

  /// Son senkronu sorar. Hiç senkron yapılmamışsa (ilk giriş) senkronu kendiliğinden
  /// başlatır ve senkron ekranını açar: veri olmadan diğer ekranlar boş kalırdı.
  Future<void> _loadSync() async {
    await _sync.load();
    final firstLogin = _sync.job == null && _sync.error == null;
    if (firstLogin && mounted) _startSync();
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

  /// Senkronu başlatır ve ilerlemeyi tam sayfada gösterir.
  void _startSync() {
    _sync.start();
    _openSyncScreen();
  }

  void _openSyncScreen() => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SyncScreen(controller: _sync, stepDuration: widget.syncStepDuration),
        ),
      );

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
              tooltip: 'Profil',
              icon: const Icon(Icons.account_circle_outlined),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => AccountScreen(
                  session: widget.session,
                  auth: widget.auth!,
                  onLogout: widget.onLogout,
                  onDeleted: widget.onDeleted ?? (_) {},
                  // Genel Bakış verisinden: rozet vitrini ve Model Laboratuvarı'ndaki kural/model payı
                  achievements: _overview.achievements,
                  bySource: (_overview.commitTypes?.raw['by_source'] as Map?)?.cast<String, int>(),
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
      // IndexedStack: sekmeler bellekte kalır; sekme değişince kaydırma/veri kaybolmaz.
      body: IndexedStack(
        index: _tab,
        children: [
          _overviewTab(context),
          AnalysisView(controller: _overview, api: widget.api),
          ProjectsView(controller: _projects),
          AchievementsView(controller: _overview),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.insights), label: 'Genel Bakış'),
          NavigationDestination(icon: Icon(Icons.query_stats), label: 'Analiz'),
          NavigationDestination(icon: Icon(Icons.folder_outlined), label: 'Projeler'),
          NavigationDestination(icon: Icon(Icons.emoji_events_outlined), label: 'Başarımlar'),
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
              SyncCard(controller: _sync, onStart: _startSync, onOpen: _openSyncScreen),
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
