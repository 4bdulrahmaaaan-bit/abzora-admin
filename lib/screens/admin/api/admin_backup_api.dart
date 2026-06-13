import '../../../services/backend_api_client.dart';

class AdminBackupModel {
  final String id;
  final String backupId;
  final String type;
  final String status;
  final int fileSizeMb;
  final String s3Url;
  final String errorMessage;
  final String triggeredBy;
  final DateTime createdAt;
  final DateTime? completedAt;

  AdminBackupModel({
    required this.id,
    required this.backupId,
    required this.type,
    required this.status,
    required this.fileSizeMb,
    required this.s3Url,
    required this.errorMessage,
    required this.triggeredBy,
    required this.createdAt,
    this.completedAt,
  });

  factory AdminBackupModel.fromMap(Map<String, dynamic> map) {
    return AdminBackupModel(
      id: map['_id'] ?? '',
      backupId: map['backupId'] ?? '',
      type: map['type'] ?? '',
      status: map['status'] ?? '',
      fileSizeMb: (map['fileSizeMb'] ?? 0).toInt(),
      s3Url: map['s3Url'] ?? '',
      errorMessage: map['errorMessage'] ?? '',
      triggeredBy: map['triggeredBy'] ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      completedAt: map['completedAt'] != null ? DateTime.tryParse(map['completedAt']) : null,
    );
  }
}

class AdminBackupApi {
  static Future<List<AdminBackupModel>> getBackups() async {
    final response = await const BackendApiClient().get('/admin/backups', authenticated: true);
    if (response != null && response is Map && response['data'] is List) {
      return (response['data'] as List)
          .map((item) => AdminBackupModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    }
    return [];
  }

  static Future<AdminBackupModel> triggerBackup() async {
    final response = await const BackendApiClient().post('/admin/backups/trigger', authenticated: true);
    if (response != null && response is Map && response['data'] != null) {
      return AdminBackupModel.fromMap(Map<String, dynamic>.from(response['data']));
    }
    throw Exception('Failed to trigger backup');
  }

  static Future<void> restoreBackup() async {
    final response = await const BackendApiClient().post('/admin/backups/restore', authenticated: true);
    if (response != null && response is Map && response['success'] == false) {
      throw Exception(response['message'] ?? 'Restore failed');
    }
  }
}
