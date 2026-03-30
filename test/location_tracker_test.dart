import 'dart:async';

import 'package:abzio/models/models.dart';
import 'package:abzio/services/location_service.dart';
import 'package:abzio/services/location_tracker.dart';
import 'package:abzio/services/rider_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

class _FakeLocationService extends LocationService {
  _FakeLocationService(this._controller);

  final StreamController<Position> _controller;

  @override
  Stream<Position> watchLocation({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 150,
  }) {
    return _controller.stream;
  }
}

class _FakeRiderService extends RiderService {
  _FakeRiderService() : super();

  final List<Map<String, dynamic>> updates = [];

  @override
  Future<void> updateRiderLocation({
    required String orderId,
    required double latitude,
    required double longitude,
    required AppUser rider,
  }) async {
    updates.add({
      'orderId': orderId,
      'latitude': latitude,
      'longitude': longitude,
      'riderId': rider.id,
    });
  }
}

Position _position(double latitude, double longitude) {
  return Position(
    longitude: longitude,
    latitude: latitude,
    timestamp: DateTime.now(),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 1,
    heading: 0,
    headingAccuracy: 1,
    speed: 0,
    speedAccuracy: 1,
  );
}

void main() {
  test('location tracker throttles rapid low-distance rider updates', () async {
    final controller = StreamController<Position>();
    final riderService = _FakeRiderService();
    final tracker = LocationTracker(
      locationService: _FakeLocationService(controller),
      riderService: riderService,
    );
    final rider = AppUser(
      id: 'rider-1',
      name: 'Rider',
      email: 'rider@abzora.app',
      role: 'rider',
    );

    await tracker.startOrderTracking(orderId: 'order-1', rider: rider);

    controller.add(_position(13.0827, 80.2707));
    controller.add(_position(13.08271, 80.27071));
    controller.add(_position(13.0835, 80.2715));

    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(riderService.updates.length, 2);

    await tracker.stop();
    await controller.close();
  });
}
