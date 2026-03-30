import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/rider_service.dart';
import '../../theme.dart';
import '../../widgets/state_views.dart';
import 'delivery_screen.dart';

class RiderRouteScreen extends StatefulWidget {
  const RiderRouteScreen({super.key});

  @override
  State<RiderRouteScreen> createState() => _RiderRouteScreenState();
}

class _RiderRouteScreenState extends State<RiderRouteScreen> {
  final _service = RiderService();
  Future<List<RiderRouteStop>>? _routeFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeFuture ??= _loadRoute();
  }

  Future<List<RiderRouteStop>> _loadRoute() {
    final rider = context.read<AuthProvider>().user;
    if (rider == null) {
      return Future.value(const <RiderRouteStop>[]);
    }
    return _service.getOptimizedRoute(rider);
  }

  Future<void> _refresh() async {
    late final Future<List<RiderRouteStop>> future;
    setState(() {
      future = _loadRoute();
      _routeFuture = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final rider = context.watch<AuthProvider>().user;
    if (rider == null) {
      return const Scaffold(
        body: AbzioLoadingView(
          title: 'Preparing your route',
          subtitle: 'Loading rider context.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Optimized Route')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<RiderRouteStop>>(
          future: _routeFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListView(
                physics: AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: 140),
                  AbzioLoadingView(
                    title: 'Building your route',
                    subtitle: 'Sorting deliveries and return pickups by distance.',
                  ),
                ],
              );
            }

            final stops = snapshot.data ?? const <RiderRouteStop>[];
            final deliveries = stops.where((stop) => !stop.isReturn).toList();
            final returns = stops.where((stop) => stop.isReturn).toList();

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _RouteHeroCard(
                  riderName: rider.name.trim().isEmpty ? 'ABZORA Rider' : rider.name.trim(),
                  totalStops: stops.length,
                  deliveryCount: deliveries.length,
                  returnCount: returns.length,
                ),
                const SizedBox(height: 20),
                if (stops.isEmpty)
                  const AbzioEmptyCard(
                    title: 'No active route yet',
                    subtitle: 'Accepted deliveries and nearby return pickups will appear here automatically.',
                  )
                else ...[
                  if (deliveries.isNotEmpty) ...[
                    _RouteSectionHeader(
                      title: 'Deliveries First',
                      subtitle: 'Orders closest to you and ready to complete.',
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(
                      deliveries.length,
                      (index) => _RouteStopCard(
                        stop: deliveries[index],
                        index: index + 1,
                        onAction: () {
                          final order = deliveries[index].order;
                          if (order == null) {
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => DeliveryScreen(order: order)),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (returns.isNotEmpty) ...[
                    _RouteSectionHeader(
                      title: 'Nearby Return Pickups',
                      subtitle: 'Bundle these stops while you are already in the area.',
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(
                      returns.length,
                      (index) => _RouteStopCard(
                        stop: returns[index],
                        index: deliveries.length + index + 1,
                        onAction: () async {
                          final stop = returns[index];
                          final messenger = ScaffoldMessenger.of(context);
                          if (stop.task.returnId == null) {
                            return;
                          }
                          if (stop.task.status == 'assigned') {
                            await _service.markReturnPicked(
                              returnId: stop.task.returnId!,
                              rider: rider,
                            );
                          } else if (stop.task.status == 'in_progress') {
                            await _service.completeReturn(
                              returnId: stop.task.returnId!,
                              rider: rider,
                            );
                          }
                          if (!mounted) {
                            return;
                          }
                          messenger.showSnackBar(
                            SnackBar(
                              behavior: SnackBarBehavior.floating,
                              content: Text(
                                stop.task.status == 'assigned'
                                    ? 'Return pickup marked as picked.'
                                    : 'Return completed successfully.',
                              ),
                            ),
                          );
                          await _refresh();
                        },
                      ),
                    ),
                  ],
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RouteHeroCard extends StatelessWidget {
  const _RouteHeroCard({
    required this.riderName,
    required this.totalStops,
    required this.deliveryCount,
    required this.returnCount,
  });

  final String riderName;
  final int totalStops;
  final int deliveryCount;
  final int returnCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.black, Color(0xFF191919)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TODAY\'S ROUTE',
            style: GoogleFonts.poppins(
              color: AbzioTheme.accentColor,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Drive smarter, $riderName',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your route keeps deliveries first, then nearby return pickups to cut empty trips.',
            style: GoogleFonts.inter(
              color: Colors.white70,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroMetricChip(label: 'Stops', value: '$totalStops'),
              _HeroMetricChip(label: 'Deliveries', value: '$deliveryCount'),
              _HeroMetricChip(label: 'Returns', value: '$returnCount'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetricChip extends StatelessWidget {
  const _HeroMetricChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteSectionHeader extends StatelessWidget {
  const _RouteSectionHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AbzioTheme.accentColor,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: GoogleFonts.inter(color: AbzioTheme.grey600, height: 1.4),
        ),
      ],
    );
  }
}

class _RouteStopCard extends StatelessWidget {
  const _RouteStopCard({
    required this.stop,
    required this.index,
    required this.onAction,
  });

  final RiderRouteStop stop;
  final int index;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final accent = stop.isReturn ? Colors.orange : Colors.blue;
    final statusLabel = switch (stop.task.status) {
      'in_progress' => stop.isReturn ? 'Picked' : 'Active',
      'completed' => 'Completed',
      _ => 'Assigned',
    };

    final buttonLabel = stop.isReturn
        ? (stop.task.status == 'assigned'
            ? 'Mark Picked'
            : (stop.task.status == 'in_progress' ? 'Complete Return' : 'Completed'))
        : 'Open Delivery';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$index',
                  style: GoogleFonts.poppins(
                    color: accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.routeLabel,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stop.customerName,
                      style: GoogleFonts.inter(color: AbzioTheme.grey600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: accent,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            stop.task.address,
            style: GoogleFonts.inter(color: AbzioTheme.grey600, height: 1.45),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _MiniInfoChip(
                icon: Icons.route_outlined,
                label: stop.distanceKm == null
                    ? 'Distance unavailable'
                    : '${stop.distanceKm!.toStringAsFixed(1)} km away',
              ),
              _MiniInfoChip(
                icon: Icons.phone_outlined,
                label: stop.customerPhone,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            stop.supportText,
            style: GoogleFonts.inter(fontSize: 12, color: AbzioTheme.grey500),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: stop.task.status == 'completed'
                ? OutlinedButton(
                    onPressed: null,
                    child: const Text('Completed'),
                  )
                : ElevatedButton(
                    onPressed: onAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: stop.isReturn ? accent : Colors.black,
                    ),
                    child: Text(buttonLabel),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MiniInfoChip extends StatelessWidget {
  const _MiniInfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AbzioTheme.grey50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AbzioTheme.grey500),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AbzioTheme.grey600,
            ),
          ),
        ],
      ),
    );
  }
}
