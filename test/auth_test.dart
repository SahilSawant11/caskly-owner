import 'dart:convert';

import 'package:caskly_owner/data/auth.dart';
import 'package:caskly_owner/main.dart';
import 'package:caskly_owner/ui/account_screen.dart';
import 'package:caskly_owner/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A tiny stand-in for the server's /api/owner endpoints.
MockClient fakeServer({String password = 'secret123'}) {
  var token = '';
  return MockClient((req) async {
    final authed = req.headers['Authorization'] == 'Bearer $token' && token.isNotEmpty;
    switch (req.url.path) {
      case '/api/owner/login':
        final b = jsonDecode(req.body) as Map;
        if (b['phone'] == '9876543210' && b['password'] == password) {
          token = 'tok-1';
          return http.Response(jsonEncode({'token': token}), 200);
        }
        return http.Response(jsonEncode({'message': 'Wrong mobile number or password.'}), 401);
      case '/api/owner/me':
        if (!authed) return http.Response('{}', 401);
        return http.Response(
          jsonEncode({
            'owner': {'name': 'Sahil Shah', 'phone': '9876543210'},
            'store': {'name': 'Gateway Wines'},
            'lastSyncAt': '2026-11-13T15:58:00Z',
            'counters': [
              {'name': 'Counter 1', 'isActive': true, 'lastSeenAt': '2026-11-13T15:58:00Z'},
            ],
          }),
          200,
        );
      case '/api/owner/logout':
        token = '';
        return http.Response('{}', 200);
    }
    return http.Response('{}', 404);
  });
}

void main() {
  test('phone numbers normalise to 10 digits', () {
    expect(normalizePhone('+91 98765 43210'), '9876543210');
    expect(normalizePhone('09876543210'), '9876543210');
    expect(normalizePhone('98765-43210'), '9876543210');
  });

  test('ApiAuth signs in, restores the saved token, and signs out', () async {
    final store = MemoryTokenStore();
    final server = fakeServer();
    final auth = ApiAuth(baseUrl: 'https://api.test/', store: store, client: server);

    await expectLater(auth.login('9876543210', 'nope'), throwsA(isA<AuthException>()));
    final account = await auth.login('+91 98765 43210', 'secret123');
    expect(account.storeName, 'Gateway Wines');
    expect(store.token, 'tok-1');

    final again = ApiAuth(baseUrl: 'https://api.test', store: store, client: server);
    expect((await again.restore())?.name, 'Sahil Shah');

    await again.logout();
    expect(store.token, isNull);
    expect(await ApiAuth(baseUrl: 'https://api.test', store: store, client: server).restore(), isNull);
  });

  test('a rejected saved token signs the owner out', () async {
    final store = MemoryTokenStore()..token = 'stale';
    final auth = ApiAuth(baseUrl: 'https://api.test', store: store, client: fakeServer());
    expect(await auth.restore(), isNull);
    expect(store.token, isNull);
  });

  for (final width in [320.0, 390.0]) {
    Future<void> sized(WidgetTester tester) async {
      tester.view.physicalSize = Size(width * 3, 2000 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
    }

    testWidgets('sign in → shell → sign out at ${width.toInt()}pt', (tester) async {
      await sized(tester);
      final auth = ApiAuth(baseUrl: 'https://api.test', store: MemoryTokenStore(), client: fakeServer());
      await tester.pumpWidget(CasklyOwnerApp(auth: auth));
      await tester.pumpAndSettle();
      expect(find.text('Your shop,\nfrom anywhere.'), findsOneWidget);

      // Validation, then a wrong password, then the right one.
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your 10-digit mobile number.'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), '98765 43210');
      await tester.enterText(find.byType(TextField).at(1), 'wrong');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Wrong mobile number or password.'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(1), 'secret123');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Nav is icon-only with a real home icon.
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
      expect(find.text('Home'), findsNothing);
      await tester.tap(find.byIcon(Icons.person_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Sahil Shah'), findsOneWidget);
      expect(find.text('+91 98765 43210'), findsOneWidget);
      expect(find.text('Gateway Wines'), findsOneWidget);
      expect(find.text('Counter 1'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out').last);
      await tester.pumpAndSettle();
      expect(find.text('Your shop,\nfrom anywhere.'), findsOneWidget);
    });

    testWidgets('demo from the sign-in screen at ${width.toInt()}pt', (tester) async {
      await sized(tester);
      await tester.pumpWidget(CasklyOwnerApp(auth: UnconfiguredAuth()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), '9876543210');
      await tester.enterText(find.byType(TextField).at(1), 'x');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.textContaining("isn't connected to a server"), findsOneWidget);

      await tester.tap(find.text('Try demo'));
      await tester.pumpAndSettle();
      expect(find.text("Today's sales"), findsOneWidget);
      await tester.tap(find.byIcon(Icons.person_rounded));
      await tester.pumpAndSettle();
      expect(find.text("You're looking at a sample shop"), findsOneWidget);
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Your shop,\nfrom anywhere.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('account with no counters at ${width.toInt()}pt', (tester) async {
      await sized(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
            body: AccountScreen(
              auth: DemoAuth(),
              account: const OwnerAccount(
                name: 'A Very Long Owner Name That Will Not Fit',
                phone: '9876543210',
                storeName: 'A Very Long Store Name Wine And Beer Shop',
                counters: [],
              ),
              onSignOut: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('No counter is connected yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
