import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/models.dart';
import 'offline_action_queue.dart';
import 'database_service.dart';

class RiderRouteStop {
  const RiderRouteStop({
    required this.task,
    required this.customer,
    required this.order,
    required this.distanceKm,
    this.etaMins,
  });

  final UnifiedRiderTask task;
  final AppUser? customer;
  final OrderModel? order;
  final double? distanceKm;
  final num? etaMins;

  bool get isReturn => task.type == 'return';

  String get customerName {
    final name = customer?.name.trim() ?? '';
    return name.isNotEmpty ? name : 'Customer';
  }

  String get customerPhone {
    final phone = customer?.phone?.trim() ?? '';
    return phone.isNotEmpty ? phone : 'Phone unavailable';
  }

  String get routeLabel {
    if (isReturn) {
      return 'Return pickup';
    }
    return order?.invoiceNumber.trim().isNotEmpty == true
        ? order!.invoiceNumber.trim()
        : (order?.id ?? task.orderId ?? task.id);
  }

  String get supportText {
    if (isReturn) {
      return task.status == 'in_progress'
          ? 'Return picked up. Head to drop-off or verification.'
          : 'Pickup this return while you are in the area.';
    }
    final count = order?.items.length ?? 0;
    if (count > 0) {
      return '$count item(s) ready on this stop.';
    }
    return 'Delivery synced from your assigned route.';
  }
}

class RiderDashboardSnapshot {
  const RiderDashboardSnapshot({
    required this.analytics,
    required this.wallet,
    required this.availableDeliveries,
    required this.tasks,
    required this.fetchedAt,
  });

  final RiderAnalytics analytics;
  final WalletSummary wallet;
  final List<OrderModel> availableDeliveries;
  final List<UnifiedRiderTask> tasks;
  final DateTime fetchedAt;

  int get assignedCount => tasks.where((task) => task.status == 'assigned').length;
  int get activeCount => tasks.where((task) => task.status == 'in_progress').length;
  int get completedCount => tasks.where((task) => task.status == 'completed').length;
}

class RiderService {
  final DatabaseService _db;

  RiderService({DatabaseService? databaseService}) : _db = databaseService ?? DatabaseService();

  Stream<List<OrderModel>> watchAvailableDeliveries() {
    return _db.watchAvailableDeliveryOrders();
  }

  Stream<List<OrderModel>> watchAssignedOrders(AppUser rider) {
    return _db.getRiderOrders(rider);
  }

  Stream<List<UnifiedRiderTask>> watchUnifiedTasks(AppUser rider) {
    return _db.watchRiderTasks(rider);
  }

  Future<RiderDashboardSnapshot> loadDashboardSnapshot(AppUser rider) async {
    Future<T?> safe<T>(Future<T> Function() loader) async {
      try {
        return await loader();
      } catch (_) {
        return null;
      }
    }

    final analyticsFuture = safe(() => _db.getRiderAnalytics(actor: rider));
    final walletFuture = safe(() => _db.getRiderWallet(actor: rider));
    final availableFuture = safe(() => _db.getAvailableDeliveryOrders());
    final tasksFuture = safe(() => _db.getRiderTasks(rider));

    final results = await Future.wait<Object?>([
      analyticsFuture as Future<Object?>,
      walletFuture as Future<Object?>,
      availableFuture as Future<Object?>,
      tasksFuture as Future<Object?>,
    ]);

    final analytics = results[0] as RiderAnalytics?;
    final wallet = results[1] as WalletSummary?;
    final availableDeliveries = (results[2] as List<OrderModel>?) ?? const [];
    final tasks = (results[3] as List<UnifiedRiderTask>?) ?? const [];

    return RiderDashboardSnapshot(
      analytics: analytics ??
          RiderAnalytics(
            todayDeliveries: 0,
            earningsToday: 0,
            totalEarnings: 0,
            pendingPayout: 0,
            availableBalance: rider.walletBalance,
            reservedAmount: 0,
          ),
      wallet: wallet ??
          WalletSummary(
            id: rider.id,
            kind: 'rider',
            linkedId: rider.id,
            balance: rider.walletBalance,
            pendingAmount: 0,
            reservedAmount: 0,
            totalEarnings: rider.walletBalance,
            totalWithdrawn: 0,
            lastSettlementDate: '',
          ),
      availableDeliveries: availableDeliveries,
      tasks: tasks,
      fetchedAt: DateTime.now(),
    );
  }

