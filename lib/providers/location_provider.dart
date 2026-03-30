import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../constants/text_constants.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';

class LocationProvider with ChangeNotifier {
  LocationProvider({
    DatabaseService? databaseService,
    LocationService? locationService,
  })  : _db = databaseService ?? DatabaseService(),
        _locationService = locationService ?? LocationService();

  static const double defaultRadiusKm = 10;
  static const List<double> radiusOptionsKm = [10, 25, 50];
  static const Map<String, _ManualCity> _manualCities = {
    'Chennai': _ManualCity('Chennai', 13.0827, 80.2707),
    'Bangalore': _ManualCity('Bangalore', 12.9716, 77.5946),
    'Hyderabad': _ManualCity('Hyderabad', 17.3850, 78.4867),
    'Mumbai': _ManualCity('Mumbai', 19.0760, 72.8777),
    'Delhi': _ManualCity('Delhi', 28.6139, 77.2090),
  };

  final DatabaseService _db;
  final LocationService _locationService;

  List<Store> _stores = const [];
  List<NearbyStore> _nearbyStores = const [];
  StreamSubscription<Position>? _positionSubscription;

  AppUser? _currentUser;
  Position? _userPosition;
  LocationAddress? _resolvedAddress;
  LocationStatus? _status;
  String? _errorMessage;
  String _activeLocation = 'Chennai';
  double _radiusKm = defaultRadiusKm;
  bool _isLoading = false;
  bool _isManualLocation = false;
  bool _isUsingNearestFallback = false;
  bool _isWatchingLocation = false;

  List<NearbyStore> get nearbyStores => _nearbyStores;
  Position? get userPosition => _userPosition;
  LocationStatus? get locationStatus => _status;
  String? get locationErrorMessage => _errorMessage;
  String get activeLocation => _activeLocation;
  double get radiusKm => _radiusKm;
  bool get isLocationLoading => _isLoading;
  bool get locationPermissionBlocked =>
      _status == LocationStatus.permissionDenied || _status == LocationStatus.permissionDeniedForever;
  bool get locationServiceDisabled => _status == LocationStatus.serviceDisabled;
  bool get isManualLocation => _isManualLocation;
  bool get isUsingNearestFallback => _isUsingNearestFallback;
  bool get hasResolvedLocation => _userPosition != null || _resolvedAddress != null;
  List<String> get manualCities => _manualCities.keys.toList(growable: false);
  String get displayAddress => _resolvedAddress?.address.trim().isNotEmpty == true ? _resolvedAddress!.address : _activeLocation;
  String get displayArea => _resolvedAddress?.area.trim().isNotEmpty == true ? _resolvedAddress!.area : _activeLocation;
  String get displayCity => _resolvedAddress?.city.trim().isNotEmpty == true ? _resolvedAddress!.city : _activeLocation;

  String deliveryHeadline(String userName) {
    final recipient = userName.trim().isEmpty ? 'You' : userName.trim();
    final city = displayCity.trim().isEmpty ? _activeLocation : displayCity.trim();
    return 'Delivering to $recipient, $city';
  }

  String deliverySubline() {
    if (_isManualLocation) {
      return AbzoraText.locationManualSubtitle;
    }
    return AbzoraText.locationSubtext;
  }

  Future<void> bootstrap({
    required List<Store> stores,
    AppUser? user,
    bool forceRefresh = false,
  }) async {
    _currentUser = user ?? _currentUser;
    updateStores(stores, notify: false);

    if (!forceRefresh && _currentUser != null) {
      final appliedSaved = _applySavedUserLocation(_currentUser!, notify: false);
      if (appliedSaved) {
        _recalculateNearbyStores();
        notifyListeners();
        return;
      }
    }

    await refreshCurrentLocation(user: _currentUser, forceRefresh: forceRefresh, notifyAfter: true);
  }

