import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:maps_launcher/maps_launcher.dart';

import '../../core/constants/rider_app_colors.dart';
import '../../core/services/rider_api_service.dart';
import '../../core/services/rider_socket_service.dart';
import '../../core/widgets/rider_glass_card.dart';
import '../../models/models.dart';
import '../../services/location_service.dart';

class RiderLiveTrackingScreen extends StatefulWidget {
  const RiderLiveTrackingScreen({
    super.key,
    required this.order,
    required this.rider,
  });

  final OrderModel order;
  final AppUser rider;

  @override
  State<RiderLiveTrackingScreen> createState() =>
      _RiderLiveTrackingScreenState();
}

class _RiderLiveTrackingScreenState extends State<RiderLiveTrackingScreen> {
  static const List<String> _statuses = <String>[
    'Accepted',
    'Arriving at Store',
    'Picked Up',
    'On The Way',
    'Arriving Soon',
    'Delivered',
  ];

  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();
  final RiderSocketService _socketService = RiderSocketService();
  final RiderApiService _apiService = RiderApiService();
  late final ConfettiController _confettiController;

  Timer? _locationTimer;
  Timer? _etaTimer;
  int _statusIndex = 0;
  bool _connected = false;
  bool _completing = false;

  LatLng? _riderPosition;
  LatLng? _pickupPosition;
  LatLng? _customerPosition;

