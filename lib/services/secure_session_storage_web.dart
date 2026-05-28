import 'package:shared_preferences/shared_preferences.dart';

import 'secure_session_storage_stub.dart';

class SecureSessionStorageImpl implements SecureSessionStorage {
  @override
  Future<void> delete({required String key}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  @override
  Future<String?> read({required String key}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  @override
  Future<void> write({required String key, required String value}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }
}

SecureSessionStorage createSecureSessionStorage() => SecureSessionStorageImpl();
