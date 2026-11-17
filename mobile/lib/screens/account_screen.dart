import 'package:flutter/material.dart';

import '../share/share_card.dart';
import '../ai/ai_controller.dart';
import '../ai/ai_widgets.dart';
import '../api/api_client.dart';
import '../auth/auth_service.dart';
import '../auth/session_store.dart';
import 'file_saver.dart';
import 'model_lab_screen.dart';
import 'privacy_screen.dart';

/// Profil: avatar ve hesap, rozet vitrini, Model Laboratuvarı, Verilerim, aydınlatma metni,
/// çıkış, veri indirme ve silme.
class AccountScreen extends StatelessWidget {
  const AccountScreen({
    super.key,
    required this.session,
    required this.auth,
    required this.onLogout,
    required this.onDeleted,
    this.saveFile = shareFile,
    this.achievements,
    this.bySource,
    this.ai,
  });

  final Session session;
  final AuthService auth;
  final VoidCallback onLogout;
  final ValueChanged<Map<String, dynamic>> onDeleted; // silme sonucu (satır sayıları)
  final FileSaver saveFile; // testlerde sahtesi verilir
  final Map<String, dynamic>? achievements; // rozet vitrini için (yüklenmediyse null)
  final Map<String, int>? bySource; // kullanıcının commit'lerinde kural / model / belirsiz
  final AiController? ai; // yapay zekâ onayı (ana ekrandan; verilmezse kart yok)

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ProfileSections(
                api: auth.api,
                session: session,
                achievements: achievements,
                bySource: bySource,
                ai: ai,
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Aydınlatma metni'),
                subtitle: const Text('Hangi veriler, neden işleniyor'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => PrivacyScreen(api: auth.api)),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Çıkış yap'),
                subtitle: const Text('Veriler sunucuda kalır (90 gün etkinlik olmazsa silinir)'),
                onTap: () {
                  Navigator.of(context).pop();
                  onLogout();
                },
              ),
              const Divider(height: 32),
              Text('Verilerimi indir', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Sunucuda senin hakkında saklanan her şeyin bir kopyası (JSON dosyası).',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              _ExportButton(onExport: () => _export(context)),
              const Divider(height: 32),
              Text('Verilerimi sil', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Hesabın ve sunucudaki tüm verilerin kalıcı olarak silinir. Bu işlem geri alınamaz.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
                onPressed: () => _confirmAndDelete(context),
                icon: const Icon(Icons.delete_forever),
                label: const Text('Verilerimi sil'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _export(BuildContext context) async {
    try {
      final bytes = await auth.exportData();
      await saveFile(bytes, exportFileName(DateTime.now()));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('İndirilemedi: ${userMessage(e)}')));
    }
  }

  Future<void> _confirmAndDelete(BuildContext context) async {
    final revoke = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteDialog(showRevoke: !session.isDemo),
    );
    if (revoke == null || !context.mounted) return; // vazgeçildi

    try {
      final result = await auth.deleteAccount(revokeGitHub: revoke);
      if (!context.mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      onDeleted(result);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Silinemedi: ${userMessage(e)}')));
    }
  }
}

/// İndirme düğmesi: beklerken kilitlenir ve dönen bir gösterge gösterir (büyük hesapta
/// dosya birkaç saniye sürebilir; iki kez basılmasın).
class _ExportButton extends StatefulWidget {
  const _ExportButton({required this.onExport});
  final Future<void> Function() onExport;

  @override
  State<_ExportButton> createState() => _ExportButtonState();
}

class _ExportButtonState extends State<_ExportButton> {
  bool _busy = false;

  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      await widget.onExport();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: _busy ? null : _run,
        icon: _busy
            ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.download),
        label: Text(_busy ? 'Hazırlanıyor…' : 'Verilerimi indir'),
      );
}

/// Onay penceresi: neyin silineceğini açıkça listeler. true/false: GitHub izni kaldırılsın mı;
/// null: vazgeçildi.
class _DeleteDialog extends StatefulWidget {
  const _DeleteDialog({required this.showRevoke});
  final bool showRevoke;

  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  bool _revoke = true;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return AlertDialog(
      title: const Text('Veriler kalıcı olarak silinsin mi?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sunucudan silinecekler: hesabın, repoların, commit\'lerin, katkı takvimin '
              've senkron kayıtların. Telefondaki oturumun da silinir.'),
          if (widget.showRevoke)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _revoke,
              onChanged: (v) => setState(() => _revoke = v ?? false),
              title: const Text('GitHub\'daki DevPulse iznini de kaldır'),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Vazgeç')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: error),
          onPressed: () => Navigator.of(context).pop(widget.showRevoke && _revoke),
          child: const Text('Kalıcı olarak sil'),
        ),
      ],
    );
  }
}


