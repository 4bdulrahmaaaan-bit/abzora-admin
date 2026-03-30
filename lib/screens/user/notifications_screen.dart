import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/network_provider.dart';
import '../../services/database_service.dart';
import '../../services/local_cache_service.dart';
import '../../theme.dart';
import '../../widgets/offline_widgets.dart';
import '../../widgets/state_views.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _db = DatabaseService();
  final _cache = LocalCacheService();
  List<AppNotification> _notifications = [];
  bool _loading = true;
  bool _loadFailed = false;
  NetworkProvider? _networkProvider;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadNotifications);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<NetworkProvider>();
    if (!identical(provider, _networkProvider)) {
      _networkProvider?.removeListener(_handleNetworkChange);
      _networkProvider = provider;
      _networkProvider?.addListener(_handleNetworkChange);
    }
  }

  @override
  void dispose() {
    _networkProvider?.removeListener(_handleNetworkChange);
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    try {
      final auth = context.read<AuthProvider>();
      final notifications = await _db.getNotificationsFor(auth.user);
      await _cache.saveJsonList(
        'notifications_${auth.user?.id ?? 'guest'}',
        notifications.map((item) => item.toMap()).toList(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _notifications = notifications;
        _loading = false;
        _loadFailed = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      final auth = context.read<AuthProvider>();
      final cached = await _cache.readJsonList('notifications_${auth.user?.id ?? 'guest'}');
      setState(() {
        _notifications = cached
            .map((item) => AppNotification.fromMap(item))
            .toList();
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  void _handleNetworkChange() {
    final provider = _networkProvider;
    if (provider == null || !provider.justCameOnline || _loading) {
      return;
    }
    _loadNotifications();
  }

  Future<void> _markAllRead() async {
    await _db.markAllNotificationsRead(context.read<AuthProvider>().user);
    await _loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((notification) => !notification.isRead).length;
    final role = context.watch<AuthProvider>().user?.role ?? 'user';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text(
                'Mark all read',
                style: TextStyle(color: AbzioTheme.accentColor, fontWeight: FontWeight.w700),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const AbzioLoadingView(
              title: 'Loading notifications',
              subtitle: 'Checking orders, offers, and account updates for you.',
            )
          : _loadFailed && _notifications.isEmpty
              ? AbzioOfflineView(
                  onRetry: () {
                    setState(() {
                      _loading = true;
                    });
                    _loadNotifications();
                  },
                )
          : _loadFailed
              ? _buildLoadError()
          : _notifications.isEmpty
              ? _buildEmpty()
              : Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AbzioTheme.accentColor.withValues(alpha: 0.22)),
                        gradient: LinearGradient(
                          colors: [
                            AbzioTheme.accentColor.withValues(alpha: 0.12),
                            Theme.of(context).inputDecorationTheme.fillColor ?? Theme.of(context).cardColor,
                            Theme.of(context).cardColor,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.notifications_active_outlined, color: AbzioTheme.accentColor),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              role == 'vendor'
                                  ? 'New order alerts, payout updates, and fulfillment changes appear here.'
                                  : role == 'super_admin'
                                      ? 'Platform events, vendor approvals, and payout activity appear here.'
                                      : 'Order updates, offers, and style reminders appear here.',
                              style: TextStyle(color: context.abzioSecondaryText, height: 1.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (unreadCount > 0)
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: context.abzioBorder),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AbzioTheme.accentColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '$unreadCount unread notification${unreadCount > 1 ? 's' : ''}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) => _buildNotificationCard(_notifications[index], index),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AbzioEmptyCard(
          title: 'Notifications are unavailable right now',
          subtitle: _notifications.isEmpty
              ? 'Your orders and account are safe. We just could not load alerts at the moment.'
              : 'Showing your last saved notifications while live updates are unavailable.',
          ctaLabel: 'Retry',
          onTap: () {
            setState(() {
              _loading = true;
            });
            _loadNotifications();
          },
        ),
      ),
    );
  }

  Widget _buildNotificationCard(AppNotification notification, int index) {
    final icons = {
      'order': Icons.local_shipping_outlined,
      'promo': Icons.local_offer_outlined,
      'tailor': Icons.content_cut_rounded,
      'referral': Icons.card_giftcard_outlined,
      'vendor_order': Icons.storefront_outlined,
      'payout': Icons.account_balance_wallet_outlined,
      'abandoned_cart': Icons.shopping_cart_checkout_outlined,
    };
    final colors = {
      'order': const Color(0xFF4DA3FF),
      'promo': AbzioTheme.accentColor,
      'tailor': const Color(0xFFB07CFF),
      'referral': const Color(0xFF4CAF50),
      'vendor_order': const Color(0xFF8A63FF),
      'payout': const Color(0xFF4CAF50),
      'abandoned_cart': const Color(0xFFFFA726),
    };

    final icon = icons[notification.type] ?? Icons.notifications_outlined;
    final color = colors[notification.type] ?? Theme.of(context).colorScheme.onSurface;
    final timeAgo = _timeAgo(notification.timestamp);

    return GestureDetector(
      onTap: () {
        setState(() {
          _notifications[index] = AppNotification(
            id: notification.id,
            title: notification.title,
            body: notification.body,
            type: notification.type,
            isRead: true,
            timestamp: notification.timestamp,
          );
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notification.isRead
              ? Theme.of(context).cardColor
              : (Theme.of(context).inputDecorationTheme.fillColor ?? Theme.of(context).cardColor),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: notification.isRead
                ? context.abzioBorder
                : AbzioTheme.accentColor.withValues(alpha: 0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withValues(alpha: 0.16),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: notification.isRead ? FontWeight.w700 : FontWeight.w800,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AbzioTheme.accentColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notification.body,
                    style: TextStyle(color: context.abzioSecondaryText, height: 1.45),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    timeAgo,
                    style: TextStyle(
                      color: context.abzioSecondaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: AbzioEmptyCard(
          title: 'All caught up',
          subtitle: 'No new notifications right now. Fresh order updates, offers, and account alerts will appear here.',
        ),
      ),
    );
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
