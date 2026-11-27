import 'dart:convert';

import 'package:devpulse/ai/ai_widgets.dart';
import 'package:devpulse/api/api_client.dart';
import 'package:devpulse/api/health_api.dart';
import 'package:devpulse/auth/auth_service.dart';
import 'package:devpulse/auth/session_store.dart';
import 'package:devpulse/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_backend.dart';

const _live = Session(sessionToken: 'jwt', githubToken: 'gho_live', userId: 3, login: 'ben');

Future<void> _start(WidgetTester tester, FakeBackend backend) async {
  tester.view.physicalSize = const Size(1080, 6000); // Genel Bakış'ın altındaki AI kartı görünsün
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  final store = MemorySessionStore();
  await store.write(_live);
  final api = ApiClient(baseUrl: 'http://test', client: backend.client);
  await tester.pumpWidget(DevPulseApp(
    auth: AuthService(api: api, store: store, browserAuth: (url, scheme) async => ''),
    healthApi: HealthApi(baseUrl: 'http://test', client: backend.client),
  ));
  await tester.pumpAndSettle();
}

Future<void> _tapChip(WidgetTester tester, String text) async {
  await tester.tap(find.widgetWithText(ChoiceChip, text));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('AI yorumu kartında üç soru çipi', (tester) async {
    await _start(tester, FakeBackend());
    expect(find.text('AI yorumu'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNWidgets(3));
    expect(find.widgetWithText(ChoiceChip, 'Projelerimi nasıl iyileştiririm?'), findsNothing); // 4. soru Sor balonunda
  });

  testWidgets('ilk soruda onay istenir; onaylanınca yapay zekâ cevabı gelir', (tester) async {
    final backend = FakeBackend();
    await _start(tester, backend);
    await _tapChip(tester, 'Güçlü yanım ne?');
    expect(find.text('Yapay zekâ yorumları'), findsOneWidget); // onay penceresi
    expect(find.textContaining('commit mesajların ve kodun gitmez'), findsOneWidget);

    await tester.tap(find.text('Onaylıyorum'));
    await tester.pumpAndSettle();
    expect(backend.bodyOf('/ai/consent'), {'enabled': true});
    expect(find.text('LLM cevabı: guclu'), findsOneWidget);
    expect(find.textContaining('Yapay zekâ (Gemini)'), findsOneWidget);
  });

  testWidgets('onaylanmazsa şablon cevap gelir ve pencere tekrar açılmaz', (tester) async {
    final backend = FakeBackend();
    await _start(tester, backend);
    await _tapChip(tester, 'Güçlü yanım ne?');
    await tester.tap(find.text('Onaylamıyorum'));
    await tester.pumpAndSettle();
    expect(backend.called('/ai/consent'), isFalse);
    expect(find.text('Şablon cevabı: guclu'), findsOneWidget);
    expect(find.textContaining('onay vermedin'), findsOneWidget);

    await _tapChip(tester, 'Neyi geliştirebilirim?');
    expect(find.text('Onaylıyorum'), findsNothing);
    expect(find.text('Şablon cevabı: gelistir'), findsOneWidget);
  });

  testWidgets('sunucuda anahtar yoksa onay sorulmaz, şablon gösterilir', (tester) async {
    await _start(tester, FakeBackend()..aiLlmReady = false);
    await _tapChip(tester, 'Güçlü yanım ne?');
    expect(find.text('Onaylıyorum'), findsNothing);
    expect(find.textContaining('anahtarı tanımlı değil'), findsOneWidget);
  });

  testWidgets('"Giden veri" ekranı gönderilen sayıları gösterir', (tester) async {
    await _start(tester, FakeBackend()..aiConsent = true);
    await _tapChip(tester, 'Güçlü yanım ne?');
    await tester.tap(find.text('Giden veri'));
    await tester.pumpAndSettle();
    expect(find.text('Yapay zekâya giden veri'), findsOneWidget);
    expect(find.text('Toplam commit'), findsOneWidget);
    expect(find.text('33'), findsOneWidget);
    expect(find.text('lisans: 2'), findsOneWidget);
    expect(find.text('0,41'), findsOneWidget);
    expect(find.text('bilinmiyor'), findsOneWidget); // yil_degisim_yuzde null
  });

  testWidgets('Profil: onay anahtarı açılıp kapatılır', (tester) async {
    final backend = FakeBackend();
    await _start(tester, backend);
    await tester.tap(find.byTooltip('Profil'));
    await tester.pumpAndSettle();
    final toggle = find.widgetWithText(SwitchListTile, 'Yapay zekâ yorumları');
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(jsonDecode(backend.requests.last.body), {'enabled': true});
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(backend.aiConsent, isFalse);
  });

  testWidgets('AI durumu yüklenemezse kart görünmez, Genel Bakış çalışır', (tester) async {
    await _start(tester, FakeBackend()..aiStatusFails = true);
    expect(find.text('AI yorumu'), findsNothing);
    expect(find.text('Genel Bakış'), findsWidgets);
  });

  testWidgets('"Neden?" düğmesi metriğin açıklamasını alttan açılan panelde gösterir', (tester) async {
    final backend = FakeBackend()..aiConsent = true;
    await _start(tester, backend);
    await tester.tap(find.byTooltip('Analiz'));
    await tester.pumpAndSettle();
    // Sahte sunucuda yalnızca süreklilik sorusu var: tek düğme görünür.
    expect(find.text('Neden?'), findsOneWidget);
    await tester.tap(find.text('Neden?'));
    await tester.pumpAndSettle();
    expect(find.text('Süreklilik sonucum neden böyle?'), findsOneWidget);
    expect(find.text('LLM cevabı: neden_sureklilik'), findsOneWidget);
  });

  testWidgets('ipucu satırı görünür, çarpıyla kapanır', (tester) async {
    await _start(tester, FakeBackend());
    expect(find.text('Şablon cevabı: ipucu'), findsOneWidget);
    expect(find.text('Onaylıyorum'), findsNothing); // ipucu kendiliğinden onay penceresi açmaz
    await tester.tap(find.byTooltip('İpucunu kapat'));
    await tester.pumpAndSettle();
    expect(find.text('Şablon cevabı: ipucu'), findsNothing);
  });

  testWidgets("Profil'den kapatılan ipucu görünmez ve tercih saklanır", (tester) async {
    await _start(tester, FakeBackend());
    await tester.tap(find.byTooltip('Profil'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SwitchListTile, 'AI ipuçları'));
    await tester.pumpAndSettle();
    expect((await SharedPreferences.getInstance()).getBool('ai_tips_enabled'), isFalse);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Şablon cevabı: ipucu'), findsNothing);
  });

  testWidgets('Sor balonu beş soruyu gösterir ve seçilenin cevabını verir', (tester) async {
    await _start(tester, FakeBackend()..aiConsent = true);
    await tester.tap(find.byTooltip('Sor'));
    await tester.pumpAndSettle();
    expect(find.text('Ne sormak istersin?'), findsOneWidget);
    final sheet = find.byType(BottomSheet);
    expect(find.descendant(of: sheet, matching: find.byType(ChoiceChip)), findsNWidgets(5));

    await tester.tap(find.descendant(of: sheet, matching: find.text('Genelde ne zaman çalışıyorum?')));
    await tester.pumpAndSettle();
    expect(find.text('LLM cevabı: ritim'), findsOneWidget);
  });

  testWidgets('giden veri ekranında güven düzeyi Türkçe yazılır', (tester) async {
    expect(AiFactsScreen.value('dusuk'), 'Düşük güven');
    expect(AiFactsScreen.label('gece_payi_yuzde'), 'Gece payı (%)');
    expect(AiFactsScreen.label('bilinmeyen_anahtar'), 'bilinmeyen anahtar');
  });
}
