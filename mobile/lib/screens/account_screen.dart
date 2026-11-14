import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../auth/auth_service.dart';
import '../auth/session_store.dart';
import 'file_saver.dart';
import 'privacy_screen.dart';

/// Hesap: kullanıcı bilgisi, aydınlatma metni, çıkış, veri indirme ve silme.
class AccountScreen extends StatelessWidget {
  const AccountScreen({
    super.key,
    required this.session,
    required this.auth,
    required this.onLogout,
    required this.onDeleted,
    this.saveFile = shareFile,
  });

  final Session session;
  final AuthService auth;
  final VoidCallback onLogout;
  final ValueChanged<Map<String, dynamic>> onDeleted; // silme sonucu (satır sayıları)
  final FileSaver saveFile; // testlerde sahtesi verilir

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Hesap')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(session.login),
                subtitle: Text(session.isDemo ? 'Demo kullanıcı (sentetik veri)' : 'GitHub hesabı'),
              ),
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
              const SizedBox(height: 8),
              _MyDataCard(api: auth.api),
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


/// "Verilerim": sunucuda ne kadar veri saklandığı ve 90 gün kuralıyla ne zaman silineceği.
class _MyDataCard extends StatefulWidget {
  const _MyDataCard({required this.api});
  final ApiClient api;

  @override
  State<_MyDataCard> createState() => _MyDataCardState();
}

class _MyDataCardState extends State<_MyDataCard> {
  late Future<Map<String, dynamic>> _me = widget.api.get('/me');

  static String _date(String iso) {
    final d = DateTime.parse(iso).toLocal();
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder(
          future: _me,
          builder: (context, snap) {
            if (snap.hasError) {
              return Row(children: [
                Expanded(child: Text(userMessage(snap.error!, fallback: 'Bilgi alınamadı.'))),
                TextButton(
                  onPressed: () => setState(() => _me = widget.api.get('/me')),
                  child: const Text('Tekrar dene'),
                ),
              ]);
            }
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final me = snap.data!;
            final counts = (me['counts'] as Map).cast<String, int>();
            Widget row(String label, String value) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    Expanded(child: Text(label)),
                    Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ]),
                );
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
            ]);
          },
        ),
      ),
    );
  }
}
