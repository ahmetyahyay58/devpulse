import 'dart:convert';

import 'package:flutter/material.dart';
import '../ui/motion.dart';

import 'cv_check.dart';
import 'cv_controller.dart';
import 'cv_edit_screen.dart';
import 'cv_pdf.dart';
import 'profile_screen.dart';

/// PDF'in gerçek sayfa sayısı. Testlerde sahtesi verilir (PDF üretimi gerçek zamanlı iştir).
typedef PageCounter = Future<int> Function(CvController c);

Future<int> countPdfPages(CvController c) async =>
    (await buildCvPdf(draft: c.effective!, format: c.format, profile: c.profile)).pages;

/// Biçim kontrolü ekranı (docs/cv.md): seçili format ve dildeki CV için eksikler ve öneriler.
/// Kullanıcı "Düzelt" ile ilgili ekrana gidip dönünce liste yeniden hesaplanır.
class CvCheckScreen extends StatefulWidget {
  const CvCheckScreen({super.key, required this.controller, this.countPages = countPdfPages});
  final CvController controller;
  final PageCounter countPages;

  @override
  State<CvCheckScreen> createState() => _CvCheckScreenState();
}

class _CvCheckScreenState extends State<CvCheckScreen> {
  String? _key; // sayfa sayısının ait olduğu CV hali
  int? _pages;
  String? _pagesKey;

  /// CV'nin o anki hali (format, dil, bilgiler, düzenlemeler): değişince sayfa yeniden sayılır.
  String _stateKey(CvController c) => jsonEncode([c.format.id, c.lang, c.profile.toJson(), c.edits.toJson()]);

  Future<void> _count(String key) async {
    try {
      final n = await widget.countPages(widget.controller);
      if (mounted && _key == key) {
        setState(() {
          _pages = n;
          _pagesKey = key;
        });
      }
    } catch (_) {
      // Sayılamadıysa sayfa kuralı atlanır; diğer kurallar yine gösterilir.
    }
  }

  void _open(CheckTarget t) {
    final c = widget.controller;
    final Widget screen = switch (t) {
      CheckTarget.profile => ProfileScreen(controller: c),
      CheckTarget.edits => CvEditScreen(controller: c),
      CheckTarget.none => const SizedBox.shrink(),
    };
    if (t != CheckTarget.none) Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Biçim kontrolü')),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final c = widget.controller;
          final draft = c.effective;
          if (draft == null) return const PageLoader();
          final key = _stateKey(c);
          if (key != _key) {
            _key = key;
            _count(key);
          }
          final pages = _pagesKey == key ? _pages : null;
          final checks = checkCv(draft: draft, profile: c.profile, format: c.format, pages: pages);
          final missing = checks.where((x) => x.level == CheckLevel.missing).length;
          final suggestions = checks.length - missing;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${c.format.name} · ${c.lang == 'en' ? 'English' : 'Türkçe'}',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        checks.isEmpty ? 'Kurallara göre eksik ya da öneri yok.' : '$missing eksik, $suggestions öneri',
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pages == null
                            ? 'PDF sayfa sayısı hesaplanıyor…'
                            : 'PDF: $pages sayfa (bu format için önerilen en çok ${c.format.maxPages}).',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, size: 18, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Bu kontrol düzen ve eksiklikler içindir; işe alım yazılımlarından (ATS) geçeceğini '
                              'garanti etmez. Kurallar sabittir ve docs/cv.md\'de yazılıdır.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Maddeler tek tek gelir (puan yok, yalnız liste).
                      for (final (i, x) in checks.indexed)
                        Rise(
                          index: i < 8 ? i : 8,
                          child: _CheckTile(check: x, onFix: () => _open(x.target)),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CheckTile extends StatelessWidget {
  const _CheckTile({required this.check, required this.onFix});
  final CvCheck check;
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isMissing = check.level == CheckLevel.missing;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        // Düzey hem simge hem yazıyla söylenir (yalnız renge bağlı değil).
        leading: Icon(
          isMissing ? Icons.error_outline : Icons.lightbulb_outline,
          color: isMissing ? scheme.error : scheme.primary,
        ),
        title: Text(check.message),
        subtitle: Text(isMissing ? 'Eksik' : 'Öneri'),
        trailing: check.target == CheckTarget.none ? null : TextButton(onPressed: onFix, child: const Text('Düzelt')),
      ),
    );
  }
}
