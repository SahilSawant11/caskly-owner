/// What the owner app shows. Field names follow the Caskly server's
/// `/api/dashboard/summary` and `/api/inventory` so the real API can
/// replace the demo source without touching the UI.
class OwnerSnapshot {
  const OwnerSnapshot({
    required this.storeName,
    required this.lastSyncedAt,
    required this.todaySales,
    required this.todayBills,
    required this.salesDeltaPercent,
    required this.last7Days,
    required this.paymentMix,
    required this.topSelling,
    required this.lowStock,
    required this.totalBottles,
    required this.stockByCategory,
  });

  final String storeName;

  /// When the counter last pushed to the server. The phone is only as
  /// fresh as this, so it is always shown.
  final DateTime lastSyncedAt;

  final double todaySales;
  final int todayBills;

  /// Today vs the same weekday last week; null when there's no history.
  final double? salesDeltaPercent;

  /// Oldest first; the last point is today.
  final List<DayPoint> last7Days;
  final List<PayModeShare> paymentMix;
  final List<TopSeller> topSelling;
  final List<LowStockItem> lowStock;
  final int totalBottles;
  final List<CategoryStock> stockByCategory;

  double get avgBill => todayBills == 0 ? 0 : todaySales / todayBills;
  double get weekSales => last7Days.fold(0, (s, d) => s + d.amount);
}

class DayPoint {
  const DayPoint(this.date, this.amount);
  final DateTime date;
  final double amount;
}

class PayModeShare {
  const PayModeShare(this.mode, this.amount);
  final String mode;
  final double amount;
}

class TopSeller {
  const TopSeller({required this.name, required this.packing, required this.qty, required this.amount});
  final String name;
  final String packing;
  final int qty;
  final double amount;
}

class LowStockItem {
  const LowStockItem({required this.name, required this.packing, required this.qty, required this.reorderLevel});
  final String name;
  final String packing;
  final int qty;
  final int reorderLevel;
}

class CategoryStock {
  const CategoryStock(this.category, this.bottles);
  final String category;
  final int bottles;
}

/// One product on hand (`/api/inventory`).
class StockItem {
  const StockItem({
    required this.code,
    required this.name,
    required this.packing,
    required this.category,
    required this.qty,
    required this.reorderLevel,
    required this.mrp,
  });
  final String code;
  final String name;
  final String packing;
  final String category;
  final int qty;
  final int reorderLevel;
  final double mrp;

  bool get isLow => qty <= reorderLevel;
  bool get isOut => qty <= 0;
}

/// One day's sales (`/api/reports/sales`).
class DailySales {
  const DailySales({
    required this.date,
    required this.total,
    required this.bills,
    required this.bottles,
    required this.byCategory,
    required this.byHour,
    required this.paymentMix,
    required this.returns,
    this.returnedBottles = 0,
  });
  final DateTime date;
  final double total;
  final int bills;
  final int bottles;
  final List<CategoryAmount> byCategory;

  /// Sales per hour of the day, index 0 = 10 AM … 12 = 10 PM.
  final List<double> byHour;
  final List<PayModeShare> paymentMix;

  /// Brought back by customers this day (any day's bills), ₹ and bottles.
  /// [total] and [bottles] are the day's bills as sold.
  final double returns;
  final int returnedBottles;

  double get avgBill => bills == 0 ? 0 : total / bills;
}

class CategoryAmount {
  const CategoryAmount(this.category, this.amount, this.bottles);
  final String category;
  final double amount;
  final int bottles;
}

/// Opening / purchase / sale / closing bottles for one brand and size.
/// [sale] is the day's net sale: bottles sold that day less bottles
/// customers brought back that day ([returned]). Returns count on the day
/// they happen, so a past day never changes (same rule as the counter).
class Movement {
  const Movement({required this.opening, required this.purchase, required this.sale, required this.closing, this.returned = 0});
  final int opening;
  final int purchase;
  final int sale;
  final int closing;
  final int returned;

  static const zero = Movement(opening: 0, purchase: 0, sale: 0, closing: 0);

