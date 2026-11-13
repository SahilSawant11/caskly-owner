import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/auth.dart';
import 'data/models.dart';
import 'data/repository.dart';
import 'ui/account_screen.dart';
import 'ui/home_screen.dart';
import 'ui/login_screen.dart';
import 'ui/reports_screen.dart';
import 'ui/stock_screen.dart';
import 'ui/theme.dart';
import 'ui/widgets/common.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
  runApp(CasklyOwnerApp(auth: apiUrl.isEmpty ? UnconfiguredAuth() : ApiAuth(baseUrl: apiUrl)));
}

class CasklyOwnerApp extends StatelessWidget {
  const CasklyOwnerApp({super.key, required this.auth});
  final AuthService auth;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Caskly Owner',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: AuthGate(auth: auth),
  );
}

/// Restores a saved session, otherwise shows sign-in (or the demo).
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.auth});
  final AuthService auth;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  // Dev aid: --dart-define=DEMO=true skips sign-in (simulator screenshots).
  static const _autoDemo = bool.fromEnvironment('DEMO');

  bool _restoring = true;
  AuthService? _active;
  OwnerAccount? _account;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    if (_autoDemo) return _enterDemo();
    OwnerAccount? account;
    try {
      account = await widget.auth.restore();
    } on AuthException catch (e) {
      _notice = e.message; // e.g. server unreachable — sign in again later
    }
    if (!mounted) return;
    setState(() {
      _restoring = false;
      if (account != null) {
        _active = widget.auth;
        _account = account;
      }
    });
  }

  Future<void> _enterDemo() async {
    final demo = DemoAuth();
    final account = await demo.account();
    if (!mounted) return;
    setState(() {
      _restoring = false;
      _active = demo;
      _account = account;
      _notice = null;
    });
  }

  void _signedIn(OwnerAccount account) => setState(() {
    _active = widget.auth;
    _account = account;
    _notice = null;
  });

  void _signedOut() => setState(() {
    _active = null;
    _account = null;
  });

  @override
  Widget build(BuildContext context) {
    if (_restoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: C.gold)));
    }
    final active = _active;
    if (active == null) {
      return LoginScreen(auth: widget.auth, onSignedIn: _signedIn, onDemo: _enterDemo, notice: _notice);
    }
    return Shell(
      // A new key per session so nothing from the previous one survives.
      key: ObjectKey(active),
      auth: active,
      account: _account!,
      onSignOut: _signedOut,
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key, required this.auth, required this.account, required this.onSignOut});
  final AuthService auth;
  final OwnerAccount account;
  final VoidCallback onSignOut;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  // Dev aid: --dart-define=TAB=1 opens on Stock (for simulator screenshots).
  int _tab = const int.fromEnvironment('TAB');

  // Sales/stock still come from the demo source; the server-backed
  // repository replaces this once the read endpoints are wired up.
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
          AccountScreen(auth: widget.auth, account: widget.account, onSignOut: widget.onSignOut),
        ],
      ),
      bottomNavigationBar: NavPill(index: _tab, onTap: (i) => setState(() => _tab = i)),
    );
  }
}

/// Floating ink pill with four icon-only tabs; the active one sits on gold.
class NavPill extends StatelessWidget {
  const NavPill({super.key, required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  static const items = [
    (Icons.home_rounded, 'Home'),
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
            for (var i = 0; i < items.length; i++)
              Expanded(
                // Labels go to screen readers only; the bar shows icons.
                child: Semantics(
                  label: items[i].$2,
                  button: true,
                  selected: i == index,
                  child: GestureDetector(
                    onTap: () => onTap(i),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      // Fill the whole cell so the gold pill is full height.
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: i == index ? C.gold : Colors.transparent,
                        borderRadius: BorderRadius.circular(R.pill),
                      ),
                      child: Icon(
                        items[i].$1,
                        size: 24,
                        color: i == index ? C.ink : C.cream.withValues(alpha: 0.6),
                      ),
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
