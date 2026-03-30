import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../services/location_service.dart';
import '../../services/location_tracker.dart';
import '../../services/rider_service.dart';
import '../../theme.dart';
import '../../widgets/state_views.dart';

class DeliveryScreen extends StatefulWidget {
  const DeliveryScreen({
    super.key,
    required this.order,
  });

  final OrderModel order;

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  final _db = DatabaseService();
  final _riderService = RiderService();
  final _locationService = LocationService();
  final _tracker = LocationTracker();
  bool _processing = false;

  @override
  void dispose() {
    _tracker.stop();
    super.dispose();
  }

  Future<void> _setStatus(String status) async {
    final rider = context.read<AuthProvider>().user;
    if (rider == null) {
      return;
    }
    setState(() => _processing = true);
    try {
      await _riderService.updateDeliveryStatus(
        orderId: widget.order.id,
        deliveryStatus: status,
        rider: rider,
      );
      if (status == 'Picked up' || status == 'Out for delivery') {
        await _tracker.startOrderTracking(orderId: widget.order.id, rider: rider);
      } else if (status == 'Delivered') {
        await _tracker.stop();
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Delivery updated to $status.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  Future<double?> _distanceFor(AppUser? customer) async {
    final rider = context.read<AuthProvider>().user;
    if (rider?.latitude == null || rider?.longitude == null) {
      return null;
    }
    double? targetLat = customer?.latitude;
    double? targetLng = customer?.longitude;
    if (targetLat == null || targetLng == null) {
      final geo = await _locationService.geocodeAddress(widget.order.shippingAddress);
      targetLat = geo.latitude;
      targetLng = geo.longitude;
    }
    if (targetLat == null || targetLng == null) {
      return null;
    }
    return _locationService.distanceInKm(
      startLatitude: rider!.latitude!,
      startLongitude: rider.longitude!,
      endLatitude: targetLat,
      endLongitude: targetLng,
    );
  }

  @override
  Widget build(BuildContext context) {
    final rider = context.watch<AuthProvider>().user;
    if (rider == null) {
      return const Scaffold(
        body: AbzioLoadingView(
          title: 'Opening delivery',
          subtitle: 'Preparing order details.',
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Delivery')),
      body: FutureBuilder<AppUser?>(
        future: _db.getUser(widget.order.userId),
        builder: (context, customerSnapshot) {
          final customer = customerSnapshot.data;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _heroCard(customer),
              const SizedBox(height: 16),
              FutureBuilder<double?>(
                future: _distanceFor(customer),
                builder: (context, distanceSnapshot) {
                  return _customerCard(customer, distanceSnapshot.data);
                },
              ),
              const SizedBox(height: 16),
              _itemsCard(),
              const SizedBox(height: 16),
              _actionsCard(),
            ],
          );
        },
      ),
    );
  }

  Widget _heroCard(AppUser? customer) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ORDER ${widget.order.invoiceNumber.isEmpty ? widget.order.id : widget.order.invoiceNumber}',
            style: GoogleFonts.poppins(
              color: AbzioTheme.accentColor,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            customer?.name.isNotEmpty == true ? customer!.name : 'Customer delivery',
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 22),
          ),
          const SizedBox(height: 6),
          Text(
            widget.order.deliveryStatus,
            style: GoogleFonts.inter(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _customerCard(AppUser? customer, double? distanceKm) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AbzioTheme.grey100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Customer Details', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _detailRow(Icons.person_outline_rounded, customer?.name.isNotEmpty == true ? customer!.name : 'Customer'),
          _detailRow(Icons.location_on_outlined, widget.order.shippingAddress),
          _detailRow(Icons.phone_outlined, customer?.phone?.isNotEmpty == true ? customer!.phone! : 'Phone unavailable'),
          _detailRow(Icons.route_outlined, distanceKm == null ? 'Distance unavailable' : '${distanceKm.toStringAsFixed(1)} km away'),
        ],
      ),
    );
  }

  Widget _itemsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AbzioTheme.grey100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Order Items', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...widget.order.items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(item.productName, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  ),
                  Text('x${item.quantity}', style: GoogleFonts.inter(color: AbzioTheme.grey600)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _actionsCard() {
    final status = widget.order.deliveryStatus;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AbzioTheme.grey100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Delivery Actions', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          if (status == 'Assigned')
            _actionButton('Pick Up Order', () => _setStatus('Picked up')),
          if (status == 'Picked up')
            _actionButton('Start Delivery', () => _setStatus('Out for delivery')),
          if (status == 'Out for delivery')
            _actionButton('Mark as Delivered', () => _setStatus('Delivered')),
          if (status == 'Delivered')
            const AbzioEmptyCard(
              title: 'Delivery completed',
              subtitle: 'This order has already been marked as delivered.',
            ),
        ],
      ),
    );
  }

  Widget _actionButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _processing ? null : onPressed,
        child: _processing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(label),
      ),
    );
  }

  Widget _detailRow(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AbzioTheme.grey600),
          const SizedBox(width: 10),
          Expanded(child: Text(value, style: GoogleFonts.inter(height: 1.4))),
        ],
      ),
    );
  }
}
