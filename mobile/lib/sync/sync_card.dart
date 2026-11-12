import 'package:flutter/material.dart';

import '../api/sync_api.dart';
import 'sync_controller.dart';

/// Senkronu başlatan ve ilerlemesini gösteren kart.
class SyncCard extends StatelessWidget {
  const SyncCard({super.key, required this.controller});

  final SyncController controller;

  @override
  Widget build(BuildContext context) {
    // ListenableBuilder: denetleyici her haber verdiğinde kartı yeniden çizer.
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('GitHub verin', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              ..._content(context),
              if (controller.error != null) ...[
                const SizedBox(height: 12),
                Text(controller.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context) {
    final c = controller;
    final job = c.job;
    if (c.loading) return const [Center(child: CircularProgressIndicator())];
    if (job != null && job.isActive) return _running(context, job);

    return [
      if (job == null) const Text('Henüz verin çekilmedi. İlk senkron hesabının büyüklüğüne göre '
          'birkaç saniye ile birkaç dakika arası sürer.'),
      if (job != null && job.status == 'done') ..._done(context, job),
      if (job != null && job.status == 'failed') _failed(context, job),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: c.start,
        icon: const Icon(Icons.sync),
        label: Text(switch (job?.status) {
          null => 'Verimi çek',
          'failed' => 'Tekrar dene',
          _ => 'Yeniden senkronla',
        }),
      ),
    ];
  }

  List<Widget> _running(BuildContext context, SyncJob job) {
    final total = job.reposTotal;
    final step = total == null
        ? 'Repo listesi alınıyor…'
        : job.reposDone < total
            ? 'Repolar: ${job.reposDone} / $total'
            : 'Katkı takvimi alınıyor…';
    return [
      LinearProgressIndicator(value: job.progress), // null: belirsiz (kayan) çubuk
      const SizedBox(height: 12),
      Text(step),
      const SizedBox(height: 4),
      Text(
        'Uygulamayı kapatabilirsin; senkron sunucuda devam eder.',
        style: _muted(context),
      ),
    ];
  }

  List<Widget> _done(BuildContext context, SyncJob job) {
    final unchanged = job.reposSkipped > 0 ? ' (${job.reposSkipped} değişmemiş)' : '';
    return [
      Row(children: [
        const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
        const SizedBox(width: 8),
        // Expanded: dar ekranda taşmak yerine alt satıra geçer.
        Expanded(child: Text('Son senkron: ${_formatLocal(job.finishedAt)}')),
      ]),
      const SizedBox(height: 12),
      _Stat('Repo', '${job.reposTotal ?? 0}$unchanged'),
      _Stat('Yeni commit', '${job.commitsInserted}'),
      _Stat('Katkı takvimi', '${job.calendarDays} gün'),
      _Stat('GitHub isteği', '${job.requestCount} · ${(job.totalDurationMs / 1000).toStringAsFixed(1)} sn'),
    ];
  }

  Widget _failed(BuildContext context, SyncJob job) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error, color: Theme.of(context).colorScheme.error, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text('Senkron başarısız: ${job.error ?? 'bilinmeyen hata'}')),
        ],
      );

  TextStyle? _muted(BuildContext context) => Theme.of(context)
      .textTheme
      .bodySmall
      ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      );
}

/// Backend UTC verir; kullanıcıya telefonun yerel saatiyle gösterilir.
String _formatLocal(DateTime? t) {
  if (t == null) return '-';
  final l = t.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(l.day)}.${two(l.month)}.${l.year} ${two(l.hour)}:${two(l.minute)}';
}
