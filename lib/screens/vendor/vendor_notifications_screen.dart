import 'package:flutter/material.dart';

import '../../core/vendor/theme/vendor_theme.dart';
import '../../core/vendor/widgets/premium_vendor_card.dart';
import '../../core/vendor/widgets/vendor_status_badge.dart';
import '../../services/vendor_notification_api.dart';

class VendorNotificationsScreen extends StatefulWidget {
  const VendorNotificationsScreen({super.key});

  @override
  State<VendorNotificationsScreen> createState() =>
      _VendorNotificationsScreenState();
}

class _VendorNotificationsScreenState extends State<VendorNotificationsScreen> {
  final VendorNotificationApi _api = VendorNotificationApi();

  String _selectedFilter = 'All';
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await _api.getNotifications(
        unreadOnly: _selectedFilter == 'Unread' ? true : null,
        priority: _selectedFilter == 'Priority' ? 'high' : null,
      );
      setState(() {
        _notifications = List<Map<String, dynamic>>.from(
          response['notifications'] ?? [],
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await _api.markAllAsRead();
      await _fetchNotifications();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications marked as read')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark all as read: $e')),
        );
      }
    }
  }

  Future<void> _markAsRead(String id, int index) async {
    if (_notifications[index]['isRead'] == true) return;

    setState(() {
      _notifications[index]['isRead'] = true;
    });

    try {
      await _api.markAsRead(id);
    } catch (e) {
      setState(() {
        _notifications[index]['isRead'] = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to mark as read: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VendorTheme.background,
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_outlined),
            tooltip: 'Mark all as read',
            onPressed: _markAllAsRead,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: VendorTheme.primary),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Failed to load notifications: $_error',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: VendorTheme.spacing16),
            ElevatedButton(
              onPressed: _fetchNotifications,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: 64,
              color: VendorTheme.grey300,
            ),
            const SizedBox(height: VendorTheme.spacing16),
            Text(
              'No notifications',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: VendorTheme.grey500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchNotifications,
      color: VendorTheme.primary,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: VendorTheme.spacing16,
          vertical: VendorTheme.spacing8,
        ),
        itemCount: _notifications.length,
        separatorBuilder: (context, index) =>
            const SizedBox(height: VendorTheme.spacing12),
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          return _buildNotificationCard(notification, index);
        },
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: VendorTheme.spacing16,
        vertical: VendorTheme.spacing12,
      ),
      child: Row(
        children: ['All', 'Unread', 'Priority'].map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: VendorTheme.spacing8),
            child: ChoiceChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedFilter = filter);
                  _fetchNotifications();
                }
              },
              backgroundColor: VendorTheme.background,
              selectedColor: VendorTheme.primary.withValues(alpha: 0.1),
              labelStyle: TextStyle(
                color: isSelected ? VendorTheme.primary : VendorTheme.grey500,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected ? VendorTheme.primary : VendorTheme.grey300,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  IconData _getIconForType(String? type) {
    switch (type) {
      case 'new_order':
        return Icons.shopping_cart_outlined;
      case 'low_stock':
        return Icons.inventory_2_outlined;
      case 'settlement_complete':
        return Icons.account_balance_wallet_outlined;
      case 'campaign_performance':
        return Icons.insights_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _getColorForPriority(String? priority) {
    switch (priority) {
      case 'high':
      case 'critical':
        return VendorTheme.error;
      default:
        return VendorTheme.primary;
    }
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification, int index) {
    final bool isRead = notification['isRead'] == true;
    final String priority =
        (notification['priority'] as String?)?.toLowerCase() ?? 'normal';
    final String title = notification['title'] ?? '';
    final String body = notification['message'] ?? notification['body'] ?? '';
    final String type = notification['type'] ?? '';

    final String timeStr = notification['createdAt'] ?? '';
    String displayTime = 'Just now';
    if (timeStr.isNotEmpty) {
      final dt = DateTime.tryParse(timeStr);
      if (dt != null) {
        final diff = DateTime.now().difference(dt);
        if (diff.inMinutes < 60) {
          displayTime = '${diff.inMinutes} mins ago';
        } else if (diff.inHours < 24) {
          displayTime = '${diff.inHours} hours ago';
        } else {
          displayTime = '${diff.inDays} days ago';
        }
      }
    }

    final color = _getColorForPriority(priority);
    final icon = _getIconForType(type);

    return PremiumVendorCard(
      padding: const EdgeInsets.all(VendorTheme.spacing16),
      backgroundColor: isRead
          ? Colors.white
          : VendorTheme.primary.withValues(alpha: 0.03),
      onTap: () => _markAsRead(notification['_id'] ?? '', index),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.1),
                child: Icon(icon, color: color, size: 20),
              ),
              if (!isRead)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: VendorTheme.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: VendorTheme.spacing16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: isRead
                              ? FontWeight.w600
                              : FontWeight.bold,
                        ),
                      ),
                    ),
                    if (priority == 'high' || priority == 'critical')
                      const Padding(
                        padding: EdgeInsets.only(left: 8.0),
                        child: VendorStatusBadge(
                          label: 'PRIORITY',
                          type: VendorBadgeType.error,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: VendorTheme.spacing4),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isRead
                        ? VendorTheme.grey600
                        : Theme.of(context).colorScheme.onSurface,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: VendorTheme.spacing8),
                Text(
                  displayTime,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: VendorTheme.grey400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
