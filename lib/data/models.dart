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
  });
  final DateTime date;
  final double total;
  final int bills;
  final int bottles;
  final List<CategoryAmount> byCategory;

  /// Sales per hour of the day, index 0 = 10 AM … 12 = 10 PM.
  final List<double> byHour;
  final List<PayModeShare> paymentMix;
  final double returns;

  double get avgBill => bills == 0 ? 0 : total / bills;
}

class CategoryAmount {
  const CategoryAmount(this.category, this.amount, this.bottles);
  final String category;
  final double amount;
  final int bottles;
}

/// Opening / purchase / sale / closing bottles for one brand and size.
class Movement {
  const Movement({required this.opening, required this.purchase, required this.sale, required this.closing});
  final int opening;
  final int purchase;
  final int sale;
  final int closing;

  static const zero = Movement(opening: 0, purchase: 0, sale: 0, closing: 0);

  Movement operator +(Movement o) => Movement(
    opening: opening + o.opening,
    purchase: purchase + o.purchase,
    sale: sale + o.sale,
    closing: closing + o.closing,
  );
}

/// One brand row of the excise brandwise register
/// (`/api/reports/brandwise-stock`); sizes in register column order.
class BrandwiseRow {
  const BrandwiseRow({required this.brand, required this.category, required this.bySize});
  final String brand;
  final String category;
  final Map<String, Movement> bySize;

  Movement get total => bySize.values.fold(Movement.zero, (a, b) => a + b);
}

class BrandwiseReport {
  const BrandwiseReport({required this.date, required this.rows});
  final DateTime date;
  final List<BrandwiseRow> rows;

  /// Register order: Fermented Beer, Mild Beer, Wine.
  static const categoryOrder = ['Fermented Beer', 'Mild Beer', 'Wine'];

  Movement totalFor(String category) =>
      rows.where((r) => r.category == category).fold(Movement.zero, (a, r) => a + r.total);
  Movement get total => rows.fold(Movement.zero, (a, r) => a + r.total);
}
