import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    print("STARTING SECURE STORAGE TEST...");
    const storage = FlutterSecureStorage();
    print("READING TOKEN...");
    final token = await storage.read(key: 'abianzo_session_access_token');
    print("TOKEN READ COMPLETE: $token");
  } catch (e, stackTrace) {
    print("ERROR CAUGHT: $e");
    print("$stackTrace");
  }
}
