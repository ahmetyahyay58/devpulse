import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../ai/ai_features.dart';
import '../screens/file_saver.dart';
import 'cv_controller.dart';
import 'cv_formats.dart';
import 'cv_page.dart';
import 'cv_pdf.dart';
import 'profile_screen.dart';

/// CV sekmesi: dil ve format seçimi, altında kağıt görünümünde CV (docs/cv.md). Taslak GitHub
/// verisinden gelir; eğitim, deneyim ve iletişim bilgileri "Bilgilerim"de, yalnız bu cihazda tutulur.
class CvView extends StatelessWidget {
  const CvView({super.key, required this.controller, this.saveFile = shareFile});

  final CvController controller;
  final FileSaver saveFile; // web: indirme, Android: paylaşım menüsü; testlerde sahtesi

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final theme = Theme.of(context);
        final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
        final d = controller.draft;
        final Widget page;
        if (d == null) {
          page = controller.error != null
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(controller.error!, style: TextStyle(color: theme.colorScheme.error)),
                  TextButton(onPressed: controller.load, child: const Text('Tekrar dene')),
                ])
              : const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
        } else if (d.projects.isEmpty && d.languages.isEmpty && d.activity.isEmpty) {
          page = const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('CV taslağı için henüz veri yok. Senkron bitince taslak burada oluşur.'),
            ),
          );
        } else {
          // Kağıt: ince gölgeli beyaz sayfa.
          page = Material(
            elevation: 2,
            child: CvPage(
              draft: d,
              format: controller.format,
              profile: controller.profile,
              showSources: controller.showSources,
            ),
          );
        }
        return ListView(padding: tabPadding, children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'tr', label: Text('Türkçe')),
                    ButtonSegment(value: 'en', label: Text('English')),
                  ],
                  selected: {controller.lang},
                  onSelectionChanged: (s) => controller.setLang(s.first),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: [for (final f in cvFormats) ButtonSegment(value: f.id, label: Text(f.name))],
                  selected: {controller.format.id},
                  onSelectionChanged: (s) => controller.setFormat(cvFormats.firstWhere((f) => f.id == s.first)),
                ),
                const SizedBox(height: 6),
                Text(controller.format.note[controller.lang] ?? '', style: muted),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => ProfileScreen(controller: controller)),
                  ),
                  icon: const Icon(Icons.badge_outlined),
                  // Boşken eğitim ve deneyim bölümleri sayfada görünmez: neyin eksik olduğunu söyle.
                  label: Text(controller.profile.isEmpty
                      ? 'Bilgilerim: ad, iletişim, eğitim, deneyim ekle'
                      : 'Bilgilerimi düzenle'),
                ),
                if (d != null && page is Material) ...[
                  const SizedBox(height: 8),
                  PdfButton(controller: controller, saveFile: saveFile),
                ],
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Maddelerin kaynağını göster'),
                  subtitle: const Text('Yalnız ekranda; CV dosyasına basılmaz.'),
                  value: controller.showSources,
                  onChanged: controller.setShowSources,
                ),
                page,
              ]),
            ),
          ),
        ]);
      },
    );
  }
}

/// "PDF olarak indir": seçili format ve dilde PDF üretir, kullanıcıya verir ve sonucu söyler.
class PdfButton extends StatefulWidget {
  const PdfButton({super.key, required this.controller, required this.saveFile});
  final CvController controller;
  final FileSaver saveFile;

  @override
  State<PdfButton> createState() => _PdfButtonState();
}

class _PdfButtonState extends State<PdfButton> {
  bool _busy = false;

  Future<void> _export() async {
    final c = widget.controller;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final result = await buildCvPdf(draft: c.draft!, format: c.format, profile: c.profile);
      final name = c.profile.fullName.trim().isEmpty ? c.draft!.login : c.profile.fullName;
      final file = cvFileName(name, c.format, c.lang);
      await widget.saveFile(result.bytes, file);
      final skipped = result.skippedPlaceholders == 0
          ? ''
          : ' Doldurulmamış ${result.skippedPlaceholders} etki cümlesi dosyaya eklenmedi.';
      messenger.showSnackBar(SnackBar(
        content: Text('${kIsWeb ? 'PDF indirildi' : 'PDF hazır'}: $file.$skipped'),
      ));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('PDF oluşturulamadı. Lütfen tekrar dene.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FilledButton.icon(
        onPressed: _busy ? null : _export,
        icon: _busy
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.picture_as_pdf_outlined),
        label: Text(_busy ? 'PDF hazırlanıyor…' : 'PDF olarak indir'),
      );
}
