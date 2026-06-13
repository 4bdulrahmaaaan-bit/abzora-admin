import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../services/database_service.dart';

class RiderTelemetry {
  const RiderTelemetry._();

  static void event(String name, {Map<String, dynamic> data = const {}}) {
    if (kDebugMode) {
      debugPrint('[RIDER_TELEMETRY] $name :: $data');
    }
    final db = DatabaseService();
    unawaited(
      db.trackExperienceEvent(eventType: 'rider_$name', metadata: data),
    );
  }
}
