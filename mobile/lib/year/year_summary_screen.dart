import 'package:flutter/material.dart';

import '../api/api_client.dart';

/// Yıllık özet (`GET /metrics/year-summary`, docs/metrikler.md "Yıllık özet").
class YearSummary {
  YearSummary(Map<String, dynamic> j)
      : year = j['year'] as int,
        periodStart = DateTime.parse(j['period_start'] as String),
        periodEnd = DateTime.parse(j['period_end'] as String),
        commits = j['commits'] as int,
        activeDays = j['active_days'] as int,
        busiestMonth = j['busiest_month'] as int?,
        busiestMonthCommits = j['busiest_month_commits'] as int,
        topLanguage = j['top_language'] as String?,
        topLanguageShare = (j['top_language_share'] as num?)?.toDouble(),
        nightShare = (j['night_share'] as num?)?.toDouble(),
        peakHour = j['peak_hour'] as int?,
        longestStreak = j['longest_streak'] as int,
        codingHours = j['coding_hours'] as int,
        sessions = j['sessions'] as int,
        journey = [
          for (final s in j['language_journey'] as List)
            (language: s['language'] as String, firstMonth: s['first_month'] as int, commits: s['commits'] as int),
        ],
        reviews = j['reviews'] as int?,
        badgesUnlocked = j['badges_unlocked'] as int,
        badgesTotal = j['badges_total'] as int,
        sufficiency = j['sufficiency'] as String;

  final int year;
  final DateTime periodStart, periodEnd;
  final int commits, activeDays;
  final int? busiestMonth;
  final int busiestMonthCommits;
  final String? topLanguage;
  final double? topLanguageShare;
  final double? nightShare;
  final int? peakHour;
  final int longestStreak;
  final int codingHours; // alt sınır (tahmin)
  final int sessions;
  final List<({String language, int firstMonth, int commits})> journey;
  final int? reviews;
  final int badgesUnlocked, badgesTotal;
  final String sufficiency; // yetersiz | dusuk | normal
}

const monthsTr = [
  'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
];

String _pct(double v) => '%${(v * 100).round()}';

/// "1 Ocak – 17 Kasım 2026"
String periodText(YearSummary s) =>
    '${s.periodStart.day} ${monthsTr[s.periodStart.month - 1]} – ${s.periodEnd.day} ${monthsTr[s.periodEnd.month - 1]} ${s.year}';

/// Bir slayt: büyük değer, açıklama ve verinin kaynağı (her slayt nereden geldiğini söyler).
class Slide {
  const Slide({required this.title, required this.value, required this.caption, required this.source, required this.colors});
  final String title;
  final String value;
  final String caption;
  final String source;
  final List<Color> colors; // arka plan geçişi (sabit; tekrar eden animasyon yok)
}

/// Veriden slayt listesi. Yetersiz veride tek kart. Sayıdan sonra Türkçe ek yok.
List<Slide> buildSlides(YearSummary s) {
  final period = periodText(s);
  const blue = [Color(0xFF1E3A8A), Color(0xFF3B82F6)];
  const purple = [Color(0xFF4C1D95), Color(0xFF8B5CF6)];
  const teal = [Color(0xFF134E4A), Color(0xFF14B8A6)];
  const night = [Color(0xFF0F172A), Color(0xFF312E81)];
  const orange = [Color(0xFF7C2D12), Color(0xFFF97316)];
  const green = [Color(0xFF14532D), Color(0xFF22C55E)];
  if (s.sufficiency == 'yetersiz') {
    return [
      Slide(
        title: '${s.year} özeti',
        value: 'Yeterli veri yok',
        caption: 'Bu dönemde ${s.commits} commit var; özet için en az 10 commit gerekiyor.',
        source: 'Dönem: $period',
        colors: blue,
      ),
    ];
  }
  return [
    Slide(
      title: '${s.year} yılında',
      value: '${s.commits} commit',
      caption: '${s.activeDays} farklı günde commit attın.',
      source: 'Senkronlanan commit\'ler · $period',
      colors: blue,
    ),
    if (s.busiestMonth != null)
      Slide(
        title: 'En yoğun ay',
        value: monthsTr[s.busiestMonth! - 1],
        caption: 'Bu ayda ${s.busiestMonthCommits} commit.',
        source: 'Aylara göre commit sayısı · $period',
        colors: purple,
      ),
    if (s.topLanguage != null)
      Slide(
        title: 'En çok çalıştığın dil',
        value: s.topLanguage!,
        caption: 'Ana dili bilinen repolardaki commit payı: ${_pct(s.topLanguageShare!)}',
        source: 'Commit\'in atıldığı reponun ana diline göre (bayt payı değil)',
        colors: teal,
      ),
    if (s.nightShare != null)
      Slide(
        title: s.nightShare! >= 0.2 ? 'Gece kuşu' : 'Çalışma saatlerin',
        value: 'Gece payı: ${_pct(s.nightShare!)}',
        caption: s.peakHour == null ? '' : 'En yoğun saat: ${s.peakHour.toString().padLeft(2, '0')}:00',
        source: 'Gece = 00:00-06:00, yerel saat',
        colors: night,
      ),
    Slide(
      title: 'En uzun seri',
      value: '${s.longestStreak} gün',
      caption: 'Art arda commit attığın en uzun dönem.',
      source: 'Dönem içindeki aktif günler',
      colors: orange,
    ),
    Slide(
      title: 'Kodlama süresi (tahmin)',
      value: 'en az ${s.codingHours} saat',
      caption: '${s.sessions} oturum. Tek commit\'lik oturum 0 sayıldığı için gerçek süre daha uzundur.',
      source: 'Oturum kuralı: commit\'ler arası 2 saatten kısa boşluklar',
      colors: purple,
    ),
    if (s.journey.length >= 2)
      Slide(
        title: 'Dil yolculuğun',
        value: s.journey.map((j) => j.language).join(' → '),
        caption: s.journey.map((j) => '${j.language}: ${monthsTr[j.firstMonth - 1]}').join(' · '),
        source: 'Her dilde ilk commit\'in ayı (reponun ana dili)',
        colors: teal,
      ),
    if (s.reviews != null && s.reviews! > 0)
      Slide(
        title: 'Kod incelemesi',
        value: '${s.reviews} inceleme',
        caption: 'Başkalarının kodunu inceledin.',
        source: 'GitHub\'ın ${s.year} için saydığı inceleme katkısı',
        colors: green,
      ),
    Slide(
      title: '${s.year} böyle geçti',
      value: 'Rozet: ${s.badgesUnlocked} / ${s.badgesTotal}',
      caption: s.sufficiency == 'dusuk' ? 'Veri az olduğu için bu özet düşük güvenle hazırlandı.' : 'Teşekkürler!',
      source: 'Başarımlar sekmesi',
      colors: blue,
    ),
  ];
}

