import 'package:flutter/material.dart';

import '../api/api_client.dart';
import 'ai_controller.dart';

/// Sunucuda yapay zekâ hazırsa ve onay yoksa, ilk soruda bir kez onay ister.
/// Onay verilmezse cevap yine gelir ama hazır şablon cümledir (hiçbir veri gönderilmez).
Future<void> ensureConsent(BuildContext context, AiController ai) async {
  if (!ai.llmReady || ai.consent || ai.consentAsked) return;
  ai.consentAsked = true; // reddederse her soruda tekrar sorulmaz (Profil'den açılabilir)
  final ok = await showDialog<bool>(context: context, builder: (_) => AiConsentDialog(ai: ai));
  if (ok == true) await ai.setConsent(true);
}

/// İlk kullanımda açık onay: ne gider, ne gitmez, nereye gider.
class AiConsentDialog extends StatelessWidget {
  const AiConsentDialog({super.key, required this.ai});
  final AiController ai;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Yapay zekâ yorumları'),
      content: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          const Text('Yorumları Google Gemini yazar. Ona yalnızca hesaplanmış toplu sayılar gider '
              '(ör. aktif gün, en uzun seri, gece çalışma oranı).'),
          const SizedBox(height: 8),
          const Text('Kullanıcı adın, repo adların, commit mesajların ve kodun gitmez.'),
          const SizedBox(height: 8),
          const Text('Ücretsiz katmanda Google gönderilen sayıları ve cevapları ürünlerini geliştirmek '
              'için kullanabilir. Onay vermezsen yorumlar hazır cümlelerle gösterilir.'),
          TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AiFactsScreen(ai: ai))),
            child: const Text('Giden veriyi gör'),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Onaylamıyorum')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Onaylıyorum')),
      ],
    );
  }
}

/// Cevabın altındaki kaynak satırı: kim yazdı, neden şablon, giden veri.
class AiSourceLine extends StatelessWidget {
  const AiSourceLine({super.key, required this.answer, required this.ai});
  final AiAnswer answer;
  final AiController ai;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final label = answer.fromLlm
        ? 'Yapay zekâ (Gemini) · yalnız toplu sayılarla'
        : 'Hazır cümle${answer.reason == null ? '' : ' · ${answer.reason}'}';
    return Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
      Icon(answer.fromLlm ? Icons.auto_awesome : Icons.notes, size: 14, color: muted?.color),
      const SizedBox(width: 4),
      Text(label, style: muted),
      TextButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => AiFactsScreen(ai: ai, facts: answer.facts)),
        ),
        child: const Text('Giden veri'),
      ),
    ]);
  }
}

/// Genel Bakış'taki AI yorumu kartı: üç hazır soru çipi, seçilenin cevabı.
class AiCommentCard extends StatefulWidget {
  const AiCommentCard({
    super.key,
    required this.ai,
    this.kind = 'sor',
    this.title = 'AI yorumu',
    this.icon = Icons.auto_awesome,
    this.subtitle,
  });
  final AiController ai;
  final String kind; // hangi hazır sorular çip olur: 'sor' (Genel Bakış) ya da 'hedef' (Başarımlar)
  final String title;
  final IconData icon;
  final String? subtitle;

  @override
  State<AiCommentCard> createState() => _AiCommentCardState();
}

class _AiCommentCardState extends State<AiCommentCard> {
  String? _selected;
  Future<AiAnswer>? _answer;

  Future<void> _pick(String id) async {
    setState(() => _selected = id);
    await ensureConsent(context, widget.ai); // cevap, onay penceresi kapandıktan sonra istenir
    if (!mounted) return;
    setState(() {
      _answer = widget.ai.ask(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.ai,
      builder: (context, _) {
        final chips = widget.ai.ofKind(widget.kind).take(3).toList();
        if (chips.isEmpty) return const SizedBox.shrink(); // AI durumu yüklenemediyse kart yok
        final theme = Theme.of(context);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Icon(widget.icon, size: 18),
                const SizedBox(width: 8),
                Text(widget.title, style: theme.textTheme.titleMedium),
              ]),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 4),
                Text(widget.subtitle!, style: theme.textTheme.bodySmall),
              ],
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 4, children: [
                for (final q in chips)
                  ChoiceChip(label: Text(q.text), selected: _selected == q.id, onSelected: (_) => _pick(q.id)),
              ]),
              if (_answer != null) ...[
                const SizedBox(height: 12),
                AiAnswerView(future: _answer!, ai: widget.ai),
              ],
            ]),
          ),
        );
      },
    );
  }
}

/// Bir cevabın yüklenme, hata ve sonuç halleri (kart, "Neden?" ve Sor balonu ortak kullanır).
class AiAnswerView extends StatelessWidget {
  const AiAnswerView({super.key, required this.future, required this.ai});
  final Future<AiAnswer> future;
  final AiController ai;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: future,
      builder: (context, snap) {
        if (snap.hasError) return Text(userMessage(snap.error!, fallback: 'Cevap alınamadı.'));
        if (!snap.hasData) return const LinearProgressIndicator();
        final a = snap.data!;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(a.answer),
          const SizedBox(height: 4),
          AiSourceLine(answer: a, ai: ai),
        ]);
      },
    );
  }
}

