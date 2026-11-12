import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/models.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/dot_digits.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.data, this.isDemo = false});

  final OwnerSnapshot data;
  final bool isDemo;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 8, 16, 120),
      children: [
        _TopBar(data: data, isDemo: isDemo),
        const SizedBox(height: 16),
        _TodayHero(data: data),
        const SizedBox(height: 12),
        _WeekCard(days: data.last7Days),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _LowStockCard(items: data.lowStock)),
              const SizedBox(width: 12),
              Expanded(
                child: _StockCard(total: data.totalBottles, byCategory: data.stockByCategory),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _PaymentsCard(mix: data.paymentMix),
        const SizedBox(height: 12),
        _TopSellersCard(items: data.topSelling),
      ],
    );
  }
}

// ── pieces ──────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.data, required this.isDemo});
  final OwnerSnapshot data;
  final bool isDemo;

  @override
  Widget build(BuildContext context) {
    final ago = DateTime.now().difference(data.lastSyncedAt);
    final fresh = ago.inMinutes < 10;
    final agoText = ago.inMinutes < 1
        ? 'just now'
        : ago.inMinutes < 60
        ? '${ago.inMinutes} min ago'
        : '${ago.inHours} h ago';
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          padding: const EdgeInsets.all(9),
          decoration: const BoxDecoration(color: C.ink, shape: BoxShape.circle),
          child: SvgPicture.asset('assets/brand/caskly_mark_light.svg'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.storeName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: label(color: C.ink, size: 17, weight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(color: fresh ? C.up : C.gold, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Counter synced $agoText',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: label(size: 12, weight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (isDemo)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              border: Border.all(color: C.ink.withValues(alpha: 0.15)),
              borderRadius: BorderRadius.circular(R.pill),
            ),
            child: Text(
              'Demo data',
              style: label(color: C.ink, size: 11, weight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}

class _TodayHero extends StatelessWidget {
  const _TodayHero({required this.data});
  final OwnerSnapshot data;

  @override
  Widget build(BuildContext context) {
    final delta = data.salesDeltaPercent;
    final weekday = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][DateTime.now().weekday - 1];
    return FlatCard(
      color: C.wheat,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Today's sales", style: label(color: C.ink.withValues(alpha: 0.6), size: 14)),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, c) {
              final digits = inr(data.todaySales);
              // Fit the dot matrix to the card width.
              final cols = digits.split('').fold<int>(0, (s, ch) => s + (ch == ',' ? 2 : 5) + 2) - 2;
              final step = ((c.maxWidth - 26) / cols).clamp(4.0, 9.0);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 8),
                    child: Text('₹', style: figure(20, weight: FontWeight.w500)),
                  ),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: DotDigits(digits, dot: step * 0.74, gap: step * 0.26, color: C.ink),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (delta != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(R.pill)),
                  child: Text(
                    '${delta >= 0 ? '↑' : '↓'} ${delta.abs().toStringAsFixed(1)}% vs last $weekday',
                    style: label(color: C.cream, size: 12, weight: FontWeight.w700),
                  ),
                ),
              Text(
                '${data.todayBills} bills  ·  avg ₹${inr(data.avgBill)}',
                style: label(color: C.ink.withValues(alpha: 0.7), size: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.days});
  final List<DayPoint> days;

  @override
  Widget build(BuildContext context) {
    final max = days.fold<double>(0, (m, d) => d.amount > m ? d.amount : m);
    final total = days.fold<double>(0, (s, d) => s + d.amount);
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return FlatCard(
      color: C.ink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Last 7 days',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: label(color: C.cream.withValues(alpha: 0.6), size: 14),
                ),
              ),
              const SizedBox(width: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '₹',
                      style: figure(14, color: C.cream, weight: FontWeight.w500),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      inr(total),
                      style: figure(22, color: C.cream, weight: FontWeight.w400),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 130,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < days.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            compactInr(days[i].amount),
                            style: label(
                              color: i == days.length - 1 ? C.gold : C.cream.withValues(alpha: 0.5),
                              size: 10,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: max == 0 ? 6 : 6 + 72 * (days[i].amount / max),
                          decoration: BoxDecoration(
                            color: i == days.length - 1 ? C.gold : C.cream.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            i == days.length - 1 ? 'Today' : letters[days[i].date.weekday - 1],
                            style: label(
                              color: i == days.length - 1 ? C.cream : C.cream.withValues(alpha: 0.45),
                              size: 11,
                            ),
                          ),
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

class _LowStockCard extends StatelessWidget {
  const _LowStockCard({required this.items});
  final List<LowStockItem> items;

  @override
  Widget build(BuildContext context) => FlatCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Low stock', style: label(size: 14)),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${items.length}', style: figure(44, color: items.isEmpty ? C.ink : C.down)),
            const SizedBox(width: 6),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  items.length == 1 ? 'brand' : 'brands',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: label(size: 12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final i in items.take(2))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${i.name} · ${i.qty} left',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: label(color: C.ink, size: 12, weight: FontWeight.w600),
            ),
          ),
        if (items.isEmpty) Text('All good', style: label(color: C.up, size: 12)),
      ],
    ),
  );
}

