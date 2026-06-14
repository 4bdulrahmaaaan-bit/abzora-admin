import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as provider;

import 'core/theme/rider_theme.dart';
import 'providers/auth_provider.dart';
import 'routes/rider_router.dart';
import 'app_shell.dart';

class AbianzoRiderApp extends StatelessWidget {
  const AbianzoRiderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return provider.ChangeNotifierProvider(
      create: (_) => AuthProvider()..mode = AbzioAppMode.rider,
      child: MaterialApp.router(
        title: 'Abianzo Rider',
        debugShowCheckedModeBanner: false,
        theme: RiderTheme.light(),
        routerConfig: riderRouter,
      ),
    );
  }
}
