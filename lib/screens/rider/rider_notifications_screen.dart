import 'package:flutter/material.dart';

import '../../services/rider_notification_api.dart';
import '../../widgets/state_views.dart';

class RiderNotificationsScreen extends StatefulWidget {
  const RiderNotificationsScreen({super.key});

  @override
  State<RiderNotificationsScreen> createState() =>
      _RiderNotificationsScreenState();
}

class _RiderNotificationsScreenState extends State<RiderNotificationsScreen> {
  bool _loading = false;
  final List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _loading = true);
    final data = await RiderNotificationApi.getNotifications();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _notifications.clear();
      _notifications.addAll(data);
    });
  }

  Future<void> _markAsRead(Map<String, dynamic> item) async {
    final id = item['id']?.toString() ?? item['_id']?.toString();
    if (id == null) return;
    
    // Optimistic UI update
    setState(() => item['read'] = true);
    
    final success = await RiderNotificationApi.markAsRead(id);
    if (!success && mounted) {
      // Revert on failure
      setState(() => item['read'] = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to mark notification as read.')),
      );
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'Deliveries':
        return Icons.local_shipping_outlined;
      case 'Trials':
        return Icons.checkroom_outlined;
      case 'Earnings':
        return Icons.account_balance_wallet_outlined;
      case 'Training':
        return Icons.school_outlined;
      case 'KYC':
        return Icons.verified_user_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5EF),
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: _notifications.isEmpty ? null : () {},
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFFC8A86B),
        onRefresh: _loadNotifications,
        child: _loading && _notifications.isEmpty
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFC8A86B)))
            : _notifications.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 100),
                      AbzioEmptyCard(
                        title: 'No Notifications',
                        subtitle: 'You are all caught up.',
                      ),
                    ],
                  )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notifications.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _notifications[index];
                    final read = item['read'] == true;
                    return Container(
                      decoration: BoxDecoration(
                        color: read ? Colors.white : const Color(0xFFFEFBF3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: read ? const Color(0xFFECE4D2) : const Color(0xFFC8A86B),
                        ),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFF8F5EF),
                          child: Icon(
                            _getIconForType(item['type']),
                            color: const Color(0xFF8D6A2E),
                          ),
                        ),
                        title: Text(
                          item['title'],
                          style: TextStyle(
                            fontWeight: read ? FontWeight.w500 : FontWeight.w700,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(item['body']),
                            const SizedBox(height: 8),
                            Text(
                              item['createdAt'],
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        onTap: () {
                          if (!read) {
                            _markAsRead(item);
                          }
                        },
                      ),
                    );
                  },
                ),
      ),
    );
  }
}
