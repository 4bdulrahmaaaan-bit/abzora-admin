import '../../../services/backend_api_client.dart';

class AdminFinanceApi {
  static Future<Map<String, dynamic>> fetchDashboard() async {
    final payload = await const BackendApiClient().get(
      '/admin/finance/dashboard',
      authenticated: true,
    );
    return Map<String, dynamic>.from(payload['data'] ?? {});
  }

  static Future<Map<String, dynamic>> fetchWithdrawals({
    int page = 1,
    int limit = 50,
    String? status,
    String? walletType,
    String? userId,
    String? storeId,
    String? riderId,
    String? from,
    String? to,
    num? minAmount,
    num? maxAmount,
    String? search,
    String? verificationStatus,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (walletType != null && walletType.isNotEmpty) {
      queryParams['walletType'] = walletType;
    }
    if (userId != null && userId.isNotEmpty) queryParams['userId'] = userId;
    if (storeId != null && storeId.isNotEmpty) queryParams['storeId'] = storeId;
    if (riderId != null && riderId.isNotEmpty) queryParams['riderId'] = riderId;
    if (from != null && from.isNotEmpty) queryParams['from'] = from;
    if (to != null && to.isNotEmpty) queryParams['to'] = to;
    if (minAmount != null) queryParams['minAmount'] = minAmount.toString();
    if (maxAmount != null) queryParams['maxAmount'] = maxAmount.toString();
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (verificationStatus != null && verificationStatus.isNotEmpty) {
      queryParams['verificationStatus'] = verificationStatus;
    }

    final queryStr = Uri(queryParameters: queryParams).query;
    final payload = await const BackendApiClient().get(
      '/finance/withdrawals?$queryStr',
      authenticated: true,
    );
    final map = Map<String, dynamic>.from(payload as Map);
    final withdrawals = (map['data'] as List? ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    return {
      'withdrawals': withdrawals,
      'summary': Map<String, dynamic>.from(map['summary'] as Map? ?? const {}),
      'meta': Map<String, dynamic>.from(map['meta'] as Map? ?? const {}),
    };
  }

  static Future<Map<String, dynamic>> fetchRecoveryJobs({
    int page = 1,
    int limit = 50,
    String? status,
    String? userRole,
    String? withdrawalRequestId,
    String? payoutId,
    String? from,
    String? to,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (userRole != null && userRole.isNotEmpty) queryParams['userRole'] = userRole;
    if (withdrawalRequestId != null && withdrawalRequestId.isNotEmpty) {
      queryParams['withdrawalRequestId'] = withdrawalRequestId;
    }
    if (payoutId != null && payoutId.isNotEmpty) queryParams['payoutId'] = payoutId;
    if (from != null && from.isNotEmpty) queryParams['from'] = from;
    if (to != null && to.isNotEmpty) queryParams['to'] = to;

    final queryStr = Uri(queryParameters: queryParams).query;
    final payload = await const BackendApiClient().get(
      '/finance/recovery/jobs?$queryStr',
      authenticated: true,
    );
    final map = Map<String, dynamic>.from(payload as Map);
    final jobs = (map['data'] as List? ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    return {
      'jobs': jobs,
      'summary': Map<String, dynamic>.from(map['summary'] as Map? ?? const {}),
      'meta': Map<String, dynamic>.from(map['meta'] as Map? ?? const {}),
    };
  }

  static Future<Map<String, dynamic>> runRecoverySweep() async {
    final payload = await const BackendApiClient().post(
      '/finance/recovery/run',
      authenticated: true,
    );
    return Map<String, dynamic>.from(payload as Map);
  }

  static Future<Map<String, dynamic>> retryRecoveryJob(String jobId) async {
    final payload = await const BackendApiClient().post(
      '/finance/recovery/jobs/$jobId/retry',
      authenticated: true,
    );
    return Map<String, dynamic>.from(payload as Map);
  }

  static Future<Map<String, dynamic>> markRecoveryJobPaid({
    required String jobId,
    String reason = '',
  }) async {
    final payload = await const BackendApiClient().post(
      '/finance/recovery/jobs/$jobId/mark-paid',
      authenticated: true,
      body: reason.isEmpty ? const {} : {'reason': reason},
    );
    return Map<String, dynamic>.from(payload as Map);
  }

  static Future<Map<String, dynamic>> markRecoveryJobFailed({
    required String jobId,
    String reason = '',
    String finalStatus = 'failed',
  }) async {
    final payload = await const BackendApiClient().post(
      '/finance/recovery/jobs/$jobId/mark-failed',
      authenticated: true,
      body: {
        if (reason.isNotEmpty) 'reason': reason,
        'finalStatus': finalStatus,
      },
    );
    return Map<String, dynamic>.from(payload as Map);
  }

  static Future<Map<String, dynamic>> escalateRecoveryJob({
    required String jobId,
    String reason = '',
  }) async {
    final payload = await const BackendApiClient().post(
      '/finance/recovery/jobs/$jobId/escalate',
      authenticated: true,
      body: reason.isEmpty ? const {} : {'reason': reason},
    );
    return Map<String, dynamic>.from(payload as Map);
  }

  static Future<Map<String, dynamic>> addRecoveryJobNote({
    required String jobId,
    required String note,
  }) async {
    final payload = await const BackendApiClient().post(
      '/finance/recovery/jobs/$jobId/note',
      authenticated: true,
      body: {'note': note},
    );
    return Map<String, dynamic>.from(payload as Map);
  }

  static Future<Map<String, dynamic>> fetchSettlements({
    int page = 1,
    int limit = 25,
    String? type,
    String? status,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (type != null && type.isNotEmpty) queryParams['type'] = type;
    if (status != null && status.isNotEmpty) queryParams['status'] = status;

    final queryStr = Uri(queryParameters: queryParams).query;
    final payload = await const BackendApiClient().get(
      '/admin/finance/settlements?$queryStr',
      authenticated: true,
    );
    final map = Map<String, dynamic>.from(payload as Map);

    final settlements = (map['data'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return {'settlements': settlements, 'meta': map['meta'] ?? {}};
  }

  static Future<Map<String, dynamic>> fetchRefunds({
    int page = 1,
    int limit = 25,
    String? status,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (status != null && status.isNotEmpty) queryParams['status'] = status;

    final queryStr = Uri(queryParameters: queryParams).query;
    final payload = await const BackendApiClient().get(
      '/admin/finance/refunds?$queryStr',
      authenticated: true,
    );
    final map = Map<String, dynamic>.from(payload as Map);

    final refunds = (map['data'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return {'refunds': refunds, 'meta': map['meta'] ?? {}};
  }

  static Future<List<Map<String, dynamic>>> fetchReports(String period) async {
    final payload = await const BackendApiClient().get(
      '/admin/finance/reports?period=$period',
      authenticated: true,
    );
    return (payload['data'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
}
