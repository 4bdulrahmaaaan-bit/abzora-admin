import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secure_session_storage_stub.dart';

class SecureSessionStorageImpl implements SecureSessionStorage {
  SecureSessionStorageImpl() : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);
}

SecureSessionStorage createSecureSessionStorage() => SecureSessionStorageImpl();
