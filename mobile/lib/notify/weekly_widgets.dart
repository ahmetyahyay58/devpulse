import 'package:flutter/material.dart';

import '../ui/theme_settings.dart';
import '../ui/toast.dart';
import 'weekly_notifications.dart';

/// Genel Bakış'taki "Bu hafta" kartı (`GET /metrics/weekly`). Yarım hafta, geçen haftanın aynı
/// günleriyle kıyaslanır; yüzde yok.
class WeeklyCard extends StatelessWidget {
  const WeeklyCard({super.key, required this.weekly});
  final Map<String, dynamic> weekly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final now = (weekly['this_week'] as Map).cast<String, dynamic>();
    final last = (weekly['last_week'] as Map).cast<String, dynamic>();
    Widget cell(String value, String label) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: theme.textTheme.titleLarge),
            Text(label, style: muted),
          ]),
        );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.date_range, size: 18),
            const SizedBox(width: 8),
            Text('Bu hafta', style: theme.textTheme.titleMedium),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            cell('${now['commits']}', 'commit (geçen hafta ${last['commits']})'),
            cell('${now['active_days']}', 'aktif gün (geçen hafta ${last['active_days']})'),
          ]),
          const SizedBox(height: 8),
          // Değişim şeridi: nane vurgu (B2), yön oku ile; yazı tema metin renginde kalır.
          Builder(builder: (context) {
            final diff = (now['commits'] as num) - (last['commits'] as num);
            final mint = mintColor(context);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: mint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(diff > 0 ? Icons.trending_up : (diff < 0 ? Icons.trending_down : Icons.trending_flat),
                    size: 18, color: mint),
                const SizedBox(width: 8),
                Expanded(child: Text(weekly['summary'] as String, style: theme.textTheme.bodyMedium)),
              ]),
            );
          }),
          const SizedBox(height: 4),
          Text('Pazartesi\'den bugüne; geçen haftanın aynı günleriyle kıyaslanır.', style: muted),
        ]),
      ),
    );
  }
}

/// Profil'deki "Haftalık bildirim" anahtarı. Web'de ve Android dışında gösterilmez.
class WeeklyReminderTile extends StatefulWidget {
  const WeeklyReminderTile({super.key, required this.reminder});
  final WeeklyReminder reminder;

  @override
  State<WeeklyReminderTile> createState() => _WeeklyReminderTileState();
}

class _WeeklyReminderTileState extends State<WeeklyReminderTile> {
  bool? _on;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    widget.reminder.isEnabled().then((v) {
      if (mounted) setState(() => _on = v);
    });
  }

  Future<void> _toggle(bool value) async {
    setState(() => _busy = true);
    final ok = await widget.reminder.setEnabled(value);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) _on = value;
    });
    if (value && !ok) {
      showToast(context, 'Bildirim açılamadı: izin verilmedi.', success: false);
    } else if (ok) {
      showToast(context, value ? 'Haftalık bildirim açıldı.' : 'Haftalık bildirim kapatıldı.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.reminder.supported) return const SizedBox.shrink();
    return Card(
      margin: EdgeInsets.zero,
      child: SwitchListTile(
        secondary: const Icon(Icons.notifications_outlined),
        title: const Text('Haftalık bildirim'),
        subtitle: const Text('Pazartesi sabahı haftalık özet hatırlatması. Telefonda planlanır; içinde sayı yok.'),
        value: _on ?? false,
        onChanged: _on == null || _busy ? null : _toggle,
      ),
    );
  }
}
