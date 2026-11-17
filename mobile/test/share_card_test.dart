import 'dart:typed_data';

import 'package:devpulse/api/api_client.dart';
import 'package:devpulse/screens/file_saver.dart';
import 'package:devpulse/share/share_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_backend.dart';

void main() {
  test('PNG dosyası doğru türle verilir', () {
    expect(mimeTypeOf('devpulse-kart-2026.png'), 'image/png');
    expect(mimeTypeOf('cv.pdf'), 'application/pdf');
  });

  testWidgets('kart önizlemesi: yalnız kullanıcı adı ve toplu sayılar; Paylaş PNG verir', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final saved = <(Uint8List, String)>[];
    final backend = FakeBackend();
    await tester.pumpWidget(MaterialApp(
      home: ShareCardScreen(
        api: ApiClient(baseUrl: 'http://test', client: backend.client),
        saveFile: (bytes, name) async => saved.add((bytes, name)),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('ben'), findsOneWidget);
    expect(find.text('120'), findsOneWidget); // bu yılın commit sayısı
    expect(find.text('Dart'), findsOneWidget);
    expect(find.textContaining('repo adı, commit mesajı ve e-posta yok'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Paylaş'));
      for (var i = 0; i < 100 && saved.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pump();
    expect(saved.single.$2, 'devpulse-kart-2026.png');
    expect(saved.single.$1.sublist(1, 4), [0x50, 0x4E, 0x47]); // "PNG" imzası
  });
}