  double _remainingKm = 0;
  int _etaMinutes = 0;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
    _initialize();
  }

  Future<void> _initialize() async {
    _connectSocket();
    await _resolveAnchors();
    await _tickLocationUpdate();
    _locationTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _tickLocationUpdate(),
    );
    _etaTimer = Timer.periodic(
      const Duration(seconds: 6),
      (_) => _refreshEta(),
    );
  }

  void _connectSocket() {
    final authToken = FirebaseAuth.instance.currentUser;
    if (authToken == null) {
      return;
    }
    authToken.getIdToken().then((token) {
      if (token == null || token.isEmpty) {
        return;
      }
      _socketService.connect(
        riderId: widget.rider.id,
        authToken: token,
        orderId: widget.order.id,
      );
    });
    _socketService.onConnect(() {
      if (mounted) {
        setState(() => _connected = true);
      }
      _socketService.emitOrderAssigned(
        orderId: widget.order.id,
        riderId: widget.rider.id,
      );
    });
    _socketService.onDisconnect(() {
      if (mounted) {
        setState(() => _connected = false);
      }
    });
  }

  Future<void> _resolveAnchors() async {
    final riderLat = widget.rider.latitude;
    final riderLng = widget.rider.longitude;
    if (riderLat != null && riderLng != null) {
      _riderPosition = LatLng(riderLat, riderLng);
    }

    final pickupSeed = await _locationService.geocodeAddress(
      'Store pickup ${widget.order.storeId}',
    );
    if (pickupSeed.latitude != null && pickupSeed.longitude != null) {
      _pickupPosition = LatLng(pickupSeed.latitude!, pickupSeed.longitude!);
    }

    final customerGeo = await _locationService.geocodeAddress(
      widget.order.shippingAddress,
    );
    if (customerGeo.latitude != null && customerGeo.longitude != null) {
      _customerPosition = LatLng(customerGeo.latitude!, customerGeo.longitude!);
    }

    if (mounted) {
      setState(() {});
      _fitCamera();
    }
  }

  Future<void> _tickLocationUpdate() async {
    final result = await _locationService.getCurrentLocation();
    final position = result.position;
    if (position == null) {
      return;
    }

    _riderPosition = LatLng(position.latitude, position.longitude);
    if (mounted) {
      setState(() {});
      _fitCamera();
    }

    _socketService.emitLocationUpdate(
      orderId: widget.order.id,
      riderId: widget.rider.id,
      latitude: position.latitude,
      longitude: position.longitude,
    );
    await _apiService.postLocationUpdate(
      orderId: widget.order.id,
      riderId: widget.rider.id,
      latitude: position.latitude,
      longitude: position.longitude,
    );
    await _refreshEta();
    _autoProgressStatus(position);
  }

  Future<void> _refreshEta() async {
    if (_riderPosition == null || _activeTarget == null) {
      return;
    }

    final km = _locationService.distanceInKm(
      startLatitude: _riderPosition!.latitude,
      startLongitude: _riderPosition!.longitude,
      endLatitude: _activeTarget!.latitude,
      endLongitude: _activeTarget!.longitude,
    );

    final etaResponse = await _apiService.fetchEtaByOrderId(
      orderId: widget.order.id,
    );
    final backendEta = (etaResponse['data'] is Map)
        ? ((etaResponse['data']['etaMinutes'] as num?)?.toInt())
        : ((etaResponse['etaMinutes'] as num?)?.toInt());
    final fallbackEta = (km / 0.45).ceil();

    if (!mounted) {
      return;
    }
    setState(() {
      _remainingKm = km;
      _etaMinutes = backendEta ?? fallbackEta;
    });
  }

  void _autoProgressStatus(Position position) {
    if (_statusIndex >= _statuses.length - 1) {
      return;
    }
    final target = _activeTarget;
    if (target == null) {
      return;
    }

    final meters = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      target.latitude,
      target.longitude,
    );

    if (_statusIndex < 2 && meters <= 200) {
      _updateStatus(2);
      return;
    }
    if (_statusIndex >= 2 && _statusIndex < 4 && meters <= 1500) {
      _updateStatus(4);
      return;
    }
    if (_statusIndex >= 4 && meters <= 180) {
      _updateStatus(5);
    }
  }

  LatLng? get _activeTarget =>
      _statusIndex < 2 ? _pickupPosition : _customerPosition;

  Future<void> _updateStatus(int nextIndex) async {
    if (nextIndex <= _statusIndex || nextIndex >= _statuses.length) {
      return;
    }
    final nextStatus = _statuses[nextIndex];
    setState(() => _statusIndex = nextIndex);

    _socketService.emitStatusUpdate(
      orderId: widget.order.id,
      status: nextStatus,
    );
    await _apiService.updateDeliveryStatus(
      orderId: widget.order.id,
      status: nextStatus,
    );

    if (nextStatus == 'Delivered') {
      await _completeDelivery();
    }
  }

  Future<void> _completeDelivery() async {
    if (_completing) {
      return;
    }
    setState(() => _completing = true);
    await _apiService.completeDelivery(
      orderId: widget.order.id,
      riderId: widget.rider.id,
    );
    _socketService.emitDeliveryCompleted(
      orderId: widget.order.id,
      riderId: widget.rider.id,
    );
    _confettiController.play();

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Delivery completed. Earned Rs ${(widget.order.totalAmount * 0.1).toStringAsFixed(0)}',
        ),
      ),
    );
    setState(() => _completing = false);
  }

  void _fitCamera() {
    final points = <LatLng>[
      ...?(_riderPosition == null ? null : <LatLng>[_riderPosition!]),
      ...?(_pickupPosition == null ? null : <LatLng>[_pickupPosition!]),
      ...?(_customerPosition == null ? null : <LatLng>[_customerPosition!]),
    ];
    if (points.length < 2) {
      return;
    }
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(80),
      ),
    );
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _etaTimer?.cancel();
    _socketService.disconnect();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final polylinePoints = <LatLng>[
      ...?(_riderPosition == null ? null : <LatLng>[_riderPosition!]),
      ...?(_activeTarget == null ? null : <LatLng>[_activeTarget!]),
    ];

    return Scaffold(
      backgroundColor: RiderAppColors.black,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _riderPosition ?? const LatLng(12.9716, 77.5946),
              initialZoom: 13,
              maxZoom: 18,
              minZoom: 3,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.abzora.rider',
              ),
              PolylineLayer(
                polylines: [
                  if (polylinePoints.length >= 2)
                    Polyline(
                      points: polylinePoints,
                      strokeWidth: 5,
                      color: RiderAppColors.orange.withValues(alpha: 0.75),
                    ),
                ],
              ),
              MarkerLayer(markers: _markers()),
            ],
          ),
          Positioned(
            top: 46,
            left: 18,
            right: 18,
            child: RiderGlassCard(
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 10,
                    color: _connected ? Colors.greenAccent : Colors.redAccent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _connected
                          ? 'Live tracking connected'
                          : 'Reconnecting live tracking...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '$_etaMinutes min',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.2),
          ),
          _bottomSheet(),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
            ),
          ),
        ],
      ),
    );
  }

  List<Marker> _markers() {
    return <Marker>[
      if (_riderPosition != null)
        Marker(
          point: _riderPosition!,
          width: 46,
          height: 46,
          child: _glowMarker(Icons.pedal_bike, RiderAppColors.orange),
        ),
      if (_pickupPosition != null)
        Marker(
          point: _pickupPosition!,
          width: 44,
          height: 44,
          child: _glowMarker(Icons.storefront, Colors.cyanAccent),
        ),
      if (_customerPosition != null)
        Marker(
          point: _customerPosition!,
          width: 44,
          height: 44,
          child: _glowMarker(Icons.location_on, Colors.greenAccent),
        ),
    ];
  }

  Widget _glowMarker(IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.22),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 16),
        ],
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _bottomSheet() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        minimum: const EdgeInsets.all(12),
        child: RiderGlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Order ${widget.order.id}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Store: ${widget.order.storeId}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 6),
              Text(
                'Drop: ${widget.order.shippingAddress}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip('${_remainingKm.toStringAsFixed(1)} km remaining'),
                  _chip('$_etaMinutes mins away'),
                  _chip(
                    'Earn Rs ${(widget.order.totalAmount * 0.1).toStringAsFixed(0)}',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _statusTracker(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickupPosition == null
                          ? null
                          : () => MapsLauncher.launchCoordinates(
                              _pickupPosition!.latitude,
                              _pickupPosition!.longitude,
                              'Pickup Location',
                            ),
                      icon: const Icon(Icons.navigation),
                      label: const Text('Navigate Pickup'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _customerPosition == null
                          ? null
                          : () => MapsLauncher.launchCoordinates(
                              _customerPosition!.latitude,
                              _customerPosition!.longitude,
                              'Customer Location',
                            ),
                      icon: const Icon(Icons.directions),
                      label: const Text('Navigate Customer'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ).animate().slideY(begin: 0.2, duration: 350.ms).fadeIn(duration: 350.ms),
      ),
    );
  }

  Widget _statusTracker() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List<Widget>.generate(_statuses.length, (index) {
        final active = index <= _statusIndex;
        return GestureDetector(
          onTap: () => _updateStatus(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: active
                  ? RiderAppColors.orange.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.06),
              border: Border.all(
                color: active ? RiderAppColors.orange : Colors.white24,
              ),
            ),
            child: Text(
              _statuses[index],
              style: TextStyle(
                color: active ? RiderAppColors.orange : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }
}
