import 'package:flutter/material.dart';

import '../ui/toast.dart';
import 'cv_controller.dart';
import 'cv_edits.dart';

/// "Maddeleri düzenle": GitHub taslağını çıktıdan önce düzenleme (docs/cv.md). Kurallar cv_edits.dart'ta:
/// sayılar kilitli (yalnız gizlenir), metin 200 karakter, proje başına 2 ek madde, en çok 4 proje.
/// Değişiklikler "Kaydet" ile yalnızca bu cihaza yazılır.
class CvEditScreen extends StatefulWidget {
  const CvEditScreen({super.key, required this.controller});
  final CvController controller;

  @override
  State<CvEditScreen> createState() => _CvEditScreenState();
}

class _CvEditScreenState extends State<CvEditScreen> {
  late CvEdits e = widget.controller.edits.copy(); // düzenlenen kopya
  bool _dirty = false;
  bool _saving = false;
  int _rev = 0; // "taslağa dön" sonrası metin alanlarını yeniden kurmak için
  final _newLanguage = TextEditingController();
  final _newTool = TextEditingController();

  CvDraft get d => widget.controller.draft!;
  String get lang => d.lang;

  @override
  void dispose() {
    _newLanguage.dispose();
    _newTool.dispose();
    super.dispose();
  }

  void _change(VoidCallback f) => setState(() {
        f();
        _dirty = true;
      });

