import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wraps token storage behind a tiny interface so the rest of the app never
/// touches `flutter_secure_storage` directly — swapping storage strategy
/// later (or mocking it in tests) only touches this file.
class SecureStorage {
  SecureStorage._();
  static final SecureStorage instance = SecureStorage._();

  final _storage = const FlutterSecureStorage();

  static const _accessKey = 'partner_access_token';
  static const _refreshKey = 'partner_refresh_token';

  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  Future<String?> get accessToken => _storage.read(key: _accessKey);
  Future<String?> get refreshToken => _storage.read(key: _refreshKey);

  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
