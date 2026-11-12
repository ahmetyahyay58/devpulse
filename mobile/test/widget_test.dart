import 'dart:async';

import 'package:devpulse/api/api_client.dart';
import 'package:devpulse/api/health_api.dart';
import 'package:devpulse/auth/auth_service.dart';
import 'package:devpulse/auth/session_store.dart';
import 'package:devpulse/main.dart';
import 'package:devpulse/screens/health_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fake_backend.dart';

Widget _app(FakeBackend backend, SessionStore store) {
  final api = ApiClient(baseUrl: 'http://test', client: backend.client);
  return DevPulseApp(
    auth: AuthService(api: api, store: store, browserAuth: (url, scheme) async => ''),
    healthApi: HealthApi(baseUrl: 'http://test', client: backend.client),
  );
}

Widget _card(http.Client client) => MaterialApp(
      home: Scaffold(body: HealthCard(api: HealthApi(baseUrl: 'http://test', client: client))),
    );

void main() {
  // --- Giriş akışı ---------------------------------------------------------------

  testWidgets('oturum yoksa giriş ekranı açılır; demo girişi ana ekrana götürür', (tester) async {
    final backend = FakeBackend();
    await tester.pumpWidget(_app(backend, MemorySessionStore()));
    await tester.pumpAndSettle();

    expect(find.text('GitHub ile giriş yap'), findsOneWidget);

    await tester.tap(find.text('Demo ile dene'));
    await tester.pumpAndSettle();

    expect(find.text('Merhaba, demo-gelistirici'), findsOneWidget);
    expect(find.textContaining('sentetik veri'), findsOneWidget); // demo açıkça belirtilir
    expect(find.text('Veritabanı'), findsOneWidget); // sunucu kartı da yüklendi
  });

  testWidgets('kayıtlı oturum varsa doğrudan ana ekran; çıkış giriş ekranına döner', (tester) async {
    final store = MemorySessionStore();
    await store.write(const Session(
      sessionToken: 'jwt', githubToken: 'gho', userId: 1, login: 'ben',
    ));

    await tester.pumpWidget(_app(FakeBackend(), store));
    await tester.pumpAndSettle();
    expect(find.text('Merhaba, ben'), findsOneWidget);
    expect(find.textContaining('sentetik veri'), findsNothing);

    await tester.tap(find.byTooltip('Çıkış yap'));
    await tester.pumpAndSettle();
    expect(find.text('GitHub ile giriş yap'), findsOneWidget);
    expect(await store.read(), isNull);
  });

  // --- Sunucu durumu kartı ----------------------------------------------------------

  testWidgets('veritabanı kapalıysa bunu gösterir', (tester) async {
    final backend = FakeBackend()..health = {'status': 'ok', 'database': 'unreachable'};
    await tester.pumpWidget(_card(backend.client));
    await tester.pumpAndSettle();
    expect(find.text('unreachable'), findsOneWidget);
  });

  testWidgets('sunucuya ulaşılamazsa hata gösterir', (tester) async {
    final client = MockClient((_) async => throw http.ClientException('bağlantı reddedildi'));
    await tester.pumpWidget(_card(client));
    await tester.pumpAndSettle();
    expect(find.text('Sunucuya ulaşılamadı'), findsOneWidget);
  });

  testWidgets('Yenile yeni istek atar, beklerken butonu kilitler', (tester) async {
    var calls = 0;
    final secondResponse = Completer<void>();
    final client = MockClient((_) async {
      calls++;
      if (calls == 2) await secondResponse.future; // ikinci cevabı bekletiyoruz
      return http.Response('{"status": "ok", "database": "ok"}', 200);
    });

    await tester.pumpWidget(_card(client));
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
}
