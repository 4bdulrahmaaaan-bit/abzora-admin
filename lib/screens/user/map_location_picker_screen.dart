import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../services/location_service.dart';

class MapLocationPickerScreen extends StatefulWidget {
  const MapLocationPickerScreen({super.key});

  @override
  State<MapLocationPickerScreen> createState() => _MapLocationPickerScreenState();
}

class _MapLocationPickerScreenState extends State<MapLocationPickerScreen> {
  final LocationService _locationService = LocationService();
  final Completer<GoogleMapController> _controller = Completer();
  
  CameraPosition _initialPosition = const CameraPosition(
    target: LatLng(20.5937, 78.9629), // Default center of India
    zoom: 5,
  );
  
  LatLng? _currentCenter;
  LocationAddress? _currentAddress;
  bool _isLoadingAddress = false;
  bool _isGettingLocation = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentCenter = _initialPosition.target;
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    setState(() {
      _isGettingLocation = true;
    });
    
    // Check permission without requesting. If granted, use current location.
    // If not, we stay on the default location.
    final result = await _locationService.getCurrentLocation();
    if (result.status == LocationStatus.success && result.address != null) {
      if (result.position?.latitude != null && result.position?.longitude != null) {
        final currentLatLng = LatLng(result.position!.latitude, result.position!.longitude);
        setState(() {
          _initialPosition = CameraPosition(target: currentLatLng, zoom: 15);
          _currentCenter = currentLatLng;
          _currentAddress = result.address;
        });
        
        if (_controller.isCompleted) {
          final GoogleMapController controller = await _controller.future;
          controller.animateCamera(CameraUpdate.newCameraPosition(_initialPosition));
        }
      }
    }
    
    setState(() {
      _isGettingLocation = false;
    });
    
    if (_currentAddress == null) {
      _reverseGeocodeCenter();
    }
  }

  Future<void> _reverseGeocodeCenter() async {
    if (_currentCenter == null) return;
    
    setState(() {
      _isLoadingAddress = true;
    });
    
    try {
      final address = await _locationService.reverseGeocode(
        _currentCenter!.latitude,
        _currentCenter!.longitude,
      );
      if (mounted) {
        setState(() {
          _currentAddress = address;
        });
      }
    } catch (e) {
      debugPrint('Error reverse geocoding: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAddress = false;
        });
      }
    }
  }

  Future<void> _handleSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    
    FocusScope.of(context).unfocus();
    
    setState(() {
      _isLoadingAddress = true;
    });
    
    final result = await _locationService.geocodeAddress(query);
    if (result.status == AddressLookupStatus.success && result.latitude != null && result.longitude != null) {
      final latLng = LatLng(result.latitude!, result.longitude!);
      
      if (_controller.isCompleted) {
        final GoogleMapController controller = await _controller.future;
        controller.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
      }
      
      setState(() {
        _currentCenter = latLng;
      });
      
      await _reverseGeocodeCenter();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location not found. Please try a different search.')),
        );
        setState(() {
          _isLoadingAddress = false;
        });
      }
    }
  }

  void _onCameraMove(CameraPosition position) {
    _currentCenter = position.target;
    if (_currentAddress != null) {
      setState(() {
        _currentAddress = null; // Clear address while moving
      });
    }
  }

  void _onCameraIdle() {
    _reverseGeocodeCenter();
  }

  Future<void> _moveToCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });
    
    final result = await _locationService.getCurrentLocation();
    if (result.status == LocationStatus.success && result.position?.latitude != null && result.position?.longitude != null) {
      final latLng = LatLng(result.position!.latitude, result.position!.longitude);
      if (_controller.isCompleted) {
        final GoogleMapController controller = await _controller.future;
        controller.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
      }
      setState(() {
        _currentCenter = latLng;
      });
      await _reverseGeocodeCenter();
    } else if (result.status == LocationStatus.permissionDeniedForever || result.status == LocationStatus.serviceDisabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.message ?? 'Location access is unavailable.'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () async {
              if (result.status == LocationStatus.serviceDisabled) {
                await _locationService.openSystemLocationSettings();
              } else {
                await _locationService.openSystemAppSettings();
              }
            },
          ),
        ));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? 'Unable to fetch your location right now.')),
        );
      }
    }
    
    if (mounted) {
      setState(() {
        _isGettingLocation = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialPosition,
            myLocationEnabled: true,
            myLocationButtonEnabled: false, // We use a custom FAB
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
          ),
          
          // Center Pin Marker
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 40.0), // Adjust to center the bottom point of the pin
              child: Icon(
                Icons.location_on,
                size: 40,
                color: Color(0xFFB08D2B), // Abzio gold
              ),
            ),
          ),
          
          // Search Bar overlay
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search locality, city...',
                  border: InputBorder.none,
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () {
                      _searchController.clear();
                    },
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _handleSearch(),
              ),
            ),
          ),
          
          // My Location FAB
          Positioned(
            right: 16,
            bottom: 180,
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              onPressed: _moveToCurrentLocation,
              child: _isGettingLocation
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location, color: Colors.black),
            ),
          ),
          
          // Bottom Address Sheet overlay
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Selected Location',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_isLoadingAddress)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_currentAddress != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Color(0xFFB08D2B), size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentAddress!.area.isNotEmpty
                                    ? _currentAddress!.area
                                    : _currentAddress!.city,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                [
                                  if (_currentAddress!.address.isNotEmpty) _currentAddress!.address,
                                  if (_currentAddress!.city.isNotEmpty) _currentAddress!.city,
                                  if (_currentAddress!.state.isNotEmpty) _currentAddress!.state,
                                  if (_currentAddress!.postalCode.isNotEmpty) _currentAddress!.postalCode,
                                ].join(', '),
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          // Return the LocationAddress back to the caller
                          Navigator.of(context).pop(_currentAddress);
                        },
                        child: const Text(
                          'Confirm Location',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('Move the pin to select a location'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
