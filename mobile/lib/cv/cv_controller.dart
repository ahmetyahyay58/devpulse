import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import 'cv_edits.dart';
import 'cv_formats.dart';
import 'cv_profile.dart';

/// CV taslağının bir maddesi (backend app/cv/draft.py). [id] veriden türetilir, konumdan değil:
/// telefondaki düzenlemeler bu kimliğe bağlanır (docs/cv.md).
class CvItem {
  CvItem(Map<String, dynamic> j)
      : id = j['id'] as String,
        text = j['text'] as String,
        source = j['source'] as String,
        placeholder = j['placeholder'] as bool? ?? false,
        edited = false;

  /// Düzenleme uygulanmış madde (cv_edits.dart).
  CvItem.of({required this.id, required this.text, required this.source, this.placeholder = false, this.edited = false});

  final String id;
  final String text;
  final String source; // hangi veriden üretildi (düzenlendiyse "Senin düzenlemen")
  final bool placeholder; // [...] kısmını kullanıcı doldurur
  final bool edited; // kullanıcı değiştirdi ya da ekledi (docs/cv.md, şeffaflık)

  /// Madde türü: kimliğin son parçası (desc, stack, work, impact, extra...).
  String get kind => id.split(':').last;
}

/// "Hakkımda" bölümünün maddesi: kullanıcı o dilde yazdıysa onun metni ("Senin yazdığın"),
/// yazmadıysa GitHub verisinden gelen özet (gizlenmişse yok). docs/cv.md, "Eklenen bölümler".
CvItem? aboutItem(CvDraft d, CvProfile p) {
  final own = p.aboutFor(d.lang);
  if (own.isEmpty) return d.summary;
  return CvItem.of(id: 'about:own', text: own, source: d.lang == 'en' ? 'Written by you' : 'Senin yazdığın',
      edited: true);
}

class CvProject {
  CvProject(Map<String, dynamic> j)
      : id = j['id'] as String,
        name = j['name'] as String,
        url = j['url'] as String? ?? '',
        tech = [for (final t in j['tech'] as List? ?? const []) t as String],
        start = j['start'] == null ? null : DateTime.parse(j['start'] as String),
        end = j['end'] == null ? null : DateTime.parse(j['end'] as String),
        defaultSelected = j['default_selected'] as bool? ?? true,
        items = [for (final i in j['items'] as List) CvItem((i as Map).cast<String, dynamic>())];

  CvProject.of(CvProject p, this.items)
      : id = p.id,
        name = p.name,
        url = p.url,
        tech = p.tech,
        start = p.start,
        end = p.end,
        defaultSelected = p.defaultSelected;

  final String id;
  final String name;
  final String url;
  final List<String> tech; // ana dil + araçlar
  final DateTime? start; // GitHub'daki oluşturma tarihi (uydurulmaz)
  final DateTime? end; // son push
  final bool defaultSelected; // sağlık puanına göre ilk 4 (kullanıcı başkasını seçebilir)
  final List<CvItem> items;

  /// Madde türü kimliğin son parçasıdır: `proj:<id>:desc`, `stack`, `work` ya da `impact`.
  CvItem? item(String kind) {
    for (final i in items) {
      if (i.id.endsWith(':$kind')) return i;
    }
    return null;
  }
}

class CvDraft {
  CvDraft(Map<String, dynamic> j)
      : lang = j['lang'] as String,
        login = j['login'] as String,
        profileUrl = j['profile_url'] as String,
        summary = j['summary'] == null ? null : CvItem((j['summary'] as Map).cast<String, dynamic>()),
        projects = [for (final p in j['projects'] as List) CvProject((p as Map).cast<String, dynamic>())],
        skills = _items(j['skills']),
        activity = _items(j['activity']),
        languages = [for (final l in j['languages'] as List? ?? const []) l as String],
        tools = [for (final t in j['tools'] as List? ?? const []) t as String];

  /// Düzenlemeler uygulanmış görünüm (sayfa ve PDF bunu çizer).
  CvDraft.of(CvDraft d,
      {required this.summary, required this.projects, required this.activity, required this.languages, required this.tools})
      : lang = d.lang,
        login = d.login,
        profileUrl = d.profileUrl,
        skills = d.skills;

  final String lang;
  final String login;
  final String profileUrl;
  final CvItem? summary;
  final List<CvProject> projects;
  final List<CvItem> skills;
  final List<CvItem> activity;
  final List<String> languages; // programlama dilleri (bayt payına göre)
  final List<String> tools;

  static List<CvItem> _items(Object? list) =>
      [for (final i in list as List) CvItem((i as Map).cast<String, dynamic>())];
}

/// CV sekmesinin verisi: seçili dildeki taslak. Taslak sunucuda veriden üretilir; kullanıcının
/// düzenlemeleri sunucuya gitmez (docs/cv.md).
class CvController extends ChangeNotifier {
  CvController({required this.api, required this.onUnauthorized, CvProfileStore? store})
      : store = store ?? PrefsCvProfileStore();

  final ApiClient api;
  final VoidCallback onUnauthorized;
  final CvProfileStore store; // "Bilgilerim": yalnız bu cihazda
  CvProfile profile = CvProfile();
  CvEdits edits = CvEdits(); // madde düzenlemeleri (yalnız bu cihazda)

  /// Sayfa ve PDF'in çizdiği son hal: taslak + düzenlemeler.
  CvDraft? get effective => draft == null ? null : applyEdits(draft!, edits);

  String lang = 'tr';
  CvFormat format = jakes;
  bool showSources = false; // kağıtta maddelerin kaynağı (yalnız ekranda)
  CvDraft? draft;
  String? error;
  bool _disposed = false;

  Future<void> load() async {
    error = null;
    _notify();
    // Profil ayrı yüklenir: cihaz deposu yavaş ya da erişilemez olsa da taslak gelir.
    _loadProfile();
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

  bool _profileLoaded = false;

  Future<void> _loadProfile() async {
    if (_profileLoaded) return; // dil değişince yeniden okunmaz; düzenlemeler bellekte güncel
    final p = await store.read();
    final e = await store.readEdits();
    _profileLoaded = true;
    profile = p;
    if (e != null) edits = CvEdits.fromJson(e);
    _notify();
  }

  Future<void> setLang(String value) async {
    if (value == lang) return;
    lang = value;
    draft = null; // eski dildeki taslak kısa süre bile görünmesin
    await load();
  }

  /// Bilgilerim "Kaydet": önce cihaza yazılır, başarılıysa sayfa güncellenir (hata çağırana gider).
  Future<void> saveProfile(CvProfile p) async {
    await store.write(p);
    profile = p;
    _notify();
  }

  /// "Maddeleri düzenle" Kaydet: önce cihaza yazılır, başarılıysa sayfa güncellenir.
  Future<void> saveEdits(CvEdits e) async {
    await store.writeEdits(e.toJson());
    edits = e;
    _notify();
  }

  void setFormat(CvFormat f) {
    format = f;
    _notify();
  }

  void setShowSources(bool v) {
    showSources = v;
    _notify();
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
