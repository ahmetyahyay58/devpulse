import 'package:flutter/material.dart';
import '../ui/motion.dart';

import '../api/api_client.dart';

/// Metrik kataloğu: her metriğin tanımı, birimi, yorumu ve hangi koşulda güvenilir olduğu.
/// Metinler backend'den gelir (kaynağı docs/metrikler.md).
class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  late final Future<List<Map<String, dynamic>>> _entries = _load();

  Future<List<Map<String, dynamic>>> _load() async =>
      ((await widget.api.get('/metrics/catalog'))['entries'] as List).cast<Map<String, dynamic>>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Metrik kataloğu')),
      body: FutureBuilder(
        future: _entries,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text(userMessage(snap.error!, fallback: 'Katalog yüklenemedi.')));
          }
          if (!snap.hasData) return const PageLoader();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(children: [for (final e in snap.data!) _EntryCard(entry: e)]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});
  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    Widget row(String label, String key) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: muted),
            Text(entry[key] as String),
          ]),
        );
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(entry['name'] as String, style: theme.textTheme.titleMedium),
          row('Tanım', 'definition'),
          row('Birim', 'unit'),
          row('Nasıl yorumlanır', 'interpretation'),
          row('Ne zaman güvenilir', 'reliable_when'),
        ]),
      ),
    );
  }
}
