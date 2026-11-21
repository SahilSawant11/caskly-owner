import 'models.dart';

/// Everything the owner app reads. The demo source below is used until a
/// server is connected; an API source will implement the same calls.
abstract class OwnerRepository {
  bool get isDemo;
  String get storeName;

  /// The shop's business day (reports are picked relative to it).
  DateTime get today;
  Future<OwnerSnapshot> snapshot();
  Future<List<StockItem>> stock();
  Future<DailySales> dailySales(DateTime day);
  Future<BrandwiseReport> brandwise(DateTime day);

  /// Bottles per permit over [from]..[to] (whole days).
  Future<LicenseHolderReport> licenseHolders(DateTime from, DateTime to);
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

  @override
  DateTime get today => _today;

  // name, size, category, MRP, on hand today, reorder level, daily pace,
  // counter brand (the line it joins on Counter Brandwise)
  static const _catalog = <(String, String, String, double, int, int, int, String)>[
    ('Kingfisher Strong', '650 ML', 'Strong Beer', 180, 240, 48, 22, 'Kingfisher Strong'),
    ('Kingfisher Strong', '500 ML (CAN)', 'Strong Beer', 190, 96, 48, 9, 'Kingfisher Strong'),
    ('Kingfisher Ultra Max', '650 ML', 'Strong Beer', 230, 4, 24, 3, 'Kingfisher Strong'),
    ('Tuborg Strong', '650 ML', 'Strong Beer', 170, 132, 48, 11, 'Tuborg Strong'),
    ('Tuborg Strong', '500 ML (CAN)', 'Strong Beer', 180, 72, 24, 5, 'Tuborg Strong'),
    ('Budweiser Magnum', '650 ML', 'Strong Beer', 210, 96, 24, 7, 'Budweiser Magnum'),
    ('Budweiser Magnum', '500 ML (CAN)', 'Strong Beer', 190, 120, 48, 10, 'Budweiser Magnum'),
    ('Haywards 5000', '650 ML', 'Strong Beer', 150, 144, 48, 9, 'Haywards 5000'),
    ('Carlsberg Elephant', '650 ML', 'Strong Beer', 200, 60, 24, 4, 'Carlsberg Elephant'),
    ('Bira 91 Boom', '650 ML', 'Strong Beer', 190, 30, 24, 3, 'Bira 91 Boom'),
    ('Godfather Strong', '650 ML', 'Strong Beer', 160, 0, 24, 2, 'Godfather Strong'),
    ('Kingfisher Premium', '650 ML', 'Mild Beer', 160, 120, 48, 9, 'Kingfisher Premium'),
    ('Kingfisher Premium', '330 ML (CAN)', 'Mild Beer', 110, 96, 48, 7, 'Kingfisher Premium'),
    ('Budweiser', '650 ML', 'Mild Beer', 200, 84, 24, 6, 'Budweiser'),
    ('Budweiser', '330 ML (CAN)', 'Mild Beer', 130, 72, 24, 6, 'Budweiser'),
    ('Heineken', '650 ML', 'Mild Beer', 220, 48, 24, 3, 'Heineken'),
    ('Corona Extra', '330 ML', 'Mild Beer', 260, 24, 12, 2, 'Corona Extra'),
    ('Bira 91 White', '330 ML (CAN)', 'Fermented Beer', 140, 7, 24, 4, 'Bira 91 White'),
    ('Hoegaarden', '330 ML', 'Fermented Beer', 250, 18, 12, 1, 'Hoegaarden'),
    ('Sula Shiraz', '750 ML', 'Wine', 820, 12, 6, 1, 'Sula'),
    ('Sula Shiraz', '375 ML', 'Wine', 430, 8, 6, 1, 'Sula'),
    ('Sula Chenin Blanc', '750 ML', 'Wine', 790, 2, 6, 1, 'Sula'),
    ('Grover La Reserve', '750 ML', 'Wine', 1450, 6, 4, 0, 'Grover La Reserve'),
    ('Big Banyan Merlot', '750 ML', 'Wine', 900, 10, 6, 1, 'Big Banyan Merlot'),
    ('Golconda Port Wine', '180 ML', 'Wine', 90, 60, 24, 4, 'Golconda Port Wine'),
    ('Golconda Port Wine', '1000 ML', 'Wine', 380, 12, 6, 1, 'Golconda Port Wine'),
  ];

  /// Permit holders the counter rotates bills through.
  static const _holders = <(String, String)>[
    ('LT-1001', 'RAMESH PATIL'),
    ('LT-1002', 'SURESH JADHAV'),
    ('LT-1003', 'ANIL SHINDE'),
    ('LT-1004', 'PRAKASH MORE'),
    ('LT-1005', 'VIJAY KALE'),
    ('LT-1006', 'SANJAY PAWAR'),
    ('OT-2207', 'WALK-IN (ONE TIME)'),
  ];

