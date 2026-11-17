import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "Bilgilerim": CV'nin GitHub'da olmayan bölümleri (ad, iletişim, eğitim, deneyim, diller).
/// Yalnızca bu cihazda saklanır, sunucuya hiç gitmez; çıkışta ve "Verilerimi sil"de silinir
/// (docs/cv.md). Web'de tarayıcının yerel deposudur (localStorage).

String newId() => '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 20)}';

class Education {
  Education({String? id, this.school = '', this.degree = '', this.dates = '', this.location = '', this.note = ''})
      : id = id ?? newId();
  final String id; // kalıcı kimlik: sıra değişse de düzenleme doğru kayda bağlı kalır
  String school, degree, dates, location, note; // tarih serbest metin, ör. "Eyl 2022 – Haz 2026"

  Map<String, dynamic> toJson() =>
      {'id': id, 'school': school, 'degree': degree, 'dates': dates, 'location': location, 'note': note};
  factory Education.fromJson(Map<String, dynamic> j) => Education(
      id: j['id'] as String?, school: j['school'] ?? '', degree: j['degree'] ?? '', dates: j['dates'] ?? '',
      location: j['location'] ?? '', note: j['note'] ?? '');
}

class Experience {
  Experience({String? id, this.role = '', this.org = '', this.dates = '', this.location = '', List<String>? bullets})
      : id = id ?? newId(),
        bullets = bullets ?? [];
  final String id;
  String role, org, dates, location;
  List<String> bullets; // madde başına tek cümle (Harvard rehberi)

  Map<String, dynamic> toJson() =>
      {'id': id, 'role': role, 'org': org, 'dates': dates, 'location': location, 'bullets': bullets};
  factory Experience.fromJson(Map<String, dynamic> j) => Experience(
      id: j['id'] as String?, role: j['role'] ?? '', org: j['org'] ?? '', dates: j['dates'] ?? '',
      location: j['location'] ?? '', bullets: [for (final b in j['bullets'] as List? ?? const []) b as String]);
}

/// Europass sadeleştirmesi: dil başına tek düzey (anadil ya da CEFR A1-C2).
const languageLevels = ['Anadil', 'A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

class SpokenLanguage {
  SpokenLanguage({String? id, this.name = '', this.level = 'B1'}) : id = id ?? newId();
  final String id;
  String name, level;

  /// "Anadil" İngilizce CV'de "Native" yazılır.
  String levelLabel(String lang) => level == 'Anadil' && lang == 'en' ? 'Native' : level;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'level': level};
  factory SpokenLanguage.fromJson(Map<String, dynamic> j) =>
      SpokenLanguage(id: j['id'] as String?, name: j['name'] ?? '', level: j['level'] ?? 'B1');
}

class CvProfile {
  CvProfile({
    this.fullName = '',
    this.email = '',
    this.phone = '',
    this.location = '',
    this.linkedin = '',
    List<Education>? education,
    List<Experience>? experience,
    List<SpokenLanguage>? languages,
  })  : education = education ?? [],
        experience = experience ?? [],
        languages = languages ?? [];

  String fullName, email, phone, location, linkedin;
  List<Education> education;
  List<Experience> experience;
  List<SpokenLanguage> languages;

  bool get isEmpty =>
      [fullName, email, phone, location, linkedin].every((s) => s.trim().isEmpty) &&
      education.isEmpty && experience.isEmpty && languages.isEmpty;

  /// Başlıktaki iletişim satırı: boş olanlar atlanır.
  List<String> contacts() =>
      [phone, email, location, linkedin].map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  Map<String, dynamic> toJson() => {
        'fullName': fullName, 'email': email, 'phone': phone, 'location': location, 'linkedin': linkedin,
        'education': [for (final e in education) e.toJson()],
        'experience': [for (final e in experience) e.toJson()],
        'languages': [for (final l in languages) l.toJson()],
      };

  factory CvProfile.fromJson(Map<String, dynamic> j) {
    List<Map<String, dynamic>> list(String k) =>
        [for (final e in j[k] as List? ?? const []) (e as Map).cast<String, dynamic>()];
    return CvProfile(
      fullName: j['fullName'] ?? '', email: j['email'] ?? '', phone: j['phone'] ?? '',
      location: j['location'] ?? '', linkedin: j['linkedin'] ?? '',
      education: list('education').map(Education.fromJson).toList(),
      experience: list('experience').map(Experience.fromJson).toList(),
      languages: list('languages').map(SpokenLanguage.fromJson).toList(),
    );
  }
}

/// CV'nin cihazdaki deposu: "Bilgilerim" profili ve madde düzenlemeleri (JSON). Testlerde bellek
/// içi sürümü kullanılır. clear ikisini birden siler (çıkış ve "Verilerimi sil").
abstract class CvProfileStore {
  Future<CvProfile> read();
  Future<void> write(CvProfile p);
  Future<Map<String, dynamic>?> readEdits();
  Future<void> writeEdits(Map<String, dynamic> edits);
  Future<void> clear();
}

class PrefsCvProfileStore implements CvProfileStore {
  static const key = 'cv_profile';
  static const editsKey = 'cv_edits';

  @override
  Future<Map<String, dynamic>?> readEdits() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(editsKey);
      return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('CV düzenlemeleri okunamadı: $e');
      return null;
    }
  }

  @override
  Future<void> writeEdits(Map<String, dynamic> edits) async {
    try {
      await (await SharedPreferences.getInstance()).setString(editsKey, jsonEncode(edits));
    } catch (e) {
      debugPrint('CV düzenlemeleri kaydedilemedi: $e');
      rethrow;
    }
  }

  @override
  Future<CvProfile> read() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(key);
      return raw == null ? CvProfile() : CvProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e, st) {
      debugPrint('CV profili okunamadı: $e\n$st');
      return CvProfile(); // bozuk ya da erişilemeyen kayıt: boş profil
    }
  }

  @override
  Future<void> write(CvProfile p) async {
    try {
      await (await SharedPreferences.getInstance()).setString(key, jsonEncode(p.toJson()));
    } catch (e, st) {
      debugPrint('CV profili kaydedilemedi: $e\n$st');
      rethrow; // ekran "kaydedilemedi" desin; sessizce kaybolmasın
    }
  }

  @override
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
      await prefs.remove(editsKey);
    } catch (_) {}
  }
}

class MemoryCvProfileStore implements CvProfileStore {
  CvProfile? saved;
  Map<String, dynamic>? savedEdits;
  @override
  Future<Map<String, dynamic>?> readEdits() async => savedEdits;
  @override
  Future<void> writeEdits(Map<String, dynamic> edits) async => savedEdits = edits;
  @override
  Future<CvProfile> read() async => saved == null ? CvProfile() : CvProfile.fromJson(saved!.toJson());
  @override
  Future<void> write(CvProfile p) async => saved = CvProfile.fromJson(p.toJson());
  @override
  Future<void> clear() async {
    saved = null;
    savedEdits = null;
  }
}
