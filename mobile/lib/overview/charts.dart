import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Grafik renkleri. Büyüklük tek renk tonuyla (logonun moru) gösterilir; koyu temada
/// "az" yüzeye yakın koyu mor, "çok" açık lavantadır. Gökkuşağı yok.
class ChartColors {
  static const bar = Color(0xFF7C6CF2); // tek seri: kart zeminine karşı koyuda ~5:1, açıkta ~4:1
  static const heat = [
    Color(0xFF3A3399), // 1: az
    Color(0xFF5546CF), // 2
    Color(0xFF7C6CF2), // 3
    Color(0xFFB9AFFF), // 4: çok
  ];

  /// Açık tema: aynı mor, açıktan koyuya ("az" açık, "çok" koyu). Tek ton; komşu adımlar
  /// arası ≥ 1,7:1, en açık adım beyaz karta karşı ≥ 2:1.
  static const heatLight = [
    Color(0xFFA79DF7), // 1: az
    Color(0xFF7363EC), // 2
    Color(0xFF4B3CC4), // 3
    Color(0xFF2A1F82), // 4: çok
  ];

  static List<Color> heatFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? heat : heatLight;

  /// Olağan dışı gün halkası: "uyarı" durumu rengi (amber). Kategorik renklerden ayrı;
  /// lejantta yazıyla da açıklanır.
  static const anomaly = Color(0xFFFAB219);

  /// Değişim noktası evreleri: aynı doğrulanmış kategorik palet, sabit sıra (Evre 1 hep mavi).
  /// En çok 6 evre olur (backend sınırlar); renk döngüye girmez.
  static const phases = [
    Color(0xFF3987E5), Color(0xFFD95926), Color(0xFF199E70),
    Color(0xFFC98500), Color(0xFFD55181), Color(0xFF008300),
  ];

  /// Commit türleri: koyu tema kategorik paleti, sabit sıra (renk sırayı değil türü izler;
  /// bir tür hangi sırada olursa olsun hep aynı renktir). Doğrulama: altı renk koyu yüzeyde
  /// açıklık, doygunluk, renk körlüğü ayrımı ve kontrast kontrollerinden geçti.
  static const types = {
    'feat': Color(0xFF3987E5), // mavi
    'fix': Color(0xFFD95926), // turuncu
    'docs': Color(0xFF199E70), // su yeşili
    'bakim': Color(0xFFC98500), // sarı
    'test': Color(0xFFD55181), // pembe
    'diger': Color(0xFF008300), // yeşil
  };
}

const _weekdayShort = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
const monthShortTr = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];

