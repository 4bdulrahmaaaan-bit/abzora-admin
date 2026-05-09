import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as provider;

import 'core/theme/rider_theme.dart';
import 'providers/auth_provider.dart';
import 'routes/rider_router.dart';

class AbzoraRiderApp extends StatelessWidget {
  const AbzoraRiderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return provider.ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp.router(
        title: 'Abzora Rider',
        debugShowCheckedModeBanner: false,
        theme: RiderTheme.dark(),
        routerConfig: riderRouter,
      ),
    );
  }
}
