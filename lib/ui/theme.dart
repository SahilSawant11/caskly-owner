import 'package:flutter/material.dart';

/// Caskly's flat two-tone system, shared with the desktop app:
/// gold for small accents, pale wheat field, ink cards, cream text on ink.
abstract final class C {
  static const gold = Color(0xFFF2A51D);
  static const goldInk = Color(0xFFA36A00); // gold text on light
  static const wheat = Color(0xFFF9E8C2); // toned-down gold field
  static const ink = Color(0xFF141218);
  static const inkSoft = Color(0xFF221F27);
  static const cream = Color(0xFFF3EFE6);
  static const paper = Color(0xFFFFFFFF);
  static const canvas = Color(0xFFF6F4EF);
  static const line = Color(0xFFE7E2D8);
  static const muted = Color(0xFF7A7586);
  static const up = Color(0xFF12A150);
  static const down = Color(0xFFE0393E);
}

abstract final class R {
  static const card = 28.0;
  static const pill = 999.0;
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Manrope',
    colorScheme: ColorScheme.fromSeed(seedColor: C.gold, surface: C.canvas),
    scaffoldBackgroundColor: C.canvas,
    splashFactory: InkSparkle.splashFactory,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: C.ink, displayColor: C.ink),
  );
}

/// Big light numbers (Urbanist), like the desktop's `Figure`.
TextStyle figure(double size, {Color color = C.ink, FontWeight weight = FontWeight.w300}) => TextStyle(
  fontFamily: 'Urbanist',
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: 1,
  letterSpacing: -size * 0.03,
  fontFeatures: const [FontFeature.tabularFigures()],
);

TextStyle label({Color color = C.muted, double size = 13, FontWeight weight = FontWeight.w600}) =>
    TextStyle(fontFamily: 'Manrope', fontSize: size, fontWeight: weight, color: color);

/// Indian grouping: 1,18,756.
String inr(num v) {
  final s = v.round().abs().toString();
  if (s.length <= 3) return '${v < 0 ? '-' : ''}$s';
  final last3 = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '${v < 0 ? '-' : ''}${parts.join(',')},$last3';
}

/// 47,860 → "47.9K", 1,18,756 → "1.19L".
String compactInr(num v) {
  if (v >= 100000) return '${(v / 100000).toStringAsFixed(2)}L';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
  return v.round().toString();
}
