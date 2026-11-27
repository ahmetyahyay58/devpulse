import 'package:devpulse/ui/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Bu dosya hareketin kendisini dener: genel test ayarındaki "animasyonsuz" kipi kapatılır.
  setUp(() => Motion.testMode = false);
  tearDown(() => Motion.testMode = true);

  int shown(WidgetTester tester) =>
      int.parse((tester.widget<Text>(find.descendant(of: find.byType(CountUp), matching: find.byType(Text)))).data!);

  testWidgets('sayaç: 0 dan sayar, hiçbir an gerçek değeri geçmez, sonunda tam değerde', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: CountUp(value: 1194))));
    expect(shown(tester), 0);
    final seen = <int>[];
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      seen.add(shown(tester));
    }
    expect(seen.every((v) => v <= 1194), isTrue);
    expect(seen.any((v) => v > 0 && v < 1194), isTrue); // gerçekten saydı
    await tester.pumpAndSettle();
    expect(shown(tester), 1194);
    expect(find.bySemanticsLabel('1194'), findsOneWidget); // ekran okuyucu son değeri okur
  });

  testWidgets('animasyonları azalt açıksa sayaç beklemeden son değerde', (tester) async {
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) =>
          MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
      home: const Scaffold(body: CountUp(value: 42)),
    ));
    expect(shown(tester), 42);
  });

  testWidgets('gizli sekmedeki giriş oynamaz; sekme görünür olunca oynar', (tester) async {
    Widget app(int epoch, bool active) => MaterialApp(
          home: EntranceScope(epoch: epoch, active: active, child: const Scaffold(body: CountUp(value: 10))),
        );
    await tester.pumpWidget(app(0, false));
    expect(shown(tester), 10); // gizliyken son halinde bekler
    await tester.pumpWidget(app(1, true));
    await tester.pump(const Duration(milliseconds: 16));
    expect(shown(tester), lessThan(10)); // görünür oldu: yeniden sayıyor
    await tester.pumpAndSettle();
    expect(shown(tester), 10);
  });

  test('seg taşmaz: 0..1 dışına çıkmaz', () {
    for (var t = 0.0; t <= 1.0; t += 0.01) {
      final v = seg(t, 0.1, 0.6);
      expect(v, inInclusiveRange(0, 1));
    }
  });
}
