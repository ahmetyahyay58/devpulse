import 'package:flutter/material.dart';
import '../ui/motion.dart';

import '../api/api_client.dart';

/// Model Laboratuvarı: commit türü sınıflandırmasının gerçek ölçümleri (docs/olcumler.md) ve
/// kullanıcının kendi commit'lerinde kararların ne kadarını kuralın, ne kadarını modelin verdiği.
/// Örnek ya da uydurma değer yoktur.
class ModelLabScreen extends StatefulWidget {
  const ModelLabScreen({super.key, required this.api, this.bySource});

  final ApiClient api;
  final Map<String, int>? bySource; // kural / model / belirsiz (Genel Bakış'tan)

  @override
  State<ModelLabScreen> createState() => _ModelLabScreenState();
}

class _ModelLabScreenState extends State<ModelLabScreen> {
  late final Future<Map<String, dynamic>> _lab = widget.api.get('/metrics/model-lab');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Model Laboratuvarı')),
      body: FutureBuilder(
        future: _lab,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text(userMessage(snap.error!, fallback: 'Ölçümler yüklenemedi.')));
          }
          if (!snap.hasData) return const PageLoader();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: _content(context, snap.data!),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _content(BuildContext context, Map<String, dynamic> lab) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final scores = (lab['scores'] as List).cast<Map<String, dynamic>>();
    Widget card(String title, List<Widget> children) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              ...children,
            ]),
          ),
        );
    // Belgede ondalık nokta ile yazılı; ekranda Türkçe virgül.
    String tr(Object v) => '$v'.replaceAll('.', ',');

    final by = widget.bySource;
    final total = by == null ? 0 : by.values.fold<int>(0, (a, b) => a + b);
    String pct(int n) => total == 0 ? '-' : '%${(n * 100 / total).round()}';

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      card('Sistem', [
        Text(lab['system'] as String),
        const SizedBox(height: 8),
        Text('Eğitim: ${lab['training']}', style: muted),
        const SizedBox(height: 8),
        Text('Sınıflar: ${(lab['classes'] as List).join(', ')}', style: muted),
      ]),
      card('Ölçülen başarı', [
        for (final s in scores)
          // Referans adı uzun: puan alt satırda (dar ekranda taşmasın).
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${s['reference']} (${s['messages']} mesaj)'),
              Text('doğruluk ${tr(s['accuracy'])} · kappa ${tr(s['kappa'])}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
          ),
        const SizedBox(height: 4),
        Text('Karşılaştırma: rastgele tahmin ${lab['random_baseline']}. İnsan kontrolü: yapay zekâ '
            'etiketlerinden rastgele ${lab['human_check']} örneğe geliştirici katıldı.', style: muted),
      ]),
      if (by != null && total > 0)
        card('Senin commit\'lerinde kararlar', [
          for (final (key, label) in [('kural', 'Kural verdi'), ('model', 'Model verdi'), ('belirsiz', 'Belirsiz')])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Expanded(child: Text(label)),
                Text('${by[key] ?? 0} · ${pct(by[key] ?? 0)}', style: const TextStyle(fontWeight: FontWeight.w600)),
              ]),
            ),
        ]),
      card('En sık karışan türler', [
        Text('Etiketleyiciler arasında (geliştirici → yapay zekâ):', style: muted),
        const SizedBox(height: 4),
        for (final c in (lab['confusions'] as List)) Text('• $c'),
      ]),
      card('Sınırlamalar', [
        for (final c in (lab['caveats'] as List))
          Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('• $c')),
      ]),
      Text('Kaynak: ${lab['source']}', style: muted),
    ]);
  }
}
