import '../../../services/backend_api_client.dart';

class AutomationExecution {
  final String status;
  final String details;
  final DateTime executedAt;

  AutomationExecution({
    required this.status,
    required this.details,
    required this.executedAt,
  });

  factory AutomationExecution.fromMap(Map<String, dynamic> map) {
    return AutomationExecution(
      status: map['status'] ?? '',
      details: map['details'] ?? '',
      executedAt: DateTime.tryParse(map['executedAt'] ?? '') ?? DateTime.now(),
    );
  }
}

class AdminAutomationModel {
  final String id;
  final String name;
  final String description;
  final String cronExpression;
  final bool enabled;
  final DateTime? lastRunAt;
  final DateTime? nextRunAt;
  final int successCount;
  final int failureCount;
  final int retryCount;
  final List<AutomationExecution> executionHistory;

  AdminAutomationModel({
    required this.id,
    required this.name,
    required this.description,
    required this.cronExpression,
    required this.enabled,
    this.lastRunAt,
    this.nextRunAt,
    required this.successCount,
    required this.failureCount,
    required this.retryCount,
    required this.executionHistory,
  });

  factory AdminAutomationModel.fromMap(Map<String, dynamic> map) {
    return AdminAutomationModel(
      id: map['_id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      cronExpression: map['cronExpression'] ?? '',
      enabled: map['enabled'] ?? false,
      lastRunAt: map['lastRunAt'] != null ? DateTime.tryParse(map['lastRunAt']) : null,
      nextRunAt: map['nextRunAt'] != null ? DateTime.tryParse(map['nextRunAt']) : null,
      successCount: (map['successCount'] ?? 0).toInt(),
      failureCount: (map['failureCount'] ?? 0).toInt(),
      retryCount: (map['retryCount'] ?? 0).toInt(),
      executionHistory: ((map['executionHistory'] ?? []) as List)
          .map((e) => AutomationExecution.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class AdminAutomationApi {
  static Future<List<AdminAutomationModel>> getAutomations() async {
    final response = await const BackendApiClient().get('/admin/automations', authenticated: true);
    if (response != null && response is Map && response['data'] is List) {
      return (response['data'] as List)
          .map((item) => AdminAutomationModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    }
    return [];
  }

  static Future<AdminAutomationModel> toggleAutomation(String id, bool enabled) async {
    final response = await const BackendApiClient().patch(
      '/admin/automations/$id/toggle',
      body: {'enabled': enabled},
      authenticated: true,
    );
    if (response != null && response is Map && response['data'] != null) {
      return AdminAutomationModel.fromMap(Map<String, dynamic>.from(response['data']));
    }
    throw Exception('Failed to toggle automation');
  }

  static Future<AdminAutomationModel> updateSchedule(String id, String cronExpression) async {
    final response = await const BackendApiClient().patch(
      '/admin/automations/$id/schedule',
      body: {'cronExpression': cronExpression},
      authenticated: true,
    );
    if (response != null && response is Map && response['data'] != null) {
      return AdminAutomationModel.fromMap(Map<String, dynamic>.from(response['data']));
    }
    throw Exception('Failed to update automation schedule');
  }
}
