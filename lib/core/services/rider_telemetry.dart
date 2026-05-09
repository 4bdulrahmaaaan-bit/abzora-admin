import 'package:flutter/foundation.dart';

class RiderTelemetry {
  const RiderTelemetry._();

  static void event(String name, {Map<String, dynamic> data = const {}}) {
    debugPrint('[RIDER_TELEMETRY] $name :: $data');
  }
}