/// Hikâye gibi kayan yıllık özet. Tek AnimationController slayt süresini sayar (Timer yok);
/// sağa dokun: ileri, sola dokun: geri. Son slaytta durur.
class YearSummaryScreen extends StatefulWidget {
  const YearSummaryScreen({
    super.key,
    required this.api,
    this.year,
    this.slideDuration = const Duration(seconds: 5),
    this.onShare,
  });
  final ApiClient api;
  final int? year;
  final Duration slideDuration;
  final void Function(BuildContext context, YearSummary summary)? onShare; // son slayttaki "Paylaş"

  @override
  State<YearSummaryScreen> createState() => _YearSummaryScreenState();
}

class _YearSummaryScreenState extends State<YearSummaryScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _progress = AnimationController(vsync: this, duration: widget.slideDuration)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _go(1);
    });
  YearSummary? _summary;
  List<Slide> _slides = const [];
  String? _error;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = YearSummary(await widget.api.get('/metrics/year-summary${widget.year == null ? '' : '?year=${widget.year}'}'));
      if (!mounted) return;
      setState(() {
        _summary = s;
        _slides = buildSlides(s);
      });
      _progress.forward(from: 0);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Yıllık özet yüklenemedi.');
    }
  }

  void _go(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= _slides.length) {
      if (next < 0) _progress.forward(from: 0);
      return; // son slaytta durur
    }
    setState(() => _index = next);
    _progress.forward(from: 0);
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final close = IconButton(
      tooltip: 'Kapat',
      icon: const Icon(Icons.close, color: Colors.white),
      onPressed: () => Navigator.of(context).pop(),
    );
    if (_summary == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: SafeArea(
          child: Stack(children: [
            Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Text(_error!, style: const TextStyle(color: Colors.white)),
            ),
            Align(alignment: Alignment.topRight, child: close),
          ]),
        ),
      );
    }
    final slide = _slides[_index];
    final last = _index == _slides.length - 1;
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: slide.colors),
        ),
        child: SafeArea(
          child: Column(children: [
            // Üstte ilerleme çubukları: geçilenler dolu, şimdiki dolmakta.
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: AnimatedBuilder(
                animation: _progress,
                builder: (context, _) => Row(children: [
                  for (var i = 0; i < _slides.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: LinearProgressIndicator(
                          value: i < _index ? 1 : (i == _index ? _progress.value : 0),
                          minHeight: 3,
                          color: Colors.white,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                    ),
                ]),
              ),
            ),
            Align(alignment: Alignment.topRight, child: close),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => _go(d.localPosition.dx < MediaQuery.sizeOf(context).width / 3 ? -1 : 1),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _SlideView(key: ValueKey(_index), slide: slide),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(children: [
                if (last && widget.onShare != null && _summary!.sufficiency != 'yetersiz')
                  FilledButton.tonalIcon(
                    onPressed: () => widget.onShare!(context, _summary!),
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Paylaş'),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: last ? () => Navigator.of(context).pop() : () => _go(1),
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: Text(last ? 'Kapat' : 'İleri'),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({super.key, required this.slide});
  final Slide slide;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(slide.title, style: t.titleLarge?.copyWith(color: Colors.white70)),
        const SizedBox(height: 12),
        Text(slide.value, style: t.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        if (slide.caption.isNotEmpty) Text(slide.caption, style: t.titleMedium?.copyWith(color: Colors.white)),
        const SizedBox(height: 24),
        Text(slide.source, style: t.bodySmall?.copyWith(color: Colors.white60)),
      ]),
    );
  }
}
