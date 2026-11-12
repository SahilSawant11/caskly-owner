import 'package:caskly_owner/data/repository.dart';
import 'package:caskly_owner/ui/home_screen.dart';
import 'package:caskly_owner/ui/reports_screen.dart';
import 'package:caskly_owner/ui/stock_screen.dart';
import 'package:caskly_owner/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 13, 21, 30);
  final today = DateTime(2026, 11, 13);

  test('Indian number grouping', () {
    expect(inr(47860), '47,860');
    expect(inr(118756), '1,18,756');
    expect(inr(12345678), '1,23,45,678');
    expect(inr(999), '999');
  });

  group('demo data reconciles', () {
    final repo = DemoRepository(now: now);

    test("today's closing equals stock on hand", () async {
      final stock = await repo.stock();
      final r = await repo.brandwise(today);
      expect(r.total.closing, stock.fold<int>(0, (a, s) => a + s.qty));
    });

    test("each day's opening is the previous day's closing; no negatives", () async {
      for (var k = 0; k < 30; k++) {
        final day = today.subtract(Duration(days: k));
        final r = await repo.brandwise(day);
        final prev = await repo.brandwise(day.subtract(const Duration(days: 1)));
        expect(r.total.opening, prev.total.closing, reason: '$day');
        for (final row in r.rows) {
          for (final m in row.bySize.values) {
            expect(m.opening + m.purchase - m.sale, m.closing, reason: '${row.brand} $day');
            expect(m.opening >= 0 && m.closing >= 0, isTrue, reason: '${row.brand} $day');
          }
        }
      }
    });

    test('daily sales bottles match the register', () async {
      final s = await repo.dailySales(today);
      final r = await repo.brandwise(today);
      expect(s.bottles, r.total.sale);
      expect(s.byCategory.fold<double>(0, (a, c) => a + c.amount), closeTo(s.total, 0.01));
      expect(s.byHour.fold<double>(0, (a, v) => a + v), closeTo(s.total, 0.01));
    });

    test('home matches the reports', () async {
      final snap = await repo.snapshot();
      final s = await repo.dailySales(today);
      expect(snap.todaySales, s.total);
      expect(snap.last7Days.last.amount, s.total);
      expect(snap.lowStock.length, (await repo.stock()).where((x) => x.isLow).length);
    });
  });

  for (final width in [320.0, 390.0, 430.0]) {
    Future<void> pump(WidgetTester tester, Widget screen) async {
      tester.view.physicalSize = Size(width * 3, 2600 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: Scaffold(body: screen)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    testWidgets('home at ${width.toInt()}pt', (tester) async {
      await pump(tester, HomeScreen(data: await DemoRepository(now: now).snapshot(), isDemo: true));
      expect(find.text("Today's sales"), findsOneWidget);
    });

    testWidgets('stock at ${width.toInt()}pt, filters and detail', (tester) async {
      await pump(tester, StockScreen(repo: DemoRepository(now: now)));
      expect(find.text('Stock'), findsOneWidget);
      await tester.tap(find.textContaining('Low ·'));
      await tester.pumpAndSettle();
      expect(find.text('Godfather Strong'), findsOneWidget, reason: 'out of stock is listed first under Low');
      await tester.tap(find.text('Godfather Strong'));
      await tester.pumpAndSettle();
      expect(find.text('out of stock'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reports at ${width.toInt()}pt, both tabs', (tester) async {
      await pump(tester, ReportsScreen(repo: DemoRepository(now: now)));
      expect(find.text('By hour'), findsOneWidget);
      await tester.tap(find.text('Brandwise stock'));
      await tester.pumpAndSettle();
      expect(find.text('FERMENTED BEER'), findsOneWidget);
      await tester.tap(find.text('Kingfisher Strong'));
      await tester.pumpAndSettle();
      expect(find.text('500 ML (CAN)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
