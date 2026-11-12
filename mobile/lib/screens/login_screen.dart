import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../auth/session_store.dart';
import 'privacy_screen.dart';

/// Giriş ekranı: GitHub ile giriş ya da demo kullanıcıyla deneme.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.auth, required this.onLoggedIn});

  final AuthService auth;
  final ValueChanged<Session> onLoggedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<Session> Function() login) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await login();
      if (mounted) widget.onLoggedIn(session);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.insights, size: 56, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text('DevPulse', textAlign: TextAlign.center, style: theme.textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  'GitHub etkinliğinden çalışma alışkanlıklarını ve projelerinin eksiklerini gösterir.',
                  textAlign: TextAlign.center,
                  style: muted,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _run(widget.auth.loginWithGitHub),
                  icon: const Icon(Icons.login),
                  label: const Text('GitHub ile giriş yap'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _busy ? null : () => _run(widget.auth.loginDemo),
                  child: const Text('Demo ile dene'),
                ),
                if (_busy) ...[
                  const SizedBox(height: 24),
                  const Center(child: CircularProgressIndicator()),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 24),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                const SizedBox(height: 32),
                Text(
                  'Yalnızca herkese açık GitHub verin okunur (read:user). '
                  'E-posta adresin ve kodun saklanmaz.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                // Kullanıcı metni giriş yapmadan önce okuyabilmeli.
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => PrivacyScreen(api: widget.auth.api)),
                  ),
                  child: const Text('Aydınlatma metni'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