String _date(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

/// Tek serili dikey çubuk grafik. Lejant yok (başlık neyi gösterdiğini söyler);
/// her çubuğun değeri dokununca/üzerine gelince görünür.
class BarChart extends StatelessWidget {
  const BarChart({
    super.key,
    required this.values,
    required this.labelFor,
    required this.tooltipFor,
    this.height = 72,
    this.colorFor,
  });

  final List<int> values;
  final Color Function(int index)? colorFor; // null: hepsi aynı mavi (tek seri)
  final String? Function(int index) labelFor; // null: o çubuğun altına etiket yazma
  final String Function(int index, int value) tooltipFor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final maxValue = values.fold<int>(0, (a, b) => a > b ? a : b);
    return Column(
      children: [
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end, // çubuklar tabana oturur
            children: [
              for (var i = 0; i < values.length; i++)
                Expanded(
                  child: Tooltip(
                    message: tooltipFor(i, values[i]),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1), // çubuklar arası 2px
                      child: Container(
                        height: maxValue == 0 ? 0 : height * values[i] / maxValue,
                        decoration: BoxDecoration(
                          color: colorFor?.call(i) ?? ChartColors.bar,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Container(height: 1, color: muted.withValues(alpha: 0.4)), // taban çizgisi
        const SizedBox(height: 4),
        Row(
          children: [
            for (var i = 0; i < values.length; i++)
              Expanded(
                child: Text(
                  labelFor(i) ?? '',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  softWrap: false, // çubuk dar olsa da etiket kırpılmadan yanlara taşar
                  overflow: TextOverflow.visible,
                  style: TextStyle(fontSize: 10, color: muted),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Saat dağılımı: 24 çubuk, etiketler 0/6/12/18.
Widget hourChart(List<int> byHour) => BarChart(
      values: byHour,
      labelFor: (i) => i % 6 == 0 ? '$i' : null,
      tooltipFor: (i, v) => '${i.toString().padLeft(2, '0')}:00-${i.toString().padLeft(2, '0')}:59 · $v commit',
    );

/// Haftanın günü dağılımı: 7 çubuk.
Widget weekdayChart(List<int> byWeekday) => BarChart(
      values: byWeekday,
      labelFor: (i) => _weekdayShort[i],
      tooltipFor: (i, v) => '${_weekdayShort[i]} · $v commit',
      height: 56,
    );

/// Halka grafik: her dilim bir yay; dilimler arasında yüzey renginde küçük bir boşluk,
/// ortada toplam. Renk tek başına anlam taşımaz: yanında yazılı lejant olmalı.
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.slices,
    required this.centerValue,
    required this.centerLabel,
    this.size = 140,
  });

  final List<(double, Color)> slices; // (değer, renk), değerler > 0
  final String centerValue;
  final String centerLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox.square(
      dimension: size,
      child: Stack(alignment: Alignment.center, children: [
        CustomPaint(size: Size.square(size), painter: _DonutPainter(slices)),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text(centerValue, style: theme.textTheme.titleLarge),
          Text(centerLabel, style: theme.textTheme.bodySmall),
        ]),
      ]),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.slices);
  final List<(double, Color)> slices;

  static const stroke = 18.0;
  static const gapPx = 2.0; // dilimler arası boşluk (yay uzunluğu olarak)

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<double>(0, (a, s) => a + s.$1);
    if (total <= 0) return;
    final radius = (size.shortestSide - stroke) / 2;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: radius);
    final gap = slices.length > 1 ? gapPx / radius : 0.0; // piksel -> radyan
    var start = -math.pi / 2; // saat 12'den başla
    for (final (value, color) in slices) {
      final sweep = value / total * 2 * math.pi;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke;
      // Çok küçük dilim boşluktan kısa kalmasın diye en az yarısı çizilir.
      final drawn = (sweep - gap).clamp(sweep / 2, sweep);
      canvas.drawArc(rect, start + (sweep - drawn) / 2, drawn, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.slices != slices;
}

/// Tek değerli halka (0-100): dolu kısım mavi, kalan kısım yüzeye yakın iz. Sayı ortada yazılı.
class ScoreRing extends StatelessWidget {
  const ScoreRing({super.key, required this.score, this.size = 120, this.percent = false});

  final int score; // 0-100
  final double size;
  final bool percent; // true: ortada "%62" (puan değil, oran); false: "62/100"

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox.square(
      dimension: size,
      child: Stack(alignment: Alignment.center, children: [
        CustomPaint(
          size: Size.square(size),
          painter: _RingPainter(score / 100, theme.colorScheme.surfaceContainerHighest),
        ),
        if (percent)
          Text('%$score', style: theme.textTheme.headlineSmall)
        else
          Text.rich(TextSpan(children: [
            TextSpan(text: '$score', style: theme.textTheme.headlineSmall),
            TextSpan(text: '/100', style: theme.textTheme.bodySmall),
          ])),
      ]),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.fraction, this.track);
  final double fraction;
  final Color track;

  static const stroke = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: (size.shortestSide - stroke) / 2);
    Paint p(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, p(track));
    if (fraction > 0) {
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * fraction.clamp(0, 1), false, p(ChartColors.bar));
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction || old.track != track;
}

/// GitHub tarzı katkı ısı haritası: sütunlar hafta, satırlar Pazartesi-Pazar.
class ContributionHeatmap extends StatelessWidget {
  const ContributionHeatmap({
    super.key,
    required this.days,
    this.unit = 'katkı',
    this.highlighted = const {},
  });

  final List<(DateTime, int)> days; // eskiden yeniye, ardışık günler
  final String unit; // ipucunda sayının yanındaki kelime ("katkı" ya da "commit")
  final Set<DateTime> highlighted; // amber halkayla çizilecek günler (olağan dışı yoğun)

  static const cell = 11.0;
  static const gap = 2.0;

  /// Sayıyı 0-4 düzeyine çevirir: 0 boş, diğerleri en yüksek güne oranla dörde bölünür.
  static int level(int count, int maxCount) {
    if (count == 0 || maxCount == 0) return 0;
    return (4 * count / maxCount).ceil().clamp(1, 4);
  }

  @override
  Widget build(BuildContext context) {
    final empty = Theme.of(context).colorScheme.surfaceContainerHighest;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    if (days.isEmpty) return const SizedBox.shrink();

    final maxCount = days.fold<int>(0, (a, d) => d.$2 > a ? d.$2 : a);
    // İlk sütunu Pazartesi'den başlat: ilk günün haftanın kaçıncı günü olduğu kadar boşluk.
    final leading = days.first.$1.weekday - 1; // Pazartesi=1 -> 0
    final cells = <(DateTime, int)?>[...List.filled(leading, null), ...days];
    final weeks = (cells.length / 7).ceil();

    // AnimatedContainer: renk değişince (senkron ekranında yeni commit'ler geldikçe)
    // kare birden değil, yumuşak bir geçişle dolar.
    Widget square(Color color, {bool ring = false}) => AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          width: cell,
          height: cell,
          margin: const EdgeInsets.all(gap / 2),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            border: ring ? Border.all(color: ChartColors.anomaly, width: 1.5) : null,
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true, // en yeni hafta (sağ uç) ilk açılışta görünür
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ay etiketleri: ayın ilk günü hangi haftadaysa o sütunun üstüne.
              Row(children: [
                for (var w = 0; w < weeks; w++)
                  SizedBox(
                    width: cell + gap,
                    child: Builder(builder: (_) {
                      final firstOfMonth = [
                        for (var r = 0; r < 7; r++)
                          if (w * 7 + r < cells.length && cells[w * 7 + r]?.$1.day == 1) cells[w * 7 + r]
                      ];
                      return Text(
                        firstOfMonth.isEmpty ? '' : monthShortTr[firstOfMonth.first!.$1.month - 1],
                        softWrap: false,
                        overflow: TextOverflow.visible,
                        style: TextStyle(fontSize: 10, color: muted),
                      );
                    }),
                  ),
              ]),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var w = 0; w < weeks; w++)
                    Column(children: [
                      for (var r = 0; r < 7; r++)
                        if (w * 7 + r < cells.length && cells[w * 7 + r] != null)
                          Tooltip(
                            message: '${_date(cells[w * 7 + r]!.$1)} · ${cells[w * 7 + r]!.$2} $unit'
                                '${highlighted.contains(cells[w * 7 + r]!.$1) ? ' · olağan dışı yoğun gün' : ''}',
                            child: square(
                              switch (level(cells[w * 7 + r]!.$2, maxCount)) {
                                0 => empty,
                                final l => ChartColors.heatFor(context)[l - 1],
                              },
                              ring: highlighted.contains(cells[w * 7 + r]!.$1),
                            ),
                          )
                        else
                          const SizedBox(width: cell + gap, height: cell + gap),
                    ]),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Lejant: renk düzeylerinin anlamı (renk tek başına bilgi taşımasın diye yazılı).
        Row(children: [
          Text('Az', style: TextStyle(fontSize: 11, color: muted)),
          const SizedBox(width: 4),
          square(empty),
          for (final c in ChartColors.heatFor(context)) square(c),
          const SizedBox(width: 4),
          Text('Çok', style: TextStyle(fontSize: 11, color: muted)),
        ]),
      ],
    );
  }
}
