import 'package:flutter/material.dart';

/// A number drawn as a 5×7 dot matrix — the one "hero" figure on the home
/// screen. Lit dots in [color], unlit dots faint, like a departure board.
class DotDigits extends StatelessWidget {
  const DotDigits(this.text, {super.key, this.dot = 6, this.gap = 2.2, this.color = Colors.black, this.off});

  final String text;

  /// Dot diameter in logical pixels.
  final double dot;
  final double gap;
  final Color color;

  /// Unlit dot colour; defaults to [color] at 5%.
  final Color? off;

  double get _step => dot + gap;

  double _width() {
    var w = 0.0;
    for (final ch in text.split('')) {
      w += (_glyphs[ch]?.first.length ?? 3) * _step + _charGap * _step;
    }
    return w - _charGap * _step;
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: text,
    child: CustomPaint(
      size: Size(_width(), 7 * _step - gap),
      painter: _DotPainter(text, dot, _step, color, off ?? color.withValues(alpha: 0.04)),
    ),
  );
}

class _DotPainter extends CustomPainter {
  _DotPainter(this.text, this.dot, this.step, this.on, this.off);
  final String text;
  final double dot;
  final double step;
  final Color on;
  final Color off;

  @override
  void paint(Canvas canvas, Size size) {
    final onPaint = Paint()..color = on;
    final offPaint = Paint()..color = off;
    final r = dot / 2;
    var x0 = 0.0;
    for (final ch in text.split('')) {
      final g = _glyphs[ch] ?? _glyphs[' ']!;
      final cols = g.first.length;
      for (var row = 0; row < 7; row++) {
        for (var col = 0; col < cols; col++) {
          final lit = g[row][col] == '#';
          // Separators (comma, dot) show only their lit dots.
          if (!lit && cols < 5) continue;
          canvas.drawCircle(Offset(x0 + col * step + r, row * step + r), r, lit ? onPaint : offPaint);
        }
      }
      x0 += cols * step + _charGap * step;
    }
  }

  @override
  bool shouldRepaint(_DotPainter old) => old.text != text || old.on != on || old.off != off || old.dot != dot;
}

/// Blank columns between characters.
const _charGap = 2;

const _glyphs = <String, List<String>>{
  '0': ['.###.', '#...#', '#...#', '#...#', '#...#', '#...#', '.###.'],
  '1': ['..#..', '.##..', '..#..', '..#..', '..#..', '..#..', '.###.'],
  '2': ['.###.', '#...#', '....#', '...#.', '..#..', '.#...', '#####'],
  '3': ['####.', '....#', '....#', '.###.', '....#', '....#', '####.'],
  '4': ['#...#', '#...#', '#...#', '#####', '....#', '....#', '....#'],
  '5': ['#####', '#....', '####.', '....#', '....#', '#...#', '.###.'],
  '6': ['..##.', '.#...', '#....', '####.', '#...#', '#...#', '.###.'],
  '7': ['#####', '....#', '...#.', '..#..', '.#...', '.#...', '.#...'],
  '8': ['.###.', '#...#', '#...#', '.###.', '#...#', '#...#', '.###.'],
  '9': ['.###.', '#...#', '#...#', '.####', '....#', '...#.', '.##..'],
  ',': ['..', '..', '..', '..', '..', '.#', '#.'],
  '.': ['.', '.', '.', '.', '.', '.', '#'],
  ' ': ['..', '..', '..', '..', '..', '..', '..'],
};
