import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../api/api_client.dart';
import '../api/sync_api.dart';
import '../auth/session_store.dart';

/// Cihazın IANA saat dilimi (ör. "Europe/Istanbul"); okunamazsa null.
typedef TimezoneProvider = Future<String?> Function();

Future<String?> deviceTimezone() async {
  try {
    return (await FlutterTimezone.getLocalTimezone()).identifier;
  } catch (_) {
    return null; // backend saat dilimi olmadan da çalışır; eskisini korur
  }
}

/// Senkronu başlatır ve bitene kadar izler. Ekran bunu dinler (ChangeNotifier).
class SyncController extends ChangeNotifier {
  SyncController({
    required this.api,
    required this.session,
    required this.onUnauthorized,
    TimezoneProvider? timezone,
    this.pollInterval = const Duration(milliseconds: 1500),
  }) : _timezone = timezone ?? deviceTimezone;

  final SyncApi api;
  final Session session;
  final VoidCallback onUnauthorized; // oturum süresi dolduysa çıkış yaptırmak için
  final TimezoneProvider _timezone;
  final Duration pollInterval;

  SyncJob? job; // en son bilinen iş
  String? error;
  bool loading = true; // açılışta son iş soruluyor
  bool _disposed = false;
  bool _polling = false;

  bool get isRunning => job?.isActive ?? false;

  /// Açılışta: son işi getir; hâlâ sürüyorsa izlemeye kaldığı yerden devam et.
  Future<void> load() async {
    await _guard(() async {
      job = await api.latest();
      if (job?.isActive ?? false) _follow(job!.id);
    });
    loading = false;
    _notify();
  }

  Future<void> start() async {
    if (isRunning) return;
    error = null;
    _notify();
    await _guard(() async {
      final id = await api.start(
        githubToken: session.githubToken, // demo'da null; backend demo'yu kendisi tanır
        timezone: await _timezone(),
      );
      job = await api.job(id);
      _notify();
      _follow(id);
    });
  }

  /// İş bitene kadar düzenli aralıkla durumunu sorar.
  Future<void> _follow(int id) async {
    if (_polling) return;
    _polling = true;
    try {
      while (!_disposed && (job?.isActive ?? true)) {
        await Future<void>.delayed(pollInterval);
        if (_disposed) return;
        final ok = await _guard(() async => job = await api.job(id));
        _notify();
        if (!ok) return; // bağlantı hatası: izlemeyi bırak, hata gösterilir
      }
    } finally {
      _polling = false;
    }
  }

  /// Hataları kullanıcıya gösterilecek mesaja çevirir. Başarılıysa true.
  Future<bool> _guard(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        onUnauthorized();
      } else {
        error = e.message;
      }
    } catch (e) {
      error = 'Sunucuya ulaşılamadı.';
    }
    return false;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true; // izleme döngüsü bir sonraki turda durur
    super.dispose();
  }
}