/// /me bir kez yüklenir; avatar başlığı ve Verilerim kartı aynı cevabı kullanır.
class _ProfileSections extends StatefulWidget {
  const _ProfileSections({required this.api, required this.session, this.achievements, this.bySource, this.ai});
  final ApiClient api;
  final Session session;
  final Map<String, dynamic>? achievements;
  final Map<String, int>? bySource;
  final AiController? ai;

  @override
  State<_ProfileSections> createState() => _ProfileSectionsState();
}

class _ProfileSectionsState extends State<_ProfileSections> {
  late Future<Map<String, dynamic>> _me = widget.api.get('/me');

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _me,
      builder: (context, snap) {
        final me = snap.data;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _ProfileHeader(session: widget.session, avatarUrl: me?['avatar_url'] as String?),
          if (widget.achievements != null) ...[
            const SizedBox(height: 12),
            BadgeShowcase(achievements: widget.achievements!),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => ShareCardScreen(api: widget.api),
            )),
            icon: const Icon(Icons.ios_share),
            label: const Text('Paylaşılabilir kart'),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.science_outlined),
              title: const Text('Model Laboratuvarı'),
              subtitle: const Text('Commit türü sınıflandırmasının ölçülen doğruluğu'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => ModelLabScreen(api: widget.api, bySource: widget.bySource),
              )),
            ),
          ),
          if (widget.ai != null) ...[
            const SizedBox(height: 12),
            AiSettingsCard(ai: widget.ai!),
          ],
          const SizedBox(height: 12),
          if (snap.hasError)
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Expanded(child: Text(userMessage(snap.error!, fallback: 'Bilgi alınamadı.'))),
                  TextButton(
                    onPressed: () => setState(() => _me = widget.api.get('/me')),
                    child: const Text('Tekrar dene'),
                  ),
                ]),
              ),
            )
          else if (me == null)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else
            _DataCard(me: me),
        ]);
      },
    );
  }
}

/// Avatar (GitHub'dan doğrudan yüklenir; yüklenemezse baş harf), ad ve bağlantı etiketi.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.session, this.avatarUrl});
  final Session session;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = session.login.isEmpty ? '?' : session.login[0].toUpperCase();
    final fallback = CircleAvatar(radius: 32, child: Text(initial, style: theme.textTheme.headlineSmall));
    return Row(children: [
      if (avatarUrl == null)
        fallback
      else
        ClipOval(
          child: Image.network(
            avatarUrl!,
            width: 64,
            height: 64,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
          ),
        ),
      const SizedBox(width: 16),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(session.login, style: theme.textTheme.titleLarge, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Chip(
            visualDensity: VisualDensity.compact,
            avatar: Icon(session.isDemo ? Icons.science_outlined : Icons.link, size: 16),
            label: Text(session.isDemo ? 'Demo kullanıcı · sentetik veri' : "GitHub'a bağlı"),
          ),
        ]),
      ),
    ]);
  }
}

/// Rozet vitrini: açılan rozetler; hiç yoksa Başarımlar sekmesine yönlendirir.
class BadgeShowcase extends StatelessWidget {
  const BadgeShowcase({super.key, required this.achievements});
  final Map<String, dynamic> achievements;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badges = (achievements['badges'] as List).cast<Map<String, dynamic>>();
    final open = badges.where((b) => b['unlocked'] as bool).toList();
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Rozet vitrini · ${open.length} / ${badges.length}', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (open.isEmpty)
            Text('Henüz açılan rozet yok. Başarımlar sekmesinde ilerlemeni görebilirsin.', style: muted)
          else
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final b in open)
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(Icons.emoji_events_outlined, size: 16, color: theme.colorScheme.primary),
                  label: Text(b['name'] as String),
                ),
            ]),
        ]),
      ),
    );
  }
}

/// "Verilerim": sunucuda ne kadar veri saklandığı ve 90 gün kuralıyla ne zaman silineceği.
class _DataCard extends StatelessWidget {
  const _DataCard({required this.me});
  final Map<String, dynamic> me;

  static String _date(String iso) {
    final d = DateTime.parse(iso).toLocal();
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final counts = (me['counts'] as Map).cast<String, int>();
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Expanded(child: Text(label)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
        );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Verilerim', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          row('Repo', '${counts['repos']}'),
          row('Commit', '${counts['commits']}'),
          row('Katkı takvimi', '${counts['contribution_days']} gün'),
          row('Senkron kaydı', '${counts['sync_jobs']}'),
          const SizedBox(height: 8),
          row('Son etkinlik', _date(me['last_active_at'] as String)),
          row('Otomatik silinme', _date(me['delete_after'] as String)),
          const SizedBox(height: 8),
          Text(
            '${me['retention_days']} gün boyunca giriş yapmaz ve senkron başlatmazsan hesabın ve '
            'bütün verilerin bu tarihte otomatik olarak, kalıcı biçimde silinir. Her giriş ya da '
            "senkron tarihi ileri alır. E-posta, gerçek ad, kodun ve GitHub token'ın saklanmaz.",
            style: muted,
          ),
        ]),
      ),
    );
  }
}
