import 'package:flutter/material.dart';

import '../ai/ai_features.dart';
import 'project_detail_screen.dart';
import 'projects_controller.dart';
import 'projects_models.dart';

const _labels = {
  'readme': 'README',
  'readme_content': 'README içeriği',
  'description': 'Açıklama',
  'license': 'Lisans',
  'topics': 'Topic',
};

/// Projeler sekmesi: özet, puanlanan repolar (en eksikli önce), puanlanmayanlar.
class ProjectsView extends StatelessWidget {
  const ProjectsView({super.key, required this.controller});

  final ProjectsController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final data = controller.data;
        if (data == null) {
          if (controller.error != null) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(controller.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                TextButton(onPressed: controller.load, child: const Text('Tekrar dene')),
              ]),
            );
          }
          return const Center(child: CircularProgressIndicator());
        }
        final scored = data.projects.where((p) => p.scored).toList();
        final unscored = data.projects.where((p) => !p.scored).toList();
        return ListView(
          padding: tabPadding,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SummaryCard(data: data),
                    for (final p in scored) ...[const SizedBox(height: 8), _ProjectCard(project: p)],
                    if (unscored.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text('Puanlanmayan repolar', style: Theme.of(context).textTheme.titleMedium),
                      Text("Fork'lar ve katkı yaptığın başkasına ait repolar; vitrinleri senin elinde değil.",
                          style: Theme.of(context).textTheme.bodySmall),
                      for (final p in unscored) ...[const SizedBox(height: 8), _ProjectCard(project: p)],
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.data});
  final ProjectsData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Proje sağlığı', style: theme.textTheme.titleLarge),
            const Align(alignment: Alignment.centerLeft, child: WhyButton(questionId: 'neden_proje')),
            Text(data.summary),
            if (data.scoredCount > 0) ...[
              const SizedBox(height: 12),
              // Her eksiğin kaç repoda olduğu: yazıyla (ör. "Lisans yok: 4/4 repo").
              for (final e in data.missingCounts.entries)
                if (e.value > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      Expanded(child: Text('${_labels[e.key] ?? e.key} eksik')),
                      Text('${e.value}/${data.scoredCount} repo',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ]),
                  ),
            ],
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 12),
                title: Text('Nasıl hesaplandı?', style: theme.textTheme.bodySmall),
                children: [Text(data.how, style: theme.textTheme.bodySmall)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Listedeki repo kartı: ad, skor, dil/commit, durum etiketi, skor çubuğu. Dokununca detay.
class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project});
  final Project project;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final p = project;
    final missing = p.missing.length;
    final details = [
      ?p.language,
      '${p.commitCount} commit',
      if (p.scored) missing == 0 ? 'eksik yok' : '$missing eksik',
    ].join(' · ');

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => ProjectDetailScreen(project: p)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Ad tam satırı alır (dar ekranda kısalmasın); durum etiketi alt satırda.
                Text(p.name, style: theme.textTheme.titleMedium, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  StateChip(project: p),
                  Text(details, style: muted),
                ]),
                if (p.scored) ...[
                  const SizedBox(height: 8),
                  // Tek değerli ilerleme çubuğu: skoru görselleştirir, sayı yanında yazılıdır.
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: (p.score ?? 0) / 100, minHeight: 4),
                  ),
                ],
              ]),
            ),
            const SizedBox(width: 12),
            if (p.scored) Text('${p.score}/100', style: theme.textTheme.titleMedium),
            const Icon(Icons.chevron_right),
          ]),
        ),
      ),
    );
  }
}
