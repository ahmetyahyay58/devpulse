import 'package:flutter/material.dart';

import 'cv_controller.dart';
import 'cv_profile.dart';

/// "Bilgilerim": CV'nin GitHub'da olmayan bölümleri. Her değişiklik hemen bu cihaza kaydedilir;
/// sunucuya gitmez (docs/cv.md).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.controller});
  final CvController controller;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final CvProfile p = CvProfile.fromJson(widget.controller.profile.toJson()); // düzenlenen kopya

  void _save() {
    widget.controller.saveProfile(CvProfile.fromJson(p.toJson()));
    setState(() {});
  }

  Widget _field(String label, String value, ValueChanged<String> onChanged, {TextInputType? type, String? hint}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          initialValue: value,
          keyboardType: type,
          decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder()),
          onChanged: (v) {
            onChanged(v);
            _save();
          },
        ),
      );

  Widget _heading(String title, String action, VoidCallback onAdd) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Row(children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          TextButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: Text(action)),
        ]),
      );

  Widget _entry(String title, String subtitle, VoidCallback onEdit, VoidCallback onDelete) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          title: Text(title.isEmpty ? '(adsız)' : title),
          subtitle: subtitle.isEmpty ? null : Text(subtitle),
          onTap: onEdit,
          trailing: IconButton(tooltip: 'Sil', icon: const Icon(Icons.delete_outline), onPressed: onDelete),
        ),
      );

  // --- Eğitim ve deneyim düzenleme penceresi -------------------------------------------------

  /// Alanları olan küçük bir form penceresi; Kaydet'te yeni değerleri, Vazgeç'te null döner.
  /// Alan: (etiket, örnek, mevcut değer, çok satırlı mı). Örnek etikete değil ipucuna yazılır, kesilmez.
  Future<List<String>?> _edit(String title, List<(String, String, String, bool)> fields) {
    final controllers = [for (final f in fields) TextEditingController(text: f.$3)];
    return showDialog<List<String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 420, // dar varsayılan genişlikte etiketler kesiliyordu
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final (i, f) in fields.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: controllers[i],
                    minLines: f.$4 ? 3 : 1,
                    maxLines: f.$4 ? 6 : 1,
                    decoration: InputDecoration(
                      labelText: f.$1,
                      hintText: f.$2.isEmpty ? null : f.$2,
                      floatingLabelBehavior: FloatingLabelBehavior.always, // ipucu boşken de görünsün
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, [for (final c in controllers) c.text.trim()]),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Future<void> _editEducation([Education? e]) async {
    final v = await _edit(e == null ? 'Eğitim ekle' : 'Eğitimi düzenle', [
      ('Okul', 'ör. Harran Üniversitesi', e?.school ?? '', false),
      ('Bölüm / derece', 'ör. Bilgisayar Mühendisliği, Lisans', e?.degree ?? '', false),
      ('Tarih', 'ör. Eyl 2022 – Haz 2026', e?.dates ?? '', false),
      ('Şehir', 'ör. Şanlıurfa', e?.location ?? '', false),
      ('Not (isteğe bağlı)', 'ör. GANO 3,2/4', e?.note ?? '', false),
    ]);
    if (v == null) return;
    final item = e ?? Education();
    item
      ..school = v[0]
      ..degree = v[1]
      ..dates = v[2]
      ..location = v[3]
      ..note = v[4];
    if (e == null) p.education.add(item);
    _save();
  }

  Future<void> _editExperience([Experience? e]) async {
    final v = await _edit(e == null ? 'Deneyim ekle' : 'Deneyimi düzenle', [
      ('Pozisyon', 'ör. Stajyer Yazılım Geliştirici', e?.role ?? '', false),
      ('Kurum', 'ör. Örnek Teknoloji A.Ş.', e?.org ?? '', false),
      ('Tarih', 'ör. Tem 2025 – Ağu 2025', e?.dates ?? '', false),
      ('Şehir', '', e?.location ?? '', false),
      ('Maddeler', 'Her satıra bir cümle; ne yaptığını ve sonucunu yaz.', e?.bullets.join('\n') ?? '', true),
    ]);
    if (v == null) return;
    final item = e ?? Experience();
    item
      ..role = v[0]
      ..org = v[1]
      ..dates = v[2]
      ..location = v[3]
      ..bullets = v[4].split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (e == null) p.experience.add(item);
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Bilgilerim')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                const Icon(Icons.phone_android, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Bu bilgiler yalnızca bu cihazda saklanır, sunucuya gönderilmez. Çıkışta ve '
                      '"Verilerimi sil"de silinir.', style: theme.textTheme.bodySmall),
                ),
              ]),
              const SizedBox(height: 16),
              Text('Kişisel bilgiler', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              _field('Ad soyad', p.fullName, (v) => p.fullName = v),
              _field('E-posta', p.email, (v) => p.email = v, type: TextInputType.emailAddress),
              _field('Telefon', p.phone, (v) => p.phone = v, type: TextInputType.phone),
              _field('Şehir', p.location, (v) => p.location = v, hint: 'ör. Şanlıurfa'),
              _field('LinkedIn', p.linkedin, (v) => p.linkedin = v, hint: 'ör. linkedin.com/in/adin'),
              _heading('Eğitim', 'Ekle', _editEducation),
              for (final e in p.education)
                _entry(e.school, [e.degree, e.dates].where((s) => s.isNotEmpty).join(' · '), () => _editEducation(e),
                    () {
                  p.education.remove(e);
                  _save();
                }),
              _heading('Deneyim', 'Ekle', _editExperience),
              for (final e in p.experience)
                _entry(e.role, [e.org, e.dates].where((s) => s.isNotEmpty).join(' · '), () => _editExperience(e), () {
                  p.experience.remove(e);
                  _save();
                }),
              _heading('Diller', 'Ekle', () {
                p.languages.add(SpokenLanguage());
                _save();
              }),
              for (final l in p.languages)
                Padding(
                  key: ValueKey(l.id),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: l.name,
                        decoration: const InputDecoration(labelText: 'Dil', border: OutlineInputBorder()),
                        onChanged: (v) {
                          l.name = v;
                          _save();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: l.level,
                      items: [for (final lv in languageLevels) DropdownMenuItem(value: lv, child: Text(lv))],
                      onChanged: (v) {
                        l.level = v ?? l.level;
                        _save();
                      },
                    ),
                    IconButton(
                      tooltip: 'Sil',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        p.languages.remove(l);
                        _save();
                      },
                    ),
                  ]),
                ),
              if (p.languages.isNotEmpty)
                Text('Düzey: Avrupa Ortak Başvuru Metni (CEFR), A1 başlangıç – C2 ileri.', style: theme.textTheme.bodySmall),
            ]),
          ),
        ),
      ]),
    );
  }
}
