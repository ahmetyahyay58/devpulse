import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../sync/sync_controller.dart' show deviceTimezone;

/// Haftalık bildirim (docs/metrikler.md "Haftalık özet"): yalnız Android, isteğe bağlı, varsayılan
/// kapalı. Telefonda planlanır (sunucu push yok); metinde sayı yok. Tercih yalnız bu cihazda tutulur.
abstract class WeeklyReminder {
  bool get supported;
  Future<bool> isEnabled();

  /// Açar (izin ister, planlar) ya da kapatır. Açılamadıysa (izin verilmedi) false döner.
  Future<bool> setEnabled(bool enabled);
}

class LocalWeeklyReminder implements WeeklyReminder {
  LocalWeeklyReminder._();
  static final instance = LocalWeeklyReminder._();

  static const prefKey = 'weekly_notification';
  static const _id = 7001;
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  @override
  bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<bool> isEnabled() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(prefKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    final name = await deviceTimezone();
    try {
      tz.setLocalLocation(tz.getLocation(name ?? 'Europe/Istanbul'));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    }
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    );
    _initialized = true;
  }

  /// Bir sonraki Pazartesi 10:00 (bugün Pazartesi ve saat 10'dan önceyse bugün).
  static tz.TZDateTime nextMonday10(tz.TZDateTime now) {
    var d = tz.TZDateTime(now.location, now.year, now.month, now.day, 10);
    while (d.weekday != DateTime.monday || !d.isAfter(now)) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }

  @override
  Future<bool> setEnabled(bool enabled) async {
    if (!supported) return false;
    try {
      await _init();
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (!enabled) {
        await _plugin.cancel(id: _id);
        await (await SharedPreferences.getInstance()).setBool(prefKey, false);
        return true;
      }
      final granted = await android?.requestNotificationsPermission() ?? false;
      if (!granted) return false;
      await _plugin.zonedSchedule(
        id: _id,
        title: 'Yeni hafta başladı',
        body: 'Geçen haftanın özeti DevPulse\'ta.',
        scheduledDate: nextMonday10(tz.TZDateTime.now(tz.local)),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'weekly', 'Haftalık özet',
            channelDescription: 'Pazartesi günleri haftalık özet hatırlatması',
          ),
        ),
        // Yaklaşık zaman: tam zamanlı alarm izni gerekmez.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
      await (await SharedPreferences.getInstance()).setBool(prefKey, true);
      return true;
    } catch (e) {
      debugPrint('Haftalık bildirim ayarlanamadı: $e');
      return false;
    }
  }
}
