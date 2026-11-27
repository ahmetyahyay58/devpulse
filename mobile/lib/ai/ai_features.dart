import 'package:flutter/material.dart';

import 'ai_controller.dart';
import 'ai_widgets.dart';

/// AI denetleyicisini alt ağaca verir: kartlar onu kurucu parametresi olmadan bulur.
/// (Ana ekranın içindeki sekmelerde geçerlidir; yoksa AI düğmeleri hiç görünmez.)
class AiScope extends InheritedWidget {
  const AiScope({super.key, required this.ai, required super.child});
  final AiController ai;

  static AiController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AiScope>()?.ai;

  @override
  bool updateShouldNotify(AiScope oldWidget) => ai != oldWidget.ai;
}

/// Kart başlığındaki "Neden?" düğmesi: o metriğin neden öyle çıktığını alttan açılan panelde anlatır.
class WhyButton extends StatelessWidget {
  const WhyButton({super.key, required this.questionId});
  final String questionId;

  @override
  Widget build(BuildContext context) {
    final ai = AiScope.maybeOf(context);
    if (ai == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: ai,
      builder: (context, _) {
        final q = ai.byId(questionId);
        if (q == null) return const SizedBox.shrink(); // AI durumu yüklenmediyse düğme yok
        return TextButton.icon(
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          onPressed: () => showAskSheet(context, ai, [q]),
          icon: const Icon(Icons.help_outline, size: 16),
          label: const Text('Neden?'),
        );
      },
    );
  }
}

/// Alttan açılan soru paneli. Tek soru verilirse doğrudan cevaplar (Neden?); birden çoksa
/// soruları liste olarak gösterir, seçilenin cevabı altında açılır (Sor balonu).
Future<void> showAskSheet(BuildContext context, AiController ai, List<AiQuestion> questions, {String? title}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AskSheet(ai: ai, questions: questions, title: title),
    );

class AskSheet extends StatefulWidget {
  const AskSheet({super.key, required this.ai, required this.questions, this.title});
  final AiController ai;
  final List<AiQuestion> questions;
  final String? title;

  @override
  State<AskSheet> createState() => _AskSheetState();
}

class _AskSheetState extends State<AskSheet> {
  String? _selected;
  Future<AiAnswer>? _answer;

  @override
  void initState() {
    super.initState();
    if (widget.questions.length == 1) {
      // İlk karede pencere açmak için bir kare bekle (onay penceresi panelin üstünde açılır).
      WidgetsBinding.instance.addPostFrameCallback((_) => _pick(widget.questions.single.id));
    }
  }

  Future<void> _pick(String id) async {
    setState(() => _selected = id);
    await ensureConsent(context, widget.ai);
    if (!mounted) return;
    setState(() {
      _answer = widget.ai.ask(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final single = widget.questions.length == 1;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                const Icon(Icons.auto_awesome, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(single ? widget.questions.single.text : (widget.title ?? 'Sor'),
                      style: theme.textTheme.titleMedium),
                ),
              ]),
              const SizedBox(height: 12),
              if (!single)
                for (final q in widget.questions)
                  Container(
                    alignment: Alignment.centerLeft, // sorular sola hizalı: liste gibi okunur
                    padding: const EdgeInsets.only(bottom: 6),
                    child: ChoiceChip(
                      label: Text(q.text),
                      selected: _selected == q.id,
                      onSelected: (_) => _pick(q.id),
                    ),
                  ),
              if (_answer != null) ...[
                if (!single) const SizedBox(height: 8),
                AiAnswerView(future: _answer!, ai: widget.ai),
              ] else if (single)
                const LinearProgressIndicator(),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Genel Bakış'ın üstündeki kapatılabilir ipucu satırı. Kendiliğinden onay penceresi açmaz:
/// onay yoksa sunucu hazır cümleyi döner, hiçbir veri gönderilmez.
class AiTipLine extends StatefulWidget {
  const AiTipLine({super.key, required this.ai});
  final AiController ai;

  @override
  State<AiTipLine> createState() => _AiTipLineState();
}

class _AiTipLineState extends State<AiTipLine> {
  Future<AiAnswer>? _tip;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.ai,
      builder: (context, _) {
        final ai = widget.ai;
        if (!ai.tipsEnabled || ai.tipDismissed || ai.byId('ipucu') == null) return const SizedBox.shrink();
        _tip ??= ai.ask('ipucu');
        return FutureBuilder(
          future: _tip,
          builder: (context, snap) {
            if (!snap.hasData) return const SizedBox.shrink(); // yüklenirken ya da hatada yer kaplamaz
            final a = snap.data!;
            final theme = Theme.of(context);
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: theme.colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                child: Row(children: [
                  // Rozet: kaynağı yazıyla söyler (renk tek başına anlam taşımaz).
                  Chip(
                    avatar: Icon(a.fromLlm ? Icons.auto_awesome : Icons.lightbulb_outline, size: 14),
                    label: Text(a.fromLlm ? 'AI' : 'İpucu'),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(a.answer, style: theme.textTheme.bodyMedium)),
                  IconButton(
                    tooltip: 'İpucunu kapat',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: ai.dismissTip,
                  ),
                ]),
              ),
            );
          },
        );
      },
    );
  }
}

/// Sekmelerin kaydırılan içeriğinin dolgusu: altta Sor balonu kadar boşluk (56 + 16 kenar + 16),
/// en alttaki satır düğmenin altında kalmasın.
// Alt boşluk: yüzen kapsül menü (64 + 14 kenar) ve üstündeki soru düğmesi içeriği örtmesin.
const tabPadding = EdgeInsets.fromLTRB(16, 16, 16, 150);

/// Sağ alttaki Sor balonu: beş hazır soru.
class AskFab extends StatelessWidget {
  const AskFab({super.key, required this.ai});
  final AiController ai;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ai,
      builder: (context, _) {
        final questions = ai.ofKind('sor');
        if (questions.isEmpty) return const SizedBox.shrink();
        return FloatingActionButton(
          tooltip: 'Sor',
          onPressed: () => showAskSheet(context, ai, questions, title: 'Ne sormak istersin?'),
          child: const Icon(Icons.chat_bubble_outline),
        );
      },
    );
  }
}
