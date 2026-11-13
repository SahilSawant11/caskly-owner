import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Server the app signs in to, baked in at build time:
/// `flutter run --dart-define=API_URL=https://caskly-api.example.net`.
/// Empty means this build has no server yet (demo only).
const apiUrl = String.fromEnvironment('API_URL');

class Counter {
  const Counter({required this.name, required this.isActive, this.lastSeenAt});
  final String name;
  final bool isActive;
  final DateTime? lastSeenAt;
}

/// The signed-in owner, their shop and its counters.
class OwnerAccount {
  const OwnerAccount({
    required this.name,
    required this.phone,
    required this.storeName,
    required this.counters,
    this.lastSyncAt,
  });

  final String name;

  /// 10-digit Indian mobile number.
  final String phone;
  final String storeName;
  final List<Counter> counters;

  /// Last time any counter of this shop pushed data.
  final DateTime? lastSyncAt;

  factory OwnerAccount.fromJson(Map<String, dynamic> j) => OwnerAccount(
    name: j['owner']['name'] as String,
    phone: j['owner']['phone'] as String,
    storeName: j['store']['name'] as String,
    lastSyncAt: _date(j['lastSyncAt']),
    counters: [
      for (final c in (j['counters'] as List? ?? const []))
        Counter(name: c['name'] as String, isActive: c['isActive'] as bool, lastSeenAt: _date(c['lastSeenAt'])),
    ],
  );

  static DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String).toLocal();
}

/// A failure worth showing to the owner as-is.
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Thrown when the saved session is no longer valid (signed out elsewhere,
/// password changed, expired). The app returns to the sign-in screen.
class SessionExpired extends AuthException {
  const SessionExpired() : super('Your session ended. Please sign in again.');
}

abstract class AuthService {
  bool get isDemo;

  /// Account for a saved session, or null when there isn't one.
  Future<OwnerAccount?> restore();
  Future<OwnerAccount> login(String phone, String password);
  Future<OwnerAccount> account();
  Future<void> changePassword(String current, String next);
  Future<void> logout();
}

/// Keeps the session token. Secure storage on devices; in memory in tests.
abstract class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  static const _key = 'owner_session_token';
  final _storage = const FlutterSecureStorage();

  @override
  Future<String?> read() async {
    try {
      return await _storage.read(key: _key);
    } catch (_) {
      return null; // keychain unavailable / corrupted → treat as signed out
    }
  }

  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

class MemoryTokenStore implements TokenStore {
  String? token;
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String t) async => token = t;
  @override
  Future<void> clear() async => token = null;
}

/// Digits only, without +91 / leading 0.
String normalizePhone(String raw) {
  var d = raw.replaceAll(RegExp(r'\D'), '');
  if (d.length == 12 && d.startsWith('91')) d = d.substring(2);
  if (d.length == 11 && d.startsWith('0')) d = d.substring(1);
  return d;
}

/// Talks to the Caskly server's /api/owner endpoints with a bearer token.
class ApiAuth implements AuthService {
  ApiAuth({required this.baseUrl, TokenStore? store, http.Client? client})
    : _store = store ?? SecureTokenStore(),
      _http = client ?? http.Client();

  final String baseUrl;
  final TokenStore _store;
  final http.Client _http;
  String? _token;

  @override
  bool get isDemo => false;

  /// For the data repository: the same token signs every read.
  String? get token => _token;

  Uri _u(String path) => Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}$path');

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Future<http.Response> _send(Future<http.Response> Function() call) async {
    try {
      return await call().timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const AuthException('The server is taking too long. Check your internet and try again.');
    } on http.ClientException {
      throw const AuthException("Can't reach the server. Check your internet and try again.");
    } catch (e) {
      if (e is AuthException) rethrow;
      throw const AuthException("Can't reach the server. Check your internet and try again.");
    }
  }

  static String _message(http.Response r, String fallback) {
    try {
      final m = (jsonDecode(r.body) as Map)['message'];
      if (m is String && m.isNotEmpty) return m;
    } catch (_) {}
    return fallback;
  }

  @override
  Future<OwnerAccount?> restore() async {
    _token = await _store.read();
    if (_token == null) return null;
    try {
      return await account();
    } on SessionExpired {
      return null;
    }
  }

  @override
  Future<OwnerAccount> login(String phone, String password) async {
    final r = await _send(
      () => _http.post(
        _u('/api/owner/login'),
        headers: _headers,
        body: jsonEncode({'phone': normalizePhone(phone), 'password': password, 'deviceName': 'Caskly Owner app'}),
      ),
    );
    if (r.statusCode != 200) throw AuthException(_message(r, 'Sign in failed (${r.statusCode}).'));
    _token = (jsonDecode(r.body) as Map)['token'] as String;
    await _store.write(_token!);
    return account();
  }

  @override
  Future<OwnerAccount> account() async {
    final r = await _send(() => _http.get(_u('/api/owner/me'), headers: _headers));
    if (r.statusCode == 401) {
      _token = null;
      await _store.clear();
      throw const SessionExpired();
    }
    if (r.statusCode != 200) throw AuthException(_message(r, 'Couldn\'t load your account (${r.statusCode}).'));
    return OwnerAccount.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  @override
  Future<void> changePassword(String current, String next) async {
    final r = await _send(
      () => _http.post(
        _u('/api/owner/password'),
        headers: _headers,
        body: jsonEncode({'currentPassword': current, 'newPassword': next}),
      ),
    );
    if (r.statusCode != 200) throw AuthException(_message(r, 'Couldn\'t change the password (${r.statusCode}).'));
  }

  @override
  Future<void> logout() async {
    // Forget the token locally even if the server can't be reached.
    try {
      await _send(() => _http.post(_u('/api/owner/logout'), headers: _headers));
    } catch (_) {}
    _token = null;
    await _store.clear();
  }
}

/// Used when the owner chooses to look around without signing in.
class DemoAuth implements AuthService {
  DemoAuth({DateTime? now}) : _now = now ?? DateTime.now();
  final DateTime _now;

  @override
  bool get isDemo => true;

  @override
  Future<OwnerAccount?> restore() async => null;

  @override
  Future<OwnerAccount> login(String phone, String password) => account();

  @override
  Future<OwnerAccount> account() async => OwnerAccount(
    name: 'Ramesh Patil',
    phone: '9876543210',
    storeName: 'Shree Sai Wines',
    lastSyncAt: _now.subtract(const Duration(minutes: 2)),
    counters: [Counter(name: 'Counter 1', isActive: true, lastSeenAt: _now.subtract(const Duration(minutes: 2)))],
  );

  @override
  Future<void> changePassword(String current, String next) async {}

  @override
  Future<void> logout() async {}
}

/// A build without API_URL: sign-in explains there's no server yet.
class UnconfiguredAuth implements AuthService {
  static const _msg = "This app isn't connected to a server yet. Try the demo for now.";

  @override
  bool get isDemo => false;
  @override
  Future<OwnerAccount?> restore() async => null;
  @override
  Future<OwnerAccount> login(String phone, String password) async => throw const AuthException(_msg);
  @override
  Future<OwnerAccount> account() async => throw const SessionExpired();
  @override
  Future<void> changePassword(String current, String next) async => throw const AuthException(_msg);
  @override
  Future<void> logout() async {}
}
