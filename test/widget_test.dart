import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:abzio/app_shell.dart';
import 'package:abzio/providers/auth_provider.dart';
import 'package:abzio/providers/network_provider.dart';
import 'package:abzio/providers/cart_provider.dart';
import 'package:abzio/providers/chat_provider.dart';
import 'package:abzio/providers/banner_provider.dart';
import 'package:abzio/providers/location_provider.dart';
import 'package:abzio/providers/product_provider.dart';
import 'package:abzio/providers/theme_provider.dart';

class _TestBannerProvider extends BannerProvider {
  @override
  Future<void> loadBanners() async {
    // Keep smoke tests timer-free and deterministic.
  }
}

void main() {
  testWidgets('Abzio Elite smoke test', (WidgetTester tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => NetworkProvider()),
          ChangeNotifierProvider(create: (_) => CartProvider()),
          ChangeNotifierProvider(create: (_) => ProductProvider()),
          ChangeNotifierProvider(create: (_) => _TestBannerProvider()),
          ChangeNotifierProvider(create: (_) => LocationProvider()),
          ChangeNotifierProvider(create: (_) => ChatProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: const AbzioApp(initialRoute: '/login'),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(MaterialApp), findsOneWidget);

    // Dispose the tree and flush any trailing one-shot timers created by startup.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle(const Duration(seconds: 1));
  });
}
