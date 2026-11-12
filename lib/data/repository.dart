import 'models.dart';

/// Everything the owner app reads. The demo source below is used until a
/// server is connected; an API source will implement the same calls.
abstract class OwnerRepository {
  bool get isDemo;
  String get storeName;
  Future<OwnerSnapshot> snapshot();
  Future<List<StockItem>> stock();
  Future<DailySales> dailySales(DateTime day);
  Future<BrandwiseReport> brandwise(DateTime day);
}

/// A consistent fake beer & wine shop: today's closing in the brandwise
/// report equals stock on hand, each day's opening is the previous day's
/// closing, and sales figures add up to the home screen.
class DemoRepository implements OwnerRepository {
  DemoRepository({DateTime? now}) : _now = now ?? DateTime.now();

  final DateTime _now;

  @override
  bool get isDemo => true;

  @override
  String get storeName => 'Shree Sai Wines';

  DateTime get _today => DateTime(_now.year, _now.month, _now.day);

  // name, size, category, MRP, on hand today, reorder level, daily pace
  static const _catalog = <(String, String, String, double, int, int, int)>[
    ('Kingfisher Strong', '650 ML', 'Fermented Beer', 180, 240, 48, 22),
    ('Kingfisher Strong', '500 ML (CAN)', 'Fermented Beer', 190, 96, 48, 9),
    ('Tuborg Strong', '650 ML', 'Fermented Beer', 170, 132, 48, 11),
    ('Tuborg Strong', '500 ML (CAN)', 'Fermented Beer', 180, 72, 24, 5),
    ('Budweiser Magnum', '650 ML', 'Fermented Beer', 210, 96, 24, 7),
    ('Budweiser Magnum', '500 ML (CAN)', 'Fermented Beer', 190, 120, 48, 10),
    ('Haywards 5000', '650 ML', 'Fermented Beer', 150, 144, 48, 9),
    ('Carlsberg Elephant', '650 ML', 'Fermented Beer', 200, 60, 24, 4),
    ('Bira 91 Boom', '650 ML', 'Fermented Beer', 190, 30, 24, 3),
    ('Kingfisher Ultra Max', '650 ML', 'Fermented Beer', 230, 4, 24, 3),
    ('Godfather Strong', '650 ML', 'Fermented Beer', 160, 0, 24, 2),
    ('Kingfisher Premium', '650 ML', 'Mild Beer', 160, 120, 48, 9),
    ('Kingfisher Premium', '330 ML (CAN)', 'Mild Beer', 110, 96, 48, 7),
    ('Budweiser', '650 ML', 'Mild Beer', 200, 84, 24, 6),
    ('Budweiser', '330 ML (CAN)', 'Mild Beer', 130, 72, 24, 6),
    ('Bira 91 White', '330 ML (CAN)', 'Mild Beer', 140, 7, 24, 4),
    ('Heineken', '650 ML', 'Mild Beer', 220, 48, 24, 3),
    ('Corona Extra', '330 ML', 'Mild Beer', 260, 24, 12, 2),
    ('Hoegaarden', '330 ML', 'Mild Beer', 250, 18, 12, 1),
    ('Sula Shiraz', '750 ML', 'Wine', 820, 12, 6, 1),
    ('Sula Shiraz', '375 ML', 'Wine', 430, 8, 6, 1),
    ('Sula Chenin Blanc', '750 ML', 'Wine', 790, 2, 6, 1),
    ('Grover La Reserve', '750 ML', 'Wine', 1450, 6, 4, 0),
    ('Big Banyan Merlot', '750 ML', 'Wine', 900, 10, 6, 1),
    ('Golconda Port Wine', '180 ML', 'Wine', 90, 60, 24, 4),
  ];

  static String _code(String name, String size) =>
      '${name.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '')}-${RegExp(r'\d+').firstMatch(size)!.group(0)}'
      '${size.contains('CAN') ? 'C' : ''}';

  /// Deterministic 0..1 noise per (item, day).
  static double _noise(int item, int day) {
    var h = (item * 73856093) ^ (day * 19349663);
    h = (h ^ (h >> 13)) * 1274126177;
    return ((h ^ (h >> 16)) & 0xffff) / 0xffff;
  }

  /// Weekend (Fri/Sat) is busier.
  static double _dayFactor(DateTime d) => switch (d.weekday) {
    DateTime.friday => 1.3,
    DateTime.saturday => 1.45,
    DateTime.sunday => 1.1,
    _ => 0.9,
  };

  /// Movement for every catalog item on [day], walked back from today's
  /// stock so the register always reconciles.
  List<Movement> _movements(DateTime day) {
    final back = _today.difference(DateTime(day.year, day.month, day.day)).inDays.clamp(0, 400);
    var closing = [for (final c in _catalog) c.$5];
    late List<Movement> result;
    for (var k = 0; k <= back; k++) {
      final d = _today.subtract(Duration(days: k));
      final dayKey = d.difference(DateTime(2026)).inDays;
      final moves = <Movement>[];
      for (var i = 0; i < _catalog.length; i++) {
        final pace = _catalog[i].$7;
        final sale = (pace * _dayFactor(d) * (0.6 + 0.8 * _noise(i, dayKey))).round();
        // Beer comes in by the case every few days.
        var purchase = 0;
        if (pace > 0 && (dayKey + i) % 4 == 0) purchase = pace >= 8 ? 96 : (pace >= 3 ? 48 : 12);
        final c = closing[i];
        if (purchase > c + sale) purchase = 0;
        final opening = c + sale - purchase;
        moves.add(Movement(opening: opening, purchase: purchase, sale: sale, closing: c));
      }
      result = moves;
      closing = [for (final m in moves) m.opening];
    }
    return result;
  }

