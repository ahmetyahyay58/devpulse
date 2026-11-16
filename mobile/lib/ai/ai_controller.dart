import 'package:flutter/foundation.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';

/// Hazır bir soru (backend app/ai/questions.py). Serbest metin soru yoktur.
class AiQuestion {
  AiQuestion(Map<String, dynamic> j)
    : id = j['id'] as String,
      kind = j['kind'] as String,
      text = j['text'] as String;
  final String id;
  final String kind; // sor | neden | ipucu
  final String text;
}

/// Bir sorunun cevabı. source: "llm" (Gemini) ya da "sablon" (hazır cümle).
class AiAnswer {
  AiAnswer(Map<String, dynamic> j)
    : questionId = j['question_id'] as String,
      question = j['question'] as String,
      answer = j['answer'] as String,
      source = j['source'] as String,
      reason = j['reason'] as String?,
      facts = (j['facts'] as Map).cast<String, dynamic>();
  final String questionId;
  final String question;
  final String answer;
  final String source;
  final String? reason;
  // Yapay zekâya giden (ya da gidecek) sayılar.
  final Map<String, dynamic> facts;
  bool get fromLlm => source == 'llm';
}

/// AI katmanının telefondaki tek durumu: onay, sunucuda anahtar var mı, soru listesi.
/// Onay sunucuda tutulur (users.ai_consent_at); onay yoksa sunucu LLM'i hiç çağırmaz.
class AiController extends ChangeNotifier {
  AiController({required this.api});
  final ApiClient api;

  bool loaded = false;
  bool consent = false;
  bool llmReady = false;
  String model = '';
  List<AiQuestion> questions = const [];
  // Bu oturumda onay penceresi gösterildi mi (yalnız bellekte).
  bool consentAsked = false;

  // İpucu satırı: Profil'den kapatılır (telefonda saklanır); çarpıyla yalnız bu oturumda gizlenir.
  static const tipsKey = 'ai_tips_enabled';
  bool tipsEnabled = true;
  bool tipDismissed = false;

  AiQuestion? byId(String id) {
    for (final q in questions) {
      if (q.id == id) return q;
    }
    return null;
  }

  Future<void> loadPrefs() async {
    try {
      tipsEnabled = (await SharedPreferences.getInstance()).getBool(tipsKey) ?? true;
      notifyListeners();
    } catch (_) {
      // Depo yoksa (ör. eklentisiz test) varsayılan: açık.
    }
  }

  Future<void> setTipsEnabled(bool enabled) async {
    tipsEnabled = enabled;
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance()).setBool(tipsKey, enabled);
    } catch (_) {}
  }

  void dismissTip() {
    tipDismissed = true;
    notifyListeners();
  }

  List<AiQuestion> ofKind(String kind) =>
      questions.where((q) => q.kind == kind).toList();

  Future<void> load() async {
    try {
      _apply(await api.get('/ai/status'));
    } catch (_) {
      // AI isteğe bağlı bir ek: yüklenemezse kart gizli kalır, uygulamanın geri kalanı etkilenmez.
    }
  }

  Future<void> setConsent(bool enabled) async {
    _apply(await api.post('/ai/consent', {'enabled': enabled}));
  }

  Future<AiAnswer> ask(String questionId) async =>
      AiAnswer(await api.post('/ai/ask', {'question': questionId}));

  Future<Map<String, dynamic>> facts() async =>
      ((await api.get('/ai/facts'))['facts'] as Map).cast<String, dynamic>();

  void _apply(Map<String, dynamic> s) {
    consent = s['consent'] as bool;
    llmReady = s['llm_ready'] as bool;
    model = s['model'] as String;
    questions = [
      for (final q in s['questions'] as List)
        AiQuestion((q as Map).cast<String, dynamic>()),
    ];
    loaded = true;
    notifyListeners();
  }
}
