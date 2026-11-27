import 'package:flutter/material.dart';
import '../ui/motion.dart';

import '../api/api_client.dart';
import 'cv_controller.dart';

/// Mülakat koçunun cevabı (`POST /ai/interview`, docs/ai_katmani.md "Mülakat koçu").
class InterviewAnswer {
  InterviewAnswer(Map<String, dynamic> j)
      : questions = [for (final q in j['questions'] as List) q as String],
        evidence = [for (final e in j['evidence'] as List) e as String],
        fromLlm = j['source'] == 'llm',
        reason = j['reason'] as String?,
        facts = (j['facts'] as Map).cast<String, dynamic>();

  final List<String> questions; // tam 3
  final List<String> evidence; // veriden kurallı; yapay zekâya gitmez
  final bool fromLlm;
  final String? reason; // şablonsa neden
  final Map<String, dynamic> facts; // yapay zekâya giden (ya da gidecek olan) sayılar
}

/// Yapay zekâya giden sayıların Türkçe adları (ekranda gösterim için).
const interviewFactLabels = {
  'ana_dil': 'Ana dil',
  'araclar': 'Araçlar',
  'commit_sayisi': 'Commit sayısı',
  'aktif_gun': 'Aktif gün',
  'sure_ay': 'Süre (ay)',
  'saglik_puani': 'Sağlık puanı',
  'eksik_belgeler': 'Eksik belgeler',
  'commit_turleri_yuzde': 'Commit türleri (%)',
  'tur_guveni': 'Tür verisi güveni',
};

String _factValue(Object? v) => switch (v) {
      null => 'bilinmiyor',
      List l when l.isEmpty => 'yok',
      List l => l.join(', '),
      Map m when m.isEmpty => 'yok',
      Map m => m.entries.map((e) => '${e.key} ${e.value}').join(', '),
      _ => '$v',
    };

/// Mülakat koçu: CV'deki projelerden biri seçilir; o proje için görüşmede sorulabilecek 3 soru ve
/// hazırlık için kanıt önerileri gösterilir. Yapay zekâya proje adı değil, yalnız sayıları gider.
class InterviewScreen extends StatefulWidget {
  const InterviewScreen({super.key, required this.controller});
  final CvController controller;

  @override
  State<InterviewScreen> createState() => _InterviewScreenState();
}

class _InterviewScreenState extends State<InterviewScreen> {
  String? _selected;
  InterviewAnswer? _answer;
  String? _error;
  bool _loading = false;

  Future<void> _pick(String projectId) async {
    setState(() {
      _selected = projectId;
      _answer = null;
      _error = null;
      _loading = true;
    });
    try {
      final a = InterviewAnswer(await widget.controller.api.post('/ai/interview', {'project_id': projectId}));
      if (mounted && _selected == projectId) setState(() => _answer = a);
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        widget.controller.onUnauthorized();
      } else if (mounted) {
        setState(() => _error = e.message);
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Sorular hazırlanamadı. Lütfen tekrar dene.');
    } finally {
      if (mounted && _selected == projectId) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final projects = widget.controller.effective?.projects ?? const <CvProject>[];
    final a = _answer;
    return Scaffold(
      appBar: AppBar(title: const Text('Mülakat koçu')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Bir proje seç: görüşmede o proje hakkında sorulabilecek 3 soru ve hazırlık önerileri gelir.',
                  style: theme.textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text('Yapay zekâya projenin adı değil, yalnız sayıları gider.', style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
              if (projects.isEmpty)
                const Text('CV\'de seçili proje yok. "Maddeleri düzenle"den proje seçebilirsin.')
              else
                Wrap(spacing: 8, runSpacing: 4, children: [
                  for (final p in projects)
                    ChoiceChip(
                      label: Text(p.name),
                      selected: _selected == p.id,
                      showCheckmark: false,
                      onSelected: _loading ? null : (_) => _pick(p.id),
                    ),
                ]),
              const SizedBox(height: 16),
              if (_loading) const PageLoader(),
              if (_error != null) Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              if (a != null) ...[
                Text('Olası sorular', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final (i, q) in a.questions.indexed)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(radius: 14, child: Text('${i + 1}')),
                      title: Text(q),
                    ),
                  ),
                Text(
                  a.fromLlm ? 'Kaynak: Yapay zekâ' : 'Kaynak: Şablon${a.reason == null ? '' : ' (${a.reason})'}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Text('Kanıt önerileri', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text('Verinden kurallı çıkarıldı; yapay zekâya gönderilmez.', style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                for (final e in a.evidence)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Icons.check_circle_outline, size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(e)),
                    ]),
                  ),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Yapay zekâya giden veri'),
                  children: [
                    for (final e in a.facts.entries)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(interviewFactLabels[e.key] ?? e.key),
                        trailing: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 220),
                          child: Text(_factValue(e.value), textAlign: TextAlign.end),
                        ),
                      ),
                  ],
                ),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}
