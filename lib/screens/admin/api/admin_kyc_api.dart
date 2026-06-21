import '../../../services/backend_api_client.dart';

class AdminKycApi {
  static String _normalizeType(String type) {
    return type.trim().toLowerCase() == 'rider' ? 'Rider' : 'Vendor';
  }

  static String? _normalizeStatusFilter(String? status) {
    final normalized = (status ?? '').trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    switch (normalized) {
      case 'pending':
        return 'submitted';
      case 'approved':
        return 'approved';
      case 'rejected':
        return 'rejected';
      default:
        return normalized;
    }
  }

  static String _normalizeReviewStatus(String status) {
    final normalized = status.trim().toLowerCase();
    switch (normalized) {
      case 'pending':
        return 'submitted';
      case 'approved':
        return 'approved';
      case 'rejected':
        return 'rejected';
      default:
        return normalized;
    }
  }

  static Map<String, dynamic> _normalizeApplication(
    Map<String, dynamic> item, {
    required String type,
  }) {
    final metadata = item['metadata'] is Map
        ? Map<String, dynamic>.from(item['metadata'] as Map)
        : <String, dynamic>{};
    final kyc = item['kyc'] is Map
        ? Map<String, dynamic>.from(item['kyc'] as Map)
        : <String, dynamic>{};
    return {
      ...item,
      '_id': item['_id'] ?? item['id'] ?? item['requestId'] ?? '',
      'type': type,
      'email': item['email'] ?? metadata['email'] ?? '',
      'kycStatus': item['status'] ?? item['kycStatus'] ?? 'submitted',
      'kycSubmittedAt': item['createdAt'] ?? item['kycSubmittedAt'] ?? '',
      'kycDocuments': item['kycDocuments'] ?? kyc,
      'kycNotes': item['rejectionReason'] ?? item['kycNotes'] ?? '',
    };
  }

  static Future<Map<String, dynamic>> fetchDashboard() async {
    final payload = await const BackendApiClient().get(
      '/admin/kyc/dashboard',
      authenticated: true,
    );
    return Map<String, dynamic>.from(payload['data'] ?? {});
  }

  static Future<Map<String, dynamic>> fetchApplications({
    int page = 1,
    int limit = 25,
    String type = 'Vendor',
    String? status,
  }) async {
    final normalizedType = _normalizeType(type);
    final normalizedStatus = _normalizeStatusFilter(status);
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      'type': normalizedType,
    };
    if (normalizedStatus != null) {
      queryParams['status'] = normalizedStatus;
    }

    final queryStr = Uri(queryParameters: queryParams).query;
    final payload = await const BackendApiClient().get(
      '/admin/kyc/applications?$queryStr',
      authenticated: true,
    );
    final map = Map<String, dynamic>.from(payload as Map);

    final apps = (map['data'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .map((item) => _normalizeApplication(item, type: normalizedType))
        .toList();

    return {'applications': apps, 'meta': map['meta'] ?? {}};
  }

  static Future<Map<String, dynamic>> reviewApplication(
    String id,
    String type,
    String status,
    String notes,
  ) async {
    final normalizedType = _normalizeType(type);
    final normalizedStatus = _normalizeReviewStatus(status);
    final payload = await const BackendApiClient().patch(
      '/admin/kyc/$id/review',
      authenticated: true,
      body: {'type': normalizedType, 'status': normalizedStatus, 'notes': notes},
    );
    return Map<String, dynamic>.from(payload['data'] ?? {});
  }
}
