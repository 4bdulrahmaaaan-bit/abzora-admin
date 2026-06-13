import '../../../services/backend_api_client.dart';

class SystemHealthKpi {
  final int uptimeSeconds;
  final int apiAvgLatencyMs;
  final int apiP95LatencyMs;
  final int dbLatencyMs;
  final double errorRatePercent;
  final double successRatePercent;
  final int memoryUsedMb;
  final int memoryTotalMb;

  SystemHealthKpi({
    required this.uptimeSeconds,
    required this.apiAvgLatencyMs,
    required this.apiP95LatencyMs,
    required this.dbLatencyMs,
    required this.errorRatePercent,
    required this.successRatePercent,
    required this.memoryUsedMb,
    required this.memoryTotalMb,
  });

  factory SystemHealthKpi.fromMap(Map<String, dynamic> map) {
    return SystemHealthKpi(
      uptimeSeconds: (map['uptimeSeconds'] ?? 0).toInt(),
      apiAvgLatencyMs: (map['apiAvgLatencyMs'] ?? 0).toInt(),
      apiP95LatencyMs: (map['apiP95LatencyMs'] ?? 0).toInt(),
      dbLatencyMs: (map['dbLatencyMs'] ?? 0).toInt(),
      errorRatePercent: (map['errorRatePercent'] ?? 0).toDouble(),
      successRatePercent: (map['successRatePercent'] ?? 0).toDouble(),
      memoryUsedMb: (map['memoryUsedMb'] ?? 0).toInt(),
      memoryTotalMb: (map['memoryTotalMb'] ?? 0).toInt(),
    );
  }
}

class SystemHealthData {
  final String apiHealth;
  final String databaseHealth;
  final String firebaseHealth;
  final String notificationHealth;
  final String backgroundJobHealth;
  final String storageHealth;
  final SystemHealthKpi kpis;

  SystemHealthData({
    required this.apiHealth,
    required this.databaseHealth,
    required this.firebaseHealth,
    required this.notificationHealth,
    required this.backgroundJobHealth,
    required this.storageHealth,
    required this.kpis,
  });

  factory SystemHealthData.fromMap(Map<String, dynamic> map) {
    return SystemHealthData(
      apiHealth: map['apiHealth'] ?? 'unknown',
      databaseHealth: map['databaseHealth'] ?? 'unknown',
      firebaseHealth: map['firebaseHealth'] ?? 'unknown',
      notificationHealth: map['notificationHealth'] ?? 'unknown',
      backgroundJobHealth: map['backgroundJobHealth'] ?? 'unknown',
      storageHealth: map['storageHealth'] ?? 'unknown',
      kpis: SystemHealthKpi.fromMap(map['kpis'] ?? {}),
    );
  }
}

class AdminSystemHealthApi {
  static Future<SystemHealthData> getSystemHealth() async {
    final response = await const BackendApiClient().get('/admin/system-health', authenticated: true);
    if (response != null && response is Map) {
      return SystemHealthData.fromMap(Map<String, dynamic>.from(response['data'] ?? response));
    }
    throw Exception('Failed to fetch system health data.');
  }
}
