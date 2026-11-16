import 'package:flutter/material.dart';

import '../ai/ai_features.dart';
import 'cv_controller.dart';
import 'cv_formats.dart';
import 'cv_page.dart';

/// CV sekmesi: dil ve format seçimi, altında kağıt görünümünde CV (docs/cv.md). Taslak GitHub
/// verisinden gelir; eğitim, deneyim ve iletişim bilgileri telefonda girilir (sonraki adım).
class CvView extends StatelessWidget {
  const CvView({super.key, required this.controller});

  final CvController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final theme = Theme.of(context);
        final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
        final d = controller.draft;
        final Widget page;
        if (d == null) {
          page = controller.error != null
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(controller.error!, style: TextStyle(color: theme.colorScheme.error)),
                  TextButton(onPressed: controller.load, child: const Text('Tekrar dene')),
                ])
              : const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
        } else if (d.projects.isEmpty && d.languages.isEmpty && d.activity.isEmpty) {
          page = const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('CV taslağı için henüz veri yok. Senkron bitince taslak burada oluşur.'),
            ),
          );
        } else {
          // Kağıt: ince gölgeli beyaz sayfa.
          page = Material(
            elevation: 2,
            child: CvPage(draft: d, format: controller.format, showSources: controller.showSources),
          );
        }
        return ListView(padding: tabPadding, children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'tr', label: Text('Türkçe')),
                    ButtonSegment(value: 'en', label: Text('English')),
                  ],
                  selected: {controller.lang},
                  onSelectionChanged: (s) => controller.setLang(s.first),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: [for (final f in cvFormats) ButtonSegment(value: f.id, label: Text(f.name))],
                  selected: {controller.format.id},
                  onSelectionChanged: (s) => controller.setFormat(cvFormats.firstWhere((f) => f.id == s.first)),
                ),
                const SizedBox(height: 6),
                Text(controller.format.note[controller.lang] ?? '', style: muted),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Maddelerin kaynağını göster'),
                  subtitle: const Text('Yalnız ekranda; CV dosyasına basılmaz.'),
                  value: controller.showSources,
                  onChanged: controller.setShowSources,
                ),
                page,
              ]),
            ),
          ),
        ]);
      },
    );
  }
}
