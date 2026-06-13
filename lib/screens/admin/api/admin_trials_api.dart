import '../../../services/backend_api_client.dart';

/// API client for the Admin Trial Command Center.
///
/// Wraps all `/admin/trials/*` endpoints for the Trial Command Center.
class AdminTrialsApi {
  AdminTrialsApi({BackendApiClient? client})
    : _client = client ?? const BackendApiClient();

  final BackendApiClient _client;

  // ─── Dashboard Metrics ──────────────────────────────────────────
  Future<Map<String, dynamic>> getDashboard() async {
    final payload = await _client.get(
      '/admin/trials/dashboard',
      authenticated: true,
    );
    return Map<String, dynamic>.from(payload as Map);
  }

  // ─── Trial Queue (Paginated) ────────────────────────────────────
  Future<Map<String, dynamic>> getQueue({
    int page = 1,
    int limit = 25,
    String? status,
    String? trialOutcome,
    String? paymentStatus,
    String? vendor,
    String? rider,
    String? startDate,
    String? endDate,
    String? search,
    String? sortBy,
    bool sortDesc = true,
  }) async {
    final payload = await _client.get(
      '/admin/trials/queue',
      authenticated: true,
      queryParameters: {
        'page': '$page',
        'limit': '$limit',
        if (status != null && status.isNotEmpty) 'status': status,
        if (trialOutcome != null && trialOutcome.isNotEmpty)
          'trialOutcome': trialOutcome,
        if (paymentStatus != null && paymentStatus.isNotEmpty)
          'paymentStatus': paymentStatus,
        if (vendor != null && vendor.isNotEmpty) 'vendor': vendor,
        if (rider != null && rider.isNotEmpty) 'rider': rider,
        if (startDate != null && startDate.isNotEmpty) 'startDate': startDate,
        if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
        if (search != null && search.isNotEmpty) 'search': search,
        if (sortBy != null && sortBy.isNotEmpty) 'sortBy': sortBy,
        'sortDesc': '$sortDesc',
      },
    );
    return Map<String, dynamic>.from(payload as Map);
  }

  // ─── Trial Details ──────────────────────────────────────────────
  Future<Map<String, dynamic>> getTrial(String id) async {
    final payload = await _client.get(
      '/admin/trials/$id',
      authenticated: true,
    );
    return Map<String, dynamic>.from(payload as Map);
  }

  // ─── Trial Analytics ───────────────────────────────────────────
  Future<Map<String, dynamic>> getAnalytics() async {
    final payload = await _client.get(
      '/admin/trials/analytics',
      authenticated: true,
    );
    return Map<String, dynamic>.from(payload as Map);
  }

  // ─── Actions ───────────────────────────────────────────────────
  Future<Map<String, dynamic>> assignRider({
    required String trialId,
    required String riderId,
  }) async {
    final payload = await _client.patch(
      '/admin/trials/$trialId/assign-rider',
      authenticated: true,
      body: {'riderId': riderId},
    );
    return Map<String, dynamic>.from(payload as Map);
  }

  Future<Map<String, dynamic>> reschedule({
    required String trialId,
    String? scheduledAt,
    String? deliverySlot,
  }) async {
    final payload = await _client.patch(
      '/admin/trials/$trialId/reschedule',
      authenticated: true,
      body: {
        // ignore: use_null_aware_elements
        if (scheduledAt != null) 'scheduledAt': scheduledAt,
        // ignore: use_null_aware_elements
        if (deliverySlot != null) 'deliverySlot': deliverySlot,
      },
    );
    return Map<String, dynamic>.from(payload as Map);
  }

  Future<Map<String, dynamic>> cancelTrial({
    required String trialId,
    String reason = '',
  }) async {
    final payload = await _client.patch(
      '/admin/trials/$trialId/cancel',
      authenticated: true,
      body: {'reason': reason},
    );
    return Map<String, dynamic>.from(payload as Map);
  }

  Future<Map<String, dynamic>> markPurchased({
    required String trialId,
    List<String> keptItems = const [],
  }) async {
    final payload = await _client.patch(
      '/admin/trials/$trialId/mark-purchased',
      authenticated: true,
      body: {'keptItems': keptItems},
    );
    return Map<String, dynamic>.from(payload as Map);
  }

  Future<Map<String, dynamic>> markReturned({
    required String trialId,
    List<String> returnedItems = const [],
    String reason = '',
  }) async {
    final payload = await _client.patch(
      '/admin/trials/$trialId/mark-returned',
      authenticated: true,
      body: {'returnedItems': returnedItems, 'reason': reason},
    );
    return Map<String, dynamic>.from(payload as Map);
  }
}
