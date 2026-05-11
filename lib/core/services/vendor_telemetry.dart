import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../services/database_service.dart';

class VendorTelemetry {
  const VendorTelemetry._();

  static void event(String name, {Map<String, dynamic> data = const {}}) {
    debugPrint('[VENDOR_TELEMETRY] $name :: $data');
    final db = DatabaseService();
    unawaited(
      db.trackExperienceEvent(eventType: 'vendor_$name', metadata: data),
    );
  }
}