  Movement operator +(Movement o) => Movement(
    opening: opening + o.opening,
    purchase: purchase + o.purchase,
    sale: sale + o.sale,
    closing: closing + o.closing,
    returned: returned + o.returned,
  );
}

/// One drink in one size on the excise register, with the TP numbers it
/// came in on that day.
class RegisterLine {
  const RegisterLine({
    required this.name,
    required this.size,
    required this.category,
    required this.counterBrand,
    required this.m,
    this.tps = const [],
  });
  final String name;
  final String size;
  final String category;
  final String counterBrand;
  final Movement m;
  final List<String> tps;
}

/// One counter brand of the Counter Brandwise register: its drinks added
/// up per size.
class BrandwiseRow {
  const BrandwiseRow({required this.brand, required this.category, required this.bySize});
  final String brand;
  final String category;
  final Map<String, Movement> bySize;

  Movement get total => bySize.values.fold(Movement.zero, (a, b) => a + b);
}

/// The day's register (`/api/reports/brandwise-stock`): one line per drink
/// and size; [rows] groups them by counter brand (Counter Brandwise).
class BrandwiseReport {
  const BrandwiseReport({required this.date, required this.lines});
  final DateTime date;
  final List<RegisterLine> lines;

  /// Register order, as on the counter.
  static const categoryOrder = ['Fermented Beer', 'Strong Beer', 'Mild Beer', 'Wine'];

  /// The register's size columns; sizes outside them (1000 ML…) follow.
  static const sizeOrder = ['750 ML', '375 ML', '180 ML', '650 ML', '500 ML (CAN)', '330 ML (CAN)', '330 ML'];

  static int compareSizes(String a, String b) {
    final x = sizeOrder.indexOf(a), y = sizeOrder.indexOf(b);
    if (x >= 0 && y >= 0) return x.compareTo(y);
    if (x >= 0) return -1;
    if (y >= 0) return 1;
    return (int.tryParse(RegExp(r'\d+').stringMatch(b) ?? '') ?? 0)
        .compareTo(int.tryParse(RegExp(r'\d+').stringMatch(a) ?? '') ?? 0);
  }

  /// Lines of [category] in register order: by name, then size.
  List<RegisterLine> linesOf(String category) => lines.where((l) => l.category == category).toList()
    ..sort((a, b) {
      final byName = a.name.compareTo(b.name);
      return byName != 0 ? byName : compareSizes(a.size, b.size);
    });

  /// Counter Brandwise: one row per counter brand (names matched ignoring
  /// case), its drinks summed per size.
  List<BrandwiseRow> get rows {
    final out = <String, BrandwiseRow>{};
    for (final l in lines) {
      final key = '${l.category}|${l.counterBrand.toLowerCase()}';
      final row = out.putIfAbsent(key, () => BrandwiseRow(brand: l.counterBrand, category: l.category, bySize: {}));
      row.bySize[l.size] = (row.bySize[l.size] ?? Movement.zero) + l.m;
    }
    return out.values.toList()..sort((a, b) => a.brand.compareTo(b.brand));
  }

  Movement totalFor(String category) =>
      lines.where((l) => l.category == category).fold(Movement.zero, (a, l) => a + l.m);
  Movement get total => lines.fold(Movement.zero, (a, l) => a + l.m);
}

/// Bottles sold against one permit in a period. A bill counts on its own
/// day; bottles brought back come off on the day of the return.
class LicenseHolderRow {
  const LicenseHolderRow({
    required this.permitNo,
    required this.name,
    required this.bills,
    required this.bottles,
    required this.amount,
  });
  final String permitNo;
  final String name;
  final int bills;
  final int bottles;
  final double amount;
}

class LicenseHolderReport {
  const LicenseHolderReport({required this.from, required this.to, required this.rows});
  final DateTime from;
  final DateTime to;
  final List<LicenseHolderRow> rows;

  int get bills => rows.fold(0, (a, r) => a + r.bills);
  int get bottles => rows.fold(0, (a, r) => a + r.bottles);
  double get amount => rows.fold(0.0, (a, r) => a + r.amount);
}
