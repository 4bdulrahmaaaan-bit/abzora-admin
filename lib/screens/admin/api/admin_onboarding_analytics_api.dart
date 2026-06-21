import '../../../services/backend_api_client.dart';

class AdminOnboardingAnalyticsApi {
  static const double _msPerHour = 1000 * 60 * 60;

  static Map<String, dynamic> _mapFrom(dynamic value) {
    return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _listOfMaps(dynamic value) {
    return value is List
        ? value.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
        : <Map<String, dynamic>>[];
  }

  static Future<Map<String, dynamic>> fetchAnalytics() async {
    final payload = await const BackendApiClient().get(
      '/admin/onboarding-analytics/dashboard',
      authenticated: true,
    );
    final data = _mapFrom((payload as Map)['data']);

    Map<String, dynamic> buildKpis(List<dynamic> funnel, Map<String, dynamic> times) {
      final stages = funnel
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final total = stages.fold<int>(0, (sum, item) => sum + ((item['count'] ?? 0) as num).toInt());
      final approved = stages
          .where((item) {
            final stage = (item['_id'] ?? '').toString().toLowerCase();
            return stage == 'approved' || stage == 'active' || stage == 'fleet_approval';
          })
          .fold<int>(0, (sum, item) => sum + ((item['count'] ?? 0) as num).toInt());
      final pending = stages
          .where((item) {
            final stage = (item['_id'] ?? '').toString().toLowerCase();
            return stage == 'submitted' ||
                stage == 'applied' ||
                stage.contains('review') ||
                stage == 'training_pending';
          })
          .fold<int>(0, (sum, item) => sum + ((item['count'] ?? 0) as num).toInt());
      final avgMs = ((times['averageMs'] ?? 0) as num).toDouble();
      final avgDays = avgMs / (1000 * 60 * 60 * 24);
      return {
        'totalApplications': total,
        'pendingApplications': pending,
        'approvedApplications': approved,
        'approvalRate': total == 0 ? 0.0 : (approved / total) * 100,
        'avgApprovalTimeHours': avgMs / (1000 * 60 * 60),
        'avgReviewTimeDays': avgDays,
      };
    }

    List<Map<String, dynamic>> normalizeFunnel(List<dynamic> funnel) {
      final stages = funnel
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final total = stages.fold<int>(0, (sum, item) => sum + ((item['count'] ?? 0) as num).toInt());
      return stages.map((item) {
        final count = ((item['count'] ?? 0) as num).toDouble();
        final stage = (item['_id'] ?? item['stage'] ?? '').toString();
        final conversion = total == 0 ? 0.0 : (count / total) * 100;
        return {
          'stage': stage.replaceAll('_', ' ').trim().replaceFirstMapped(
                RegExp(r'^[a-z]'),
                (match) => match.group(0)!.toUpperCase(),
              ),
          'count': count.toInt(),
          'conversion': double.parse(conversion.toStringAsFixed(1)),
          'dropoff': double.parse((100 - conversion).clamp(0, 100).toStringAsFixed(1)),
        };
      }).toList();
    }

    final vendorFunnel = normalizeFunnel(_listOfMaps(data['vendorFunnel']).cast<Map>());
    final riderFunnel = normalizeFunnel(_listOfMaps(data['riderFunnel']).cast<Map>());
    final approvalTimes = _mapFrom(data['approvalTimes']);
    final vendorTimes = _mapFrom(approvalTimes['vendor']);
    final riderTimes = _mapFrom(approvalTimes['rider']);
    final alerts = _listOfMaps(data['alerts'])
        .map((item) => item['message']?.toString() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
    final dropoffs = _mapFrom(data['dropoffs']);
    final vendorDropoffs = _listOfMaps(dropoffs['vendor']);
    final riderDropoffs = _listOfMaps(dropoffs['rider']);

    return {
      'vendorKpis': buildKpis(_listOfMaps(data['vendorFunnel']).cast<Map>(), vendorTimes),
      'riderKpis': buildKpis(_listOfMaps(data['riderFunnel']).cast<Map>(), riderTimes),
      'vendorFunnel': vendorFunnel,
      'riderFunnel': riderFunnel,
      'executiveInsights': {
        'biggestDropoffPoints': [
          ...vendorDropoffs.map((item) => 'Vendor ${(item['_id'] ?? '').toString()}: ${item['count'] ?? 0}'),
          ...riderDropoffs.map((item) => 'Rider ${(item['_id'] ?? '').toString()}: ${item['count'] ?? 0}'),
        ],
        'fastestStages': [
          'Vendor average review time: ${(((vendorTimes['averageMs'] as num?)?.toDouble() ?? 0) / _msPerHour).toStringAsFixed(1)} hrs',
          'Rider average review time: ${(((riderTimes['averageMs'] as num?)?.toDouble() ?? 0) / _msPerHour).toStringAsFixed(1)} hrs',
        ],
        'slowestStages': [
          'Vendor review span: ${(((vendorTimes['maxMs'] as num?)?.toDouble() ?? 0) / _msPerHour).toStringAsFixed(1)} hrs',
          'Rider review span: ${(((riderTimes['maxMs'] as num?)?.toDouble() ?? 0) / _msPerHour).toStringAsFixed(1)} hrs',
        ],
        'alerts': alerts,
      },
    };
  }
}
