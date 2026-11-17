import 'package:devpulse/api/api_client.dart';
import 'package:devpulse/cv/cv_controller.dart';
import 'package:devpulse/cv/cv_edits.dart';
import 'package:devpulse/cv/cv_profile.dart';
import 'package:devpulse/cv/cv_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_backend.dart';

Future<CvDraft> _draft() async {
  final c = CvController(api: ApiClient(baseUrl: 'http://test', client: FakeBackend().client), onUnauthorized: () {},
      store: MemoryCvProfileStore());
  await c.load();
  return c.draft!;
}

Future<MemoryCvProfileStore> _pump(WidgetTester tester, {CvEdits? edits}) async {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  final store = MemoryCvProfileStore();
  if (edits != null) await store.writeEdits(edits.toJson());
  final c = CvController(api: ApiClient(baseUrl: 'http://test', client: FakeBackend().client), onUnauthorized: () {},
      store: store)
    ..load();
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: CvView(controller: c, saveFile: (_, _) async {}))));
  await tester.pumpAndSettle();
  return store;
}

void main() {
  group('applyEdits (kurallar)', () {
    test('varsayılan seçim: default_selected olanlar (en çok 4)', () async {
      final d = await _draft();
      expect(applyEdits(d, CvEdits()).projects.map((p) => p.name), ['proje-a', 'proje-b']);
    });

    test('kullanıcı seçimi en çok 4 ve taslakta olmayan kimlik yok sayılır', () async {
      final d = await _draft();
      final e = CvEdits(selected: ['proj:R_e', 'proj:R_d', 'proj:R_c', 'proj:R_b', 'proj:R_a', 'yok']);
      expect(applyEdits(d, e).projects, hasLength(maxProjects));
    });

    test('sayı içeren madde kilitli: metin düzenlemesi yok sayılır, gizlenebilir', () async {
      final d = await _draft();
      final e = CvEdits(texts: {CvEdits.key('tr', 'proj:R_a:work'): 'Commit sayısı: 9999.'});
      final work = applyEdits(d, e).projects.first.item('work')!;
      expect(work.text, 'Commit sayısı: 12; README ile belgelendi.');
      expect(work.edited, isFalse);
      e.hidden.add('proj:R_a:work');
      expect(applyEdits(d, e).projects.first.item('work'), isNull);
    });

    test('serbest metin düzenlenir, "senin düzenlemen" diye işaretlenir; dolu etki yer tutucu değildir', () async {
      final d = await _draft();
      final e = CvEdits(texts: {
        CvEdits.key('tr', 'proj:R_a:desc'): 'Yeni açıklama',
        CvEdits.key('tr', 'proj:R_a:impact'): 'Etki: 300 kullanıcı',
        CvEdits.key('en', 'proj:R_a:desc'): 'English only',
      });
      final p = applyEdits(d, e).projects.first;
      expect(p.item('desc')!.text, 'Yeni açıklama'); // Türkçe CV'de Türkçe düzenleme
      expect(p.item('desc')!.source, 'Senin düzenlemen');
      expect(p.item('impact')!.placeholder, isFalse);
    });

    test('ek maddeler sonda, boşlar atlanır', () async {
      final d = await _draft();
      final e = CvEdits(extras: {CvEdits.key('tr', 'proj:R_a'): ['JWT ekledim.', '  ']});
      final items = applyEdits(d, e).projects.first.items;
      expect(items.last.text, 'JWT ekledim.');
      expect(items.last.source, 'Senin eklemen');
      expect(items.where((i) => i.edited && i.kind.startsWith('extra')), hasLength(1));
    });

    test('beceriler: çıkarılan gider, eklenen sona gelir', () async {
      final d = await _draft();
      final e = CvEdits(removedSkills: {'Python'}, addedLanguages: ['SQL'], addedTools: ['Figma']);
      final v = applyEdits(d, e);
      expect(v.languages, ['Dart', 'SQL']);
      expect(v.tools, ['Docker', 'Figma']);
    });

    test('JSON gidiş-dönüşü', () {
      final e = CvEdits(texts: {'tr|x': 'a'}, hidden: {'h'}, extras: {'tr|p': ['b']}, selected: ['p'],
          removedSkills: {'C++'}, addedLanguages: ['SQL']);
      final back = CvEdits.fromJson(e.toJson());
      expect(back.toJson(), e.toJson());
      expect(CvEdits().isEmpty, isTrue);
    });
  });

  testWidgets('düzenle → Kaydet: balon mesajı, cihaza yazılır, sayfada düzenlenmiş metin', (tester) async {
    final store = await _pump(tester);
    await tester.tap(find.text('Maddeleri düzenle'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Veriden gelen sayı; düzenlenemez'), findsWidgets); // kilitli madde
    expect(find.widgetWithText(TextFormField, 'Commit sayısı: 12; README ile belgelendi.'), findsNothing);

    await tester.enterText(find.widgetWithText(TextFormField, 'Hava durumu servisi'), 'Şehir bazlı hava API\'si');
    await tester.pump();
    expect(store.savedEdits, isNull); // Kaydet'e basılmadan yazılmaz
    await tester.tap(find.widgetWithText(FilledButton, 'Kaydet').last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Düzenlemeler kaydedildi.'), findsOneWidget); // balon
    await tester.pumpAndSettle(); // balon kaybolur
    expect(find.text('Düzenlemeler kaydedildi.'), findsNothing);
    expect(store.savedEdits!['texts'], {'tr|proj:R_a:desc': 'Şehir bazlı hava API\'si'});

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('•  Şehir bazlı hava API\'si'), findsOneWidget);
    expect(find.text('Maddeleri düzenle (düzenlendi)'), findsOneWidget);
  });

  testWidgets('en çok 4 proje: dördü seçiliyken diğerleri pasif', (tester) async {
    await _pump(tester, edits: CvEdits(selected: ['proj:R_a', 'proj:R_b', 'proj:R_c', 'proj:R_d']));
    await tester.tap(find.text('Maddeleri düzenle (düzenlendi)'));
    await tester.pumpAndSettle();
    expect(find.text('4/4 seçili'), findsOneWidget);
    final e = tester.widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, 'proje-e'));
    expect(e.onChanged, isNull);
  });

  testWidgets('ek madde en çok 2; taslağa dön (tümü) düzenlemeleri temizler', (tester) async {
    final store = await _pump(tester, edits: CvEdits(hidden: {'proj:R_a:desc'}));
    await tester.tap(find.text('Maddeleri düzenle (düzenlendi)'));
    await tester.pumpAndSettle();
    final add = find.textContaining('Madde ekle (');
    await tester.tap(add.first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Madde ekle (1/2)').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Madde ekle (2/2)'), findsNothing); // sınır doldu, düğme yok

    await tester.tap(find.text('Taslağa dön (tümü)'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Taslağa dön'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Kaydet').last);
    await tester.pumpAndSettle();
    expect(CvEdits.fromJson(store.savedEdits!).isEmpty, isTrue);
  });
}
