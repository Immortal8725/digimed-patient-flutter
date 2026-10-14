import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class TokenStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const keys = ['token', 'role', 'userId', 'tenantId', 'tenantType'];

  @override
  Future<void> clear() async {
    for (final key in keys) {
      await _storage.delete(key: key);
    }
  }

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

class MemoryTokenStore implements TokenStore {
  final Map<String, String> _values = {};

  @override
  Future<void> clear() async => _values.clear();

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;
}

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());
