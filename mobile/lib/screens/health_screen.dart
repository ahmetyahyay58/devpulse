import 'package:flutter/material.dart';

import '../api/health_api.dart';

/// Backend'in ayakta olup olmadığını gösteren ilk ekran.
class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key, required this.api});

  final HealthApi api;

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  late Future<HealthResult> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.check(); // ekran açılınca bir kez sor
  }

  void _refresh() {
    // setState: durumu değiştirir ve Flutter'a ekranı yeniden çizmesini söyler.
    setState(() => _future = widget.api.check());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('DevPulse')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
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
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 24),
                    FutureBuilder<HealthResult>(
                      future: _future,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        if (snapshot.hasError) {
                          return _ErrorView(error: snapshot.error!);
                        }
                        return _ResultView(result: snapshot.data!);
                      },
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Yenile'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
