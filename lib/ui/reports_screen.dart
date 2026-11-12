import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/repository.dart';
import 'theme.dart';
import 'widgets/common.dart';

/// Daily sales and the brandwise stock register for any past day.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.repo});
  final OwnerRepository repo;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _tab = const int.fromEnvironment('REPORT_TAB');
  late DateTime _day = _today;
  late Future<DailySales> _sales = widget.repo.dailySales(_day);
  late Future<BrandwiseReport> _register = widget.repo.brandwise(_day);

  static DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  void _pick(DateTime d) => setState(() {
    _day = d;
    _sales = widget.repo.dailySales(d);
    _register = widget.repo.brandwise(d);
  });

  Future<void> _pickOlder() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: _today.subtract(const Duration(days: 365)),
      lastDate: _today,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: C.ink, onPrimary: C.cream),
        ),
        child: child!,
      ),
    );
    if (d != null) _pick(d);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return ListView(
      padding: EdgeInsets.fromLTRB(16, top + 12, 16, 120),
      children: [
        const ScreenTitle('Reports'),
        const SizedBox(height: 16),
        PillTabs(
          labels: const ['Daily sales', 'Brandwise stock'],
          expand: true,
          selected: _tab,
          onSelected: (i) => setState(() => _tab = i),
        ),
        const SizedBox(height: 12),
        _DayStrip(day: _day, onPick: _pick, onMore: _pickOlder),
        const SizedBox(height: 16),
        if (_tab == 0)
          Loader<DailySales>(key: ValueKey('s$_day'), future: _sales, builder: (context, s) => _DailySalesView(s))
        else
          Loader<BrandwiseReport>(
            key: ValueKey('b$_day'),
            future: _register,
            builder: (context, r) => _BrandwiseView(r),
          ),
      ],
    );
  }
}

/// The last two weeks as tappable day chips, plus a calendar for older days.
class _DayStrip extends StatelessWidget {
  const _DayStrip({required this.day, required this.onPick, required this.onMore});
  final DateTime day;
  final ValueChanged<DateTime> onPick;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final days = [for (var k = 0; k < 14; k++) today.subtract(Duration(days: k))];
    final inStrip = days.contains(day);
    return SizedBox(
      height: 68,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          if (i == days.length) {
            return _chip(
              selected: !inStrip,
              top: inStrip ? 'More' : monthShort[day.month - 1],
              bottom: inStrip ? null : '${day.day}',
              icon: inStrip ? Icons.calendar_month_rounded : null,
              onTap: onMore,
            );
          }
          final d = days[i];
          return _chip(
            selected: d == day,
            top: i == 0 ? 'Today' : weekdayShort[d.weekday - 1],
            bottom: '${d.day}',
            onTap: () => onPick(d),
          );
        },
      ),
    );
  }

  Widget _chip({
    required bool selected,
    required String top,
    String? bottom,
    IconData? icon,
    required VoidCallback onTap,
  }) {
    final fg = selected ? C.cream : C.ink;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 56,
        decoration: BoxDecoration(color: selected ? C.ink : C.paper, borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(top, style: label(color: selected ? C.cream.withValues(alpha: 0.7) : C.muted, size: 11)),
            const SizedBox(height: 4),
            if (icon != null)
              Icon(icon, size: 20, color: fg)
            else
              Text(
                bottom ?? '',
                style: figure(20, color: fg, weight: FontWeight.w500),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Daily sales ─────────────────────────────────────────────────────────

class _DailySalesView extends StatelessWidget {
  const _DailySalesView(this.s);
  final DailySales s;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FlatCard(
          color: C.wheat,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sales · ${dayLabel(s.date)}', style: label(color: C.ink.withValues(alpha: 0.6), size: 14)),
              const SizedBox(height: 14),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6, right: 4),
                      child: Text('₹', style: figure(22, weight: FontWeight.w500)),
                    ),
                    Text(inr(s.total), style: figure(60)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _Stat('Bills', inr(s.bills)),
                  _Stat('Avg bill', '₹${inr(s.avgBill)}'),
                  _Stat('Bottles', inr(s.bottles)),
                ],
              ),
              if (s.returns > 0) ...[
                const SizedBox(height: 12),
                Text(
                  'Returns ₹${inr(s.returns)}',
                  style: label(color: C.down, size: 12, weight: FontWeight.w700),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _HourlyCard(s.byHour),
        const SizedBox(height: 12),
        _CategoryCard(s.byCategory, s.total),
        const SizedBox(height: 12),
        _PayCard(s.paymentMix),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.k, this.v);
  final String k;
  final String v;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: label(color: C.ink.withValues(alpha: 0.55), size: 12)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(v, style: figure(22, weight: FontWeight.w400)),
        ),
      ],
    ),
  );
}

class _HourlyCard extends StatelessWidget {
  const _HourlyCard(this.byHour);
  final List<double> byHour;

  static String _hour(int i) {
    final h = 10 + i;
    return h == 12 ? '12p' : (h > 12 ? '${h - 12}p' : '${h}a');
  }

