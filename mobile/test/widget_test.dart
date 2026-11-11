import 'dart:async';
import 'dart:convert';

import 'package:devpulse/api/health_api.dart';
import 'package:devpulse/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Gerçek backend yerine sahte HTTP istemcisi (MockClient) kullanılır.
HealthApi _api(MockClient client) =>
    HealthApi(baseUrl: 'http://test', client: client);

void main() {
  testWidgets('sunucu ayaktaysa durumları gösterir', (tester) async {
    final client = MockClient((request) async {
      expect(request.url.path, '/health');
      return http.Response(jsonEncode({'status': 'ok', 'database': 'ok'}), 200);
    });

    await tester.pumpWidget(DevPulseApp(api: _api(client)));
    await tester.pumpAndSettle(); // Future bitip ekran yeniden çizilsin

    expect(find.text('Veritabanı'), findsOneWidget);
    expect(find.text('ok'), findsNWidgets(2));
  });

  testWidgets('veritabanı kapalıysa bunu gösterir', (tester) async {
    final client = MockClient((_) async => http.Response(
        jsonEncode({'status': 'ok', 'database': 'unreachable'}), 200));

    await tester.pumpWidget(DevPulseApp(api: _api(client)));
    await tester.pumpAndSettle();

    expect(find.text('unreachable'), findsOneWidget);
  });

  testWidgets('Yenile yeni istek atar, beklerken butonu kilitler', (tester) async {
    var calls = 0;
    final secondResponse = Completer<void>();
    final client = MockClient((_) async {
      calls++;
      if (calls == 2) await secondResponse.future; // ikinci cevabı bekletiyoruz
      return http.Response(jsonEncode({'status': 'ok', 'database': 'ok'}), 200);
    });

    await tester.pumpWidget(DevPulseApp(api: _api(client)));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.textContaining('Son kontrol:'), findsOneWidget);

    await tester.tap(find.text('Yenile'));
    await tester.pump();

    expect(calls, 2);
    expect(find.text('Kontrol ediliyor…'), findsOneWidget);
    expect(find.text('ok'), findsNWidgets(2)); // eski sonuç ekranda kalır

    secondResponse.complete();
    await tester.pumpAndSettle();
    expect(find.text('Yenile'), findsOneWidget);
  });

  testWidgets('sunucuya ulaşılamazsa hata gösterir', (tester) async {
    final client = MockClient((_) async => throw http.ClientException('bağlantı reddedildi'));

    await tester.pumpWidget(DevPulseApp(api: _api(client)));
    await tester.pumpAndSettle();

    expect(find.text('Sunucuya ulaşılamadı'), findsOneWidget);
  });
}
