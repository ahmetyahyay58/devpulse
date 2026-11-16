/// Üç CV formatının düzeni, veri olarak (docs/cv.md, "Formatlar"). Ekrandaki sayfa (cv_page.dart)
/// ve ileride PDF bu tanımı okur; böylece ikisi birbirinden ayrışmaz.
library;

/// Sayfadaki bölümler. Kullanıcının girdiği bölümler (eğitim, deneyim, dil) boşsa sayfada çıkmaz.
enum CvSection { personal, about, education, experience, projects, spokenLanguages, skills, digitalSkills, additional }

enum HeaderStyle {
  centered, // Jake's ve Harvard: ortada büyük ad, altında tek iletişim satırı
  europass, // Europass: "Kişisel bilgiler" bölümü, sola yaslı satırlar
}

class CvFormat {
  const CvFormat({
    required this.id,
    required this.name,
    required this.note,
    required this.sections,
    required this.header,
    required this.serif,
    required this.headingCaps,
    required this.techInProjectTitle,
  });

  final String id;
  final String name; // seçicide görünen ad
  final Map<String, String> note; // ad altında kısa açıklama (tr/en); uyarlamalar dürüstçe söylenir
  final List<CvSection> sections; // sayfadaki sıra
  final HeaderStyle header;
  final bool serif; // Harvard: serif yazı tipi
  final bool headingCaps; // bölüm başlıkları büyük harf + altında çizgi
  final bool techInProjectTitle; // Jake's: "Ad | teknolojiler" tek satırda
}

const jakes = CvFormat(
  id: 'jakes',
  name: "Jake's",
  note: {
    'tr': "Jake's Resume düzeni: yazılımcılar arasında yaygın tek sayfalık şablon. Özet yok.",
    'en': "Jake's Resume layout: a one-page template common among software developers. No summary.",
  },
  sections: [CvSection.education, CvSection.experience, CvSection.projects, CvSection.skills],
  header: HeaderStyle.centered,
  serif: false,
  headingCaps: true,
  techInProjectTitle: true,
);

const harvard = CvFormat(
  id: 'harvard',
  name: 'Harvard',
  note: {
    'tr': 'Harvard kariyer rehberlerindeki ters kronolojik düzen (tek resmî şablon yok). Projeler '
        'bölümü GitHub için eklendi.',
    'en': 'Reverse-chronological layout from Harvard career guides (there is no single official '
        'template). The Projects section is added for GitHub.',
  },
  sections: [CvSection.education, CvSection.experience, CvSection.projects, CvSection.skills],
  header: HeaderStyle.centered,
  serif: true,
  headingCaps: true,
  techInProjectTitle: false,
);

const europass = CvFormat(
  id: 'europass',
  name: 'Europass',
  note: {
    'tr': 'Europass düzeni, tek sütun uyarlama: resmî Europass iki sütunlu bir formdur; aynı bölümler '
        'burada tek sütuna dizilir.',
    'en': 'Europass layout, single-column adaptation: the official Europass is a two-column form; the '
        'same sections are stacked in one column here.',
  },
  sections: [
    CvSection.personal, CvSection.about, CvSection.experience, CvSection.education,
    CvSection.spokenLanguages, CvSection.digitalSkills, CvSection.projects, CvSection.additional,
  ],
  header: HeaderStyle.europass,
  serif: false,
  headingCaps: false,
  techInProjectTitle: false,
);

const cvFormats = [jakes, harvard, europass];

/// Bölüm başlıkları, format ve dile göre.
String sectionTitle(CvFormat f, CvSection s, String lang) {
  final en = lang == 'en';
  return switch (s) {
    CvSection.personal => en ? 'Personal information' : 'Kişisel bilgiler',
    CvSection.about => en ? 'About me' : 'Hakkımda',
    CvSection.education => f.id == 'europass'
        ? (en ? 'Education and training' : 'Eğitim ve öğretim')
        : (en ? 'Education' : 'Eğitim'),
    CvSection.experience => f.id == 'europass'
        ? (en ? 'Work experience' : 'İş deneyimi')
        : (en ? 'Experience' : 'Deneyim'),
    CvSection.projects => en ? 'Projects' : 'Projeler',
    CvSection.spokenLanguages => en ? 'Language skills' : 'Dil becerileri',
    CvSection.skills => f.id == 'jakes'
        ? (en ? 'Technical Skills' : 'Teknik beceriler')
        : (en ? 'Skills' : 'Beceriler'),
    CvSection.digitalSkills => en ? 'Digital skills' : 'Dijital beceriler',
    CvSection.additional => en ? 'Additional information' : 'Ek bilgiler',
  };
}

/// Türkçe büyük harf: Dart'ın toUpperCase'i dil bilmez ("beceriler" -> "BECERILER" olurdu).
String upper(String s, String lang) =>
    lang == 'tr' ? s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase() : s.toUpperCase();

const _monthsTr = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
const _monthsEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Mar 2025 – Şub 2026"; aynı ay ise tek tarih; bilinmiyorsa boş (tarih uydurulmaz).
String dateRange(DateTime? start, DateTime? end, String lang) {
  final months = lang == 'en' ? _monthsEn : _monthsTr;
  String fmt(DateTime d) => '${months[d.month - 1]} ${d.year}';
  if (start == null && end == null) return '';
  if (start == null) return fmt(end!);
  if (end == null || (start.year == end.year && start.month == end.month)) return fmt(start);
  return '${fmt(start)} – ${fmt(end)}';
}
