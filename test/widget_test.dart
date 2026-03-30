import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:abzio/app_shell.dart';
import 'package:abzio/providers/auth_provider.dart';
import 'package:abzio/providers/cart_provider.dart';
import 'package:abzio/providers/chat_provider.dart';
import 'package:abzio/providers/product_provider.dart';
import 'package:abzio/providers/theme_provider.dart';

void main() {
  testWidgets('Abzio Elite smoke test', (WidgetTester tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => CartProvider()),
          ChangeNotifierProvider(create: (_) => ProductProvider()),
          ChangeNotifierProvider(create: (_) => ChatProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: const AbzioApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 4));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
