/// Beş CV formatının düzeni, veri olarak (docs/cv.md, "Formatlar"). Ekrandaki sayfa (cv_page.dart)
/// ve PDF (cv_pdf.dart) bu tanımı okur; böylece ikisi birbirinden ayrışmaz.
library;

/// Sayfadaki bölümler. Kullanıcının girdiği bölümler (eğitim, deneyim, dil, sertifika, ilgi
/// alanları) boşsa sayfada çıkmaz.
enum CvSection {
  personal, about, education, experience, projects, certificates, spokenLanguages, skills, digitalSkills,
  interests, additional,
}

enum HeaderStyle {
  centered, // Jake's, Harvard, Beceri odaklı: ortada büyük ad, altında tek iletişim satırı
  left, // Türkiye klasik: ad sola yaslı, altında iletişim satırı
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
    required this.maxPages,
    this.headingBand = false,
  });

  final String id;
  final String name; // seçicide görünen ad
  final Map<String, String> note; // ad altında kısa açıklama (tr/en); uyarlamalar dürüstçe söylenir
  final List<CvSection> sections; // sayfadaki sıra
  final HeaderStyle header;
  final bool serif; // Harvard: serif yazı tipi
  final bool headingCaps; // bölüm başlıkları büyük harf
  final bool techInProjectTitle; // Jake's: "Ad | teknolojiler" tek satırda
  final bool headingBand; // Türkiye klasik: başlık gri şerit içinde (alt çizgi yerine)
  final int maxPages; // biçim kontrolündeki sayfa sınırı (docs/cv.md, "Biçim kontrolü")
}

const jakes = CvFormat(
  id: 'jakes',
  name: "Jake's",
  note: {
    'tr': "Jake's Resume düzeni: yazılımcılar arasında yaygın tek sayfalık şablon. Hakkımda ve "
        'sertifikalar eklemedir; boşsa görünmez.',
    'en': "Jake's Resume layout: a one-page template common among software developers. About and "
        'certificates are additions; hidden when empty.',
  },
  sections: [
    CvSection.about, CvSection.education, CvSection.experience, CvSection.projects, CvSection.skills,
    CvSection.certificates,
  ],
  header: HeaderStyle.centered,
  serif: false,
  headingCaps: true,
  techInProjectTitle: true,
  maxPages: 1,
);

const harvard = CvFormat(
  id: 'harvard',
  name: 'Harvard',
  note: {
    'tr': 'Harvard kariyer rehberlerindeki ters kronolojik düzen (tek resmî şablon yok). Hakkımda ve '
        'Projeler bölümleri eklemedir.',
    'en': 'Reverse-chronological layout from Harvard career guides (there is no single official '
        'template). The About and Projects sections are additions.',
  },
  sections: [
    CvSection.about, CvSection.education, CvSection.experience, CvSection.projects, CvSection.skills,
    CvSection.certificates,
  ],
  header: HeaderStyle.centered,
  serif: true,
  headingCaps: true,
  techInProjectTitle: false,
  maxPages: 1,
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
    CvSection.spokenLanguages, CvSection.digitalSkills, CvSection.projects, CvSection.certificates,
    CvSection.interests, CvSection.additional,
  ],
  header: HeaderStyle.europass,
  serif: false,
  headingCaps: false,
  techInProjectTitle: false,
  maxPages: 2,
);

const turkish = CvFormat(
  id: 'turkiye',
  name: 'Türkiye klasik',
  note: {
    'tr': "Türkiye'deki özgeçmiş rehberlerinde yaygın bölüm düzeni (tek resmî şablon yok): eğitim, "
        'iş deneyimi, sertifikalar, yabancı dil, bilgisayar bilgisi, ilgi alanları.',
    'en': 'Section order common in Turkish CV guides (there is no single official template): '
        'education, work experience, certificates, languages, computer skills, interests.',
  },
  sections: [
    CvSection.about, CvSection.education, CvSection.experience, CvSection.projects, CvSection.certificates,
    CvSection.spokenLanguages, CvSection.skills, CvSection.interests,
  ],
  header: HeaderStyle.left,
  serif: false,
  headingCaps: true,
  techInProjectTitle: false,
  maxPages: 2,
  headingBand: true,
);

const skillsFirst = CvFormat(
  id: 'beceri',
  name: 'Beceri odaklı',
  note: {
    'tr': 'İşlevsel (beceri temelli) düzen: beceriler ve projeler önde. Deneyimi az olan öğrenciye '
        'uyar; bazı işe alımcılar kronolojik düzeni tercih eder.',
    'en': 'Functional (skills-based) layout: skills and projects first. Suits students with little '
        'experience; some recruiters prefer a chronological layout.',
  },
  sections: [
    CvSection.about, CvSection.skills, CvSection.projects, CvSection.certificates, CvSection.experience,
    CvSection.education, CvSection.spokenLanguages,
  ],
  header: HeaderStyle.centered,
  serif: false,
  headingCaps: true,
  techInProjectTitle: false,
  maxPages: 1,
);

const cvFormats = [jakes, harvard, europass, turkish, skillsFirst];

/// Bölüm başlıkları, format ve dile göre.
String sectionTitle(CvFormat f, CvSection s, String lang) {
  final en = lang == 'en';
  final eu = f.id == 'europass';
  final tr = f.id == 'turkiye';
  return switch (s) {
    CvSection.personal => en ? 'Personal information' : 'Kişisel bilgiler',
    CvSection.about => en ? (f.id == 'jakes' || f.id == 'harvard' ? 'Summary' : 'About me') : 'Hakkımda',
    CvSection.education => eu ? (en ? 'Education and training' : 'Eğitim ve öğretim') : (en ? 'Education' : 'Eğitim'),
    CvSection.experience => eu || tr ? (en ? 'Work experience' : 'İş deneyimi') : (en ? 'Experience' : 'Deneyim'),
    CvSection.projects => f.id == 'beceri' ? (en ? 'Selected projects' : 'Öne çıkan projeler') : (en ? 'Projects' : 'Projeler'),
    CvSection.certificates => en ? 'Certificates and courses' : 'Sertifikalar ve kurslar',
    CvSection.spokenLanguages => tr ? (en ? 'Languages' : 'Yabancı diller') : (en ? 'Language skills' : 'Dil becerileri'),
    CvSection.skills => tr
        ? (en ? 'Computer skills' : 'Bilgisayar bilgisi')
        : f.id == 'jakes' || f.id == 'beceri'
            ? (en ? 'Technical Skills' : 'Teknik beceriler')
            : (en ? 'Skills' : 'Beceriler'),
    CvSection.digitalSkills => en ? 'Digital skills' : 'Dijital beceriler',
    CvSection.interests => eu ? (en ? 'Hobbies and interests' : 'Hobiler ve ilgi alanları') : (en ? 'Interests' : 'İlgi alanları'),
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
