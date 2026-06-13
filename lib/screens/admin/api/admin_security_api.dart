import '../../../services/backend_api_client.dart';

class SecurityEvent {
  final String id;
  final String type;
  final String severity;
  final String ip;
  final DateTime timestamp;
  final String details;

  SecurityEvent({
    required this.id,
    required this.type,
    required this.severity,
    required this.ip,
    required this.timestamp,
    required this.details,
  });

  factory SecurityEvent.fromMap(Map<String, dynamic> map) {
    return SecurityEvent(
      id: map['id'] ?? '',
      type: map['type'] ?? '',
      severity: map['severity'] ?? '',
      ip: map['ip'] ?? '',
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      details: map['details'] ?? '',
    );
  }
}

class AdminActionCount {
  final String email;
  final int count;
  final DateTime lastActive;

  AdminActionCount({
    required this.email,
    required this.count,
    required this.lastActive,
  });

  factory AdminActionCount.fromMap(Map<String, dynamic> map) {
    return AdminActionCount(
      email: map['_id'] ?? '',
      count: (map['count'] ?? 0).toInt(),
      lastActive: DateTime.tryParse(map['lastActive'] ?? '') ?? DateTime.now(),
    );
  }
}

class AdminActivityLogEntry {
  final String adminEmail;
  final String action;
  final String entityType;
  final DateTime createdAt;

  AdminActivityLogEntry({
    required this.adminEmail,
    required this.action,
    required this.entityType,
    required this.createdAt,
  });

  factory AdminActivityLogEntry.fromMap(Map<String, dynamic> map) {
    return AdminActivityLogEntry(
      adminEmail: map['adminEmail'] ?? '',
      action: map['action'] ?? '',
      entityType: map['entityType'] ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}

class SecurityDashboardData {
  final List<AdminActivityLogEntry> recentActivity;
  final List<AdminActionCount> adminActionCounts;
  final List<SecurityEvent> securityEvents;

  SecurityDashboardData({
    required this.recentActivity,
    required this.adminActionCounts,
    required this.securityEvents,
  });

  factory SecurityDashboardData.fromMap(Map<String, dynamic> map) {
    return SecurityDashboardData(
      recentActivity: ((map['recentActivity'] ?? []) as List)
          .map(
            (e) => AdminActivityLogEntry.fromMap(Map<String, dynamic>.from(e)),
          )
          .toList(),
      adminActionCounts: ((map['adminActionCounts'] ?? []) as List)
          .map((e) => AdminActionCount.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      securityEvents: ((map['securityEvents'] ?? []) as List)
          .map((e) => SecurityEvent.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class AdminSecurityApi {
  static Future<SecurityDashboardData> getDashboard() async {
    final response = await const BackendApiClient().get(
      '/admin/security/dashboard',
      authenticated: true,
    );
    if (response != null && response is Map && response['data'] != null) {
      return SecurityDashboardData.fromMap(
        Map<String, dynamic>.from(response['data']),
      );
    }
    throw Exception('Failed to fetch security dashboard');
  }

  static Future<void> revokeAccess(String adminEmail) async {
    final response = await const BackendApiClient().post(
      '/admin/security/revoke-access',
      body: {'adminEmail': adminEmail},
      authenticated: true,
    );
    if (response != null && response is Map && response['success'] == false) {
      throw Exception(response['message'] ?? 'Failed to revoke access');
    }
  }
}
