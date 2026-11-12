import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/models.dart';
import 'data/repository.dart';
import 'ui/home_screen.dart';
import 'ui/reports_screen.dart';
import 'ui/stock_screen.dart';
import 'ui/theme.dart';
import 'ui/widgets/common.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
  runApp(const CasklyOwnerApp());
}

class CasklyOwnerApp extends StatelessWidget {
  const CasklyOwnerApp({super.key});

  @override
  Widget build(BuildContext context) =>
      MaterialApp(title: 'Caskly Owner', debugShowCheckedModeBanner: false, theme: buildTheme(), home: const _Shell());
}

class _Shell extends StatefulWidget {
  const _Shell();

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  // Dev aid: --dart-define=TAB=1 opens on Stock (for simulator screenshots).
  int _tab = const int.fromEnvironment('TAB');
  final OwnerRepository _repo = DemoRepository();
  late final Future<OwnerSnapshot> _snapshot = _repo.snapshot();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      // Keep each tab alive so scroll position and filters survive switching.
      body: IndexedStack(
        index: _tab,
        children: [
          Loader<OwnerSnapshot>(
            future: _snapshot,
            builder: (context, data) => HomeScreen(data: data, isDemo: _repo.isDemo),
          ),
          StockScreen(repo: _repo),
          ReportsScreen(repo: _repo),
          Center(child: Text('Account — coming next', style: label(size: 15))),
        ],
      ),
      bottomNavigationBar: _NavPill(index: _tab, onTap: (i) => setState(() => _tab = i)),
    );
  }
}

/// Floating ink pill with four tabs; the active one sits on gold.
class _NavPill extends StatelessWidget {
  const _NavPill({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  static const _items = [
    (Icons.space_dashboard_rounded, 'Home'),
    (Icons.inventory_2_rounded, 'Stock'),
    (Icons.receipt_long_rounded, 'Reports'),
    (Icons.person_rounded, 'Account'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        height: 64,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(R.pill)),
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                flex: i == index ? 2 : 1,
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    decoration: BoxDecoration(
                      color: i == index ? C.gold : Colors.transparent,
                      borderRadius: BorderRadius.circular(R.pill),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_items[i].$1, size: 22, color: i == index ? C.ink : C.cream.withValues(alpha: 0.6)),
                        if (i == index) ...[
                          const SizedBox(width: 8),
                          Text(
                            _items[i].$2,
                            style: label(color: C.ink, size: 13, weight: FontWeight.w800),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
