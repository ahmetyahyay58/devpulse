import 'package:flutter/material.dart';

import '../api/health_api.dart';
import '../auth/session_store.dart';
import 'health_card.dart';

/// Giriş sonrası ana ekran. (Senkron ve Genel Bakış sonraki adımlarda gelecek.)
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.session,
    required this.healthApi,
    required this.onLogout,
  });

  final Session session;
  final HealthApi healthApi;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('DevPulse'),
        actions: [
          IconButton(
            tooltip: 'Çıkış yap',
            onPressed: onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Merhaba, ${session.login}', style: theme.textTheme.headlineSmall),
                if (session.isDemo) ...[
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(label: Text('Demo kullanıcı · sentetik veri')),
                  ),
                ],
                const SizedBox(height: 16),
                HealthCard(api: healthApi),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
