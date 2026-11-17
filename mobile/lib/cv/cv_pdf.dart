import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'cv_controller.dart';
import 'cv_formats.dart';
import 'cv_profile.dart';

/// CV'nin PDF'i, telefonda üretilir (docs/cv.md). Ekrandaki sayfayla (cv_page.dart) aynı format
/// tanımını okur. Farklar bilerek: doldurulmamış yer tutucular ve kaynak satırları basılmaz.
/// Yazı tipi gömülüdür (Noto); varsayılan PDF yazı tipleri Türkçe harfleri (ş, ğ, ı, İ) içermez.

class CvPdfResult {
  CvPdfResult(this.bytes, this.skippedPlaceholders);
  final Uint8List bytes;
  final int skippedPlaceholders; // basılmayan "Etki: [...]" gibi doldurulmamış maddeler
}

/// Yazı tipi dosyasını yükler; testlerde de aynı varlıklar (assets) kullanılır.
typedef FontLoader = Future<ByteData> Function(String asset);

Future<pw.ThemeData> _theme(bool serif, FontLoader load) async {
  final name = serif ? 'NotoSerif' : 'NotoSans';
  pw.Font font(ByteData d) => pw.Font.ttf(d);
  return pw.ThemeData.withFont(
    base: font(await load('assets/fonts/$name-Regular.ttf')),
    bold: font(await load('assets/fonts/$name-Bold.ttf')),
    italic: font(await load('assets/fonts/$name-Italic.ttf')),
  );
}

/// Dosya adı: `cv-ad-format-dil.pdf` (Türkçe harfler sadeleştirilir).
String cvFileName(String name, CvFormat f, String lang) {
  const map = {'ç': 'c', 'ğ': 'g', 'ı': 'i', 'İ': 'i', 'ö': 'o', 'ş': 's', 'ü': 'u'};
  final slug = name
      .toLowerCase()
      .split('')
      .map((c) => map[c] ?? c)
      .join()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return 'cv-${slug.isEmpty ? 'devpulse' : slug}-${f.id}-$lang.pdf';
}

Future<CvPdfResult> buildCvPdf({
  required CvDraft draft,
  required CvFormat format,
  required CvProfile profile,
  FontLoader? loadFont,
}) async {
  final b = _Builder(draft, format, profile);
  final doc = pw.Document(title: 'CV', author: b.name, creator: 'DevPulse');
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 36),
    theme: await _theme(format.serif, loadFont ?? rootBundle.load),
    build: (_) => b.build(),
  ));
  return CvPdfResult(await doc.save(), b.skipped);
}

class _Builder {
  _Builder(this.draft, this.format, this.profile);
  final CvDraft draft;
  final CvFormat format;
  final CvProfile profile;
  int skipped = 0;

  static const ink = PdfColor.fromInt(0xFF111111);
  static const muted = PdfColor.fromInt(0xFF555555);
  static const europassBlue = PdfColor.fromInt(0xFF1F3B73);
  String get lang => draft.lang;
  String get github => draft.profileUrl.replaceFirst('https://', '');
  String get name => profile.fullName.trim().isEmpty ? draft.login : profile.fullName.trim();

  pw.TextStyle get base => const pw.TextStyle(fontSize: 10, color: ink, lineSpacing: 1.5);
  pw.TextStyle get bold => base.copyWith(fontWeight: pw.FontWeight.bold);
  pw.TextStyle get italic => base.copyWith(fontStyle: pw.FontStyle.italic);

  List<pw.Widget> build() => [
        if (format.header == HeaderStyle.centered) ..._header(),
        for (final s in format.sections) ..._section(s),
      ];

  List<pw.Widget> _header() => [
        pw.Center(child: pw.Text(name, style: bold.copyWith(fontSize: 20))),
        pw.SizedBox(height: 3),
        pw.Center(
          child: pw.Text([...profile.contacts(), github].join(format.techInProjectTitle ? '  |  ' : '  ·  '),
              style: base.copyWith(fontSize: 9.5)),
        ),
      ];

  List<pw.Widget> _section(CvSection s) {
    final body = switch (s) {
      CvSection.personal => _personal(),
      CvSection.about => [if (draft.summary != null) ..._item(draft.summary!)],
      CvSection.education => [for (final e in profile.education) ..._education(e)],
      CvSection.experience => [for (final e in profile.experience) ..._experience(e)],
      CvSection.projects => [for (final p in draft.projects) ..._project(p)],
      CvSection.spokenLanguages => [
          for (final l in profile.languages)
            if (l.name.trim().isNotEmpty) _labelled(l.name.trim(), l.levelLabel(lang)),
        ],
      CvSection.skills || CvSection.digitalSkills => _skills(),
      CvSection.additional => [for (final i in draft.activity) ..._item(i, bullet: true)],
    };
    if (body.isEmpty) return const [];
    return [_heading(sectionTitle(format, s, lang)), ...body];
  }

