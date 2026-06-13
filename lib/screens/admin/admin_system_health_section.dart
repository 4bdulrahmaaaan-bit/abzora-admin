import 'package:flutter/material.dart';
import 'dart:async';
import 'api/admin_system_health_api.dart';

class AdminSystemHealthSection extends StatefulWidget {
  const AdminSystemHealthSection({super.key});

  @override
  State<AdminSystemHealthSection> createState() =>
      _AdminSystemHealthSectionState();
}

class _AdminSystemHealthSectionState extends State<AdminSystemHealthSection> {
  SystemHealthData? _healthData;
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadData(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final data = await AdminSystemHealthApi.getSystemHealth();
      if (mounted) {
        setState(() {
          _healthData = data;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'healthy':
        return Colors.green;
      case 'warning':
        return Colors.orange;
      case 'critical':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildStatusCard(String title, String status, IconData icon) {
    final color = _getStatusColor(status);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  String _formatUptime(int seconds) {
    final d = seconds ~/ (24 * 3600);
    final h = (seconds % (24 * 3600)) ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return '${d}d ${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Health & Monitoring'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading && _healthData == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _healthData == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 56,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Unable to load system health data',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _isLoading = true;
                        });
                        _loadData();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Core Services',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: MediaQuery.of(context).size.width > 1200
                        ? 6
                        : (MediaQuery.of(context).size.width > 800 ? 3 : 2),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      _buildStatusCard(
                        'API Service',
                        _healthData!.apiHealth,
                        Icons.api,
                      ),
                      _buildStatusCard(
                        'MongoDB',
                        _healthData!.databaseHealth,
                        Icons.storage,
                      ),
                      _buildStatusCard(
                        'Firebase',
                        _healthData!.firebaseHealth,
                        Icons.local_fire_department,
                      ),
                      _buildStatusCard(
                        'Notifications',
                        _healthData!.notificationHealth,
                        Icons.notifications_active,
                      ),
                      _buildStatusCard(
                        'Background Jobs',
                        _healthData!.backgroundJobHealth,
                        Icons.schedule,
                      ),
                      _buildStatusCard(
                        'Storage/CDN',
                        _healthData!.storageHealth,
                        Icons.cloud_done,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Performance Metrics',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'API Metrics',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const Divider(),
                                _buildKpiRow(
                                  'Average Latency',
                                  '${_healthData!.kpis.apiAvgLatencyMs} ms',
                                ),
                                _buildKpiRow(
                                  'P95 Latency',
                                  '${_healthData!.kpis.apiP95LatencyMs} ms',
                                  valueColor:
                                      _healthData!.kpis.apiP95LatencyMs > 300
                                      ? Colors.orange
                                      : Colors.green,
                                ),
                                _buildKpiRow(
                                  'Success Rate',
                                  '${_healthData!.kpis.successRatePercent}%',
                                  valueColor:
                                      _healthData!.kpis.successRatePercent < 99
                                      ? Colors.red
                                      : Colors.green,
                                ),
                                _buildKpiRow(
                                  'Error Rate',
                                  '${_healthData!.kpis.errorRatePercent}%',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Infrastructure',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const Divider(),
                                _buildKpiRow(
                                  'Database Latency',
                                  '${_healthData!.kpis.dbLatencyMs} ms',
                                ),
                                _buildKpiRow(
                                  'Node Uptime',
                                  _formatUptime(
                                    _healthData!.kpis.uptimeSeconds,
                                  ),
                                ),
                                _buildKpiRow(
                                  'Memory Used',
                                  '${_healthData!.kpis.memoryUsedMb} MB',
                                ),
                                _buildKpiRow(
                                  'Memory Total',
                                  '${_healthData!.kpis.memoryTotalMb} MB',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
