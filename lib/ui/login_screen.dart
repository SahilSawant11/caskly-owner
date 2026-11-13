import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/auth.dart';
import 'theme.dart';
import 'widgets/common.dart';

/// Phone + password sign-in. The owner's login is set up on the shop's
/// counter (Settings → Online sync), so there's no sign-up here.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.auth, required this.onSignedIn, required this.onDemo, this.notice});

  final AuthService auth;
  final ValueChanged<OwnerAccount> onSignedIn;
  final VoidCallback onDemo;

  /// Shown above the form, e.g. "Your session ended".
  final String? notice;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _hide = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _error = widget.notice;
  }

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final phone = normalizePhone(_phone.text);
    if (phone.length != 10) return setState(() => _error = 'Enter your 10-digit mobile number.');
    if (_password.text.isEmpty) return setState(() => _error = 'Enter your password.');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final account = await widget.auth.login(phone, _password.text);
      if (mounted) widget.onSignedIn(account);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight - 40),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          padding: const EdgeInsets.all(9),
                          decoration: const BoxDecoration(color: C.ink, shape: BoxShape.circle),
                          child: SvgPicture.asset('assets/brand/caskly_mark_light.svg'),
                        ),
                        const SizedBox(width: 12),
                        Text('Caskly Owner', style: label(color: C.ink, size: 17, weight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 40),
                    Text('Your shop,\nfrom anywhere.', style: figure(40, weight: FontWeight.w500).copyWith(height: 1.1)),
                    const SizedBox(height: 14),
                    Text(
                      "Sign in with the mobile number and password set up on your shop's counter.",
                      style: label(size: 14, weight: FontWeight.w500).copyWith(height: 1.45),
                    ),
                    const SizedBox(height: 32),
                    FlatField(
                      text: 'Mobile number',
                      controller: _phone,
                      prefix: '+91',
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.telephoneNumberNational, AutofillHints.username],
                      maxLength: 14,
                    ),
                    const SizedBox(height: 16),
                    FlatField(
                      text: 'Password',
                      controller: _password,
                      obscure: _hide,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _submit(),
                      suffix: IconButton(
                        tooltip: _hide ? 'Show password' : 'Hide password',
                        onPressed: () => setState(() => _hide = !_hide),
                        icon: Icon(_hide ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: C.muted),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 1),
                            child: Icon(Icons.error_rounded, size: 18, color: C.down),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_error!, style: label(color: C.down, size: 13, weight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    InkButton(text: 'Sign in', busy: _busy, onPressed: _submit),
                    const SizedBox(height: 32),
                    FlatCard(
                      color: C.wheat,
                      padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('No login yet?', style: label(color: C.ink, size: 15, weight: FontWeight.w800)),
                                const SizedBox(height: 4),
                                Text(
                                  'Look around with a sample shop.',
                                  style: label(color: C.ink.withValues(alpha: 0.65), size: 13, weight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: _busy ? null : widget.onDemo,
                            style: TextButton.styleFrom(foregroundColor: C.ink, shape: const StadiumBorder()),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Try demo', style: label(color: C.ink, size: 14, weight: FontWeight.w800)),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_forward_rounded, size: 18),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
