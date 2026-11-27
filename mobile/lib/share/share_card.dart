import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import 'package:flutter/material.dart';
import '../ui/motion.dart';
import 'package:flutter/rendering.dart';

import '../api/api_client.dart';
import '../screens/file_saver.dart';
import '../ui/toast.dart';
import '../year/year_summary_screen.dart';

/// Paylaşılabilir kartın içeriği: yalnız kullanıcı adı ve toplu sayılar (docs/ozellikler.md).
/// Repo adı, commit mesajı, e-posta yok. Kart kullanıcı "Paylaş" diyene kadar telefondan çıkmaz.
class ShareCardData {
  const ShareCardData({
    required this.login,
    required this.year,
    required this.commits,
    required this.activeDays,
    required this.longestStreak,
    required this.topLanguage,
    required this.badges,
  });
  final String login;
  final int year;
  final int commits, activeDays, longestStreak;
  final String? topLanguage;
  final List<String> badges; // açılan rozetlerin adları

  factory ShareCardData.of(String login, YearSummary s, List<String> badges) => ShareCardData(
        login: login, year: s.year, commits: s.commits, activeDays: s.activeDays,
        longestStreak: s.longestStreak, topLanguage: s.topLanguage, badges: badges,
      );
}

/// Kartın kendisi: sabit boyut (360×450), kendi renkleriyle; tema değişse de aynı görünür.
class ShareCard extends StatelessWidget {
  const ShareCard({super.key, required this.data});
  final ShareCardData data;

  static const size = Size(360, 450);

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;
    Widget stat(String value, String label) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: const TextStyle(color: white, fontSize: 26, fontWeight: FontWeight.w700)),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        );
    return SizedBox.fromSize(
      size: size,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E3A8A), Color(0xFF7C3AED)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.insights, color: white, size: 20),
              SizedBox(width: 6),
              Text('DevPulse', style: TextStyle(color: white, fontSize: 16, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 20),
            Text(data.login, style: const TextStyle(color: white, fontSize: 24, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis),
            Text('${data.year} yılı', style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 24),
            Row(children: [stat('${data.commits}', 'commit'), stat('${data.activeDays}', 'aktif gün')]),
            const SizedBox(height: 16),
            Row(children: [
              stat('${data.longestStreak} gün', 'en uzun seri'),
              stat(data.topLanguage ?? '-', 'en çok dil'),
            ]),
            const Spacer(),
            Text(data.badges.isEmpty ? 'Henüz açılan rozet yok' : 'Rozetler',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final b in data.badges.take(6))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                  child: Text(b, style: const TextStyle(color: white, fontSize: 11)),
                ),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Bir widget'ın görüntüsünü PNG baytlarına çevirir (RepaintBoundary üzerinden).
Future<List<int>> captureBoundary(GlobalKey key, {double pixelRatio = 3}) async {
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: pixelRatio);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// Kart önizlemesi ve "Paylaş". [summary] verilmezse bu yılın özeti yüklenir.
class ShareCardScreen extends StatefulWidget {
  const ShareCardScreen({super.key, required this.api, this.summary, this.saveFile = shareFile});
  final ApiClient api;
  final YearSummary? summary;
  final FileSaver saveFile;

  @override
  State<ShareCardScreen> createState() => _ShareCardScreenState();
}

class _ShareCardScreenState extends State<ShareCardScreen> {
  final _key = GlobalKey();
  late final Future<ShareCardData> _data = _load();
  bool _busy = false;

  Future<ShareCardData> _load() async {
    final results = await Future.wait([
      widget.api.get('/me'),
      widget.api.get('/metrics/achievements'),
      if (widget.summary == null) widget.api.get('/metrics/year-summary'),
    ]);
    final badges = [
      for (final b in (results[1]['badges'] as List).cast<Map<String, dynamic>>())
        if (b['unlocked'] == true) b['name'] as String,
    ];
    final summary = widget.summary ?? YearSummary(results[2]);
    return ShareCardData.of(results[0]['login'] as String, summary, badges);
  }

  Future<void> _share(ShareCardData d) async {
    setState(() => _busy = true);
    try {
      final bytes = await captureBoundary(_key);
      final name = 'devpulse-kart-${d.year}.png';
      await widget.saveFile(Uint8List.fromList(bytes), name);
      if (mounted) showToast(context, kIsWeb ? 'Kart indirildi: $name' : 'Kart hazır: $name');
    } catch (_) {
      if (mounted) showToast(context, 'Kart oluşturulamadı. Lütfen tekrar dene.', success: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Paylaşım kartı')),
      body: FutureBuilder(
        future: _data,
        builder: (context, snap) {
          if (snap.hasError) return const Center(child: Text('Kart için veri yüklenemedi.'));
          final d = snap.data;
          if (d == null) return const PageLoader();
          return ListView(padding: const EdgeInsets.all(16), children: [
            Center(
              child: FittedBox(
                child: RepaintBoundary(key: _key, child: ShareCard(data: d)),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(
                    'Kartta yalnız kullanıcı adın ve toplu sayılar var; repo adı, commit mesajı ve e-posta yok. '
                    'Sen paylaşana kadar telefonundan çıkmaz.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _share(d),
                    icon: const Icon(Icons.share_outlined),
                    label: Text(kIsWeb ? 'Görsel olarak indir' : 'Paylaş'),
                  ),
                ]),
              ),
            ),
          ]);
        },
      ),
    );
  }
}
