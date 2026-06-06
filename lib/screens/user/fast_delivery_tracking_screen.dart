import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../models/models.dart';
import '../../services/database_service.dart';

class FastDeliveryTrackingScreen extends StatefulWidget {
  const FastDeliveryTrackingScreen({
    super.key,
    required this.order,
  });

  final OrderModel order;

  @override
  State<FastDeliveryTrackingScreen> createState() => _FastDeliveryTrackingScreenState();
}

enum _TrackingStage { confirmed, packed, outForDelivery, delivered }

class _FastDeliveryTrackingScreenState extends State<FastDeliveryTrackingScreen> {
  static const Color _dark = Color(0xFF0B0B0C);
  static const Color _text = Color(0xFFFFFFFF);
  static const Color _sub = Color(0xFF9A9A9A);
  static const Color _green = Color(0xFF00C853);
  static const Color _accent = Color(0xFFC6A769);
  Timer? _refreshTimer;
  final DatabaseService _database = DatabaseService();

  bool _loading = true;
  final bool _mapUnavailable = false;
  bool _showNoTracking = false;
  String? _error;
  bool _detailsExpanded = false;
  AppUser? _rider;

  _TrackingStage _stage = _TrackingStage.confirmed;
  double _markerProgress = 0.35;
  double _progressValue = 0.76;
  String _etaText = 'Arriving in 2-3 hours';
  String _statusText = 'Out for delivery';

  @override
  void initState() {
    super.initState();
    _initScreen();
    _refreshTimer = Timer.periodic(const Duration(seconds: 12), (_) => _refreshTracking(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _initScreen() async {
    await Future<void>.delayed(const Duration(milliseconds: 520));
    if (!mounted) return;
    await _loadRider();
    setState(() {
      _loading = false;
      _error = null;
      _showNoTracking = false;
      _syncFromOrder();
    });
  }

  Future<void> _loadRider() async {
    final riderId = widget.order.riderId?.trim() ?? '';
    if (riderId.isEmpty) {
      return;
    }
    try {
      final rider = await _database.getUser(riderId);
      if (!mounted) {
        return;
      }
      setState(() => _rider = rider);
    } catch (_) {
      // Keep tracking resilient if rider profile fetch fails.
    }
  }

  void _syncFromOrder() {
    final status = (widget.order.deliveryStatus.isNotEmpty
            ? widget.order.deliveryStatus
            : widget.order.status)
        .trim()
        .toLowerCase();
    if (status == 'delivered' || widget.order.isDelivered) {
      _stage = _TrackingStage.delivered;
      _statusText = 'Delivered Successfully';
      _etaText = 'Package delivered';
      _progressValue = 1;
      _markerProgress = 1;
      return;
    }
    if (status == 'out for delivery' || status == 'shipped' || status == 'assigned') {
      _stage = _TrackingStage.outForDelivery;
      _statusText = 'Out for delivery';
      _etaText = 'Arriving in 2-3 hours';
      _progressValue = 0.78;
      return;
    }
    if (status == 'packed') {
      _stage = _TrackingStage.packed;
      _statusText = 'Packed';
      _etaText = 'Handing over to delivery partner';
      _progressValue = 0.55;
      return;
    }
    _stage = _TrackingStage.confirmed;
    _statusText = 'Order confirmed';
    _etaText = 'Preparing your order';
    _progressValue = 0.32;
  }

  Future<void> _refreshTracking({bool silent = false}) async {
    if (!silent) {
      setState(() => _loading = true);
    }
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;

    final next = (_markerProgress + 0.07).clamp(0.0, 1.0);
    setState(() {
      _loading = false;
      _markerProgress = next;
      _progressValue = (0.55 + (next * 0.45)).clamp(0.0, 1.0);
      if (_markerProgress < 0.25) {
        _stage = _TrackingStage.confirmed;
        _statusText = 'Order confirmed';
        _etaText = 'Getting your package ready';
      } else if (_markerProgress < 0.55) {
        _stage = _TrackingStage.packed;
        _statusText = 'Packed';
        _etaText = 'Handing over to delivery partner';
      } else if (_markerProgress <= 0.94) {
        _stage = _TrackingStage.outForDelivery;
        _statusText = 'Out for delivery';
        _etaText = 'Arriving in 2-3 hours';
      }
      if (_markerProgress > 0.94) {
        _stage = _TrackingStage.delivered;
        _statusText = 'Delivered Successfully';
        _etaText = 'Package delivered';
      }
    });
  }

  Future<void> _callPartner() async {
    await HapticFeedback.selectionClick();
    final phone = (_rider?.phone ?? '').trim();
    if (phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Partner phone is not available yet.')),
      );
      return;
    }
    final ok = await launchUrlString('tel:$phone');
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open dialer.')),
      );
    }
  }

