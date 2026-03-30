import 'dart:async';
import 'dart:math' as math;

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static const Duration _cacheTtl = Duration(minutes: 5);

  Position? _cachedPosition;
  LocationAddress? _cachedAddress;
  DateTime? _cachedAt;

  Future<LocationFetchResult> getCurrentLocation({
    bool forceRefresh = false,
    int retryCount = 2,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    try {
      final permissionResult = await ensurePermission();
      if (!permissionResult.isGranted) {
        return LocationFetchResult(
          status: permissionResult.status,
          permission: permissionResult.permission,
          message: permissionResult.message,
        );
      }

      if (!forceRefresh && _cachedPosition != null && _cachedAt != null) {
        final age = DateTime.now().difference(_cachedAt!);
        if (age <= _cacheTtl) {
          return LocationFetchResult(
            status: LocationStatus.success,
            permission: permissionResult.permission,
            position: _cachedPosition,
            address: _cachedAddress,
            fromCache: true,
          );
        }
      }

      Position? position;
      Object? lastError;
      for (var attempt = 0; attempt <= retryCount; attempt++) {
        try {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.best,
              distanceFilter: 50,
            ),
          ).timeout(timeout);
          if (position.accuracy <= 120 || attempt == retryCount) {
            break;
          }
        } catch (error) {
          lastError = error;
          if (attempt == retryCount) {
            break;
          }
          await Future<void>.delayed(Duration(milliseconds: 350 * (attempt + 1)));
        }
      }

      position ??= await Geolocator.getLastKnownPosition();
      if (position == null) {
        return LocationFetchResult(
          status: lastError is TimeoutException ? LocationStatus.timeout : LocationStatus.error,
          permission: permissionResult.permission,
          message: _failureMessage(lastError),
        );
      }

      final address = await reverseGeocode(position.latitude, position.longitude);
      _cachedPosition = position;
      _cachedAddress = address;
      _cachedAt = DateTime.now();

      return LocationFetchResult(
        status: LocationStatus.success,
        permission: permissionResult.permission,
        position: position,
        address: address,
        fromLastKnown: lastError != null,
      );
    } catch (error) {
      return LocationFetchResult(
        status: LocationStatus.error,
        permission: LocationPermission.unableToDetermine,
        message: _failureMessage(error),
      );
    }
  }

  Future<LocationPermissionResult> ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const LocationPermissionResult(
        status: LocationStatus.serviceDisabled,
        permission: LocationPermission.denied,
        message: 'Turn on device location to discover nearby stores.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      return LocationPermissionResult(
        status: LocationStatus.permissionDenied,
        permission: permission,
        message: 'Allow location access to see nearby stores and delivery details.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationPermissionResult(
        status: LocationStatus.permissionDeniedForever,
        permission: permission,
        message: 'Location access is blocked. Open app settings to enable it again.',
      );
    }

    return LocationPermissionResult(
      status: LocationStatus.success,
      permission: permission,
      message: permission == LocationPermission.whileInUse || permission == LocationPermission.always
          ? null
          : 'Location permission granted.',
    );
  }

  Future<LocationAddress> reverseGeocode(double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) {
        return const LocationAddress(
          address: 'Location detected',
          area: '',
          city: '',
          state: '',
          postalCode: '',
        );
      }

      final place = placemarks.first;
      final name = _firstNonEmpty([
        place.name,
        place.street,
        place.thoroughfare,
      ]);
      final area = _firstNonEmpty([
        place.subLocality,
        place.locality,
        place.subAdministrativeArea,
      ]);
      final city = _firstNonEmpty([
        place.locality,
        place.subAdministrativeArea,
        place.administrativeArea,
      ]);
      final state = _firstNonEmpty([
        place.administrativeArea,
        place.subAdministrativeArea,
      ]);
      final postalCode = (place.postalCode ?? '').trim();

      final parts = <String>[
        if (name.isNotEmpty && name != area) name,
        if (area.isNotEmpty) area,
        if (city.isNotEmpty && city != area) city,
      ];

      return LocationAddress(
        address: parts.isEmpty ? 'Location detected' : parts.join(', '),
        area: area,
        city: city,
        state: state,
        postalCode: postalCode,
      );
    } catch (_) {
      return const LocationAddress(
        address: 'Location detected',
        area: '',
        city: '',
        state: '',
        postalCode: '',
      );
    }
  }

  Future<String> getAddressFromCoordinates(double latitude, double longitude) async {
    final address = await reverseGeocode(latitude, longitude);
    return address.address;
  }

  Future<AddressLookupResult> geocodeAddress(String address) async {
    final trimmed = address.trim();
    if (trimmed.isEmpty) {
      return const AddressLookupResult(status: AddressLookupStatus.invalidInput);
    }
    try {
      final locations = await locationFromAddress(trimmed);
      if (locations.isEmpty) {
        return const AddressLookupResult(status: AddressLookupStatus.notFound);
      }
      final first = locations.first;
      return AddressLookupResult(
        status: AddressLookupStatus.success,
        latitude: first.latitude,
        longitude: first.longitude,
      );
    } catch (_) {
      return const AddressLookupResult(status: AddressLookupStatus.error);
    }
  }

  Future<LocationAddress?> lookupByPincode(String pincode) async {
    final trimmed = pincode.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(trimmed)) {
      return null;
    }
    try {
      final locations = await locationFromAddress(trimmed);
      if (locations.isEmpty) {
        return null;
      }
      return reverseGeocode(locations.first.latitude, locations.first.longitude);
    } catch (_) {
      return null;
    }
  }

  Stream<Position> watchLocation({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 150,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      ),
    );
  }

  double distanceInKm({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    const earthRadiusKm = 6371.0;
    final dLat = _degreesToRadians(endLatitude - startLatitude);
    final dLon = _degreesToRadians(endLongitude - startLongitude);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(startLatitude)) *
            math.cos(_degreesToRadians(endLatitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  Future<bool> openSystemLocationSettings() async {
    return Geolocator.openLocationSettings();
  }

  Future<bool> openSystemAppSettings() async {
    return Geolocator.openAppSettings();
  }

  String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim() ?? '';
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return '';
  }

  double _degreesToRadians(double degrees) => degrees * math.pi / 180;

  String _failureMessage(Object? error) {
    if (error is TimeoutException) {
      return 'Location lookup timed out. Try again in a moment.';
    }
    return 'Unable to fetch your location right now.';
  }
}

enum LocationStatus {
  success,
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
  timeout,
  error,
  manual,
}

enum AddressLookupStatus {
  success,
  invalidInput,
  notFound,
  error,
}

class LocationAddress {
  final String address;
  final String area;
  final String city;
  final String state;
  final String postalCode;

  const LocationAddress({
    required this.address,
    required this.area,
    required this.city,
    this.state = '',
    this.postalCode = '',
  });
}

class LocationFetchResult {
  final LocationStatus status;
  final LocationPermission permission;
  final Position? position;
  final LocationAddress? address;
  final String? message;
  final bool fromCache;
  final bool fromLastKnown;

  const LocationFetchResult({
    required this.status,
    required this.permission,
    this.position,
    this.address,
    this.message,
    this.fromCache = false,
    this.fromLastKnown = false,
  });
}

class LocationPermissionResult {
  final LocationStatus status;
  final LocationPermission permission;
  final String? message;

  const LocationPermissionResult({
    required this.status,
    required this.permission,
    this.message,
  });

  bool get isGranted => status == LocationStatus.success;
}

class AddressLookupResult {
  final AddressLookupStatus status;
  final double? latitude;
  final double? longitude;

  const AddressLookupResult({
    required this.status,
    this.latitude,
    this.longitude,
  });
}
