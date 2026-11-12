import 'package:flutter/material.dart';

/// Grafik renkleri. Büyüklük tek renk tonuyla (mavi) gösterilir; koyu temada
/// "az" yüzeye yakın koyu mavi, "çok" açık mavidir. Gökkuşağı yok.
class ChartColors {
  static const bar = Color(0xFF3987E5); // mavi 400
  static const heat = [
    Color(0xFF184F95), // 1: az   (mavi 600)
    Color(0xFF256ABF), // 2       (mavi 500)
    Color(0xFF3987E5), // 3       (mavi 400)
    Color(0xFF86B6EF), // 4: çok  (mavi 250)
  ];
}

const _weekdayShort = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
const _monthShort = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];

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
  });

  final List<int> values;
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
                        decoration: const BoxDecoration(
                          color: ChartColors.bar,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
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

/// GitHub tarzı katkı ısı haritası: sütunlar hafta, satırlar Pazartesi-Pazar.
class ContributionHeatmap extends StatelessWidget {
  const ContributionHeatmap({super.key, required this.days});

  final List<(DateTime, int)> days; // eskiden yeniye, ardışık günler

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

    Widget square(Color color) => Container(
          width: cell,
          height: cell,
          margin: const EdgeInsets.all(gap / 2),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
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
                        firstOfMonth.isEmpty ? '' : _monthShort[firstOfMonth.first!.$1.month - 1],
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
                            message: '${_date(cells[w * 7 + r]!.$1)} · ${cells[w * 7 + r]!.$2} katkı',
                            child: square(switch (level(cells[w * 7 + r]!.$2, maxCount)) {
                              0 => empty,
                              final l => ChartColors.heat[l - 1],
                            }),
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
          square(empty),
          for (final c in ChartColors.heat) square(c),
          Text('Çok', style: TextStyle(fontSize: 11, color: muted)),
        ]),
      ],
    );
  }
}
