import 'package:flutter/material.dart';

import 'cv_controller.dart';
import 'cv_formats.dart';
import 'cv_profile.dart';

/// CV'nin kağıt görünümü: beyaz sayfa, siyah yazı, seçili formatın düzeni (cv_formats.dart).
/// Tema (açık/koyu) sayfayı etkilemez; gerçek bir CV gibi görünür. Yer tutucular yalnız ekranda
/// sarı vurgulanır; kaynak satırları isteğe bağlıdır (PDF'e ikisi de basılmaz).
class CvPage extends StatelessWidget {
  const CvPage({super.key, required this.draft, required this.format, required this.profile, this.showSources = false});

  final CvDraft draft;
  final CvFormat format;
  final CvProfile profile; // "Bilgilerim": ad, iletişim, eğitim, deneyim, diller (telefonda)
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

  /// Ad girilmediyse GitHub kullanıcı adı gösterilir.
  String get _name => profile.fullName.trim().isEmpty ? draft.login : profile.fullName.trim();

  Widget _centeredHeader(TextStyle base) => Column(children: [
        Text(_name,
            textAlign: TextAlign.center,
            style: base.copyWith(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
        const SizedBox(height: 2),
        // Jake's: "telefon | e-posta | ...", Harvard: "telefon · e-posta · ..."
        Text([...profile.contacts(), _github].join(format.techInProjectTitle ? '  |  ' : '  ·  '),
            textAlign: TextAlign.center, style: base.copyWith(fontSize: 10.5)),
      ]);

  // --- Bölümler -----------------------------------------------------------------------------

  List<Widget> _section(CvSection s, TextStyle base, String lang) {
    final body = switch (s) {
      CvSection.personal => _personal(base, lang),
      CvSection.about => [if (draft.summary != null) _item(draft.summary!, base)],
      CvSection.projects => [for (final p in draft.projects) ..._project(p, base, lang)],
      CvSection.skills => _skills(base, lang),
      CvSection.digitalSkills => _skills(base, lang),
      CvSection.additional => [for (final i in draft.activity) _item(i, base, bullet: true)],
      // Kullanıcının girdiği bölümler: veri yoksa sayfada hiç görünmez (docs/cv.md).
      CvSection.education => [for (final e in profile.education) ..._education(e, base)],
      CvSection.experience => [for (final e in profile.experience) ..._experience(e, base)],
      CvSection.spokenLanguages => [
          for (final l in profile.languages)
            if (l.name.trim().isNotEmpty) _labelled(l.name.trim(), l.levelLabel(lang), base),
        ],
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

  List<Widget> _personal(TextStyle base, String lang) {
    final en = lang == 'en';
    return [
      Text(_name, style: base.copyWith(fontSize: 18, fontWeight: FontWeight.w700)),
      for (final (label, value) in [
        (en ? 'Email' : 'E-posta', profile.email),
        (en ? 'Phone' : 'Telefon', profile.phone),
        (en ? 'Location' : 'Şehir', profile.location),
        ('LinkedIn', profile.linkedin),
        ('GitHub', _github),
      ])
        if (value.trim().isNotEmpty) _labelled(label, value.trim(), base),
    ];
  }

  /// Satır: solda metin, sağda (sağa yaslı) tarih ya da yer. Sütun değil, tek satır.
  Widget _row(String left, String right, TextStyle leftStyle, TextStyle base, {double top = 6}) => Padding(
        padding: EdgeInsets.only(top: top),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(left, style: leftStyle)),
          if (right.isNotEmpty) Text(right, style: base.copyWith(fontSize: 10.5)),
        ]),
      );

  Widget _dates(String dates, TextStyle base) =>
      Padding(padding: const EdgeInsets.only(top: 6), child: Text(dates, style: base.copyWith(color: muted)));

  List<Widget> _education(Education e, TextStyle base) {
    final bold = base.copyWith(fontWeight: FontWeight.w700);
    final italic = base.copyWith(fontStyle: FontStyle.italic);
    if (format.header == HeaderStyle.europass) {
      return [
        if (e.dates.isNotEmpty) _dates(e.dates, base),
        Text(e.degree.isEmpty ? e.school : e.degree, style: bold),
        if (e.degree.isNotEmpty) Text([e.school, e.location].where((s) => s.isNotEmpty).join(', ')),
        if (e.note.isNotEmpty) Text(e.note),
      ];
    }
    return [
      _row(e.school, e.location, bold, base),
      if (e.degree.isNotEmpty || e.dates.isNotEmpty) _row(e.degree, e.dates, italic, base, top: 0),
      if (e.note.isNotEmpty) Text(e.note),
    ];
  }

  List<Widget> _experience(Experience e, TextStyle base) {
    final bold = base.copyWith(fontWeight: FontWeight.w700);
    final italic = base.copyWith(fontStyle: FontStyle.italic);
    final bullets = [
      for (final b in e.bullets) Padding(padding: const EdgeInsets.only(top: 2, left: 8), child: Text('•  $b')),
    ];
    if (format.header == HeaderStyle.europass) {
      return [
        if (e.dates.isNotEmpty) _dates(e.dates, base),
        Text(e.role, style: bold),
        if (e.org.isNotEmpty || e.location.isNotEmpty) Text([e.org, e.location].where((s) => s.isNotEmpty).join(', ')),
        ...bullets,
      ];
    }
    // Jake's: pozisyon + tarih, altında kurum + şehir. Harvard: kurum + şehir, altında pozisyon + tarih.
    final (top, topRight, bottom, bottomRight) =
        format.techInProjectTitle ? (e.role, e.dates, e.org, e.location) : (e.org, e.location, e.role, e.dates);
    return [
      _row(top, topRight, bold, base),
      if (bottom.isNotEmpty || bottomRight.isNotEmpty) _row(bottom, bottomRight, italic, base, top: 0),
      ...bullets,
    ];
  }

  List<Widget> _skills(TextStyle base, String lang) {
    final en = lang == 'en';
    final spoken = [
      for (final l in profile.languages)
        if (l.name.trim().isNotEmpty) '${l.name.trim()} (${l.levelLabel(lang)})',
    ].join(', ');
    return [
      if (draft.languages.isNotEmpty)
        _labelled(en ? 'Languages' : 'Programlama dilleri', draft.languages.join(', '), base),
      if (draft.tools.isNotEmpty)
        _labelled(en ? 'Developer tools' : 'Geliştirici araçları', draft.tools.join(', '), base),
      // Harvard "Skills & Interests" konuşulan dilleri de içerir; Europass'ta ayrı bölüm var.
      if (format.id == 'harvard' && spoken.isNotEmpty)
        _labelled(en ? 'Spoken languages' : 'Yabancı dil ve anadil', spoken, base),
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
