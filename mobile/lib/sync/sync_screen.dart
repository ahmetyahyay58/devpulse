import 'dart:async';

import 'package:flutter/material.dart';

import '../api/sync_api.dart';
import '../overview/charts.dart';
import 'sync_controller.dart';
import 'sync_steps.dart';

/// Tam sayfa senkron ekranı: aşamalı liste, genel ilerleme ve commit'ler yazıldıkça
/// dolan takvim. "Atla" yalnızca bu sayfayı kapatır; senkron sunucuda sürer.
class SyncScreen extends StatefulWidget {
  const SyncScreen({
    super.key,
    required this.controller,
    this.stepDuration = const Duration(milliseconds: 800),
  });

  final SyncController controller;

  /// Her aşamanın ekranda en az kalacağı süre. Demo senkronu anında biter; bu olmasa ekran
  /// göz açıp kapayana kadar geçerdi. Gerçek senkron zaten daha yavaştır. Sıfır: bekleme yok.
  final Duration stepDuration;

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  static const _tickEvery = Duration(milliseconds: 200);
  int _shown = 0; // ekranda "bitti" görünen aşama sayısı
  int _ticksSinceAdvance = 0; // saat yerine tur sayılır: testlerin sahte saatiyle de çalışır
  Timer? _ticker;
  bool _closing = false; // bitti; ekran bir kez kapatılacak

  bool get _paced => widget.stepDuration > Duration.zero;

  @override
  void initState() {
    super.initState();
    // Bitmiş bir senkron için açıldıysa takvimi bir kez doldur (izleme döngüsü çalışmıyor).
    if (widget.controller.commitDays.isEmpty) widget.controller.refreshDays();
    if (_paced) _ticker = Timer.periodic(_tickEvery, (_) => _tick());
  }

