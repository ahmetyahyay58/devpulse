import 'dart:convert';
import 'dart:typed_data';

import 'package:devpulse/api/api_client.dart';
import 'package:devpulse/api/health_api.dart';
import 'package:devpulse/auth/auth_service.dart';
import 'package:devpulse/auth/session_store.dart';
import 'package:devpulse/main.dart';
import 'package:devpulse/screens/account_screen.dart';
import 'package:devpulse/screens/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_backend.dart';

const _live = Session(sessionToken: 'jwt', githubToken: 'gho_live', userId: 3, login: 'ben');
const _demo = Session(sessionToken: 'jwt', githubToken: null, userId: 1, login: 'demo-gelistirici');

Future<MemorySessionStore> _start(WidgetTester tester, FakeBackend backend, Session? session) async {
  tester.view.physicalSize = const Size(1080, 8000); // uzun Profil sayfası tamamen görünsün
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  final store = MemorySessionStore();
  if (session != null) await store.write(session);
  final api = ApiClient(baseUrl: 'http://test', client: backend.client);
  await tester.pumpWidget(DevPulseApp(
    auth: AuthService(api: api, store: store, browserAuth: (url, scheme) async => ''),
    healthApi: HealthApi(baseUrl: 'http://test', client: backend.client),
  ));
  await tester.pumpAndSettle();
  return store;
}

Future<void> _openDeleteDialog(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Profil'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(OutlinedButton, 'Verilerimi sil'));
  await tester.pumpAndSettle();
}

bool _deleteCalled(FakeBackend b) => b.requests.any((r) => r.method == 'DELETE');

