import 'package:flutter/material.dart';

import '../theme.dart';

/// Flat rounded card — every block on every screen sits in one.
class FlatCard extends StatelessWidget {
  const FlatCard({super.key, required this.child, this.color = C.paper, this.padding = const EdgeInsets.all(20)});
  final Widget child;
  final Color color;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(R.card)),
    child: child,
  );
}

/// Screen title row: big title, optional muted subtitle and trailing widget.
class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.title, {super.key, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: figure(34, weight: FontWeight.w500)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, style: label(size: 13, weight: FontWeight.w500)),
            ],
          ],
        ),
      ),
      ?trailing,
    ],
  );
}

/// Horizontally scrolling pill tabs; the selected pill is ink.
class PillTabs extends StatelessWidget {
  const PillTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.dark = false,
    this.expand = false,
  });

  /// Fill the width with equal pills instead of scrolling (for 2–3 tabs).
  final bool expand;
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  /// On an ink background the selected pill is gold instead.
  final bool dark;

  Widget _pill(int i) {
    final on = i == selected;
    final bg = on ? (dark ? C.gold : C.ink) : Colors.transparent;
    final fg = on ? (dark ? C.ink : C.cream) : (dark ? C.cream.withValues(alpha: 0.7) : C.ink);
    return GestureDetector(
      onTap: () => onSelected(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(R.pill),
          border: on ? null : Border.all(color: dark ? C.cream.withValues(alpha: 0.2) : C.ink.withValues(alpha: 0.14)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            labels[i],
            style: label(color: fg, size: 13, weight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 40,
    child: expand
        ? Row(
            children: [
              for (var i = 0; i < labels.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _pill(i)),
              ],
            ],
          )
        : ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: labels.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) => _pill(i),
          ),
  );
}

/// Small rounded "chip" used for sizes like 650 ML.
class SizeChip extends StatelessWidget {
  const SizeChip(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: C.canvas, borderRadius: BorderRadius.circular(8)),
    child: Text(
      text,
      style: label(color: C.ink, size: 11, weight: FontWeight.w700),
    ),
  );
}

/// Loading / error wrapper for a Future-backed screen.
class Loader<T> extends StatelessWidget {
  const Loader({super.key, required this.future, required this.builder});
  final Future<T> future;
  final Widget Function(BuildContext, T) builder;

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: future,
    builder: (context, snap) {
      if (snap.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text('Couldn\'t load: ${snap.error}', textAlign: TextAlign.center, style: label(size: 14)),
          ),
        );
      }
      if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: C.gold));
      return builder(context, snap.data as T);
    },
  );
}

const weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const monthShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String dayLabel(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return '${weekdayShort[d.weekday - 1]}, ${d.day} ${monthShort[d.month - 1]}';
}

/// Full-width ink pill button; shows a spinner while [busy].
class InkButton extends StatelessWidget {
  const InkButton({super.key, required this.text, required this.onPressed, this.busy = false});
  final String text;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 56,
    width: double.infinity,
    child: FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: C.ink,
        foregroundColor: C.cream,
        disabledBackgroundColor: C.ink.withValues(alpha: 0.85),
        shape: const StadiumBorder(),
        textStyle: label(size: 15, weight: FontWeight.w800),
      ),
      child: busy
          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: C.gold))
          : Text(text),
    ),
  );
}

/// Flat white rounded input with a small label above it.
class FlatField extends StatelessWidget {
  const FlatField({
    super.key,
    required this.text,
    required this.controller,
    this.prefix,
    this.suffix,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
    this.maxLength,
  });

  final String text;
  final TextEditingController controller;
  final String? prefix;
  final Widget? suffix;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(text, style: label(size: 13)),
        ),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          autofillHints: autofillHints,
          maxLength: maxLength,
          style: label(color: C.ink, size: 17, weight: FontWeight.w700),
          cursorColor: C.ink,
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: C.paper,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            prefixIcon: prefix == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: 20, right: 10),
                    child: Text(prefix!, style: label(size: 17, weight: FontWeight.w700)),
                  ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            suffixIcon: suffix,
            border: border,
            enabledBorder: border,
            focusedBorder: border.copyWith(borderSide: const BorderSide(color: C.ink, width: 1.5)),
          ),
        ),
      ],
    );
  }
}

/// "2 min ago", "3 h ago", "12 Nov".
String agoText(DateTime? t, {DateTime? now}) {
  if (t == null) return 'never';
  final ago = (now ?? DateTime.now()).difference(t);
  if (ago.inMinutes < 1) return 'just now';
  if (ago.inMinutes < 60) return '${ago.inMinutes} min ago';
  if (ago.inHours < 24) return '${ago.inHours} h ago';
  if (ago.inDays == 1) return 'yesterday';
  return '${t.day} ${monthShort[t.month - 1]}';
}
