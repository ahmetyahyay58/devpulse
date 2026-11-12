import 'package:flutter/material.dart';

import '../api/health_api.dart';

/// Backend'in ayakta olup olmadığını gösteren kart.
class HealthCard extends StatefulWidget {
  const HealthCard({super.key, required this.api});

  final HealthApi api;

  @override
  State<HealthCard> createState() => _HealthCardState();
}

class _HealthCardState extends State<HealthCard> {
  // Durumu kendimiz tutuyoruz: yenilenirken eski sonuç ekranda kalabilsin.
  HealthResult? _result;
  Object? _error;
  bool _loading = false;
  DateTime? _checkedAt;

  @override
  void initState() {
    super.initState();
    _refresh(); // ekran açılınca bir kez sor
  }

  Future<void> _refresh() async {
    // setState: durumu değiştirir ve Flutter'a ekranı yeniden çizmesini söyler.
    setState(() => _loading = true);
    try {
      final result = await widget.api.check();
      if (!mounted) return; // bu arada ekran kapandıysa dokunma
      setState(() {
        _result = result;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _checkedAt = DateTime.now();
        });
      }
    }
  }

  Widget _body() {
    if (_error != null) return _ErrorView(error: _error!);
    if (_result != null) return _ResultView(result: _result!);
    // İlk açılış: henüz hiç sonuç yok.
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Sunucu durumu', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              widget.api.baseUrl,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            _body(),
            if (_checkedAt != null) ...[
              const SizedBox(height: 12),
              Text(
                'Son kontrol: ${_formatTime(_checkedAt!)}',
                textAlign: TextAlign.center,
                style:
                    theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              // null: buton devre dışı (sorgu sürerken tekrar basılamaz)
              onPressed: _loading ? null : _refresh,
              icon: _loading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: Text(_loading ? 'Kontrol ediliyor…' : 'Yenile'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTime(DateTime t) =>
    [t.hour, t.minute, t.second].map((n) => n.toString().padLeft(2, '0')).join(':');

class _ResultView extends StatelessWidget {
  const _ResultView({required this.result});

  final HealthResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _StatusRow(label: 'API', value: result.status, ok: result.status == 'ok'),
        _StatusRow(
          label: 'Veritabanı',
          value: result.database,
          ok: result.database == 'ok',
        ),
        _StatusRow(label: 'Yanıt süresi', value: '${result.elapsedMs} ms'),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value, this.ok});

  final String label;
  final String value;
  final bool? ok; // null: iyi/kötü durumu olmayan bilgi satırı

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            ok == null
                ? Icons.timer_outlined
                : ok!
                    ? Icons.check_circle
                    : Icons.error,
            size: 20,
            color: ok == null
                ? colors.onSurfaceVariant
                : ok!
                    ? Colors.greenAccent
                    : colors.error,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(Icons.cloud_off, size: 40, color: colors.error),
        const SizedBox(height: 8),
        const Text('Sunucuya ulaşılamadı', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          '$error',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}