  Future<bool> _commit() async {
    setState(() => _saving = true);
    try {
      await widget.controller.saveEdits(e.copy());
      if (!mounted) return true;
      setState(() => _dirty = false);
      showToast(context, 'Düzenlemeler kaydedildi.');
      return true;
    } catch (_) {
      if (mounted) showToast(context, 'Kaydedilemedi. Lütfen tekrar dene.', success: false);
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmLeave() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kaydedilmemiş değişiklikler var'),
        content: const Text('Çıkmadan önce kaydetmek ister misin?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'stay'), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'discard'), child: const Text('Kaydetmeden çık')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('Kaydet ve çık')),
        ],
      ),
    );
    if (!mounted || choice == null || choice == 'stay') return;
    if (choice == 'save' && !await _commit()) return;
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _resetAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Taslağa dönülsün mü?'),
        content: const Text('Bütün düzenlemeler (metinler, gizlenenler, ek maddeler, proje seçimi, beceriler) '
            'silinir ve GitHub taslağı geri gelir. "Kaydet"e basana kadar cihazdaki kayıt değişmez.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Taslağa dön')),
        ],
      ),
    );
    if (ok == true) {
      _change(() {
        e = CvEdits();
        _rev++;
      });
    }
  }

  // --- Projeler ---------------------------------------------------------------------------

  Widget _projectPicker(ThemeData theme) {
    final selected = e.selectedIds(d);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _heading(theme, 'Projeler', '${selected.length}/$maxProjects seçili'),
      Text('Kendi herkese açık repolarından en çok $maxProjects tanesini seç. GitHub\'da olmayan işleri '
          'Bilgilerim\'deki "Deneyim"e yazabilirsin.', style: theme.textTheme.bodySmall),
      for (final p in d.projects)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: selected.contains(p.id),
          title: Text(p.name),
          subtitle: p.tech.isEmpty ? null : Text(p.tech.join(', '), maxLines: 1, overflow: TextOverflow.ellipsis),
          // Dördü doluysa seçilmemiş olanlar pasif: önce birini kaldırmak gerekir.
          onChanged: !selected.contains(p.id) && selected.length >= maxProjects
              ? null
              : (on) => _change(() {
                    final next = [...selected];
                    on == true ? next.add(p.id) : next.remove(p.id);
                    // Taslak sırası korunur (sağlık puanına göre).
                    e.selected = [for (final q in d.projects) if (next.contains(q.id)) q.id];
                  }),
        ),
    ]);
  }

  static const _kindLabels = {'desc': 'Açıklama', 'stack': 'Teknoloji', 'impact': 'Etki'};

  Widget _hideButton(String id) {
    final hidden = e.hidden.contains(id);
    return IconButton(
      tooltip: hidden ? 'Göster' : 'Gizle',
      icon: Icon(hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined),
      onPressed: () => _change(() => hidden ? e.hidden.remove(id) : e.hidden.add(id)),
    );
  }

  Widget _itemEditor(ThemeData theme, CvItem i) {
    final hidden = e.hidden.contains(i.id);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    if (!isEditable(i)) {
      // Kilitli: veriden gelen sayı. Yalnız gizlenebilir.
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Tooltip(message: 'Veriden gelen sayı; düzenlenemez', child: Icon(Icons.lock_outline, size: 18, color: muted?.color)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(i.text,
                style: hidden ? TextStyle(decoration: TextDecoration.lineThrough, color: muted?.color) : null),
          ),
          _hideButton(i.id),
        ]),
      );
    }
    final key = CvEdits.key(lang, i.id);
    final edited = e.texts.containsKey(key);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: TextFormField(
            key: ValueKey('$key|$_rev'),
            initialValue: e.texts[key] ?? i.text,
            enabled: !hidden,
            maxLength: maxItemChars,
            minLines: 1,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: '${_kindLabels[i.kind] ?? 'Madde'}${edited ? ' · senin düzenlemen' : ''}',
              helperText: i.placeholder && !edited ? 'Rakamı sen yaz ya da gizle; "[…]" haliyle PDF\'e basılmaz.' : null,
              helperMaxLines: 2,
              border: const OutlineInputBorder(),
              suffixIcon: edited
                  ? IconButton(
                      tooltip: 'Taslağa dön',
                      icon: const Icon(Icons.restore),
                      onPressed: () => _change(() {
                        e.texts.remove(key);
                        _rev++;
                      }),
                    )
                  : null,
            ),
            onChanged: (v) => _change(() => v == i.text ? e.texts.remove(key) : e.texts[key] = v),
          ),
        ),
        _hideButton(i.id),
      ]),
    );
  }

  Widget _projectCard(ThemeData theme, CvProject p) {
    final extrasKey = CvEdits.key(lang, p.id);
    final extras = e.extras[extrasKey] ?? <String>[];
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(p.name, style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          for (final i in p.items) _itemEditor(theme, i),
          for (final (n, text) in extras.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: TextFormField(
                    key: ValueKey('$extrasKey|$n|$_rev|${extras.length}'),
                    initialValue: text,
                    maxLength: maxItemChars,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Ek madde · senin eklemen', border: OutlineInputBorder()),
                    onChanged: (v) => _change(() => extras[n] = v),
                  ),
                ),
                IconButton(
                  tooltip: 'Ek maddeyi sil',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _change(() {
                    extras.removeAt(n);
                    _rev++;
                  }),
                ),
              ]),
            ),
          if (extras.length < maxExtraPerProject)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _change(() => e.extras[extrasKey] = [...extras, '']),
                icon: const Icon(Icons.add),
                label: Text('Madde ekle (${extras.length}/$maxExtraPerProject)'),
              ),
            ),
        ]),
      ),
    );
  }

  // --- Beceriler ----------------------------------------------------------------------------

  Widget _skills(ThemeData theme) {
    Widget chips(List<String> fromData, List<String> added) => Wrap(spacing: 6, runSpacing: 4, children: [
          for (final s in fromData)
            if (e.removedSkills.contains(s))
              ActionChip(
                avatar: const Icon(Icons.undo, size: 16),
                label: Text(s, style: const TextStyle(decoration: TextDecoration.lineThrough)),
                tooltip: 'Geri al',
                onPressed: () => _change(() => e.removedSkills.remove(s)),
              )
            else
              InputChip(label: Text(s), onDeleted: () => _change(() => e.removedSkills.add(s)), deleteButtonTooltipMessage: 'Çıkar'),
          for (final s in added)
            InputChip(
              avatar: const Icon(Icons.person_outline, size: 16),
              label: Text(s),
              tooltip: 'Senin eklemen',
              onDeleted: () => _change(() => added.remove(s)),
              deleteButtonTooltipMessage: 'Sil',
            ),
        ]);
    Widget adder(TextEditingController c, String hint, List<String> into) => Row(children: [
          Expanded(
            child: TextField(
              controller: c,
              decoration: InputDecoration(hintText: hint, isDense: true, border: const OutlineInputBorder()),
              onSubmitted: (_) => _add(c, into),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: () => _add(c, into), child: const Text('Ekle')),
        ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _heading(theme, 'Beceriler', null),
      Text('Veriden gelenleri çıkarabilirsin (ör. Flutter\'ın ürettiği C++/CMake). Eklediklerin "senin eklemen" '
          'diye işaretlenir.', style: theme.textTheme.bodySmall),
      const SizedBox(height: 8),
      Text('Programlama dilleri', style: theme.textTheme.labelLarge),
      const SizedBox(height: 4),
      chips(d.languages, e.addedLanguages),
      const SizedBox(height: 6),
      adder(_newLanguage, 'Dil ekle (ör. SQL)', e.addedLanguages),
      const SizedBox(height: 12),
      Text('Araçlar', style: theme.textTheme.labelLarge),
      const SizedBox(height: 4),
      chips(d.tools, e.addedTools),
      const SizedBox(height: 6),
      adder(_newTool, 'Araç ekle (ör. Figma)', e.addedTools),
    ]);
  }

  void _add(TextEditingController c, List<String> into) {
    final v = c.text.trim();
    if (v.isEmpty || into.contains(v)) return;
    _change(() => into.add(v));
    c.clear();
  }

  Widget _heading(ThemeData theme, String title, String? trailing) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 4),
        child: Row(children: [
          Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
          if (trailing != null) Text(trailing, style: theme.textTheme.bodySmall),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final saveButton = FilledButton.icon(
      onPressed: _dirty && !_saving ? _commit : null,
      icon: const Icon(Icons.save_outlined),
      label: Text(_dirty ? 'Kaydet' : 'Kaydedildi'),
    );
    final byId = {for (final p in d.projects) p.id: p};
    final locked = [if (d.summary != null) d.summary!, ...d.activity];
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Maddeleri düzenle'),
          actions: [Padding(padding: const EdgeInsets.only(right: 12), child: saveButton)],
        ),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(
                  '${lang == 'en' ? 'İngilizce' : 'Türkçe'} CV\'yi düzenliyorsun; metin düzenlemeleri dile özeldir. '
                  'Kilitli (🔒) maddeler GitHub verisinden gelen sayılardır, yalnız gizlenebilir. Madde başına en çok '
                  '$maxItemChars karakter. Düzenlemeler yalnızca bu cihazda saklanır.',
                  style: theme.textTheme.bodySmall,
                ),
                _projectPicker(theme),
                for (final id in e.selectedIds(d)) _projectCard(theme, byId[id]!),
                _skills(theme),
                if (locked.isNotEmpty) ...[
                  _heading(theme, 'Özet ve etkinlik', null),
                  for (final i in locked) _itemEditor(theme, i),
                ],
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: e.isEmpty ? null : _resetAll,
                      icon: const Icon(Icons.restore),
                      label: const Text('Taslağa dön (tümü)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: saveButton),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
