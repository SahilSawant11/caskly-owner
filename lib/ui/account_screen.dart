import 'package:flutter/material.dart';

import '../data/auth.dart';
import 'theme.dart';
import 'widgets/common.dart';

/// Who's signed in, which counters feed the app, password and sign-out.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, required this.auth, required this.account, required this.onSignOut, this.now});

  final AuthService auth;
  final OwnerAccount account;

  /// Signs out (real account) or leaves the demo (demo).
  final VoidCallback onSignOut;
  final DateTime? now;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late OwnerAccount _account = widget.account;

  Future<void> _refresh() async {
    try {
      final a = await widget.auth.account();
      if (mounted) setState(() => _account = a);
    } on SessionExpired {
      widget.onSignOut();
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _confirmSignOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: C.paper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.card)),
        title: Text('Sign out?', style: label(color: C.ink, size: 20, weight: FontWeight.w800)),
        content: Text(
          "You'll need your mobile number and password to sign in again.",
          style: label(size: 14, weight: FontWeight.w500),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: label(color: C.ink, size: 14, weight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Sign out', style: label(color: C.down, size: 14, weight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.auth.logout();
      widget.onSignOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final demo = widget.auth.isDemo;
    return RefreshIndicator(
      color: C.ink,
      onRefresh: _refresh,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 8, 16, 120),
        children: [
          const ScreenTitle('Account', subtitle: 'View-only access to your shop'),
          const SizedBox(height: 20),
          _ProfileCard(account: _account, demo: demo),
          const SizedBox(height: 12),
          _CountersCard(account: _account, now: widget.now),
          const SizedBox(height: 12),
          if (demo)
            _DemoCard(onSignIn: widget.onSignOut)
          else
            FlatCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  _Row(
                    icon: Icons.lock_rounded,
                    text: 'Change password',
                    onTap: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: C.canvas,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(R.card))),
                      builder: (_) => _PasswordSheet(auth: widget.auth),
                    ),
                  ),
                  const Divider(height: 1, indent: 20, endIndent: 20, color: C.line),
                  _Row(icon: Icons.logout_rounded, text: 'Sign out', color: C.down, onTap: _confirmSignOut),
                ],
              ),
            ),
          const SizedBox(height: 24),
          Center(child: Text('Caskly Owner · 0.1.0', style: label(size: 12, weight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.account, required this.demo});
  final OwnerAccount account;
  final bool demo;

  String get _initials {
    final parts = account.name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
  }

  String get _phone {
    final p = account.phone;
    return p.length == 10 ? '+91 ${p.substring(0, 5)} ${p.substring(5)}' : p;
  }

  @override
  Widget build(BuildContext context) {
    return FlatCard(
      color: C.ink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: C.gold, shape: BoxShape.circle),
                child: Text(_initials, style: figure(22, weight: FontWeight.w700)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: label(color: C.cream, size: 19, weight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(_phone, style: label(color: C.cream.withValues(alpha: 0.6), size: 14, weight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(height: 1, color: C.cream.withValues(alpha: 0.12)),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.storefront_rounded, size: 20, color: C.cream.withValues(alpha: 0.6)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  account.storeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: label(color: C.cream, size: 15, weight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: demo ? Colors.transparent : C.gold,
                  border: demo ? Border.all(color: C.cream.withValues(alpha: 0.3)) : null,
                  borderRadius: BorderRadius.circular(R.pill),
                ),
                child: Text(
                  demo ? 'Demo' : 'Owner',
                  style: label(color: demo ? C.cream : C.ink, size: 11, weight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountersCard extends StatelessWidget {
  const _CountersCard({required this.account, this.now});
  final OwnerAccount account;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final t = now ?? DateTime.now();
    final counters = account.counters;
    return FlatCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Counters', style: label(color: C.ink, size: 16, weight: FontWeight.w800))),
              Text('${counters.length}', style: figure(22, weight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 14),
          if (counters.isEmpty)
            Text(
              'No counter is connected yet. Turn on Online sync on the shop computer.',
              style: label(size: 13, weight: FontWeight.w500).copyWith(height: 1.4),
            ),
          for (final c in counters) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: C.canvas, borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.point_of_sale_rounded, size: 20, color: C.ink),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: label(color: C.ink, size: 15, weight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          c.isActive ? 'Synced ${agoText(c.lastSeenAt, now: t)}' : 'Switched off',
                          style: label(size: 12, weight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  _StatusDot(color: !c.isActive ? C.muted : _fresh(c.lastSeenAt, t) ? C.up : C.gold),
                ],
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Sales and stock here are as fresh as the last counter sync.',
            style: label(size: 12, weight: FontWeight.w500).copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }

  static bool _fresh(DateTime? seen, DateTime now) => seen != null && now.difference(seen).inMinutes < 10;
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _DemoCard extends StatelessWidget {
  const _DemoCard({required this.onSignIn});
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) => FlatCard(
    color: C.wheat,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("You're looking at a sample shop", style: label(color: C.ink, size: 16, weight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          'Sign in to see your own sales and stock.',
          style: label(color: C.ink.withValues(alpha: 0.65), size: 13, weight: FontWeight.w500),
        ),
        const SizedBox(height: 16),
        InkButton(text: 'Sign in', onPressed: onSignIn),
      ],
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.text, required this.onTap, this.color = C.ink});
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(R.card),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 14),
          Expanded(child: Text(text, style: label(color: color, size: 15, weight: FontWeight.w700))),
          Icon(Icons.chevron_right_rounded, color: color.withValues(alpha: 0.4)),
        ],
      ),
    ),
  );
}

class _PasswordSheet extends StatefulWidget {
  const _PasswordSheet({required this.auth});
  final AuthService auth;

  @override
  State<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<_PasswordSheet> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _again = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _again.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_next.text.length < 8) return setState(() => _error = 'Use at least 8 characters.');
    if (_next.text != _again.text) return setState(() => _error = "The new passwords don't match.");
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.auth.changePassword(_current.text, _next.text);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(const SnackBar(content: Text('Password changed. Other phones were signed out.')));
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: C.line, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text('Change password', style: figure(28, weight: FontWeight.w500)),
            const SizedBox(height: 20),
            FlatField(text: 'Current password', controller: _current, obscure: true, textInputAction: TextInputAction.next),
            const SizedBox(height: 14),
            FlatField(text: 'New password', controller: _next, obscure: true, textInputAction: TextInputAction.next),
            const SizedBox(height: 14),
            FlatField(
              text: 'New password again',
              controller: _again,
              obscure: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: label(color: C.down, size: 13)),
            ],
            const SizedBox(height: 20),
            InkButton(text: 'Update password', busy: _busy, onPressed: _save),
          ],
        ),
      ),
    ),
  );
}