  void _openHelp() {
    HapticFeedback.selectionClick();
    Navigator.of(context).pushNamed('/chats');
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _text),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Track Your Delivery',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.playfairDisplay(
                    color: _text,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _stage == _TrackingStage.delivered ? 'Delivered' : 'Arriving Today',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(color: _sub, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _openHelp,
            icon: const Icon(Icons.support_agent_rounded, color: _text),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    final delivered = _stage == _TrackingStage.delivered;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161618).withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 26,
            spreadRadius: 1,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 520),
            switchInCurve: Curves.easeOutCubic,
            child: Text(
              delivered ? 'Delivered Successfully' : _statusText,
              key: ValueKey<String>('status-${_statusText}_$delivered'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.playfairDisplay(
                color: _text,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 420),
            child: Text(
              delivered ? 'Enjoy your outfit' : _etaText,
              key: ValueKey<String>('eta-$_etaText-$delivered'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(color: _sub, fontSize: 13),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            delivered ? 'Delivered with care' : 'Your order is on its way',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(color: _sub, fontSize: 12),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 6,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: const Color(0xFF252528)),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: _progressValue),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeInOutCubic,
                    builder: (context, value, child) {
                      return FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: value,
                        child: child,
                      );
                    },
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_accent, _green],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (delivered) ...[
            const SizedBox(height: 14),
            Row(
              children: List.generate(
                5,
                (index) => const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.star_rounded, color: _accent, size: 20),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 44,
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: _accent,
                  side: const BorderSide(color: _accent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Return / Exchange', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMapSection() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 232,
        width: double.infinity,
        child: _mapUnavailable
            ? Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl:
                        'https://images.unsplash.com/photo-1473186578172-c141e6798cf4?auto=format&fit=crop&w=1200&q=80',
                    fit: BoxFit.cover,
                  ),
                  Container(color: Colors.black.withValues(alpha: 0.5)),
                  Center(
                    child: Text(
                      'Live map unavailable. Tracking visually.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(color: _text, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl:
                        'https://images.unsplash.com/photo-1533929736458-ca588d08c8be?auto=format&fit=crop&w=1200&q=80',
                    fit: BoxFit.cover,
                  ),
                  Container(color: Colors.black.withValues(alpha: 0.35)),
                  Positioned(
                    left: 26,
                    right: 26,
                    top: 110,
                    child: Container(height: 3, color: _accent.withValues(alpha: 0.92)),
                  ),
                  const Positioned(
                    left: 16,
                    top: 97,
                    child: _MapPin(icon: Icons.home_rounded, color: _green),
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 920),
                    curve: Curves.easeInOutCubicEmphasized,
                    left: 16 + (260 * _markerProgress),
                    top: 87,
                    child: const _MapPin(icon: Icons.delivery_dining_rounded, color: _accent),
                  ),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _dark,
      body: SafeArea(
        top: true,
        bottom: true,
        child: _loading
            ? const _TrackingSkeleton()
            : _error != null
                ? _ErrorState(
                    message: _error!,
                    onRetry: () async {
                      setState(() {
                        _error = null;
                        _loading = true;
                      });
                      await _initScreen();
                    },
                  )
                : _showNoTracking
                    ? const _NoTrackingState()
                    : Column(
                        children: [
                          _buildHeader(),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            child: _buildStatusBanner(),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: _buildMapSection(),
                          ),
                          Expanded(
                            child: RefreshIndicator(
                              onRefresh: _refreshTracking,
                              color: _green,
                              child: ListView(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                                children: [
                                  _PartnerCard(
                                    partnerName: _rider?.name.trim().isNotEmpty == true
                                        ? _rider!.name
                                        : widget.order.assignedDeliveryPartner,
                                    partnerPhone: _rider?.phone,
                                    onCall: _callPartner,
                                    onChat: _openHelp,
                                  ),
                                  const SizedBox(height: 12),
                                  _OrderSummaryCard(order: widget.order),
                                  const SizedBox(height: 12),
                                  _ProgressSteps(stage: _stage),
                                  const SizedBox(height: 12),
                                  _DetailsCard(
                                    expanded: _detailsExpanded,
                                    order: widget.order,
                                    etaText: _etaText,
                                    onToggle: () => setState(() => _detailsExpanded = !_detailsExpanded),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: _dark,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _callPartner,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: _dark,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Text('Call Delivery Partner', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: _openHelp,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _accent),
                    foregroundColor: _accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Text('Need Help?', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PartnerCard extends StatelessWidget {
  const _PartnerCard({
    required this.partnerName,
    required this.partnerPhone,
    required this.onCall,
    required this.onChat,
  });

  final String partnerName;
  final String? partnerPhone;
  final VoidCallback onCall;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF171719).withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 24,
            backgroundImage: CachedNetworkImageProvider(
              'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=400&q=80',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  partnerName.trim().isEmpty ? 'Delivery Partner' : partnerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '4.8 rating | Your delivery partner',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(color: const Color(0xFF9A9A9A), fontSize: 12),
                ),
              ],
            ),
          ),
          _actionCircle(icon: Icons.call_rounded, color: const Color(0xFF00C853), onTap: onCall),
          const SizedBox(width: 8),
          _actionCircle(
            icon: Icons.chat_bubble_outline_rounded,
            color: const Color(0xFFC6A769),
            onTap: onChat,
          ),
        ],
      ),
    );
  }

  Widget _actionCircle({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final item = order.items.isNotEmpty ? order.items.first : null;
    final title = item?.productName.trim().isNotEmpty == true
        ? item!.productName
        : 'Fashion Order';
    final imageUrl = item?.imageUrl ?? '';
    final size = item?.size.trim() ?? '';
    final color = (order.customDesignOptions['color'] ?? '').toString().trim();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF171719),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 80,
              height: 100,
              child: imageUrl.isEmpty
                  ? Container(
                      color: const Color(0xFF27272A),
                      child: const Icon(Icons.checkroom_rounded, color: Colors.white54),
                    )
                  : CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Size: ${size.isEmpty ? '-' : size} | Color: ${color.isEmpty ? '-' : color}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 6),
                Text(
                  '₹${order.totalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(color: Color(0xFFC6A769), fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressSteps extends StatelessWidget {
  const _ProgressSteps({required this.stage});

  final _TrackingStage stage;

  @override
  Widget build(BuildContext context) {
    const labels = ['Confirmed', 'Packed', 'Out', 'Delivered'];
    const icons = [
      Icons.receipt_long_rounded,
      Icons.inventory_2_rounded,
      Icons.local_shipping_rounded,
      Icons.check_circle_rounded,
    ];
    final current = stage.index;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF171719),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: List<Widget>.generate(labels.length, (index) {
          final done = index < current;
          final now = index == current;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Tooltip(
                    message: labels[index],
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 320),
                      width: now ? 30 : 24,
                      height: now ? 30 : 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done
                            ? const Color(0xFF00C853)
                            : now
                            ? const Color(0xFFC6A769)
                            : const Color(0xFF3A3A3D),
                        boxShadow: now
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFC6A769).withValues(alpha: 0.30),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        done ? Icons.check_rounded : icons[index],
                        size: 14,
                        color: now || done ? const Color(0xFF0B0B0C) : const Color(0xFF76767A),
                      ),
                    ),
                  ),
                ),
                if (index < labels.length - 1)
                  Container(
                    width: 24,
                    height: 1.5,
                    color: done ? const Color(0xFF00C853) : const Color(0xFF3A3A3D),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({
    required this.expanded,
    required this.onToggle,
    required this.order,
    required this.etaText,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final OrderModel order;
  final String etaText;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF171719),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            onTap: onToggle,
            title: Text(
              'Delivery Details',
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            trailing: Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: Colors.white70),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Address: ${order.shippingAddress.trim().isEmpty ? 'Not available' : order.shippingAddress.trim()}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(color: const Color(0xFF9A9A9A)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'ETA Window: Today, 5:30-7:00 PM',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(color: const Color(0xFF9A9A9A)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    etaText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(color: const Color(0xFF9A9A9A), fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Payment: ${order.isPaymentVerified || order.paymentMethod.toUpperCase() != 'COD' ? 'Paid' : 'Cash on Delivery'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(color: const Color(0xFF00C853), fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [
        BoxShadow(color: color.withValues(alpha: 0.30), blurRadius: 12, offset: const Offset(0, 4)),
      ]),
      child: Icon(icon, size: 15, color: const Color(0xFF0F0F10)),
    );
  }
}

class _TrackingSkeleton extends StatelessWidget {
  const _TrackingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            height: index == 1 ? 220 : 88,
            decoration: BoxDecoration(color: const Color(0xFF18181B), borderRadius: BorderRadius.circular(16)),
          ),
        );
      },
    );
  }
}

class _NoTrackingState extends StatelessWidget {
  const _NoTrackingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Tracking will be available soon',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () => unawaited(onRetry()), child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}


