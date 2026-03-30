import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../models/models.dart';
import 'location_service.dart';
import 'rider_service.dart';

class LocationTracker {
  static const Duration _minUpdateInterval = Duration(seconds: 8);
  static const double _minDistanceMeters = 50;

  LocationTracker({
    LocationService? locationService,
    RiderService? riderService,
  })  : _locationService = locationService ?? LocationService(),
        _riderService = riderService ?? RiderService();

  final LocationService _locationService;
  final RiderService _riderService;
  StreamSubscription<Position>? _subscription;
  DateTime? _lastSentAt;
  Position? _lastSentPosition;

  Future<void> startOrderTracking({
    required String orderId,
    required AppUser rider,
  }) async {
    await stop();
    _subscription = _locationService
        .watchLocation(accuracy: LocationAccuracy.high, distanceFilter: 80)
        .listen((position) {
      if (!_shouldSend(position)) {
        return;
      }
      _lastSentAt = DateTime.now();
      _lastSentPosition = position;
      unawaited(
        _riderService.updateRiderLocation(
          orderId: orderId,
          latitude: position.latitude,
          longitude: position.longitude,
          rider: rider,
        ),
      );
    });
  }

  bool _shouldSend(Position current) {
    final now = DateTime.now();
    if (_lastSentAt == null || _lastSentPosition == null) {
      return true;
    }
    final elapsed = now.difference(_lastSentAt!);
    if (elapsed >= _minUpdateInterval) {
      return true;
    }
    final distance = Geolocator.distanceBetween(
      _lastSentPosition!.latitude,
      _lastSentPosition!.longitude,
      current.latitude,
      current.longitude,
    );
    return distance >= _minDistanceMeters;
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _lastSentAt = null;
    _lastSentPosition = null;
  }
}
