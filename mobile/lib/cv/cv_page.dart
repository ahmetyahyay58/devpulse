import 'package:flutter/material.dart';

import 'cv_controller.dart';
import 'cv_formats.dart';

/// CV'nin kağıt görünümü: beyaz sayfa, siyah yazı, seçili formatın düzeni (cv_formats.dart).
/// Tema (açık/koyu) sayfayı etkilemez; gerçek bir CV gibi görünür. Yer tutucular yalnız ekranda
/// sarı vurgulanır; kaynak satırları isteğe bağlıdır (PDF'e ikisi de basılmaz).
class CvPage extends StatelessWidget {
  const CvPage({super.key, required this.draft, required this.format, this.showSources = false});

  final CvDraft draft;
  final CvFormat format;
  final bool showSources;

  static const ink = Color(0xFF111111);
  static const muted = Color(0xFF555555);

  @override
  Widget build(BuildContext context) {
    final lang = draft.lang;
    final family = format.serif ? 'serif' : null; // Android'de Noto Serif; web'de tarayıcının serif'i
    final base = TextStyle(color: ink, fontSize: 11, height: 1.35, fontFamily: family);
    return DefaultTextStyle(
      style: base,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (format.header == HeaderStyle.centered) _centeredHeader(base),
          for (final s in format.sections) ..._section(s, base, lang),
        ]),
      ),
    );
  }

  // --- Başlık -------------------------------------------------------------------------------

  String get _github => draft.profileUrl.replaceFirst('https://', '');

  Widget _centeredHeader(TextStyle base) => Column(children: [
        Text(draft.login, // ad, "Bilgilerim" formu gelince kullanıcının adı olur
            textAlign: TextAlign.center,
            style: base.copyWith(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
        const SizedBox(height: 2),
        Text(_github, textAlign: TextAlign.center, style: base.copyWith(fontSize: 10.5)),
      ]);

  // --- Bölümler -----------------------------------------------------------------------------

  List<Widget> _section(CvSection s, TextStyle base, String lang) {
    final body = switch (s) {
      CvSection.personal => [
          Text(draft.login, style: base.copyWith(fontSize: 18, fontWeight: FontWeight.w700)),
          _labelled(lang == 'en' ? 'GitHub' : 'GitHub', _github, base),
        ],
      CvSection.about => [if (draft.summary != null) _item(draft.summary!, base)],
      CvSection.projects => [for (final p in draft.projects) ..._project(p, base, lang)],
      CvSection.skills => _skills(base, lang),
      CvSection.digitalSkills => _skills(base, lang),
      CvSection.additional => [for (final i in draft.activity) _item(i, base, bullet: true)],
      // Kullanıcının gireceği bölümler: veri yoksa sayfada hiç görünmez (docs/cv.md).
      CvSection.education || CvSection.experience || CvSection.spokenLanguages => <Widget>[],
    };
    if (body.isEmpty) return const [];
    return [_heading(sectionTitle(format, s, lang), base, lang), ...body];
  }

  Widget _heading(String title, TextStyle base, String lang) {
    final text = format.headingCaps ? upper(title, lang) : title;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(text,
            style: base.copyWith(
              fontSize: format.headingCaps ? 11.5 : 13,
              fontWeight: FontWeight.w700,
              letterSpacing: format.headingCaps ? 0.8 : 0,
              color: format.header == HeaderStyle.europass ? const Color(0xFF1F3B73) : ink,
            )),
        const SizedBox(height: 2),
        const Divider(height: 1, thickness: 0.8, color: ink),
      ]),
    );
  }

  List<Widget> _project(CvProject p, TextStyle base, String lang) {
    final dates = dateRange(p.start, p.end, lang);
    final bold = base.copyWith(fontWeight: FontWeight.w700);
    final italic = base.copyWith(fontStyle: FontStyle.italic);
    final title = format.techInProjectTitle && p.tech.isNotEmpty
        ? Text.rich(TextSpan(children: [
            TextSpan(text: p.name, style: bold),
            TextSpan(text: ' | ${p.tech.join(', ')}', style: italic),
          ]))
        : Text(p.name, style: bold);
    // Jake's teknolojiyi başlıkta verir; diğerlerinde "stack" maddesi gövdede kalır.
    final kinds = format.techInProjectTitle ? ['desc', 'work', 'impact'] : ['desc', 'stack', 'work', 'impact'];
    return [
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: title),
          if (dates.isNotEmpty) Text(dates, style: base.copyWith(fontSize: 10.5)), // sağa yaslı tarih
        ]),
      ),
      if (format.header == HeaderStyle.europass && p.url.isNotEmpty)
        Text(p.url.replaceFirst('https://', ''), style: base.copyWith(fontSize: 10, color: muted)),
      for (final k in kinds)
        if (p.item(k) != null) _item(p.item(k)!, base, bullet: true),
    ];
  }

  List<Widget> _skills(TextStyle base, String lang) {
    final en = lang == 'en';
    return [
      if (draft.languages.isNotEmpty)
        _labelled(en ? 'Languages' : 'Diller', draft.languages.join(', '), base),
      if (draft.tools.isNotEmpty)
        _labelled(en ? 'Developer tools' : 'Geliştirici araçları', draft.tools.join(', '), base),
    ];
  }

  // --- Satırlar -----------------------------------------------------------------------------

  Widget _labelled(String label, String value, TextStyle base) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: '$label: ', style: base.copyWith(fontWeight: FontWeight.w700)),
          TextSpan(text: value),
        ])),
      );

  Widget _item(CvItem i, TextStyle base, {bool bullet = false}) {
    final text = Text('${bullet ? '•  ' : ''}${i.text}');
    return Padding(
      padding: EdgeInsets.only(top: 2, left: bullet ? 8 : 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (i.placeholder)
          // Ekranda sarı vurgu: rakamı kullanıcı yazar (uygulama sayı uydurmaz).
          Container(color: const Color(0xFFFFF2B3), child: text)
        else
          text,
        if (showSources)
          Text(i.source, style: base.copyWith(fontSize: 8.5, color: muted, fontStyle: FontStyle.italic)),
      ]),
    );
  }
}
