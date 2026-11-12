import 'package:flutter/material.dart';

import 'projects_controller.dart';
import 'projects_models.dart';

const _labels = {'readme': 'README', 'description': 'Açıklama', 'license': 'Lisans', 'topics': 'Topic'};

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
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SummaryCard(data: data),
                    for (final p in scored) ...[const SizedBox(height: 12), _ProjectCard(project: p)],
                    if (unscored.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text('Puanlanmayan repolar', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      for (final p in unscored) _UnscoredTile(project: p),
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
            const SizedBox(height: 8),
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

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project});
  final Project project;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final p = project;
    final details = [
      ?p.language,
      if (p.isPrivate) 'özel',
      '${p.commitCount} commit',
      if (p.daysSincePush != null) 'son push ${p.daysSincePush} gün önce',
    ].join(' · ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(child: Text(p.name, style: theme.textTheme.titleMedium)),
              Text('${p.score}/100', style: theme.textTheme.titleMedium),
            ]),
            const SizedBox(height: 4),
            Text(details, style: muted),
            const SizedBox(height: 8),
            // Tek değerli ilerleme çubuğu: skoru görselleştirir, sayı yanında yazılıdır.
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: (p.score ?? 0) / 100, minHeight: 6),
            ),
            const SizedBox(height: 12),
            for (final c in p.checks) _CheckRow(check: c),
          ],
        ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.check});
  final ProjectCheck check;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color, word) = switch (check.status) {
      'ok' => (Icons.check_circle, const Color(0xFF0CA30C), 'var'),
      'missing' => (Icons.cancel, const Color(0xFFEC835A), 'eksik'),
      _ => (Icons.help_outline, theme.colorScheme.onSurfaceVariant, 'bilinmiyor'),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Durum ikonun yanında yazıyla da söylenir (renk tek başına anlam taşımaz).
              Text('${check.label}: $word'),
              if (check.hint != null)
                Text(check.hint!,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _UnscoredTile extends StatelessWidget {
  const _UnscoredTile({required this.project});
  final Project project;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${project.name} · ${project.commitCount} commit'),
        Text(project.notScoredReason ?? '', style: muted),
      ]),
    );
  }
}