  @override
  Widget build(BuildContext context) {
    final max = byHour.fold<double>(0, (m, v) => v > m ? v : m);
    var peak = 0;
    for (var i = 1; i < byHour.length; i++) {
      if (byHour[i] > byHour[peak]) peak = i;
    }
    return FlatCard(
      color: C.ink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('By hour', style: label(color: C.cream.withValues(alpha: 0.6), size: 14)),
              ),
              if (max > 0)
                Text(
                  'Busiest ${_hour(peak)}–${_hour(peak + 1)}',
                  style: label(color: C.gold, size: 12, weight: FontWeight.w700),
                ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < byHour.length; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: max == 0 ? 4 : 4 + 74 * byHour[i] / max,
                          decoration: BoxDecoration(
                            color: i == peak && max > 0 ? C.gold : C.cream.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 14,
                          child: i.isEven
                              ? FittedBox(
                                  child: Text(_hour(i), style: label(color: C.cream.withValues(alpha: 0.45), size: 10)),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard(this.cats, this.total);
  final List<CategoryAmount> cats;
  final double total;

  @override
  Widget build(BuildContext context) => FlatCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('By category', style: label(size: 14)),
        const SizedBox(height: 6),
        for (var i = 0; i < cats.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        cats[i].category,
                        style: label(color: C.ink, size: 14, weight: FontWeight.w700),
                      ),
                    ),
                    Text('${inr(cats[i].bottles)} btl  ', style: label(size: 12, weight: FontWeight.w500)),
                    Text('₹${inr(cats[i].amount)}', style: figure(17, weight: FontWeight.w400)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(R.pill),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : cats[i].amount / total,
                    minHeight: 8,
                    backgroundColor: C.canvas,
                    color: const [C.ink, C.gold, C.goldInk][i % 3],
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _PayCard extends StatelessWidget {
  const _PayCard(this.mix);
  final List<PayModeShare> mix;

  @override
  Widget build(BuildContext context) {
    final total = mix.fold<double>(0, (a, m) => a + m.amount);
    return FlatCard(
      child: Row(
        children: [
          for (var i = 0; i < mix.length; i++)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mix[i].mode, style: label(size: 12)),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text('₹${inr(mix[i].amount)}', style: figure(19, weight: FontWeight.w400)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    total == 0 ? '—' : '${(mix[i].amount * 100 / total).round()}%',
                    style: label(color: C.goldInk, size: 12, weight: FontWeight.w700),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Brandwise register ──────────────────────────────────────────────────

class _BrandwiseView extends StatelessWidget {
  const _BrandwiseView(this.r);
  final BrandwiseReport r;

  @override
  Widget build(BuildContext context) {
    final t = r.total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FlatCard(
          color: C.ink,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bottles · ${dayLabel(r.date)}', style: label(color: C.cream.withValues(alpha: 0.6), size: 14)),
              const SizedBox(height: 16),
              Row(
                children: [
                  _Big('Opening', t.opening),
                  _Big('In', t.purchase),
                  _Big('Sold', t.sale),
                  _Big('Closing', t.closing, gold: true),
                ],
              ),
            ],
          ),
        ),
        for (final cat in BrandwiseReport.categoryOrder)
          if (r.rows.any((x) => x.category == cat)) ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      cat.toUpperCase(),
                      style: label(color: C.ink, size: 12, weight: FontWeight.w800),
                    ),
                  ),
                  Text('${inr(r.totalFor(cat).closing)} closing', style: label(size: 12)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            for (final row in r.rows.where((x) => x.category == cat)) ...[_BrandTile(row), const SizedBox(height: 8)],
          ],
        const SizedBox(height: 8),
        Text(
          'Same figures as the counter\'s Brandwise Stock Report.',
          textAlign: TextAlign.center,
          style: label(size: 12, weight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _Big extends StatelessWidget {
  const _Big(this.k, this.v, {this.gold = false});
  final String k;
  final int v;
  final bool gold;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: label(color: C.cream.withValues(alpha: 0.5), size: 11)),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            inr(v),
            style: figure(26, color: gold ? C.gold : C.cream, weight: FontWeight.w400),
          ),
        ),
      ],
    ),
  );
}

class _BrandTile extends StatefulWidget {
  const _BrandTile(this.row);
  final BrandwiseRow row;

  @override
  State<_BrandTile> createState() => _BrandTileState();
}

class _BrandTileState extends State<_BrandTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final t = row.total;
    return Material(
      color: C.paper,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => setState(() => _open = !_open),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      row.brand,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: label(color: C.ink, size: 15, weight: FontWeight.w700),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(Icons.expand_more_rounded, color: C.muted),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _MoveRow(t, header: true),
              if (_open) ...[
                const SizedBox(height: 10),
                for (final e in row.bySize.entries)
                  Container(
                    padding: const EdgeInsets.only(top: 10),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: C.line)),
                    ),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [SizeChip(e.key), const SizedBox(height: 8), _MoveRow(e.value)],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// O / In / Sold / Closing in four even columns.
class _MoveRow extends StatelessWidget {
  const _MoveRow(this.m, {this.header = false});
  final Movement m;
  final bool header;

  @override
  Widget build(BuildContext context) {
    Widget col(String k, int v, {bool strong = false}) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k, style: label(size: 10, weight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
            v == 0 ? '–' : inr(v),
            style: figure(
              header ? 20 : 17,
              color: strong ? C.goldInk : C.ink,
              weight: strong ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
    return Row(
      children: [
        col('Opening', m.opening),
        col('In', m.purchase),
        col('Sold', m.sale),
        col('Closing', m.closing, strong: true),
      ],
    );
  }
}