  @override
  Future<List<StockItem>> stock() async => [
    for (final c in _catalog)
      StockItem(
        code: _code(c.$1, c.$2),
        name: c.$1,
        packing: c.$2,
        category: c.$3,
        qty: c.$5,
        reorderLevel: c.$6,
        mrp: c.$4,
      ),
  ];

  @override
  Future<BrandwiseReport> brandwise(DateTime day) async {
    final moves = _movements(day);
    final rows = <String, BrandwiseRow>{};
    for (var i = 0; i < _catalog.length; i++) {
      final c = _catalog[i];
      final m = moves[i];
      if (m.opening == 0 && m.purchase == 0 && m.sale == 0 && m.closing == 0) continue;
      final row = rows.putIfAbsent(c.$1, () => BrandwiseRow(brand: c.$1, category: c.$3, bySize: {}));
      row.bySize[c.$2] = m;
    }
    return BrandwiseReport(date: day, rows: rows.values.toList());
  }

  @override
  Future<DailySales> dailySales(DateTime day) async {
    final moves = _movements(day);
    var total = 0.0;
    var bottles = 0;
    final byCat = <String, (double, int)>{};
    for (var i = 0; i < _catalog.length; i++) {
      final c = _catalog[i];
      final amount = moves[i].sale * c.$4;
      total += amount;
      bottles += moves[i].sale;
      final prev = byCat[c.$3] ?? (0.0, 0);
      byCat[c.$3] = (prev.$1 + amount, prev.$2 + moves[i].sale);
    }
    const profile = [2, 3, 4, 4, 5, 5, 6, 8, 11, 14, 15, 13, 10]; // 10 AM … 10 PM
    // Today only has hours up to now; spread today's total over those.
    final isToday = DateTime(day.year, day.month, day.day) == _today;
    // Before 10 AM the shop hasn't opened yet, so show the full business day.
    final lastHour = isToday && _now.hour >= 10 ? (_now.hour - 10).clamp(0, 12) : 12;
    var sum = 0;
    for (var h = 0; h <= lastHour; h++) {
      sum += profile[h];
    }
    final byHour = [for (var h = 0; h < profile.length; h++) h > lastHour ? 0.0 : total * profile[h] / sum];
    final dayKey = day.difference(DateTime(2026)).inDays;
    final upi = 0.52 + 0.1 * _noise(99, dayKey);
    final card = 0.08 + 0.05 * _noise(98, dayKey);
    return DailySales(
      date: day,
      total: total,
      bills: (bottles / 2.4).round(),
      bottles: bottles,
      byCategory: [
        for (final cat in BrandwiseReport.categoryOrder)
          if (byCat[cat] != null) CategoryAmount(cat, byCat[cat]!.$1, byCat[cat]!.$2),
      ],
      byHour: byHour,
      paymentMix: [
        PayModeShare('UPI', total * upi),
        PayModeShare('Cash', total * (1 - upi - card)),
        PayModeShare('Card', total * card),
      ],
      returns: _noise(97, dayKey) > 0.8 ? 360 : 0,
    );
  }

  @override
  Future<OwnerSnapshot> snapshot() async {
    final today = await dailySales(_today);
    final week = [for (var k = 6; k >= 0; k--) await dailySales(_today.subtract(Duration(days: k)))];
    final lastWeekSameDay = await dailySales(_today.subtract(const Duration(days: 7)));
    final items = await stock();
    final moves = _movements(_today);
    final top = [
      for (var i = 0; i < _catalog.length; i++)
        TopSeller(
          name: _catalog[i].$1,
          packing: _catalog[i].$2,
          qty: moves[i].sale,
          amount: moves[i].sale * _catalog[i].$4,
        ),
    ]..sort((a, b) => b.amount.compareTo(a.amount));
    final low = items.where((s) => s.isLow).toList()..sort((a, b) => a.qty.compareTo(b.qty));
    return OwnerSnapshot(
      storeName: storeName,
      lastSyncedAt: _now.subtract(const Duration(minutes: 2)),
      todaySales: today.total,
      todayBills: today.bills,
      salesDeltaPercent: lastWeekSameDay.total == 0
          ? null
          : (today.total - lastWeekSameDay.total) * 100 / lastWeekSameDay.total,
      last7Days: [for (final d in week) DayPoint(d.date, d.total)],
      paymentMix: today.paymentMix,
      topSelling: top.take(4).toList(),
      lowStock: [
        for (final s in low) LowStockItem(name: s.name, packing: s.packing, qty: s.qty, reorderLevel: s.reorderLevel),
      ],
      totalBottles: items.fold(0, (a, s) => a + s.qty),
      stockByCategory: [
        for (final cat in BrandwiseReport.categoryOrder)
          CategoryStock(cat, items.where((s) => s.category == cat).fold(0, (a, s) => a + s.qty)),
      ],
    );
  }
}
