import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/repository.dart';
import 'theme.dart';
import 'widgets/common.dart';

/// Stock on hand: search, category / low-stock filters, and a gauge per
/// product against its reorder level.
class StockScreen extends StatefulWidget {
  const StockScreen({super.key, required this.repo});
  final OwnerRepository repo;

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  late final Future<List<StockItem>> _future = widget.repo.stock();
  String _query = '';
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Loader<List<StockItem>>(
      future: _future,
      builder: (context, items) {
        final low = items.where((s) => s.isLow).length;
        final tabs = ['All', 'Low · $low', ...BrandwiseReport.categoryOrder];
        final q = _query.trim().toLowerCase();
        final shown =
            items.where((s) {
              if (q.isNotEmpty && !s.name.toLowerCase().contains(q) && !s.code.toLowerCase().contains(q)) return false;
              if (_tab == 1) return s.isLow;
              if (_tab >= 2) return s.category == tabs[_tab];
              return true;
            }).toList()..sort(
              (a, b) => _tab == 1 ? a.qty.compareTo(b.qty) : '${a.name}${a.packing}'.compareTo('${b.name}${b.packing}'),
            );
        final bottles = items.fold<int>(0, (a, s) => a + s.qty);
        final value = items.fold<double>(0, (a, s) => a + s.qty * s.mrp);

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 12, 16, 0),
              sliver: SliverList.list(
                children: [
                  ScreenTitle('Stock', subtitle: '${inr(bottles)} bottles · ₹${inr(value)} at MRP'),
                  const SizedBox(height: 16),
                  _SearchField(onChanged: (v) => setState(() => _query = v)),
                  const SizedBox(height: 12),
                  PillTabs(labels: tabs, selected: _tab, onSelected: (i) => setState(() => _tab = i)),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            if (shown.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    _tab == 1 && q.isEmpty ? 'Nothing is low. All good.' : 'No products match.',
                    style: label(size: 15),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                sliver: SliverList.separated(
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _StockRow(item: shown[i], onTap: () => _showDetail(shown[i])),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showDetail(StockItem s) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.paper,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(R.card))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.name,
                style: label(color: C.ink, size: 20, weight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  SizeChip(s.packing),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      s.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: label(size: 13, weight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(inr(s.qty), style: figure(56, color: s.isLow ? C.down : C.ink)),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(s.isOut ? 'out of stock' : 'bottles on hand', style: label(size: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _DetailLine('Reorder level', '${s.reorderLevel} bottles'),
              _DetailLine('MRP', '₹${inr(s.mrp)}'),
              _DetailLine('Stock value at MRP', '₹${inr(s.qty * s.mrp)}'),
              _DetailLine('SCM code', s.code),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    onChanged: onChanged,
    style: label(color: C.ink, size: 15, weight: FontWeight.w500),
    textInputAction: TextInputAction.search,
    decoration: InputDecoration(
      hintText: 'Search brand or code',
      hintStyle: label(size: 15, weight: FontWeight.w500),
      prefixIcon: const Icon(Icons.search_rounded, color: C.muted),
      filled: true,
      fillColor: C.paper,
      contentPadding: const EdgeInsets.symmetric(vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(R.pill), borderSide: BorderSide.none),
    ),
  );
}

class _StockRow extends StatelessWidget {
  const _StockRow({required this.item, required this.onTap});
  final StockItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = item;
    // Gauge: full at 3× the reorder level; the tick marks the reorder level.
    final full = (s.reorderLevel * 3).clamp(1, 1 << 30);
    final fill = (s.qty / full).clamp(0.0, 1.0);
    final tick = (s.reorderLevel / full).clamp(0.0, 1.0);
    final color = s.isLow ? C.down : C.ink;
    return Material(
      color: C.paper,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 18, 14),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: label(color: C.ink, size: 15, weight: FontWeight.w700),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            SizeChip(s.packing),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                s.category,
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
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        inr(s.qty),
                        style: figure(28, color: color, weight: FontWeight.w400),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s.isOut ? 'Out' : (s.isLow ? 'Low' : 'bottles'),
                        style: label(color: s.isLow ? C.down : C.muted, size: 11, weight: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, c) => SizedBox(
                  height: 6,
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(color: C.canvas, borderRadius: BorderRadius.circular(R.pill)),
                      ),
                      Container(
                        width: c.maxWidth * fill,
                        decoration: BoxDecoration(
                          color: s.isLow ? C.down : C.gold,
                          borderRadius: BorderRadius.circular(R.pill),
                        ),
                      ),
                      Positioned(
                        left: (c.maxWidth * tick - 1).clamp(0, c.maxWidth - 2),
                        top: 0,
                        bottom: 0,
                        child: Container(width: 2, color: C.ink.withValues(alpha: 0.35)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine(this.k, this.v);
  final String k;
  final String v;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: C.line)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(k, style: label(size: 14, weight: FontWeight.w500)),
        ),
        Text(
          v,
          style: label(color: C.ink, size: 14, weight: FontWeight.w700),
        ),
      ],
    ),
  );
}
