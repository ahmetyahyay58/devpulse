import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../auth/auth_service.dart';
import '../auth/session_store.dart';
import 'privacy_screen.dart';

/// Hesap: kullanıcı bilgisi, aydınlatma metni, çıkış ve veri silme.
class AccountScreen extends StatelessWidget {
  const AccountScreen({
    super.key,
    required this.session,
    required this.auth,
    required this.onLogout,
    required this.onDeleted,
  });

  final Session session;
  final AuthService auth;
  final VoidCallback onLogout;
  final ValueChanged<Map<String, dynamic>> onDeleted; // silme sonucu (satır sayıları)

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
                subtitle: const Text('Veriler sunucuda kalır'),
                onTap: () {
                  Navigator.of(context).pop();
                  onLogout();
                },
              ),
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
