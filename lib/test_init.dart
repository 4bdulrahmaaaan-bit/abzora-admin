// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:abzio/services/app_bootstrap_service.dart';
import 'package:abzio/providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    print("STARTING APP BOOTSTRAP...");
    final result = await AppBootstrapService().initialize();
    print("BOOTSTRAP COMPLETE. firebaseReady: ${result.firebaseReady}");

    print("CREATING AUTH PROVIDER...");
    final auth = AuthProvider();
    
    print("WAITING FOR IS_INITIALIZED...");
    auth.addListener(() {
      print("AUTH NOTIFIED. isInitialized: ${auth.isInitialized}");
    });
  } catch (e, stackTrace) {
    print("ERROR CAUGHT: $e");
    print("$stackTrace");
  }
}
