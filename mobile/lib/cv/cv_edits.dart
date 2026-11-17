import 'cv_controller.dart';

/// CV maddelerinin düzenlenmesi (docs/cv.md, "Maddeleri düzenleme"). Kurallar burada, tek yerde:
/// sayılar kilitli, serbest metin 200 karakter, proje başına 2 ek madde, en çok 6 proje.
/// Düzenlemeler yalnızca cihazda saklanır; sunucuya gitmez.

const maxItemChars = 200;
const maxExtraPerProject = 2;
const maxProjects = 6;

/// Düzenlenebilen madde türleri: verinin bilemeyeceği metinler. Diğerleri (commit sayısı, özet,
/// etkinlik satırları) sayı içerir; kilitlidir, yalnızca gizlenebilir.
const editableKinds = {'desc', 'stack', 'impact'};

bool isEditable(CvItem i) => editableKinds.contains(i.kind);

String editedLabel(String lang) => lang == 'en' ? 'Your edit' : 'Senin düzenlemen';
String addedLabel(String lang) => lang == 'en' ? 'Added by you' : 'Senin eklemen';

class CvEdits {
  CvEdits({
    Map<String, String>? texts,
    Set<String>? hidden,
    Map<String, List<String>>? extras,
    this.selected,
    Set<String>? removedSkills,
    List<String>? addedLanguages,
    List<String>? addedTools,
  })  : texts = texts ?? {},
        hidden = hidden ?? {},
        extras = extras ?? {},
        removedSkills = removedSkills ?? {},
        addedLanguages = addedLanguages ?? [],
        addedTools = addedTools ?? [];

  /// Metin düzenlemeleri dile göre ayrı: anahtar "dil|madde kimliği".
  final Map<String, String> texts;
  final Set<String> hidden; // gizlenen madde kimlikleri (iki dilde ortak)
  final Map<String, List<String>> extras; // "dil|proje kimliği" -> ek maddeler (en çok 2)
  List<String>? selected; // seçilen proje kimlikleri (en çok 6); null: varsayılan ilk 6
  final Set<String> removedSkills; // listeden çıkarılan dil/araç adları
  final List<String> addedLanguages; // elle eklenen ("Senin eklemen")
  final List<String> addedTools;

  static String key(String lang, String id) => '$lang|$id';

  bool get isEmpty =>
      texts.isEmpty && hidden.isEmpty && extras.values.every((l) => l.isEmpty) && selected == null &&
      removedSkills.isEmpty && addedLanguages.isEmpty && addedTools.isEmpty;

  /// Seçili proje kimlikleri: kullanıcı seçimi (taslakta hâlâ var olanlar) ya da varsayılan ilk 6.
  List<String> selectedIds(CvDraft d) {
    final ids = d.projects.map((p) => p.id).toSet();
    final chosen = selected?.where(ids.contains).toList();
    if (chosen != null) return chosen.take(maxProjects).toList();
    return [for (final p in d.projects) if (p.defaultSelected) p.id].take(maxProjects).toList();
  }

  Map<String, dynamic> toJson() => {
        'texts': texts,
        'hidden': hidden.toList(),
        'extras': extras,
        'selected': selected,
        'removedSkills': removedSkills.toList(),
        'addedLanguages': addedLanguages,
        'addedTools': addedTools,
      };

  factory CvEdits.fromJson(Map<String, dynamic> j) {
    List<String> strings(Object? v) => [for (final s in v as List? ?? const []) s as String];
    return CvEdits(
      texts: (j['texts'] as Map? ?? const {}).map((k, v) => MapEntry(k as String, v as String)),
      hidden: strings(j['hidden']).toSet(),
      extras: (j['extras'] as Map? ?? const {}).map((k, v) => MapEntry(k as String, strings(v))),
      selected: j['selected'] == null ? null : strings(j['selected']),
      removedSkills: strings(j['removedSkills']).toSet(),
      addedLanguages: strings(j['addedLanguages']),
      addedTools: strings(j['addedTools']),
    );
  }

  CvEdits copy() => CvEdits.fromJson(toJson());
}

/// Bir maddenin düzenlenmiş hali (gizliyse yine döner; gizleme ayrı uygulanır).
CvItem effectiveItem(CvItem i, CvEdits e, String lang) {
  final text = isEditable(i) ? e.texts[CvEdits.key(lang, i.id)] : null; // kilitli maddede yok sayılır
  if (text == null) return i;
  return CvItem.of(
    id: i.id,
    text: text,
    source: editedLabel(lang),
    placeholder: text.contains('[') && text.contains(']'), // "[…]" kaldıysa hâlâ doldurulmamış
    edited: true,
  );
}

/// Sayfa ve PDF'in çizdiği son hal: seçili projeler, gizlenenler çıkarılmış, metinler düzenlenmiş,
/// ek maddeler ve beceri değişiklikleri uygulanmış.
CvDraft applyEdits(CvDraft d, CvEdits e) {
  final lang = d.lang;
  List<CvItem> visible(List<CvItem> items) =>
      [for (final i in items) if (!e.hidden.contains(i.id)) effectiveItem(i, e, lang)];

  final byId = {for (final p in d.projects) p.id: p};
  final projects = [
    for (final id in e.selectedIds(d))
      CvProject.of(byId[id]!, [
        ...visible(byId[id]!.items),
        for (final (n, text) in (e.extras[CvEdits.key(lang, id)] ?? const <String>[]).indexed)
          if (text.trim().isNotEmpty)
            CvItem.of(id: '$id:extra$n', text: text.trim(), source: addedLabel(lang), edited: true),
      ]),
  ];
  final summary = d.summary == null || e.hidden.contains(d.summary!.id) ? null : d.summary;
  return CvDraft.of(
    d,
    summary: summary,
    projects: projects,
    activity: visible(d.activity),
    languages: [...d.languages.where((l) => !e.removedSkills.contains(l)), ...e.addedLanguages],
    tools: [...d.tools.where((t) => !e.removedSkills.contains(t)), ...e.addedTools],
  );
}
