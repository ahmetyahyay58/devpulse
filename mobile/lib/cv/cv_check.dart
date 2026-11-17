import 'cv_controller.dart';
import 'cv_formats.dart';
import 'cv_profile.dart';

/// Biçim kontrolü (docs/cv.md, "Biçim kontrolü"): sabit, açıklanabilir kurallar. Telefonda çalışır;
/// sunucuya ve LLM'e bir şey gitmez. "ATS'den geçer" demez, puan vermez; yalnız liste döner.
/// Mesajlarda değişkenden sonra Türkçe ek yok ("proje-a: açıklama yok").

enum CheckLevel { missing, suggestion } // Eksik, Öneri

/// Sorunu düzeltmek için gidilecek ekran.
enum CheckTarget { profile, edits, none }

class CvCheck {
  const CvCheck(this.level, this.message, this.target);
  final CheckLevel level;
  final String message;
  final CheckTarget target;
}

/// Hakkımda için kısa sayılan uzunluk (2-4 cümle beklenir).
const minAboutChars = 80;

/// Deneyim maddesi için üst sınır: madde düzenlemedeki sınırla aynı (madde başına tek cümle).
const maxBulletChars = 200;

/// [draft] düzenlemeleri uygulanmış taslaktır (sayfada görünen). [pages] PDF'in gerçek sayfa
/// sayısıdır; bilinmiyorsa null (sayfa kuralı atlanır).
List<CvCheck> checkCv({
  required CvDraft draft,
  required CvProfile profile,
  required CvFormat format,
  int? pages,
}) {
  final out = <CvCheck>[];
  void missing(String m, CheckTarget t) => out.add(CvCheck(CheckLevel.missing, m, t));
  void suggest(String m, CheckTarget t) => out.add(CvCheck(CheckLevel.suggestion, m, t));
  final lang = draft.lang;
  final langName = lang == 'en' ? 'İngilizce' : 'Türkçe';

  // Sayfa sayısı: tahmin değil, üretilen PDF'in sayfaları.
  if (pages != null && pages > format.maxPages) {
    missing('PDF $pages sayfa; ${format.name} için önerilen en çok ${format.maxPages} sayfa. '
        'Proje ya da madde sayısını azalt.', CheckTarget.edits);
  }

  // Başlık ve iletişim.
  if (profile.fullName.trim().isEmpty) {
    missing('Ad soyad yazılmadı; başlıkta GitHub kullanıcı adı görünüyor.', CheckTarget.profile);
  }
  if (profile.email.trim().isEmpty) missing('E-posta yok.', CheckTarget.profile);
  if (profile.phone.trim().isEmpty) suggest('Telefon yok.', CheckTarget.profile);
  if (profile.linkedin.trim().isEmpty) suggest('LinkedIn adresi yok.', CheckTarget.profile);

  // Hakkımda.
  final own = profile.aboutFor(lang);
  if (own.isEmpty) {
    if (aboutDraftText(draft) == null) {
      missing('Hakkımda bölümü boş ($langName CV).', CheckTarget.profile);
    } else {
      missing('Hakkımda: kendini tanıttığın metin yazılmadı ($langName CV); hazır metin kullanılıyor, '
          'sarı yer tutucu PDF\'e basılmaz.', CheckTarget.profile);
    }
  } else if (own.length < minAboutChars) {
    suggest('Hakkımda çok kısa (${own.length} karakter); 2-4 cümle önerilir.', CheckTarget.profile);
  }

  // Eğitim.
  if (profile.education.isEmpty) {
    missing('Eğitim bilgisi yok.', CheckTarget.profile);
  } else {
    for (final e in profile.education) {
      if (e.dates.trim().isEmpty) suggest('Eğitim (${_or(e.school)}): tarih yok.', CheckTarget.profile);
    }
  }

  // Deneyim.
  if (profile.experience.isEmpty) {
    suggest(
        format.id == 'beceri'
            ? 'Deneyim yok: staj, gönüllülük ya da kulüp işi varsa ekle.'
            : 'Deneyim yok: staj, gönüllülük ya da kulüp işi varsa ekle; yoksa "Beceri odaklı" şablon daha uygun olabilir.',
        CheckTarget.profile);
  }
  for (final e in profile.experience) {
    if (e.bullets.isEmpty) {
      suggest('Deneyim (${_or(e.role)}): madde yok; ne yaptığını ve sonucunu yaz.', CheckTarget.profile);
    }
    if (e.bullets.any((b) => b.length > maxBulletChars)) {
      suggest('Deneyim (${_or(e.role)}): $maxBulletChars karakteri aşan madde var; madde başına tek cümle önerilir.',
          CheckTarget.profile);
    }
  }

  // Projeler ve doldurulmamış yer tutucular.
  if (draft.projects.isEmpty) {
    missing('CV\'de proje yok.', CheckTarget.edits);
  } else if (draft.projects.length < 2) {
    suggest('Yalnız 1 proje seçili; en az 2 önerilir.', CheckTarget.edits);
  }
  for (final p in draft.projects) {
    if (p.item('desc') == null) suggest('${p.name}: açıklama yok.', CheckTarget.edits);
    final empty = p.items.where((i) => i.placeholder).length;
    if (empty > 0) {
      missing('${p.name}: doldurulmamış madde var ([…]); PDF\'e basılmaz.', CheckTarget.edits);
    }
  }

  // İlgi alanları: yalnız bu bölümü gösteren formatlarda.
  if (format.sections.contains(CvSection.interests) && profile.interestsFor(lang).isEmpty) {
    suggest('İlgi alanları boş ($langName CV).', CheckTarget.profile);
  }

  // Önce eksikler, sonra öneriler (her grubun kendi sırası korunur).
  return [
    ...out.where((c) => c.level == CheckLevel.missing),
    ...out.where((c) => c.level == CheckLevel.suggestion),
  ];
}

String _or(String s) => s.trim().isEmpty ? 'adsız' : s.trim();
