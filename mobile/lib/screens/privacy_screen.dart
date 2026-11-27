import 'package:flutter/material.dart';
import '../ui/motion.dart';

import '../api/api_client.dart';

/// Aydınlatma metni. Metin backend'den gelir (tek kaynak: backend/app/legal/).
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key, required this.api});

  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aydınlatma metni')),
      body: FutureBuilder<String>(
        future: api.getText('/privacy'),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('Metin yüklenemedi. Sunucuya ulaşılamıyor olabilir.'));
          }
          if (!snap.hasData) return const PageLoader();
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [for (final line in snap.data!.split('\n')) _line(context, line)],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Basit biçim: "# " başlık, "## " ara başlık, "- " madde, diğerleri paragraf.
  Widget _line(BuildContext context, String line) {
    final t = Theme.of(context).textTheme;
    if (line.startsWith('# ')) {
      return Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(line.substring(2), style: t.headlineSmall));
    }
    if (line.startsWith('## ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Text(line.substring(3), style: t.titleMedium),
      );
    }
    if (line.startsWith('- ')) {
      return Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('•  '),
          Expanded(child: Text(line.substring(2))),
        ]),
      );
    }
    if (line.trim().isEmpty) return const SizedBox(height: 4);
    return Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(line));
  }
}
