import 'package:flutter/material.dart';

import '../ai/ai_features.dart';
import 'cv_controller.dart';

/// CV sekmesi: GitHub verisinden üretilen taslak. Her madde kaynağını gösterir; verinin bilemeyeceği
/// sayılar (etki) sarı yer tutucudur ve kullanıcı doldurur (docs/cv.md).
class CvView extends StatelessWidget {
  const CvView({super.key, required this.controller});

  final CvController controller;

  static const _titles = {
    'tr': ('Özet', 'Projeler', 'Beceriler', 'Etkinlik'),
    'en': ('Summary', 'Projects', 'Skills', 'Activity'),
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final d = controller.draft;
        final Widget body;
        if (d == null) {
          body = controller.error != null
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(controller.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  TextButton(onPressed: controller.load, child: const Text('Tekrar dene')),
                ])
              : const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
        } else {
          body = _draft(context, d);
        }
        return ListView(padding: tabPadding, children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
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
                const SizedBox(height: 12),
                body,
              ]),
            ),
          ),
        ]);
      },
    );
  }

  Widget _draft(BuildContext context, CvDraft d) {
    final theme = Theme.of(context);
    final (summary, projects, skills, activity) = _titles[d.lang] ?? _titles['tr']!;
    Widget heading(String s) => Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 4),
          child: Text(s, style: theme.textTheme.titleMedium),
        );
    if (d.summary == null && d.projects.isEmpty && d.skills.isEmpty && d.activity.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('CV taslağı için henüz veri yok. Senkron bitince taslak burada oluşur.'),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(d.login, style: theme.textTheme.headlineSmall),
          Text(d.profileUrl, style: theme.textTheme.bodySmall),
          if (d.summary != null) ...[heading(summary), CvItemTile(item: d.summary!, lang: d.lang)],
          if (d.projects.isNotEmpty) heading(projects),
          for (final p in d.projects) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            for (final i in p.items) CvItemTile(item: i, bullet: true, lang: d.lang),
          ],
          if (d.skills.isNotEmpty) heading(skills),
          for (final i in d.skills) CvItemTile(item: i, lang: d.lang),
          if (d.activity.isNotEmpty) heading(activity),
          for (final i in d.activity) CvItemTile(item: i, bullet: true, lang: d.lang),
        ]),
      ),
    );
  }
}

/// Tek madde: metin ve altında kaynağı. Yer tutucu sarı zeminli ve "Doldurulacak" etiketlidir
/// (renk tek başına anlam taşımaz).
class CvItemTile extends StatelessWidget {
  const CvItemTile({super.key, required this.item, this.bullet = false, this.lang = 'tr'});
  final CvItem item;
  final bool bullet;
  final String lang; // kart içindeki her şey CV'nin dilini izler

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final text = Text('${bullet ? '• ' : ''}${item.text}');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (item.placeholder)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.6)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.edit_note, size: 16),
                const SizedBox(width: 4),
                Text(lang == 'en' ? 'To fill in' : 'Doldurulacak', style: theme.textTheme.labelSmall),
              ]),
              text,
            ]),
          )
        else
          text,
        Text(item.source, style: muted),
      ]),
    );
  }
}