/// "Yapay zekâya giden veri": sunucunun LLM'e gönderdiği (göndereceği) sayıların aynısı.
class AiFactsScreen extends StatelessWidget {
  const AiFactsScreen({super.key, required this.ai, this.facts});
  final AiController ai;
  final Map<String, dynamic>? facts; // verilmezse sunucudan alınır

  // JSON anahtarlarının ekrandaki adları (backend app/ai/facts.py ile aynı anahtarlar).
  static const labels = {
    'toplam_commit': 'Toplam commit', 'aktif_gun': 'Aktif gün', 'repo_sayisi': 'Repo sayısı',
    'guncel_seri_gun': 'Güncel seri (gün)', 'en_uzun_seri_gun': 'En uzun seri (gün)',
    'sureklilik_guveni': 'Süreklilik güveni', 'en_yogun_saat': 'En yoğun saat',
    'gece_payi_yuzde': 'Gece payı (%)', 'hafta_sonu_payi_yuzde': 'Hafta sonu payı (%)',
    'ritim_guveni': 'Ritim güveni', 'oturum_sayisi': 'Oturum sayısı', 'oturum_basi_commit': 'Oturum başına commit',
    'ortalama_oturum_dk': 'Ortalama oturum (dk)', 'oturum_guveni': 'Oturum güveni',
    'commit_turleri_yuzde': 'Commit türleri (%)', 'tur_guveni': 'Tür güveni', 'olagan_disi_gun': 'Olağan dışı gün',
    'puanlanan_proje': 'Puanlanan proje', 'ortalama_saglik': 'Ortalama sağlık puanı',
    'eksik_proje': 'Eksiği olan proje sayısı', 'dil_sayisi': 'Dil sayısı', 'baskin_dil': 'Baskın dil',
    'baskin_dil_yuzde': 'Baskın dil payı (%)', 'cesitlilik': 'Dil çeşitliliği (0-1)',
    'teknoloji_guveni': 'Teknoloji güveni', 'yil_degisim_yuzde': 'Yıllık değişim (%)', 'yil_guveni': 'Yıl kıyası güveni',
    'acik_rozet': 'Açılan rozet', 'kilitli_rozetler': 'Kilitli rozetler (şu an/hedef)',
  };
  static const _levels = {'yetersiz': 'Yeterli veri yok', 'dusuk': 'Düşük güven', 'normal': 'Normal'};

  static String label(String key) => labels[key] ?? key.replaceAll('_', ' ');

  static String value(Object? v) => switch (v) {
        null => 'bilinmiyor',
        String s when _levels.containsKey(s) => _levels[s]!,
        Map m when m.isEmpty => '-',
        Map m => m.entries.map((e) => '${e.key}: ${e.value}').join(', '),
        double d => '$d'.replaceAll('.', ','),
        _ => '$v',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Yapay zekâya giden veri')),
      body: FutureBuilder(
        future: facts != null ? Future.value(facts) : ai.facts(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text(userMessage(snap.error!, fallback: 'Yüklenemedi.')));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final f = snap.data!;
          return ListView(padding: const EdgeInsets.all(16), children: [
            Text('Yalnızca bu sayılar gider. Kullanıcı adın, repo adların, commit mesajların ve kodun gitmez.',
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            for (final e in f.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Text(label(e.key), style: theme.textTheme.bodySmall)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(value(e.value), textAlign: TextAlign.end)),
                ]),
              ),
          ]);
        },
      ),
    );
  }
}

/// Profil'deki ayar kartı: onay aç/kapa ve giden veri.
class AiSettingsCard extends StatelessWidget {
  const AiSettingsCard({super.key, required this.ai});
  final AiController ai;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ai,
      builder: (context, _) => Card(
        margin: EdgeInsets.zero,
        child: Column(children: [
          SwitchListTile(
            secondary: const Icon(Icons.auto_awesome),
            title: const Text('Yapay zekâ yorumları'),
            subtitle: Text(ai.llmReady
                ? "Açıkken yalnız toplu sayılar Google Gemini'ye gider."
                : 'Sunucuda yapay zekâ kurulu değil; yorumlar hazır cümlelerle gösterilir.'),
            value: ai.consent,
            onChanged: ai.loaded ? (v) => ai.setConsent(v) : null,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.lightbulb_outline),
            title: const Text('AI ipuçları'),
            subtitle: const Text("Genel Bakış'ın üstündeki tek cümlelik öneri"),
            value: ai.tipsEnabled,
            onChanged: ai.setTipsEnabled,
          ),
          ListTile(
            leading: const Icon(Icons.data_object),
            title: const Text('Yapay zekâya giden veri'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AiFactsScreen(ai: ai))),
          ),
        ]),
      ),
    );
  }
}
