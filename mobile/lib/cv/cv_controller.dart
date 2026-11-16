import 'package:flutter/foundation.dart';

import '../api/api_client.dart';

/// CV taslağının bir maddesi (backend app/cv/draft.py). [id] veriden türetilir, konumdan değil:
/// telefondaki düzenlemeler bu kimliğe bağlanır (docs/cv.md).
class CvItem {
  CvItem(Map<String, dynamic> j)
      : id = j['id'] as String,
        text = j['text'] as String,
        source = j['source'] as String,
        placeholder = j['placeholder'] as bool? ?? false;
  final String id;
  final String text;
  final String source; // hangi veriden üretildi
  final bool placeholder; // [...] kısmını kullanıcı doldurur
}

class CvProject {
  CvProject(Map<String, dynamic> j)
      : id = j['id'] as String,
        name = j['name'] as String,
        items = [for (final i in j['items'] as List) CvItem((i as Map).cast<String, dynamic>())];
  final String id;
  final String name;
  final List<CvItem> items;
}

class CvDraft {
  CvDraft(Map<String, dynamic> j)
      : lang = j['lang'] as String,
        login = j['login'] as String,
        profileUrl = j['profile_url'] as String,
        summary = j['summary'] == null ? null : CvItem((j['summary'] as Map).cast<String, dynamic>()),
        projects = [for (final p in j['projects'] as List) CvProject((p as Map).cast<String, dynamic>())],
        skills = _items(j['skills']),
        activity = _items(j['activity']);
  final String lang;
  final String login;
  final String profileUrl;
  final CvItem? summary;
  final List<CvProject> projects;
  final List<CvItem> skills;
  final List<CvItem> activity;

  static List<CvItem> _items(Object? list) =>
      [for (final i in list as List) CvItem((i as Map).cast<String, dynamic>())];
}

/// CV sekmesinin verisi: seçili dildeki taslak. Taslak sunucuda veriden üretilir; kullanıcının
/// düzenlemeleri sunucuya gitmez (docs/cv.md).
class CvController extends ChangeNotifier {
  CvController({required this.api, required this.onUnauthorized});

  final ApiClient api;
  final VoidCallback onUnauthorized;

  String lang = 'tr';
  CvDraft? draft;
  String? error;
  bool _disposed = false;

  Future<void> load() async {
    error = null;
    _notify();
    try {
      draft = CvDraft(await api.get('/cv/draft?lang=$lang'));
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        onUnauthorized();
      } else {
        error = e.message;
      }
    } catch (_) {
      error = 'CV taslağı yüklenemedi.';
    }
    _notify();
  }

  Future<void> setLang(String value) async {
    if (value == lang) return;
    lang = value;
    draft = null; // eski dildeki taslak kısa süre bile görünmesin
    await load();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
