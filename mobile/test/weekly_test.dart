import 'package:devpulse/notify/weekly_notifications.dart';
import 'package:devpulse/notify/weekly_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class FakeReminder implements WeeklyReminder {
  FakeReminder({this.grant = true});
  final bool grant;
  bool on = false;
  final calls = <bool>[];
  @override
  bool get supported => true;
  @override
  Future<bool> isEnabled() async => on;
  @override
  Future<bool> setEnabled(bool enabled) async {
    calls.add(enabled);
    if (enabled && !grant) return false;
    on = enabled;
    return true;
  }
}

Future<void> _pump(WidgetTester tester, WeeklyReminder r) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: WeeklyReminderTile(reminder: r))));
  await tester.pumpAndSettle();
}

void main() {
  test('bir sonraki Pazartesi 10:00', () {
    tzdata.initializeTimeZones();
    final ist = tz.getLocation('Europe/Istanbul');
    final wed = tz.TZDateTime(ist, 2026, 11, 18, 15); // Çarşamba
    expect(LocalWeeklyReminder.nextMonday10(wed), tz.TZDateTime(ist, 2026, 11, 23, 10));
    final monEarly = tz.TZDateTime(ist, 2026, 11, 23, 9);
    expect(LocalWeeklyReminder.nextMonday10(monEarly), tz.TZDateTime(ist, 2026, 11, 23, 10));
    final monLate = tz.TZDateTime(ist, 2026, 11, 23, 11);
    expect(LocalWeeklyReminder.nextMonday10(monLate), tz.TZDateTime(ist, 2026, 11, 30, 10));
  });

  testWidgets('anahtar: açınca planlanır, kapatınca iptal', (tester) async {
    final r = FakeReminder();
    await _pump(tester, r);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(r.calls, [true]);
    expect(find.text('Haftalık bildirim açıldı.'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(r.calls, [true, false]);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets('izin verilmezse anahtar kapalı kalır ve söylenir', (tester) async {
    final r = FakeReminder(grant: false);
    await _pump(tester, r);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(find.text('Bildirim açılamadı: izin verilmedi.'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  testWidgets('Bu hafta kartı: iki dönem ve yöntem notu', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: WeeklyCard(weekly: {
          'this_week': {'commits': 5, 'active_days': 2},
          'last_week': {'commits': 3, 'active_days': 3},
          'summary': 'Bu hafta 5 commit, 2 aktif gün; geçen haftanın aynı günlerine göre 2 commit fazla.',
        }),
      ),
    ));
    expect(find.text('commit (geçen hafta 3)'), findsOneWidget);
    expect(find.textContaining('aynı günleriyle kıyaslanır'), findsOneWidget);
  });
}