  /// Gerçekte bitmiş ama ekranda henüz "bitti" görünmeyen aşama varsa, süre dolunca bir ilerlet.
  void _tick() {
    final job = widget.controller.job;
    if (job == null || widget.controller.starting) return;
    _ticksSinceAdvance++;
    final needed = (widget.stepDuration.inMilliseconds / _tickEvery.inMilliseconds).ceil();
    if (_shown < doneCount(stepsFor(job)) && _ticksSinceAdvance >= needed) {
      setState(() {
        _shown++;
        _ticksSinceAdvance = 0;
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Senkron bitti ve ekranda da %100 göründü: kısa bir an bekleyip (kullanıcı tamamlandığını
  /// görsün) kendiliğinden ana ekrana döner. Bir kez çalışır.
  void _closeSoon() {
    if (_closing) return;
    _closing = true;
    Future<void>.delayed(widget.stepDuration, () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _skip() {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(const SnackBar(
      content: Text('Senkron arka planda sürüyor; bitince Genel Bakış yenilenir.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Senkron')),
      body: ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          final job = c.job;
          if (job == null || c.starting) {
            return const Center(child: Text('Senkron başlatılıyor…'));
          }
          final v = _view(job);
          if (v.finished) _closeSoon();
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _Progress(v.progress, percentText(v.progress), finished: v.finished),
                  const SizedBox(height: 16),
                  for (final step in v.steps) _StepRow(step),
                  const SizedBox(height: 16),
                  _Calendar(days: v.days),
                  if (job.status == 'failed') ...[
                    const SizedBox(height: 16),
                    Text(job.error ?? 'Senkron başarısız oldu.',
                        style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  if (c.error != null) ...[
                    const SizedBox(height: 16),
                    Text(c.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                ],
              ),
            ),
          );
        },
      ),
      // Düğme ekranın altına sabit: küçük telefonda da kaydırmadan görünür.
      bottomNavigationBar: ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          final job = c.job;
          if (job == null || c.starting) return const SizedBox.shrink();
          final v = _view(job);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  // Düğme 420 piksele kadar tüm genişliği kaplasın.
                  child: SizedBox(
                    width: double.infinity,
                    child: _action(finished: v.finished, failed: v.failed),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Ekranda ne görüneceği: gerçek iş + gösterim hızı.
  _View _view(SyncJob job) {
    final real = stepsFor(job);
    final actual = doneCount(real);
    final shown = _paced ? _shown.clamp(0, actual) : actual;
    final caughtUp = shown >= actual;
    // Yetişene kadar ilerleme gösterilen aşama sayısından; yetişince gerçek değer.
    final progress = caughtUp ? job.progress : shown / real.length;
    final failed = job.status == 'failed' && caughtUp;
    return _View(
      steps: pacedSteps(real, shown),
      progress: job.status == 'done' && caughtUp ? 1.0 : progress,
      days: revealDays(widget.controller.commitDays, caughtUp && !job.isActive ? 1 : (progress ?? 0)),
      finished: job.status == 'done' && caughtUp,
      failed: failed,
    );
  }

  Widget _action({required bool finished, required bool failed}) {
    if (failed) {
      return FilledButton.icon(
        onPressed: () {
          setState(() {
            _shown = 0;
            _ticksSinceAdvance = 0;
          });
          widget.controller.start();
        },
        icon: const Icon(Icons.refresh),
        label: const Text('Tekrar dene'),
      );
    }
    // Bitince düğme yok: ekran kendiliğinden kapanır (_closeSoon).
    if (finished) return const SizedBox(height: 40);
    return OutlinedButton(onPressed: _skip, child: const Text('Atla'));
  }
}

class _View {
  const _View({
    required this.steps,
    required this.progress,
    required this.days,
    required this.finished,
    required this.failed,
  });
  final List<SyncStep> steps;
  final double? progress;
  final List<(DateTime, int)> days;
  final bool finished;
  final bool failed;
}

class _Progress extends StatelessWidget {
  const _Progress(this.value, this.percent, {required this.finished});
  final double? value;
  final String? percent;
  final bool finished;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget bar(double? v) =>
        LinearProgressIndicator(value: v, minHeight: 6, borderRadius: BorderRadius.circular(3));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
          child: Text(finished ? 'Senkron tamamlandı' : 'GitHub verin çekiliyor',
              style: theme.textTheme.titleMedium),
        ),
        if (percent != null) Text(percent!, style: theme.textTheme.titleMedium),
      ]),
      const SizedBox(height: 8),
      // value null: repo sayısı henüz bilinmiyor, çubuk "belirsiz" (kayan) çizilir.
      // Değer varsa çubuk yeni değere sıçramaz, kısa bir animasyonla kayar.
      if (value == null)
        bar(null)
      else
        TweenAnimationBuilder<double>(
          tween: Tween(end: value),
          duration: const Duration(milliseconds: 400),
          builder: (_, v, _) => bar(v),
        ),
      if (!finished) ...[
        const SizedBox(height: 6),
        Text('Uygulamayı kapatabilirsin; senkron sunucuda devam eder.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    ]);
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow(this.step);
  final SyncStep step;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = switch (step.state) {
      SyncStepState.active => const SizedBox.square(
          dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
      SyncStepState.done => const Icon(Icons.check_circle, color: Colors.greenAccent, size: 22),
      SyncStepState.failed => Icon(Icons.error, color: scheme.error, size: 22),
      SyncStepState.waiting => Icon(Icons.radio_button_unchecked, color: scheme.outline, size: 22),
    };
    final waiting = step.state == SyncStepState.waiting;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 24, height: 24, child: Center(child: icon)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(step.title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: waiting ? scheme.onSurfaceVariant : null,
                )),
            if (step.detail != null)
              Text(step.detail!,
                  style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
          ]),
        ),
      ]),
    );
  }
}

class _Calendar extends StatelessWidget {
  const _Calendar({required this.days});
  final List<(DateTime, int)> days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = days.fold<int>(0, (a, d) => a + d.$2);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Son 30 hafta', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            days.isEmpty ? 'Commit\'ler işlendikçe burası dolacak.' : '$total commit işlendi',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (days.isNotEmpty) ContributionHeatmap(days: days, unit: 'commit'),
        ]),
      ),
    );
  }
}