  /// The day's delivery TP number (one delivery a day in the demo).
  static String _tpFor(int dayKey) => 'TP-${4000 + (dayKey * 37) % 5000}';

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
  /// stock so the register always reconciles. Now and then a customer
  /// brings a bottle back: it counts on that day (net sale = sold − back).
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
        final sold = (pace * _dayFactor(d) * (0.6 + 0.8 * _noise(i, dayKey))).round();
        // Beer comes in by the case every few days.
        var purchase = 0;
        if (pace > 0 && (dayKey + i) % 4 == 0) purchase = pace >= 8 ? 96 : (pace >= 3 ? 48 : 12);
        final c = closing[i];
        var returned = pace > 0 && _noise(i + 500, dayKey) > 0.9 ? 1 + (_noise(i + 700, dayKey) > 0.7 ? 1 : 0) : 0;
        if (purchase > c + sold - returned) purchase = 0;
        if (c + sold - returned - purchase < 0) returned = 0;
        final opening = c + sold - returned - purchase;
        moves.add(Movement(opening: opening, purchase: purchase, sale: sold - returned, closing: c, returned: returned));
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
    final dayKey = DateTime(day.year, day.month, day.day).difference(DateTime(2026)).inDays;
    return BrandwiseReport(date: day, lines: [
      for (var i = 0; i < _catalog.length; i++)
        if (moves[i].opening != 0 || moves[i].purchase != 0 || moves[i].sale != 0 || moves[i].closing != 0)
          RegisterLine(
            name: _catalog[i].$1,
            size: _catalog[i].$2,
            category: _catalog[i].$3,
            counterBrand: _catalog[i].$8,
            m: moves[i],
            tps: moves[i].purchase > 0 ? [_tpFor(dayKey)] : const [],
          ),
    ]);
  }

  @override
  Future<LicenseHolderReport> licenseHolders(DateTime from, DateTime to) async {
    final agg = <String, (int, int, double)>{}; // permit → bills, bottles, ₹
    for (var d = DateTime(from.year, from.month, from.day);
        !d.isAfter(DateTime(to.year, to.month, to.day));
        d = DateTime(d.year, d.month, d.day + 1)) {
      if (d.isAfter(_today)) break;
      final s = await dailySales(d);
      if (s.bills == 0) continue;
      final dayKey = d.difference(DateTime(2026)).inDays;
      // Bills rotate through the permits; bottles and ₹ follow the bills.
      final n = _holders.length;
      for (var k = 0; k < n; k++) {
        final bills = s.bills ~/ n + (k < s.bills % n ? 1 : 0);
        if (bills == 0) continue;
        final permit = _holders[(dayKey + k) % n].$1;
        final prev = agg[permit] ?? (0, 0, 0.0);
        agg[permit] = (
          prev.$1 + bills,
          prev.$2 + (s.bottles * bills / s.bills).round(),
          prev.$3 + s.total * bills / s.bills,
        );
      }
      // The day's returns come off the permit on whose bill they were sold.
      if (s.returnedBottles > 0) {
        final permit = _holders[dayKey % n].$1;
        final prev = agg[permit] ?? (0, 0, 0.0);
        agg[permit] = (prev.$1, prev.$2 - s.returnedBottles, prev.$3 - s.returns);
      }
    }
    final names = {for (final h in _holders) h.$1: h.$2};
    final rows = [
      for (final e in agg.entries)
        LicenseHolderRow(permitNo: e.key, name: names[e.key]!, bills: e.value.$1, bottles: e.value.$2, amount: e.value.$3),
    ]..sort((a, b) => b.bottles.compareTo(a.bottles));
    return LicenseHolderReport(from: from, to: to, rows: rows);
  }

  @override
  Future<DailySales> dailySales(DateTime day) async {
    final moves = _movements(day);
    var total = 0.0;
    var bottles = 0;
    final byCat = <String, (double, int)>{};
    var returnedBottles = 0;
    var returns = 0.0;
    for (var i = 0; i < _catalog.length; i++) {
      final c = _catalog[i];
      // The day's bills as sold; returns are shown apart, on their day.
      final sold = moves[i].sale + moves[i].returned;
      final amount = sold * c.$4;
      total += amount;
      bottles += sold;
      returnedBottles += moves[i].returned;
      returns += moves[i].returned * c.$4;
      final prev = byCat[c.$3] ?? (0.0, 0);
      byCat[c.$3] = (prev.$1 + amount, prev.$2 + sold);
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
      returns: returns,
      returnedBottles: returnedBottles,
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
          qty: moves[i].sale + moves[i].returned,
          amount: (moves[i].sale + moves[i].returned) * _catalog[i].$4,
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