  void updateStores(List<Store> stores, {bool notify = true}) {
    _stores = stores;
    _recalculateNearbyStores();
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> setRadiusKm(double radiusKm) async {
    _radiusKm = radiusKm;
    _recalculateNearbyStores();
    notifyListeners();
    await persistRadiusOnly();
  }

  Future<void> setManualLocation(String city, {AppUser? user}) async {
    final selected = _manualCities[city];
    if (selected == null) {
      return;
    }

    _currentUser = user ?? _currentUser;
    _isManualLocation = true;
    _status = LocationStatus.manual;
    _errorMessage = 'Using manual city until GPS is available.';
    _activeLocation = selected.city;
    _resolvedAddress = LocationAddress(
      address: selected.city,
      area: selected.city,
      city: selected.city,
      state: '',
      postalCode: '',
    );
    _userPosition = Position(
      longitude: selected.longitude,
      latitude: selected.latitude,
      timestamp: DateTime.now(),
      accuracy: 5000,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
    _recalculateNearbyStores();
    notifyListeners();
    await _persistLocation(selected.city, _resolvedAddress!, _userPosition!);
  }

  Future<void> refreshCurrentLocation({
    AppUser? user,
    bool forceRefresh = false,
    bool notifyAfter = true,
  }) async {
    _currentUser = user ?? _currentUser;
    _isLoading = true;
    _errorMessage = null;
    if (notifyAfter) {
      notifyListeners();
    }

    final result = await _locationService.getCurrentLocation(forceRefresh: forceRefresh);
    _status = result.status;

    if (result.status == LocationStatus.success && result.position != null) {
      _isManualLocation = false;
      _userPosition = result.position;
      _resolvedAddress = result.address;
      _activeLocation = result.address?.city.trim().isNotEmpty == true ? result.address!.city : _activeLocation;
      _errorMessage = null;
      _recalculateNearbyStores();
      await _persistLocation(_activeLocation, _resolvedAddress, _userPosition!);
    } else if (_currentUser != null && _applySavedUserLocation(_currentUser!, notify: false)) {
      _errorMessage = result.message ?? 'Using your saved delivery location.';
      _recalculateNearbyStores();
    } else {
      final fallbackCity = _currentUser?.city?.trim().isNotEmpty == true ? _currentUser!.city!.trim() : _activeLocation;
      await setManualLocation(fallbackCity, user: _currentUser);
      _errorMessage = result.message ?? _friendlyError(result.status);
    }

    _isLoading = false;
    if (notifyAfter) {
      notifyListeners();
    }
  }

  Future<void> requestLocationAccess({AppUser? user}) async {
    await refreshCurrentLocation(user: user, forceRefresh: true);
  }

  Future<void> startLocationUpdates({AppUser? user}) async {
    _currentUser = user ?? _currentUser;
    await _positionSubscription?.cancel();
    _positionSubscription = _locationService.watchLocation(distanceFilter: 250).listen((position) async {
      _userPosition = position;
      _resolvedAddress = await _locationService.reverseGeocode(position.latitude, position.longitude);
      _activeLocation = _resolvedAddress?.city.trim().isNotEmpty == true ? _resolvedAddress!.city : _activeLocation;
      _status = LocationStatus.success;
      _isManualLocation = false;
      _errorMessage = null;
      _recalculateNearbyStores();
      notifyListeners();
      await _persistLocation(_activeLocation, _resolvedAddress, position);
    });
    _isWatchingLocation = true;
  }

  Future<void> stopLocationUpdates() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _isWatchingLocation = false;
  }

  Future<bool> openSystemLocationSettings() => _locationService.openSystemLocationSettings();

  Future<bool> openSystemAppSettings() => _locationService.openSystemAppSettings();

  bool _applySavedUserLocation(AppUser user, {bool notify = true}) {
    final hasCoordinates = user.latitude != null && user.longitude != null;
    final savedCity = user.city?.trim().isNotEmpty == true
        ? user.city!.trim()
        : _extractCity(user.address ?? '');
    if (!hasCoordinates && savedCity.isEmpty) {
      return false;
    }

    _activeLocation = savedCity.isNotEmpty ? savedCity : _activeLocation;
    _radiusKm = radiusOptionsKm.contains(user.deliveryRadiusKm) ? user.deliveryRadiusKm : defaultRadiusKm;
    _resolvedAddress = LocationAddress(
      address: (user.address ?? '').trim().isEmpty ? _activeLocation : user.address!.trim(),
      area: user.area?.trim() ?? '',
      city: savedCity,
      state: '',
      postalCode: '',
    );
    if (hasCoordinates) {
      _userPosition = Position(
        longitude: user.longitude!,
        latitude: user.latitude!,
        timestamp: DateTime.tryParse(user.locationUpdatedAt ?? '') ?? DateTime.now(),
        accuracy: 20,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
      _status = LocationStatus.success;
      _isManualLocation = false;
    } else {
      final manual = _manualCities[_activeLocation] ?? _manualCities.values.first;
      _userPosition = Position(
        longitude: manual.longitude,
        latitude: manual.latitude,
        timestamp: DateTime.now(),
        accuracy: 5000,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
      _status = LocationStatus.manual;
      _isManualLocation = true;
    }
    _recalculateNearbyStores();
    if (notify) {
      notifyListeners();
    }
    return true;
  }

  Future<void> _persistLocation(
    String city,
    LocationAddress? address,
    Position position,
  ) async {
    final currentUser = _currentUser;
    if (currentUser == null) {
      return;
    }
    final updated = currentUser.copyWith(
      address: address?.address ?? currentUser.address,
      area: address?.area.isNotEmpty == true ? address!.area : currentUser.area,
      city: city,
      latitude: position.latitude,
      longitude: position.longitude,
      deliveryRadiusKm: _radiusKm,
      locationUpdatedAt: DateTime.now().toIso8601String(),
    );
    _currentUser = updated;
    await _db.saveUser(updated);
  }

  Future<void> persistRadiusOnly() async {
    final currentUser = _currentUser;
    if (currentUser == null) {
      return;
    }
    final updated = currentUser.copyWith(
      deliveryRadiusKm: _radiusKm,
      city: displayCity,
      address: _resolvedAddress?.address ?? currentUser.address,
      area: _resolvedAddress?.area.isNotEmpty == true ? _resolvedAddress!.area : currentUser.area,
      locationUpdatedAt: currentUser.locationUpdatedAt ?? DateTime.now().toIso8601String(),
    );
    _currentUser = updated;
    await _db.saveUser(updated);
  }

  void _recalculateNearbyStores() {
    if (_userPosition == null) {
      _nearbyStores = const [];
      _isUsingNearestFallback = false;
      return;
    }

    final distances = <NearbyStore>[];
    for (final store in _stores) {
      if (store.latitude == null || store.longitude == null) {
        continue;
      }
      final distanceKm = _locationService.distanceInKm(
        startLatitude: _userPosition!.latitude,
        startLongitude: _userPosition!.longitude,
        endLatitude: store.latitude!,
        endLongitude: store.longitude!,
      );
      distances.add(
        NearbyStore(
          store: store,
          distanceKm: (distanceKm * 10).roundToDouble() / 10,
        ),
      );
    }

    distances.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    final filtered = distances.where((store) => store.distanceKm <= _radiusKm).toList();
    if (filtered.isNotEmpty) {
      _nearbyStores = filtered;
      _isUsingNearestFallback = false;
      return;
    }

    _nearbyStores = distances.take(10).toList();
    _isUsingNearestFallback = _nearbyStores.isNotEmpty;
  }

  String _extractCity(String address) {
    final parts = address
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '';
    }
    return parts.last;
  }

  String _friendlyError(LocationStatus status) {
    switch (status) {
      case LocationStatus.permissionDenied:
        return 'Allow location access to discover nearby stores.';
      case LocationStatus.permissionDeniedForever:
        return 'Location permission is blocked. Open app settings to enable it.';
      case LocationStatus.serviceDisabled:
        return 'Turn on device location to see nearby stores.';
      case LocationStatus.timeout:
        return 'Location timed out. Using a fallback city for now.';
      case LocationStatus.manual:
        return 'Using a manual city.';
      case LocationStatus.error:
      case LocationStatus.success:
        return 'Unable to fetch GPS right now.';
    }
  }

  @override
  void dispose() {
    if (_isWatchingLocation) {
      _positionSubscription?.cancel();
    }
    super.dispose();
  }
}

class _ManualCity {
  final String city;
  final double latitude;
  final double longitude;

  const _ManualCity(this.city, this.latitude, this.longitude);
}
