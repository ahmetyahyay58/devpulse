import 'package:flutter/material.dart';
import '../ui/motion.dart';

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

/// Projeler sekmesi: "Liste" (özet, puanlanan repolar en eksikli önce, puanlanmayanlar) ya da
/// "Kümeler" (gözetimsiz k-means; docs/metrikler.md "Repo kümeleri").
class ProjectsView extends StatefulWidget {
  const ProjectsView({super.key, required this.controller});

  final ProjectsController controller;

  @override
  State<ProjectsView> createState() => _ProjectsViewState();
}

class _ProjectsViewState extends State<ProjectsView> {
  bool _clusters = false;
  Future<Map<String, dynamic>>? _clusterData;

  ProjectsController get controller => widget.controller;

  Widget _modeSwitch() => SegmentedButton<bool>(
    showSelectedIcon: false,
    segments: const [
      ButtonSegment(value: false, label: Text('Liste')),
      ButtonSegment(value: true, label: Text('Kümeler')),
    ],
    selected: {_clusters},
    onSelectionChanged: (s) => setState(() {
      _clusters = s.first;
      // Her açılışta yeniden ister: senkrondan sonra kümeler değişmiş olabilir.
      if (_clusters) _clusterData = controller.api.get('/projects/clusters');
    }),
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final data = controller.data;
        if (data == null) {
          if (controller.error != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(controller.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  TextButton(onPressed: controller.load, child: const Text('Tekrar dene')),
                ],
              ),
            );
          }
          return const PageLoader();
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
                    _modeSwitch(),
                    const SizedBox(height: 12),
                    if (_clusters)
                      _ClustersSection(future: _clusterData!)
                    else ...[
                      Rise(child: _SummaryCard(data: data)),
                      // Proje kartları sırayla gelir (ilk 8'i kademeli, gerisi birlikte).
                      for (final (i, p) in scored.indexed) ...[
                        const SizedBox(height: 8),
                        Rise(
                          index: 1 + (i < 8 ? i : 8),
                          child: _ProjectCard(project: p),
                        ),
                      ],
                      if (unscored.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text('Puanlanmayan repolar', style: Theme.of(context).textTheme.titleMedium),
                        Text(
                          "Fork'lar ve katkı yaptığın başkasına ait repolar; vitrinleri senin elinde değil.",
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        for (final p in unscored) ...[const SizedBox(height: 8), _ProjectCard(project: p)],
                      ],
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
            const Align(
              alignment: Alignment.centerLeft,
              child: WhyButton(questionId: 'neden_proje'),
            ),
            Text(data.summary),
            if (data.scoredCount > 0) ...[
              const SizedBox(height: 12),
              // Her eksiğin kaç repoda olduğu: yazıyla (ör. "Lisans yok: 4/4 repo").
              for (final e in data.missingCounts.entries)
                if (e.value > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(child: Text('${_labels[e.key] ?? e.key} eksik')),
                        Text(
                          '${e.value}/${data.scoredCount} repo',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
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

    // Basınca hafifçe küçülür.
    return Pressable(
      child: Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ProjectDetailScreen(project: p))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ad tam satırı alır (dar ekranda kısalmasın); durum etiketi alt satırda.
                    Text(p.name, style: theme.textTheme.titleMedium, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StateChip(project: p),
                        Text(details, style: muted),
                      ],
                    ),
                    if (p.scored) ...[
                      const SizedBox(height: 8),
                      // Tek değerli ilerleme çubuğu: skoru görselleştirir, sayı yanında yazılıdır.
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        // Sağlık çubuğu dolarak gelir (taşmaz: puanı geçmez).
                        child: OnEnter(
                          ms: 900,
                          delayMs: 150,
                          builder: (context, t, _) =>
                              LinearProgressIndicator(value: (p.score ?? 0) / 100 * seg(t, 0, 1), minHeight: 4),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (p.scored) Text('${p.score}/100', style: theme.textTheme.titleMedium),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

/// Kümeler görünümü: her küme bir kart (ad, repolar, ortanca değerler, en sık dil).
class _ClustersSection extends StatelessWidget {
  const _ClustersSection({required this.future});
  final Future<Map<String, dynamic>> future;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return FutureBuilder(
      future: future,
      builder: (context, snap) {
        if (snap.hasError) return const Text('Kümeler yüklenemedi.');
        final d = snap.data;
        if (d == null) {
          return const PageLoader();
        }
        final clusters = (d['clusters'] as List).cast<Map<String, dynamic>>();
        String fmt(Object? v) => v == null ? '-' : (v as num).round().toString();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(d['summary'] as String, style: theme.textTheme.bodyMedium),
            if (d['sufficiency'] == 'dusuk')
              Text('Düşük güven: az repo olduğu için küme sayısı 2 sabit.', style: muted),
            for (final c in clusters)
              Card(
                margin: const EdgeInsets.only(top: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c['name'] as String, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Ortanca: ${fmt(c['median_commits'])} commit · son push ${fmt(c['median_days_since_push'])} gün önce'
                        ' · puan ${fmt(c['median_score'])}'
                        '${c['top_language'] == null ? '' : ' · en sık dil: ${c['top_language']}'}',
                        style: muted,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final r in (c['repos'] as List).cast<String>())
                            Chip(label: Text(r), visualDensity: VisualDensity.compact),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Nasıl hesaplandı?'),
              children: [Text(d['how'] as String, style: muted)],
            ),
          ],
        );
      },
    );
  }
}