void main() {
  testWidgets('Vazgeç: hiçbir şey silinmez', (tester) async {
    final backend = FakeBackend();
    final store = await _start(tester, backend, _live);
    await _openDeleteDialog(tester);
    expect(find.text('Veriler kalıcı olarak silinsin mi?'), findsOneWidget);

    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(_deleteCalled(backend), isFalse);
    expect(await store.read(), isNotNull);
  });

  testWidgets('onaylayınca silinir, GitHub izni kaldırılır, giriş ekranına dönülür', (tester) async {
    final backend = FakeBackend();
    final store = await _start(tester, backend, _live);
    await _openDeleteDialog(tester);
    await tester.tap(find.text('Kalıcı olarak sil'));
    await tester.pumpAndSettle();

    final req = backend.requests.lastWhere((r) => r.method == 'DELETE');
    expect(jsonDecode(req.body), {'github_token': 'gho_live'}); // kutu varsayılan olarak işaretli
    expect(await store.read(), isNull); // telefondaki token'lar da silindi
    expect(find.text('GitHub ile giriş yap'), findsOneWidget);
    expect(find.textContaining('Verilerin silindi: 4 repo, 33 commit'), findsOneWidget);
    expect(find.textContaining('GitHub izni kaldırıldı'), findsOneWidget);
  });

  testWidgets('kutu kaldırılırsa GitHub token\'ı gönderilmez', (tester) async {
    final backend = FakeBackend();
    await _start(tester, backend, _live);
    await _openDeleteDialog(tester);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kalıcı olarak sil'));
    await tester.pumpAndSettle();

    final req = backend.requests.lastWhere((r) => r.method == 'DELETE');
    expect(jsonDecode(req.body), isEmpty);
  });

  testWidgets('demo kullanıcıda GitHub izni seçeneği yok', (tester) async {
    await _start(tester, FakeBackend(), _demo);
    await _openDeleteDialog(tester);
    expect(find.byType(Checkbox), findsNothing);
  });

  group('Verilerimi indir', () {
    Future<List<(Uint8List, String)>> openAccount(WidgetTester tester, FakeBackend backend) async {
      final saved = <(Uint8List, String)>[];
      tester.view.physicalSize = const Size(1080, 8000); // uzun Profil sayfası tamamen görünsün
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      final api = ApiClient(baseUrl: 'http://test', client: backend.client)..sessionToken = 'jwt';
      await tester.pumpWidget(MaterialApp(
        home: AccountScreen(
          session: _live,
          auth: AuthService(api: api, store: MemorySessionStore()),
          onLogout: () {},
          onDeleted: (_) {},
          saveFile: (bytes, name) async => saved.add((bytes, name)),
        ),
      ));
      return saved;
    }

    testWidgets('sunucudaki JSON dosya olarak verilir', (tester) async {
      final backend = FakeBackend();
      final saved = await openAccount(tester, backend);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Verilerimi indir'));
      await tester.pumpAndSettle();

      expect(backend.requests.last.headers['Authorization'], 'Bearer jwt');
      expect(saved, hasLength(1));
      final (bytes, name) = saved.single;
      expect(name, matches(RegExp(r'^devpulse-verilerim-\d{4}-\d{2}-\d{2}\.json$')));
      expect(jsonDecode(utf8.decode(bytes))['user']['github_login'], 'ben');
    });

    testWidgets('hata olursa anlaşılır mesaj, dosya verilmez', (tester) async {
      final backend = FakeBackend()..exportFails = true;
      final saved = await openAccount(tester, backend);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Verilerimi indir'));
      await tester.pumpAndSettle();

      expect(saved, isEmpty);
      expect(find.text('İndirilemedi: Sunucuda bir hata oluştu.'), findsOneWidget);
    });
  });

  test('dosya adı tarihi iki haneli yazar', () {
    expect(exportFileName(DateTime(2026, 3, 7)), 'devpulse-verilerim-2026-03-07.json');
  });

  testWidgets('aydınlatma metni giriş yapmadan açılır', (tester) async {
    await _start(tester, FakeBackend(), null);
    await tester.tap(find.text('Aydınlatma metni'));
    await tester.pumpAndSettle();
    expect(find.text('DevPulse Aydınlatma Metni'), findsOneWidget);
    expect(find.text('Saklanmayan veriler'), findsOneWidget);
    expect(find.text('E-posta adresin.'), findsOneWidget);
  });

  testWidgets('Verilerim: saklanan sayılar ve 90 gün kuralıyla silinme tarihi', (tester) async {
    await _start(tester, FakeBackend(), _live);
    await tester.tap(find.byTooltip('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Verilerim'), findsOneWidget);
    expect(find.text('1048 gün'), findsOneWidget);
    expect(find.text('Otomatik silinme'), findsOneWidget);
    expect(find.text('11.02.2027'), findsOneWidget);
    expect(find.textContaining('90 gün boyunca giriş yapmaz'), findsOneWidget);
    expect(find.textContaining('90 gün etkinlik olmazsa silinir'), findsOneWidget); // çıkış satırı
  });

  testWidgets('senkronu yeniden oynat: Profil kapanır, senkron başlar ve aşamalı ekran açılır', (tester) async {
    final backend = FakeBackend();
    await _start(tester, backend, _live);
    await tester.tap(find.byTooltip('Profil'));
    await tester.pumpAndSettle();
    final before = backend.requests.where((r) => r.method == 'POST' && r.url.path == '/sync').length;
    await tester.tap(find.text('Senkronu yeniden oynat'));
    await tester.pumpAndSettle();
    expect(find.text('Veri kapsamı'), findsNothing); // Profil kapandı
    expect(backend.requests.where((r) => r.method == 'POST' && r.url.path == '/sync').length, before + 1);
    // Aşamalı ekran aşamaları sırayla gösterip kendisi kapanır; zamanlayıcı açık kalmasın.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pumpAndSettle();
  });

  testWidgets('ana ekranda profil fotoğrafı Profil açılmadan görünür', (tester) async {
    final backend = FakeBackend()..avatarUrl = 'https://avatars.example/ben.png';
    await _start(tester, backend, _live);
    final icon = tester.widget<ProfileAvatarIcon>(find.byType(ProfileAvatarIcon));
    expect(icon.url, 'https://avatars.example/ben.png');
    expect(find.descendant(of: find.byTooltip('Profil'), matching: find.byType(ClipOval)), findsOneWidget);
  });

  testWidgets('fotoğraf yoksa ana ekranda simge kalır', (tester) async {
    await _start(tester, FakeBackend(), _live);
    expect(find.descendant(of: find.byTooltip('Profil'), matching: find.byIcon(Icons.account_circle_outlined)),
        findsOneWidget);
  });

  testWidgets('Veri kapsamı: commit aralığı, repo türleri ve sabit notlar', (tester) async {
    await _start(tester, FakeBackend(), _live);
    await tester.tap(find.byTooltip('Profil'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Veri kapsamı'), 200);
    expect(find.text('02.03.2025 – 13.11.2026'), findsOneWidget);
    expect(find.text('Katkı verdiğin başka repolar'), findsOneWidget);
    expect(find.textContaining('ortak yazar olarak eklendiğin'), findsOneWidget);
  });

  testWidgets('Profil: avatar yoksa baş harf, GitHub etiketi ve rozet vitrini', (tester) async {
    await _start(tester, FakeBackend(), _live);
    await tester.tap(find.byTooltip('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Profil'), findsOneWidget); // başlık
    expect(find.text('B'), findsOneWidget); // "ben" -> baş harf (avatar_url yok)
    expect(find.text("GitHub'a bağlı"), findsOneWidget);
    expect(find.text('Rozet vitrini · 2 / 8'), findsOneWidget);
    expect(find.text('Bir haftalık seri'), findsOneWidget);
    expect(find.text('Lisanslı'), findsNothing); // kilitli rozet vitrinde yok
  });

  testWidgets('demo profilinde demo etiketi', (tester) async {
    await _start(tester, FakeBackend(), _demo);
    await tester.tap(find.byTooltip('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Demo kullanıcı · sentetik veri'), findsOneWidget);
  });

  testWidgets('Model Laboratuvarı: gerçek ölçümler ve kural/model payı', (tester) async {
    await _start(tester, FakeBackend(), _live);
    await tester.tap(find.byTooltip('Profil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Model Laboratuvarı'));
    await tester.pumpAndSettle();
    expect(find.text('doğruluk 0,63 · kappa 0,53'), findsOneWidget);
    expect(find.text('doğruluk 0,39 · kappa 0,24'), findsOneWidget);
    expect(find.textContaining('rastgele tahmin ~0,14'), findsOneWidget);
    expect(find.text('30 · %91'), findsOneWidget); // kural: 30 / 33
    expect(find.text('3 · %9'), findsOneWidget); // model
    expect(find.textContaining('referansın değişmesinden'), findsOneWidget);
  });
}