class _StockCard extends StatelessWidget {
  const _StockCard({required this.total, required this.byCategory});
  final int total;
  final List<CategoryStock> byCategory;

  @override
  Widget build(BuildContext context) => FlatCard(
    color: C.cream,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('In stock', style: label(size: 14)),
        const SizedBox(height: 14),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(inr(total), style: figure(44)),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('bottles', style: label(size: 12)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(R.pill),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                for (var i = 0; i < byCategory.length; i++)
                  Expanded(
                    flex: byCategory[i].bottles,
                    child: Container(
                      margin: EdgeInsets.only(left: i == 0 ? 0 : 2),
                      color: const [C.ink, C.gold, C.goldInk][i % 3],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < byCategory.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: const [C.ink, C.gold, C.goldInk][i % 3], shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    byCategory[i].category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: label(size: 11, weight: FontWeight.w500),
                  ),
                ),
                Text(
                  inr(byCategory[i].bottles),
                  style: label(color: C.ink, size: 11, weight: FontWeight.w700),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _PaymentsCard extends StatelessWidget {
  const _PaymentsCard({required this.mix});
  final List<PayModeShare> mix;

  @override
  Widget build(BuildContext context) {
    final total = mix.fold<double>(0, (s, m) => s + m.amount);
    const colors = [C.gold, C.ink, C.wheat];
    return FlatCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payments today', style: label(size: 14)),
          const SizedBox(height: 16),
          SizedBox(
            height: 44,
            child: Row(
              children: [
                for (var i = 0; i < mix.length; i++)
                  Expanded(
                    flex: (mix[i].amount * 100 / (total == 0 ? 1 : total)).round().clamp(8, 100),
                    child: Container(
                      margin: EdgeInsets.only(left: i == 0 ? 0 : 4),
                      decoration: BoxDecoration(color: colors[i % 3], borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 0; i < mix.length; i++)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: colors[i % 3],
                              shape: BoxShape.circle,
                              border: colors[i % 3] == C.wheat ? Border.all(color: C.line) : null,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(mix[i].mode, style: label(size: 12)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('₹${inr(mix[i].amount)}', style: figure(18, weight: FontWeight.w400)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopSellersCard extends StatelessWidget {
  const _TopSellersCard({required this.items});
  final List<TopSeller> items;

  @override
  Widget build(BuildContext context) => FlatCard(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Top sellers today', style: label(size: 14)),
        const SizedBox(height: 8),
        for (var i = 0; i < items.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: i == 0 ? null : const Border(top: BorderSide(color: C.line)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: i == 0 ? C.gold : C.canvas, borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    '${i + 1}',
                    style: label(color: C.ink, size: 13, weight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        items[i].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: label(color: C.ink, size: 14, weight: FontWeight.w700),
                      ),
                      Text(
                        '${items[i].packing} · ${items[i].qty} sold',
                        style: label(size: 12, weight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                Text('₹${inr(items[i].amount)}', style: figure(17, weight: FontWeight.w400)),
              ],
            ),
          ),
      ],
    ),
  );
}