  pw.Widget _heading(String title) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 10, bottom: 3),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.Text(format.headingCaps ? upper(title, lang) : title,
              style: bold.copyWith(
                fontSize: format.headingCaps ? 10.5 : 12,
                letterSpacing: format.headingCaps ? 0.8 : 0,
                color: format.header == HeaderStyle.europass ? europassBlue : ink,
              )),
          pw.SizedBox(height: 2),
          pw.Divider(height: 1, thickness: 0.7, color: ink),
        ]),
      );

  pw.Widget _row(String left, String right, pw.TextStyle leftStyle, {double top = 5}) => pw.Padding(
        padding: pw.EdgeInsets.only(top: top),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(child: pw.Text(left, style: leftStyle)),
          if (right.isNotEmpty) pw.Text(right, style: base.copyWith(fontSize: 9.5)),
        ]),
      );

  pw.Widget _labelled(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 2),
        child: pw.RichText(
          text: pw.TextSpan(style: base, children: [
            pw.TextSpan(text: '$label: ', style: bold),
            pw.TextSpan(text: value),
          ]),
        ),
      );

  pw.Widget _bullet(String text) =>
      pw.Padding(padding: const pw.EdgeInsets.only(top: 2, left: 8), child: pw.Text('•  $text', style: base));

  /// Doldurulmamış yer tutucu basılmaz (uygulama sayı uydurmaz; boş "[...]" de CV'ye girmez).
  List<pw.Widget> _item(CvItem i, {bool bullet = false}) {
    if (i.placeholder) {
      skipped++;
      return const [];
    }
    return [bullet ? _bullet(i.text) : pw.Padding(padding: const pw.EdgeInsets.only(top: 2), child: pw.Text(i.text))];
  }

  List<pw.Widget> _personal() {
    final en = lang == 'en';
    return [
      pw.Text(name, style: bold.copyWith(fontSize: 16)),
      for (final (label, value) in [
        (en ? 'Email' : 'E-posta', profile.email),
        (en ? 'Phone' : 'Telefon', profile.phone),
        (en ? 'Location' : 'Şehir', profile.location),
        ('LinkedIn', profile.linkedin),
        ('GitHub', github),
      ])
        if (value.trim().isNotEmpty) _labelled(label, value.trim()),
    ];
  }

  pw.Widget _dates(String d) =>
      pw.Padding(padding: const pw.EdgeInsets.only(top: 5), child: pw.Text(d, style: base.copyWith(color: muted)));

  List<pw.Widget> _education(Education e) {
    if (format.header == HeaderStyle.europass) {
      return [
        if (e.dates.isNotEmpty) _dates(e.dates),
        pw.Text(e.degree.isEmpty ? e.school : e.degree, style: bold),
        if (e.degree.isNotEmpty) pw.Text([e.school, e.location].where((s) => s.isNotEmpty).join(', ')),
        if (e.note.isNotEmpty) pw.Text(e.note),
      ];
    }
    return [
      _row(e.school, e.location, bold),
      if (e.degree.isNotEmpty || e.dates.isNotEmpty) _row(e.degree, e.dates, italic, top: 0),
      if (e.note.isNotEmpty) pw.Text(e.note),
    ];
  }

  List<pw.Widget> _experience(Experience e) {
    final bullets = [for (final b in e.bullets) _bullet(b)];
    if (format.header == HeaderStyle.europass) {
      return [
        if (e.dates.isNotEmpty) _dates(e.dates),
        pw.Text(e.role, style: bold),
        if (e.org.isNotEmpty || e.location.isNotEmpty) pw.Text([e.org, e.location].where((s) => s.isNotEmpty).join(', ')),
        ...bullets,
      ];
    }
    final (top, topRight, bottom, bottomRight) =
        format.techInProjectTitle ? (e.role, e.dates, e.org, e.location) : (e.org, e.location, e.role, e.dates);
    return [
      _row(top, topRight, bold),
      if (bottom.isNotEmpty || bottomRight.isNotEmpty) _row(bottom, bottomRight, italic, top: 0),
      ...bullets,
    ];
  }

  List<pw.Widget> _project(CvProject p) {
    final dates = dateRange(p.start, p.end, lang);
    final title = format.techInProjectTitle && p.tech.isNotEmpty
        ? pw.RichText(
            text: pw.TextSpan(style: base, children: [
              pw.TextSpan(text: p.name, style: bold),
              pw.TextSpan(text: ' | ${p.tech.join(', ')}', style: italic),
            ]),
          )
        : pw.Text(p.name, style: bold);
    final kinds = format.techInProjectTitle ? ['desc', 'work', 'impact'] : ['desc', 'stack', 'work', 'impact'];
    return [
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 5),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(child: title),
          if (dates.isNotEmpty) pw.Text(dates, style: base.copyWith(fontSize: 9.5)),
        ]),
      ),
      if (format.header == HeaderStyle.europass && p.url.isNotEmpty)
        pw.Text(p.url.replaceFirst('https://', ''), style: base.copyWith(fontSize: 9, color: muted)),
      for (final k in kinds)
        if (p.item(k) != null) ..._item(p.item(k)!, bullet: true),
    ];
  }

  List<pw.Widget> _skills() {
    final en = lang == 'en';
    final spoken = [
      for (final l in profile.languages)
        if (l.name.trim().isNotEmpty) '${l.name.trim()} (${l.levelLabel(lang)})',
    ].join(', ');
    return [
      if (draft.languages.isNotEmpty) _labelled(en ? 'Languages' : 'Programlama dilleri', draft.languages.join(', ')),
      if (draft.tools.isNotEmpty) _labelled(en ? 'Developer tools' : 'Geliştirici araçları', draft.tools.join(', ')),
      if (format.id == 'harvard' && spoken.isNotEmpty)
        _labelled(en ? 'Spoken languages' : 'Yabancı dil ve anadil', spoken),
    ];
  }
}