  Future<List<RiderRouteStop>> getOptimizedRoute(AppUser rider) async {
    final routeData = await _db.getOptimizedRiderRoute(
      lat: rider.latitude,
      lng: rider.longitude,
    );

    if (routeData.isNotEmpty) {
      final stops = <RiderRouteStop>[];
      final tasks = await _db.getRiderTasks(rider);
      
      for (final map in routeData) {
        final taskMap = map['task'] as Map<String, dynamic>? ?? {};
        final taskId = taskMap['id']?.toString() ?? '';
        final distanceKm = map['distanceKm'] as num?;
        
        final taskIdx = tasks.indexWhere((t) => t.id == taskId);
        if (taskIdx == -1) continue;
        final task = tasks[taskIdx];
        
        final customer = await _db.getUser(task.userId);
        final order = task.orderId == null ? null : await _db.getOrderById(task.orderId!);
        
        stops.add(
          RiderRouteStop(
            task: task,
            customer: customer,
            order: order,
            distanceKm: distanceKm?.toDouble(),
            etaMins: map['etaMins'] as num?,
          ),
        );
      }
      return stops;
    }

    final tasks = await _db.getRiderTasks(rider);
    final stops = <RiderRouteStop>[];

    for (final task in tasks) {
      final customer = await _db.getUser(task.userId);
      final order = task.orderId == null ? null : await _db.getOrderById(task.orderId!);
      final distanceKm = _distanceFromRider(rider, customer);
      stops.add(
        RiderRouteStop(
          task: task,
          customer: customer,
          order: order,
          distanceKm: distanceKm,
        ),
      );
    }

    stops.sort((a, b) {
      final typeCompare = _taskPriority(a.task.type).compareTo(_taskPriority(b.task.type));
      if (typeCompare != 0) {
        return typeCompare;
      }
      final statusCompare = _statusPriority(a.task.status).compareTo(_statusPriority(b.task.status));
      if (statusCompare != 0) {
        return statusCompare;
      }
      final aDistance = a.distanceKm ?? double.infinity;
      final bDistance = b.distanceKm ?? double.infinity;
      final distanceCompare = aDistance.compareTo(bDistance);
      if (distanceCompare != 0) {
        return distanceCompare;
      }
      return b.task.updatedAt.compareTo(a.task.updatedAt);
    });

    return stops;
  }

  Future<void> submitRiderApplication({
    required AppUser user,
    required String name,
    required String phone,
    required String vehicleType,
    String? licenseNumber,
    required String city,
  }) async {
    final updated = user.copyWith(
      role: 'rider',
      name: name.trim(),
      phone: phone.trim(),
      city: city.trim(),
      riderCity: city.trim(),
      riderVehicleType: vehicleType.trim(),
      riderLicenseNumber: (licenseNumber ?? '').trim().isEmpty ? null : licenseNumber!.trim(),
      riderApprovalStatus: 'pending',
      isActive: true,
    );
    await _db.saveUser(updated);
  }

  Future<void> acceptDelivery({
    required String orderId,
    required AppUser rider,
  }) {
    return _db.acceptDeliveryRequest(orderId, rider);
  }

  Future<void> updateDeliveryStatus({
    required String orderId,
    required String deliveryStatus,
    required AppUser rider,
  }) async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      await OfflineActionQueue.enqueue(
        endpoint: '/api/orders/$orderId/delivery-status',
        method: 'PATCH',
        payload: {'status': deliveryStatus},
      );
      return;
    }
    return _db.updateDeliveryStatus(orderId, deliveryStatus, actor: rider);
  }

  Future<void> updateRiderLocation({
    required String orderId,
    required double latitude,
    required double longitude,
    required AppUser rider,
  }) async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      await OfflineActionQueue.enqueue(
        endpoint: '/api/orders/$orderId/location',
        method: 'PATCH',
        payload: {'latitude': latitude, 'longitude': longitude},
      );
      return;
    }
    return _db.updateRiderLocation(
      orderId: orderId,
      latitude: latitude,
      longitude: longitude,
      actor: rider,
    );
  }

  Future<void> markReturnPicked({
    required String returnId,
    required AppUser rider,
  }) {
    return _db.markReturnPicked(returnId, actor: rider);
  }

  Future<void> completeReturn({
    required String returnId,
    required AppUser rider,
  }) {
    return _db.completeReturnRequest(returnId: returnId, actor: rider);
  }

  int _taskPriority(String type) => type == 'delivery' ? 0 : 1;

  int _statusPriority(String status) {
    return switch (status) {
      'in_progress' => 0,
      'assigned' => 1,
      'completed' => 2,
      _ => 3,
    };
  }

  double? _distanceFromRider(AppUser rider, AppUser? customer) {
    final riderLat = rider.latitude;
    final riderLng = rider.longitude;
    final customerLat = customer?.latitude;
    final customerLng = customer?.longitude;
    if (riderLat == null || riderLng == null || customerLat == null || customerLng == null) {
      return null;
    }
    const earthRadiusKm = 6371.0;
    final dLat = _degreesToRadians(customerLat - riderLat);
    final dLng = _degreesToRadians(customerLng - riderLng);
    final startLat = _degreesToRadians(riderLat);
    final endLat = _degreesToRadians(customerLat);
    final a =
        (_squareSin(dLat / 2)) +
        (_squareSin(dLng / 2) * cos(startLat) * cos(endLat));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _degreesToRadians(double degrees) => degrees * (3.141592653589793 / 180);

  double _squareSin(double value) {
    final sine = sin(value);
    return sine * sine;
  }
}
