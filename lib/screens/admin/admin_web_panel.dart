import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../services/onboarding_service.dart';
import '../../theme.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/state_views.dart';
import 'admin_banners_section.dart';
import 'admin_categories_section.dart';

enum AdminWebSection {
  dashboard,
  banners,
  categories,
  kyc,
  support,
  orders,
  vendors,
  riders,
  users,
  products,
  payouts,
  analytics,
  settings,
}

class AdminWebPanel extends StatefulWidget {
  const AdminWebPanel({
    super.key,
    this.initialSection = AdminWebSection.dashboard,
  });

  final AdminWebSection initialSection;

  @override
  State<AdminWebPanel> createState() => _AdminWebPanelState();
}

class _AdminWebPanelState extends State<AdminWebPanel> {
  static const int _pageSize = 10;

  final _db = DatabaseService();
  final _onboardingService = OnboardingService();
  final _globalSearchController = TextEditingController();
  final _userSearchController = TextEditingController();
  final _vendorSearchController = TextEditingController();
  final _riderSearchController = TextEditingController();
  final _orderSearchController = TextEditingController();
  final _productSearchController = TextEditingController();
  final _supportReplyController = TextEditingController();
  final _supportSearchController = TextEditingController();
  final _aiCostThresholdController = TextEditingController();

  late AdminWebSection _tab;
  AdminAnalytics? _analytics;
  PlatformSettings _settings = const PlatformSettings();
  GlobalSearchResults _searchResults = const GlobalSearchResults();
  List<AppUser> _users = [];
  List<Store> _stores = [];
  List<Product> _products = [];
  List<OrderModel> _orders = [];
  List<PayoutModel> _payouts = [];
  List<AppNotification> _notifications = [];
  List<VendorKycRequest> _vendorRequests = [];
  List<RiderKycRequest> _riderRequests = [];
  List<DisputeRecord> _disputes = [];
  List<ActivityLogEntry> _activityLogs = [];
  List<SupportChat> _supportChats = [];
  List<AiUsageLogEntry> _aiUsageLogs = [];
  List<AiDailyStat> _aiDailyStats = [];
  List<UserAiUsageStat> _userAiUsageStats = [];

  bool _loading = true;
  bool _runningSearch = false;
  bool _pinVerified = !kIsWeb;
  String? _loadError;

  String _userRoleFilter = 'All';
  String _vendorStatusFilter = 'All';
  String _riderStatusFilter = 'All';
  String _orderStatusFilter = 'All';
  String _productStatusFilter = 'All';
  String _supportStatusFilter = 'all';
  String _supportTypeFilter = 'all';

  int _vendorPage = 0;
  int _userPage = 0;
  int _riderPage = 0;
  int _orderPage = 0;
  int _productPage = 0;
  int _payoutPage = 0;
  String? _selectedSupportChatId;

  AppUser? get _actor => context.read<AuthProvider>().user;
  bool get _usesBackendCommerce => _db.usesBackendCommerce;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialSection;
    _userSearchController.addListener(() => _resetPage('users'));
    _vendorSearchController.addListener(() => _resetPage('vendors'));
    _riderSearchController.addListener(() => _resetPage('riders'));
    _orderSearchController.addListener(() => _resetPage('orders'));
    _productSearchController.addListener(() => _resetPage('products'));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _ensurePinIfNeeded();
      if (mounted && _pinVerified) {
        await _load();
      }
    });
  }

  @override
  void dispose() {
    _globalSearchController.dispose();
    _userSearchController.dispose();
    _vendorSearchController.dispose();
    _riderSearchController.dispose();
    _orderSearchController.dispose();
    _productSearchController.dispose();
    _supportReplyController.dispose();
    _supportSearchController.dispose();
    _aiCostThresholdController.dispose();
    super.dispose();
  }

  void _resetPage(String scope) {
    if (!mounted) {
      return;
    }
    setState(() {
      switch (scope) {
        case 'users':
          _userPage = 0;
          break;
        case 'vendors':
          _vendorPage = 0;
          break;
        case 'riders':
          _riderPage = 0;
          break;
        case 'orders':
          _orderPage = 0;
          break;
        case 'products':
          _productPage = 0;
          break;
        case 'payouts':
          _payoutPage = 0;
          break;
        default:
          break;
      }
    });
  }

  Future<void> _ensurePinIfNeeded() async {
    final actor = _actor;
    if (actor == null || !context.read<AuthProvider>().isSuperAdmin) {
      return;
    }
    final settings = await _safePlatformSettings(actor);
    if (!mounted) {
      return;
    }
    if (!kIsWeb || !settings.adminPinEnabled) {
      setState(() {
        _settings = settings;
        _pinVerified = true;
      });
      return;
    }

    final controller = TextEditingController();
    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Admin PIN'),
        content: TextField(
          controller: controller,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Enter admin PIN',
            prefixIcon: Icon(Icons.lock_outline_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Logout'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              controller.text.trim() == settings.adminPin,
            ),
            child: const Text('Verify'),
          ),
        ],
      ),
    );

    if (!mounted) {
      return;
    }
    if (verified == true) {
      setState(() {
        _settings = settings;
        _pinVerified = true;
      });
      return;
    }

    await context.read<AuthProvider>().logout();
    if (!mounted) {
      return;
    }
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  Future<void> _load() async {
    final actor = _actor;
    if (actor == null) {
      return;
    }
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        _db.getAdminAnalytics(),
        _safePlatformSettings(actor),
        _db.getUsers(actor: actor),
        _db.getAdminStores(),
        _db.getAllProducts(actor: actor),
        _db.getAllOrders(actor: actor),
        _safePayouts(actor),
        _safeNotifications(actor),
        _onboardingService.getVendorRequests(actor: actor),
        _onboardingService.getRiderRequests(actor: actor),
        _db.getSupportChats(actor: actor),
        _safeDisputes(actor),
        _safeActivityLogs(actor),
        _db.getAiUsageLogs(actor: actor),
        _db.getAiDailyStats(actor: actor),
        _db.getUserAiUsageStats(actor: actor),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _analytics = results[0] as AdminAnalytics;
        _settings = results[1] as PlatformSettings;
        _aiCostThresholdController.text =
            _settings.aiDailyCostLimit.toStringAsFixed(2);
        _users = results[2] as List<AppUser>;
        _stores = results[3] as List<Store>;
        _products = results[4] as List<Product>;
        _orders = results[5] as List<OrderModel>;
        _payouts = results[6] as List<PayoutModel>;
        _notifications = results[7] as List<AppNotification>;
        _vendorRequests = results[8] as List<VendorKycRequest>;
        _riderRequests = results[9] as List<RiderKycRequest>;
        _supportChats = results[10] as List<SupportChat>;
        _disputes = results[11] as List<DisputeRecord>;
        _activityLogs = results[12] as List<ActivityLogEntry>;
        _aiUsageLogs = results[13] as List<AiUsageLogEntry>;
        _aiDailyStats = results[14] as List<AiDailyStat>;
        _userAiUsageStats = results[15] as List<UserAiUsageStat>;
        _selectedSupportChatId ??= _supportChats.isEmpty ? null : _supportChats.first.id;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _loadError = error.toString();
      });
    }
  }

  Future<void> _runGlobalSearch() async {
    final actor = _actor;
    if (actor == null) {
      return;
    }
    setState(() => _runningSearch = true);
    try {
      final results = await _db.runGlobalAdminSearch(
        _globalSearchController.text.trim(),
        actor: actor,
      );
      if (!mounted) {
        return;
      }
      setState(() => _searchResults = results);
    } finally {
      if (mounted) {
        setState(() => _runningSearch = false);
      }
    }
  }

  Future<void> _toggleUserActive(AppUser user) async {
    await _db.updateUser(user.copyWith(isActive: !user.isActive), actor: _actor);
    await _load();
  }

  Future<void> _changeUserRole(AppUser user, String role) async {
    await _db.updateUser(user.copyWith(role: role), actor: _actor);
    await _load();
  }

  Future<void> _toggleRiderApproval(AppUser user) async {
    final approved = user.riderApprovalStatus == 'approved';
    await _db.updateUser(
      user.copyWith(
        riderApprovalStatus: approved ? 'pending' : 'approved',
        isActive: approved ? user.isActive : true,
      ),
      actor: _actor,
    );
    await _load();
  }

  Future<void> _toggleStoreApproval(Store store) async {
    final nextApproved = !store.isApproved;
    await _db.saveStore(
      store.copyWith(
        isApproved: nextApproved,
        isActive: nextApproved ? store.isActive : false,
        approvalStatus: nextApproved ? 'approved' : 'pending',
      ),
      actor: _actor,
    );
    await _load();
  }

  Future<void> _toggleStoreActive(Store store) async {
    await _db.saveStore(store.copyWith(isActive: !store.isActive), actor: _actor);
    await _load();
  }

  Future<void> _toggleFeatured(Store store) async {
    await _db.saveStore(store.copyWith(isFeatured: !store.isFeatured), actor: _actor);
    await _load();
  }

  Future<void> _adjustCommission(Store store) async {
    final controller = TextEditingController(
      text: (store.commissionRate * 100).toStringAsFixed(0),
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Commission for ${store.name}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Commission %',
            prefixIcon: Icon(Icons.percent_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    final rate =
        (double.tryParse(controller.text.trim()) ?? (store.commissionRate * 100)) /
            100;
    await _db.adjustStoreCommission(
      storeId: store.id,
      commissionRate: rate,
      actor: _actor!,
    );
    await _load();
  }

  Future<void> _processPayout(Store store) async {
    final actor = _actor;
    if (actor == null) {
      return;
    }
    final payout = await _db.processVendorPayout(
      storeId: store.id,
      actor: actor,
      periodLabel: 'Admin settlement',
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          payout == null
              ? 'No payout-ready balance is available for ${store.name}.'
              : 'Processed payout of ${_formatCurrency(payout.amount)} for ${store.name}.',
        ),
      ),
    );
    await _load();
  }

  Future<void> _setOrderStatus(OrderModel order, String status) async {
    await _db.updateOrderStatus(order.id, status, actor: _actor);
    await _load();
  }

  Future<void> _settleRiderPayouts() async {
    final actor = _actor;
    if (actor == null) {
      return;
    }
    final settled = await _db.settleRiderPayouts(actor: actor, periodLabel: 'Admin rider settlement');
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          settled.isEmpty
              ? 'No rider payouts are pending right now.'
              : 'Processed ${settled.length} rider settlement${settled.length == 1 ? '' : 's'}.',
        ),
      ),
    );
    await _load();
  }

  Future<void> _runScheduledSettlements(String walletType) async {
    final actor = _actor;
    if (actor == null) {
      return;
    }
    final result = await _db.runScheduledSettlements(walletType: walletType, actor: actor);
    if (!mounted) {
      return;
    }
    final successes = (result['successes'] as List? ?? const []).length;
    final failures = (result['failures'] as List? ?? const []).length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$walletType settlements finished. $successes success, $failures failed.',
        ),
      ),
    );
    await _load();
  }

  Future<void> _approveWithdrawal(WithdrawalRequestSummary request) async {
    final actor = _actor;
    if (actor == null) {
      return;
    }
    await _db.approveWithdrawalRequest(requestId: request.id, actor: actor);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Withdrawal approved.')),
    );
    await _load();
  }

  Future<void> _rejectWithdrawal(WithdrawalRequestSummary request) async {
    final actor = _actor;
    if (actor == null) {
      return;
    }
    final controller = TextEditingController();
    try {
      final reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Reject withdrawal'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Add a short reason',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('Reject'),
            ),
          ],
        ),
      );
      if ((reason ?? '').isEmpty) {
        return;
      }
      await _db.rejectWithdrawalRequest(
        requestId: request.id,
        reason: reason!,
        actor: actor,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Withdrawal rejected.')),
      );
      await _load();
    } finally {
      controller.dispose();
    }
  }

  Future<void> _updateFraudAlert(FraudAlertSummary alert, String status) async {
    final actor = _actor;
    if (actor == null) {
      return;
    }
    await _db.updateFraudAlertStatus(
      alertId: alert.id,
      status: status,
      actor: actor,
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Fraud alert moved to ${status.toUpperCase()}')),
    );
    await _load();
  }

  Future<void> _approveRefund(RefundRequest request) async {
    final actor = _actor;
    if (actor == null) {
      return;
    }
    try {
      await _db.approveRefundRequest(request.id, actor: actor);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Refund approved and processed.')),
      );
      await _load();
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message.toString())),
      );
      await _load();
    }
  }

  Future<PlatformSettings> _safePlatformSettings(AppUser actor) async {
    try {
      return await _db.getPlatformSettings(actor: actor);
    } catch (_) {
      return const PlatformSettings();
    }
  }

  Future<List<PayoutModel>> _safePayouts(AppUser actor) async {
    try {
      return await _db.getPayouts(actor: actor);
    } catch (_) {
      return const <PayoutModel>[];
    }
  }

  Future<List<AppNotification>> _safeNotifications(AppUser actor) async {
    try {
      return await _db.getNotificationsFor(actor);
    } catch (_) {
      return const <AppNotification>[];
    }
  }

  Future<List<DisputeRecord>> _safeDisputes(AppUser actor) async {
    try {
      return await _db.getDisputes(actor: actor);
    } catch (_) {
      return const <DisputeRecord>[];
    }
  }

  Future<List<ActivityLogEntry>> _safeActivityLogs(AppUser actor) async {
    try {
      return await _db.getActivityLogs(actor: actor);
    } catch (_) {
      return const <ActivityLogEntry>[];
    }
  }

  Future<void> _rejectRefund(RefundRequest request) async {
    final actor = _actor;
    if (actor == null) {
      return;
    }
    final controller = TextEditingController();
    try {
      final reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Reject refund'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Add a short reason for the customer',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: const Text('Reject'),
            ),
          ],
        ),
      );
      if ((reason ?? '').trim().isEmpty) {
        return;
      }
      await _db.rejectRefundRequest(
        request.id,
        reason: reason!.trim(),
        actor: actor,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Refund request rejected.')),
      );
      await _load();
    } finally {
      controller.dispose();
    }
  }

  Future<void> _assignRider(OrderModel order) async {
    final riders = _users
        .where(
          (user) =>
              user.role == 'rider' &&
              user.riderApprovalStatus == 'approved' &&
              user.isActive,
        )
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (riders.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('No approved riders are available to assign.'),
        ),
      );
      return;
    }
    String? selectedId = order.riderId;
    final shouldAssign = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'Assign rider for ${order.invoiceNumber.isEmpty ? order.id : order.invoiceNumber}',
          ),
          content: DropdownButtonFormField<String>(
            initialValue: selectedId,
            decoration: const InputDecoration(labelText: 'Rider'),
            items: riders
                .map(
                  (rider) => DropdownMenuItem<String>(
                    value: rider.id,
                    child: Text(
                      '${rider.name} (${rider.riderCity ?? rider.city ?? 'Unknown'})',
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => setDialogState(() => selectedId = value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
    if (shouldAssign != true || selectedId == null || selectedId == order.riderId) {
      return;
    }
    final rider = riders.firstWhere((user) => user.id == selectedId);
    await _db.assignRiderToOrder(order.id, rider, actor: _actor!);
    await _load();
  }

  Future<void> _toggleProductVisibility(Product product) async {
    await _db.updateProduct(
      Product(
        id: product.id,
        storeId: product.storeId,
        name: product.name,
        brand: product.brand,
        description: product.description,
        price: product.price,
        originalPrice: product.originalPrice,
        images: product.images,
        sizes: product.sizes,
        stock: product.stock,
        category: product.category,
        subcategory: product.subcategory,
        isActive: !product.isActive,
        createdAt: product.createdAt,
        rating: product.rating,
        reviewCount: product.reviewCount,
        isCustomTailoring: product.isCustomTailoring,
        outfitType: product.outfitType,
        fabric: product.fabric,
        attributes: product.attributes,
        customizations: product.customizations,
        measurements: product.measurements,
        addons: product.addons,
        measurementProfileLabel: product.measurementProfileLabel,
        neededBy: product.neededBy,
        tailoringDeliveryMode: product.tailoringDeliveryMode,
        tailoringExtraCost: product.tailoringExtraCost,
      ),
      actor: _actor,
    );
    await _load();
  }

  Future<void> _sendSupportReply() async {
    final actor = _actor;
    final chat = _selectedSupportChat;
    final text = _supportReplyController.text.trim();
    if (actor == null || chat == null || text.isEmpty) {
      return;
    }
    await _db.sendSupportMessage(
      chatId: chat.id,
      text: text,
      actor: actor,
    );
    _supportReplyController.clear();
    await _load();
  }

  Future<void> _selectSupportChat(SupportChat chat) async {
    setState(() {
      _selectedSupportChatId = chat.id;
    });
    final actor = _actor;
    if (actor == null) {
      return;
    }
    await _db.markSupportChatRead(chatId: chat.id, actor: actor);
    await _load();
  }

  Future<void> _closeSupportConversation(SupportChat chat) async {
    final actor = _actor;
    if (actor == null) {
      return;
    }
    await _db.closeSupportTicket(chatId: chat.id, actor: actor);
    await _load();
  }

  Future<void> _reopenSupportConversation(SupportChat chat) async {
    final actor = _actor;
    if (actor == null) {
      return;
    }
    await _db.reopenSupportTicket(chatId: chat.id, actor: actor);
    await _load();
  }

  Future<void> _toggleFeature(String key, bool value) async {
    final actor = _actor;
    if (actor == null) {
      return;
    }
    PlatformSettings next = _settings;
    switch (key) {
      case 'custom':
        next = next.copyWith(customTailoringEnabled: value);
        break;
      case 'offers':
        next = next.copyWith(offersEnabled: value);
        break;
      case 'reels':
        next = next.copyWith(reelsEnabled: value);
        break;
      case 'checkout':
        next = next.copyWith(checkoutEnabled: value);
        break;
      case 'marketplace':
        next = next.copyWith(marketplaceEnabled: value);
        break;
      case 'dispatch':
        next = next.copyWith(riderDispatchEnabled: value);
        break;
      case 'ai':
        next = next.copyWith(aiAssistantEnabled: value);
        break;
      default:
        break;
    }
    await _db.savePlatformSettings(next, actor: actor);
    await _load();
  }

  Future<void> _toggleCity(String city, bool enabled) async {
    final actor = _actor;
    if (actor == null) {
      return;
    }
    final nextCities = Map<String, bool>.from(_settings.cities)..[city] = enabled;
    final nextRegions =
        Map<String, bool>.from(_settings.regionVendorAvailability)..[city] = enabled;
    await _db.savePlatformSettings(
      _settings.copyWith(
        cities: nextCities,
        regionVendorAvailability: nextRegions,
      ),
      actor: actor,
    );
    await _load();
  }

  Future<void> _saveAiCostThreshold() async {
    final actor = _actor;
    if (actor == null) {
      return;
    }
    final parsed = double.tryParse(_aiCostThresholdController.text.trim());
    if (parsed == null || parsed < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid AI cost threshold.')),
      );
      return;
    }
    await _db.savePlatformSettings(
      _settings.copyWith(
        aiDailyCostLimit: parsed,
        aiDailyCostAlertThreshold: parsed * 0.8,
      ),
      actor: actor,
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('AI budget controls updated.')),
    );
    await _load();
  }

  List<AppUser> get _filteredUsers {
    final query = _userSearchController.text.trim().toLowerCase();
    final filtered = _users.where((user) {
      final matchesRole = _userRoleFilter == 'All' || user.role == _userRoleFilter;
      final haystack =
          '${user.name} ${user.email} ${user.phone ?? ''} ${user.city ?? ''}'
              .toLowerCase();
      final matchesQuery = query.isEmpty || haystack.contains(query);
      return matchesRole && matchesQuery;
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return filtered;
  }

  List<Store> get _filteredStores {
    final query = _vendorSearchController.text.trim().toLowerCase();
    final filtered = _stores.where((store) {
      final matchesStatus = _vendorStatusFilter == 'All' ||
          (_vendorStatusFilter == 'Approved' && store.isApproved) ||
          (_vendorStatusFilter == 'Pending' && store.approvalStatus == 'pending') ||
          (_vendorStatusFilter == 'Rejected' && store.approvalStatus == 'rejected');
      final haystack =
          '${store.name} ${store.address} ${store.city} ${store.ownerId}'.toLowerCase();
      final matchesQuery = query.isEmpty || haystack.contains(query);
      return matchesStatus && matchesQuery;
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return filtered;
  }

  List<AppUser> get _filteredRiders {
    final query = _riderSearchController.text.trim().toLowerCase();
    final filtered = _users.where((user) {
      final isRider = user.role == 'rider' || user.roles['rider'] == true;
      if (!isRider) {
        return false;
      }
      final matchesStatus = _riderStatusFilter == 'All' ||
          (_riderStatusFilter == 'Approved' &&
              user.riderApprovalStatus == 'approved') ||
          (_riderStatusFilter == 'Pending' && user.riderApprovalStatus == 'pending') ||
          (_riderStatusFilter == 'Active' && user.isActive) ||
          (_riderStatusFilter == 'Inactive' && !user.isActive);
      final haystack =
          '${user.name} ${user.phone ?? ''} ${user.city ?? ''} ${user.riderCity ?? ''}'
              .toLowerCase();
      final matchesQuery = query.isEmpty || haystack.contains(query);
      return matchesStatus && matchesQuery;
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return filtered;
  }

  List<OrderModel> get _filteredOrders {
    final query = _orderSearchController.text.trim().toLowerCase();
    final filtered = _orders.where((order) {
      final invoice = order.invoiceNumber.isEmpty ? order.id : order.invoiceNumber;
      final matchesStatus =
          _orderStatusFilter == 'All' || order.status == _orderStatusFilter;
      final haystack =
          '$invoice ${order.shippingAddress} ${order.storeId} ${order.userId}'
              .toLowerCase();
      final matchesQuery = query.isEmpty || haystack.contains(query);
      return matchesStatus && matchesQuery;
    }).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return filtered;
  }

  List<Product> get _filteredProducts {
    final query = _productSearchController.text.trim().toLowerCase();
    final filtered = _products.where((product) {
      final matchesStatus = _productStatusFilter == 'All' ||
          (_productStatusFilter == 'Active' && product.isActive) ||
          (_productStatusFilter == 'Hidden' && !product.isActive);
      final haystack =
          '${product.name} ${product.brand} ${product.category} ${product.storeId}'
              .toLowerCase();
      final matchesQuery = query.isEmpty || haystack.contains(query);
      return matchesStatus && matchesQuery;
    }).toList()
      ..sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
    return filtered;
  }

  List<PayoutModel> get _sortedPayouts {
    final payouts = _payouts.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return payouts;
  }

  List<SupportChat> get _filteredSupportChats {
    final query = _supportSearchController.text.trim().toLowerCase();
    final filtered = _supportChats.where((chat) {
      final matchesStatus = _supportStatusFilter == 'all' || chat.status == _supportStatusFilter;
      final matchesType = _supportTypeFilter == 'all' || chat.type == _supportTypeFilter;
      final haystack =
          '${chat.userName} ${chat.userPhone} ${chat.type} ${chat.lastMessage} ${chat.id} ${chat.orderId ?? ''}'
              .toLowerCase();
      final matchesQuery = query.isEmpty || haystack.contains(query);
      return matchesStatus && matchesType && matchesQuery;
    }).toList()
      ..sort((a, b) {
        final statusWeight = _supportWeight(a.status).compareTo(_supportWeight(b.status));
        if (statusWeight != 0) {
          return statusWeight;
        }
        return b.updatedAt.compareTo(a.updatedAt);
      });
    return filtered;
  }

  SupportChat? get _selectedSupportChat {
    final selectedId = _selectedSupportChatId;
    if (selectedId == null) {
      return _filteredSupportChats.isEmpty ? null : _filteredSupportChats.first;
    }
    for (final chat in _supportChats) {
      if (chat.id == selectedId) {
        return chat;
      }
    }
    return _filteredSupportChats.isEmpty ? null : _filteredSupportChats.first;
  }

  int get _pendingKycCount =>
      _vendorRequests.where((request) => request.status == 'pending').length +
      _riderRequests.where((request) => request.status == 'pending').length;

  double get _revenueToday {
    final now = DateTime.now();
    return _orders
        .where(
          (order) =>
              order.timestamp.year == now.year &&
              order.timestamp.month == now.month &&
              order.timestamp.day == now.day &&
              order.status != 'Cancelled',
        )
        .fold<double>(0, (sum, order) => sum + order.totalAmount);
  }

  int get _activeRiderCount => _users
      .where(
        (user) =>
            (user.role == 'rider' || user.roles['rider'] == true) &&
            user.isActive &&
            user.riderApprovalStatus == 'approved',
      )
      .length;

  int _activeDeliveriesForRider(String riderId) => _orders
      .where(
        (order) =>
            order.riderId == riderId &&
            order.status != 'Delivered' &&
            order.status != 'Cancelled',
      )
      .length;

  double _pendingPayoutForStore(String storeId) => _orders
      .where(
        (order) =>
            order.storeId == storeId &&
            order.payoutStatus == 'Ready' &&
            !order.payoutProcessed,
      )
      .fold<double>(0, (sum, order) => sum + order.vendorEarnings);

  int _supportWeight(String status) {
    switch (status) {
      case 'waiting':
        return 0;
      case 'open':
        return 1;
      case 'closed':
        return 2;
      default:
        return 3;
    }
  }

  int _supportUnreadCount({
    String? status,
    String? type,
  }) {
    return _supportChats.where((chat) {
      final matchesStatus = status == null || chat.status == status;
      final matchesType = type == null || chat.type == type;
      return matchesStatus && matchesType;
    }).fold<int>(0, (sum, chat) => sum + chat.unreadCountAdmin);
  }

  int _supportChatCount({
    String? status,
    String? type,
  }) {
    return _supportChats.where((chat) {
      final matchesStatus = status == null || chat.status == status;
      final matchesType = type == null || chat.type == type;
      return matchesStatus && matchesType;
    }).length;
  }

  List<ActivityLogEntry> _supportTimelineFor(String chatId) {
    final entries = _activityLogs
        .where((entry) => entry.targetType == 'support_chat' && entry.targetId == chatId)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries;
  }

  Store? _storeForId(String storeId) {
    for (final store in _stores) {
      if (store.id == storeId) {
        return store;
      }
    }
    return null;
  }

  AppUser? _userForId(String userId) {
    for (final user in _users) {
      if (user.id == userId) {
        return user;
      }
    }
    return null;
  }

  List<T> _pageSlice<T>(List<T> items, int page) {
    final start = page * _pageSize;
    if (start >= items.length) {
      return const [];
    }
    final end = (start + _pageSize).clamp(0, items.length);
    return items.sublist(start, end);
  }

  int _pageCount(List<dynamic> items) {
    if (items.isEmpty) {
      return 1;
    }
    return (items.length / _pageSize).ceil();
  }

  String _formatCurrency(double value) {
    final rounded = value.round().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < rounded.length; i++) {
      final reverseIndex = rounded.length - i;
      buffer.write(rounded[i]);
      final charsAfter = reverseIndex - 1;
      if (charsAfter > 0 && charsAfter % 3 == 0) {
        buffer.write(',');
      }
    }
    return 'Rs ${buffer.toString()}';
  }

  String _formatAiCost(double value) {
    return '\$${value.toStringAsFixed(value >= 1 ? 2 : 4)}';
  }

  String _formatAiCostCompact(double value) {
    if (value == 0) {
      return '\$0';
    }
    if (value >= 1) {
      return '\$${value.toStringAsFixed(2)}';
    }
    return '\$${value.toStringAsFixed(3)}';
  }

  String _escapeCsv(String value) {
    final escaped = value.replaceAll('"', '""');
    if (escaped.contains(',') || escaped.contains('"') || escaped.contains('\n')) {
      return '"$escaped"';
    }
    return escaped;
  }

  String _formatDate(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }

  String _formatIsoMoment(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return value;
    }
    return '${_formatDate(parsed)} · ${DateFormat('hh:mm a').format(parsed)}';
  }

  String get _todayKey => DateFormat('yyyy-MM-dd').format(DateTime.now());

  AiDailyStat? get _todayAiStat {
    for (final stat in _aiDailyStats) {
      if (stat.date == _todayKey) {
        return stat;
      }
    }
    return null;
  }

  List<AiDailyStat> get _recentAiDailyStats {
    if (_aiDailyStats.length <= 7) {
      return _aiDailyStats;
    }
    return _aiDailyStats.sublist(_aiDailyStats.length - 7);
  }

  double get _todayAiCost => _todayAiStat?.totalCost ?? 0;

  int get _todayActiveAiUsers {
    return _userAiUsageStats.where((usage) {
      final parsed = DateTime.tryParse(usage.lastUsed);
      if (parsed == null) {
        return false;
      }
      return DateFormat('yyyy-MM-dd').format(parsed) == _todayKey && usage.dailyUsage > 0;
    }).length;
  }

  double get _averageAiCostPerUser {
    final users = _todayActiveAiUsers;
    if (users == 0) {
      return 0;
    }
    return _todayAiCost / users;
  }

  double get _logicHandledRate {
    if (_aiUsageLogs.isEmpty) {
      return 0;
    }
    final logicCount = _aiUsageLogs.where((log) => !log.usedAi).length;
    return (logicCount / _aiUsageLogs.length) * 100;
  }

  List<MapEntry<String, int>> get _intentBreakdown {
    final totals = <String, int>{};
    for (final log in _aiUsageLogs) {
      totals.update(log.intentType, (value) => value + 1, ifAbsent: () => 1);
    }
    final items = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return items;
  }

  List<MapEntry<UserAiUsageStat, AppUser?>> get _topAiUsers {
    final items = _userAiUsageStats
        .map((usage) => MapEntry(usage, _userForId(usage.userId)))
        .toList()
      ..sort((a, b) => b.key.aiMessages.compareTo(a.key.aiMessages));
    return items.take(6).toList();
  }

  List<AiUsageLogEntry> get _topExpensiveQueries {
    final logs = _aiUsageLogs.where((log) => log.usedAi).toList()
      ..sort((a, b) => b.cost.compareTo(a.cost));
    return logs.take(6).toList();
  }

  Future<void> _exportAiUsageCsv() async {
    final rows = <String>[
      'timestamp,userId,intentType,usedAi,tokensUsed,cost,responseLength,message',
      ..._aiUsageLogs.map(
        (log) => [
          _escapeCsv(log.timestamp),
          _escapeCsv(log.userId),
          _escapeCsv(log.intentType),
          log.usedAi ? 'true' : 'false',
          '${log.tokensUsed}',
          log.cost.toStringAsFixed(6),
          '${log.responseLength}',
          _escapeCsv(log.message),
        ].join(','),
      ),
    ];
    await Clipboard.setData(ClipboardData(text: rows.join('\n')));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('AI analytics CSV copied to clipboard.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isSuperAdmin) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: AbzioEmptyCard(
              title: 'Admin access only',
              subtitle: 'This workspace is restricted to ABZORA platform administrators.',
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AbzioTheme.backgroundColor,
      body: SafeArea(
        child: Row(
          children: [
            _buildSidebar(context),
            Expanded(
              child: _loading
                  ? const AbzioLoadingView(
                      title: 'Loading admin control center',
                      subtitle: 'Preparing platform analytics, vendor approvals, and operational controls.',
                    )
                  : _loadError != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: AbzioEmptyCard(
                              title: 'Could not load admin data',
                              subtitle: _loadError!,
                              ctaLabel: 'Try again',
                              onTap: _load,
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(
                            padding: const EdgeInsets.all(24),
                            children: [
                              _buildHeader(context),
                              const SizedBox(height: 20),
                              _buildTabContent(context),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    final items = <(AdminWebSection, IconData, String)>[
      (AdminWebSection.dashboard, Icons.dashboard_outlined, 'Dashboard'),
      (AdminWebSection.banners, Icons.view_carousel_outlined, 'Banners'),
      (AdminWebSection.categories, Icons.category_outlined, 'Categories'),
      (AdminWebSection.kyc, Icons.verified_user_outlined, 'KYC Requests'),
      (AdminWebSection.support, Icons.support_agent_rounded, 'Support'),
      (AdminWebSection.orders, Icons.receipt_long_outlined, 'Orders'),
      (AdminWebSection.vendors, Icons.storefront_outlined, 'Vendors'),
      (AdminWebSection.riders, Icons.delivery_dining_outlined, 'Riders'),
      (AdminWebSection.users, Icons.people_alt_outlined, 'Users'),
      (AdminWebSection.products, Icons.inventory_2_outlined, 'Products'),
      (AdminWebSection.analytics, Icons.insights_outlined, 'Analytics'),
      if (!_usesBackendCommerce)
        (AdminWebSection.payouts, Icons.payments_outlined, 'Payouts'),
      if (!_usesBackendCommerce)
        (AdminWebSection.settings, Icons.tune_rounded, 'Settings'),
    ];

    return Container(
      width: 250,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AbzioTheme.grey200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BrandLogo(size: 52, radius: 16),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ABZORA ADMIN',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Marketplace control center',
                      style: GoogleFonts.inter(
                        color: AbzioTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...items.map((item) {
            final selected = _tab == item.$1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(() => _tab = item.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: selected
                        ? AbzioTheme.accentColor.withValues(alpha: 0.16)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected
                          ? AbzioTheme.accentColor.withValues(alpha: 0.3)
                          : AbzioTheme.grey200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        item.$2,
                        color: selected
                            ? AbzioTheme.accentColor
                            : AbzioTheme.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        item.$3,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? AbzioTheme.textPrimary
                              : AbzioTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () async {
              final auth = context.read<AuthProvider>();
              final navigator = Navigator.of(context);
              await auth.logout();
              if (!mounted) {
                return;
              }
              navigator.pushNamedAndRemoveUntil('/login', (route) => false);
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Platform command view',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Monitor users, vendors, riders, payouts, KYC, and revenue from one clean control surface.',
                style: GoogleFonts.inter(
                  color: AbzioTheme.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 580,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _globalSearchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _runGlobalSearch(),
                  decoration: InputDecoration(
                    hintText: 'Search users, stores, vendors, or orders',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _runningSearch
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            onPressed: _runGlobalSearch,
                            icon: const Icon(Icons.arrow_forward_rounded),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => setState(() => _tab = AdminWebSection.kyc),
                icon: const Icon(Icons.verified_user_outlined),
                label: const Text('KYC Queue'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabContent(BuildContext context) {
      switch (_tab) {
        case AdminWebSection.dashboard:
          return _buildDashboard();
        case AdminWebSection.banners:
          return _usesBackendCommerce
            ? const AdminBannersSection()
            : _buildBackendUnavailableState(
                title: 'Banner tools need backend mode',
                subtitle:
                  'Homepage banner management is available only when the admin panel is connected to the backend API.',
                );
        case AdminWebSection.categories:
          return _usesBackendCommerce
              ? const AdminCategoriesSection()
              : _buildBackendUnavailableState(
                  title: 'Category tools need backend mode',
                  subtitle:
                      'Category and subcategory management is available only when the admin panel is connected to the backend API.',
                );
        case AdminWebSection.kyc:
        return _buildKycHub(context);
      case AdminWebSection.support:
        return _buildSupport();
      case AdminWebSection.orders:
        return _buildOrders();
      case AdminWebSection.vendors:
        return _buildVendors();
      case AdminWebSection.riders:
        return _buildRiders();
      case AdminWebSection.users:
        return _buildUsers();
      case AdminWebSection.products:
        return _buildProducts();
      case AdminWebSection.payouts:
        return _usesBackendCommerce
            ? _buildBackendUnavailableState(
                title: 'Payout tools are still migrating',
                subtitle:
                    'Vendor settlement controls still depend on legacy Firebase admin data and are hidden in production backend mode.',
              )
            : _buildPayouts();
      case AdminWebSection.analytics:
        return _buildAnalytics();
      case AdminWebSection.settings:
        return _usesBackendCommerce
            ? _buildBackendUnavailableState(
                title: 'Settings are temporarily hidden',
                subtitle:
                    'Platform toggles, disputes, notifications, and audit controls are still using legacy admin storage and will return after the backend migration.',
              )
            : _buildSettings();
    }
  }

  Widget _buildBackendUnavailableState({
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: AbzioEmptyCard(
          title: title,
          subtitle: subtitle,
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    final analytics = _analytics;
    final vendorCount = _users.where((user) => user.role == 'vendor').length;
    final recentOrders = _orders.toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 136,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _MetricCard(title: 'Total Orders', value: analytics?.totalOrders.toString() ?? '0'),
              _MetricCard(title: 'Revenue Today', value: _formatCurrency(_revenueToday)),
              _MetricCard(title: 'Total Vendors', value: '$vendorCount'),
              _MetricCard(title: 'Active Riders', value: '$_activeRiderCount'),
              _MetricCard(title: 'Pending KYC', value: '$_pendingKycCount'),
              _MetricCard(
                title: 'Total Revenue',
                value: analytics == null ? 'Rs 0' : _formatCurrency(analytics.totalRevenue),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _Panel(
                title: 'Recent orders',
                subtitle: 'Latest marketplace transactions across all stores.',
                child: recentOrders.isEmpty
                    ? const AbzioEmptyCard(
                        title: 'No orders yet',
                        subtitle: 'Orders will appear here as customers complete checkout.',
                      )
                    : Column(
                        children: recentOrders.take(6).map((order) {
                          final invoice =
                              order.invoiceNumber.isEmpty ? order.id : order.invoiceNumber;
                          final store = _storeForId(order.storeId);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              invoice,
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              '${store?.name ?? order.storeId} - ${order.shippingAddress}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _formatCurrency(order.totalAmount),
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  order.status,
                                  style: GoogleFonts.inter(
                                    color: AbzioTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: _Panel(
                title: 'Search results',
                subtitle: 'Global search across users, stores, and orders.',
                child: (_searchResults.users.isEmpty &&
                        _searchResults.stores.isEmpty &&
                        _searchResults.orders.isEmpty)
                    ? const AbzioEmptyCard(
                        title: 'Search the platform',
                        subtitle: 'Use the top search field to find users, stores, and orders instantly.',
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SearchMetric(label: 'Users', value: _searchResults.users.length),
                          _SearchMetric(label: 'Stores', value: _searchResults.stores.length),
                          _SearchMetric(label: 'Orders', value: _searchResults.orders.length),
                        ],
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Panel(
                title: 'Admin alerts',
                subtitle: 'New KYC, payment, and marketplace signals.',
                child: _usesBackendCommerce
                    ? const AbzioEmptyCard(
                        title: 'Alerts are migrating',
                        subtitle:
                            'Admin notification feeds will return here once the backend notification API is wired.',
                      )
                    : _notifications.isEmpty
                    ? const AbzioEmptyCard(
                        title: 'No alerts right now',
                        subtitle: 'Admin notifications will appear here as important events happen.',
                      )
                    : Column(
                        children: _notifications.take(6).map((notification) {
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.notifications_active_outlined),
                            title: Text(
                              notification.title,
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              notification.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Text(
                              _formatDate(notification.timestamp),
                              style: GoogleFonts.inter(
                                color: AbzioTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _Panel(
                title: 'Activity logs',
                subtitle: 'Recent admin and ops actions.',
                child: _usesBackendCommerce
                    ? const AbzioEmptyCard(
                        title: 'Audit log migration in progress',
                        subtitle:
                            'Recent admin actions are temporarily hidden until the backend activity log API is connected.',
                      )
                    : _activityLogs.isEmpty
                    ? const AbzioEmptyCard(
                        title: 'No activity yet',
                        subtitle: 'Admin and operations logs will appear here once actions are taken.',
                      )
                    : Column(
                        children: _activityLogs.take(8).map((entry) {
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.history_rounded),
                            title: Text(
                              entry.message,
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${entry.actorRole} - ${entry.targetType}',
                              style: GoogleFonts.inter(color: AbzioTheme.textSecondary),
                            ),
                            trailing: Text(
                              _formatDate(entry.timestamp),
                              style: GoogleFonts.inter(
                                color: AbzioTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKycHub(BuildContext context) {
    final allRequests = <_KycQueueItem>[
      ..._vendorRequests.map(
        (request) => _KycQueueItem(
          id: request.id,
          name: request.ownerName,
          role: 'Vendor',
          city: request.city,
          status: request.status,
          submittedAt: request.createdAt,
          phone: request.phone,
          autoReviewStatus: request.verification.autoReviewStatus,
          confidenceScore: request.verification.confidenceScore,
          flags: request.verification.flags,
          riskScore: request.verification.riskScore,
          riskDecision: request.verification.riskDecision,
          riskReasons: request.verification.riskReasons,
        ),
      ),
      ..._riderRequests.map(
        (request) => _KycQueueItem(
          id: request.id,
          name: request.name,
          role: 'Rider',
          city: request.city,
          status: request.status,
          submittedAt: request.createdAt,
          phone: request.phone,
        ),
      ),
    ]..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

    final pending = allRequests.where((item) => item.status == 'pending').toList();
    final approved = allRequests.where((item) => item.status == 'approved').length;
    final rejected = allRequests.where((item) => item.status == 'rejected').length;
    final flagged = allRequests.where((item) => item.autoReviewStatus == 'fraud_flagged').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _MetricCard(title: 'Pending KYC', value: '${pending.length}'),
            _MetricCard(title: 'Approved', value: '$approved'),
            _MetricCard(title: 'Rejected', value: '$rejected'),
            _MetricCard(title: 'Flagged by AI', value: '$flagged'),
          ],
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'KYC queue',
          subtitle: 'Fast review access for vendor and rider verification.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pushNamed('/admin-kyc'),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Open full KYC review'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _tab = AdminWebSection.dashboard),
                    icon: const Icon(Icons.dashboard_outlined),
                    label: const Text('Back to dashboard'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              pending.isEmpty
                  ? const AbzioEmptyCard(
                      title: 'No pending requests',
                      subtitle: 'New partner applications will appear here automatically.',
                    )
                  : Column(
                      children: pending.take(8).map((item) {
                        final reviewColor = switch (item.autoReviewStatus) {
                          'auto_verified' => Colors.green,
                          'fraud_flagged' => Colors.red,
                          _ => const Color(0xFFB76E00),
                        };
                        final riskColor = item.riskScore >= 85
                            ? Colors.green
                            : item.riskScore >= 60
                                ? Colors.orange
                                : Colors.red;
                        final reviewLabel = switch (item.autoReviewStatus) {
                          'auto_verified' => 'AI VERIFIED',
                          'fraud_flagged' => 'FLAGGED',
                          _ => 'REVIEW',
                        };
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.verified_user_outlined),
                          title: Text(
                            item.name,
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${item.role} - ${item.city.isEmpty ? 'Unknown city' : item.city} - ${item.phone}'
                            '${item.confidenceScore > 0 ? ' - ${item.confidenceScore.toStringAsFixed(0)}% OCR confidence' : ''}'
                            '${item.riskScore > 0 ? '\nRisk ${item.riskScore} (${item.riskDecision.toUpperCase()})' : ''}'
                            '${item.flags.isNotEmpty ? '\n${item.flags.take(2).join(' • ')}' : item.riskReasons.isNotEmpty ? '\n${item.riskReasons.take(2).join(' • ')}' : ''}',
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _StatusPill(
                                label: item.status.toUpperCase(),
                                color: const Color(0xFFB76E00),
                              ),
                              const SizedBox(height: 6),
                              _StatusPill(
                                label: reviewLabel,
                                color: reviewColor,
                              ),
                              if (item.riskScore > 0) ...[
                                const SizedBox(height: 6),
                                _StatusPill(
                                  label: 'RISK ${item.riskScore}',
                                  color: riskColor,
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrders() {
    final filtered = _filteredOrders;
    final pageCount = _pageCount(filtered);
    final safePage = _orderPage >= pageCount ? pageCount - 1 : _orderPage;
    final visible = _pageSlice(filtered, safePage);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FilterPanel(
          title: 'Order management',
          subtitle: 'Search, inspect, override status, and assign riders when needed.',
          children: [
            SizedBox(
              width: 320,
              child: TextField(
                controller: _orderSearchController,
                decoration: const InputDecoration(
                  hintText: 'Search order, store, user, or address',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                initialValue: _orderStatusFilter,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  'All',
                  'Placed',
                  'Confirmed',
                  'Packed',
                  'Ready for pickup',
                  'Assigned',
                  'Picked up',
                  'Out for delivery',
                  'Delivered',
                  'Cancelled',
                ]
                    .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                    .toList(),
                onChanged: (value) => setState(() {
                  _orderStatusFilter = value ?? 'All';
                  _orderPage = 0;
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Orders',
          subtitle: '${filtered.length} result(s)',
          child: filtered.isEmpty
              ? const AbzioEmptyCard(
                  title: 'No orders match this filter',
                  subtitle: 'Try another status or search term.',
                )
              : Column(
                  children: [
                    ...visible.map((order) {
                      final invoice =
                          order.invoiceNumber.isEmpty ? order.id : order.invoiceNumber;
                      final store = _storeForId(order.storeId);
                      final customer = _userForId(order.userId);
                      final riderName = order.assignedDeliveryPartner == 'Unassigned'
                          ? 'Unassigned'
                          : order.assignedDeliveryPartner;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AbzioTheme.grey200),
                        ),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        invoice,
                                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${customer?.name ?? order.userId} - ${store?.name ?? order.storeId}',
                                        style: GoogleFonts.inter(color: AbzioTheme.textSecondary),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        order.shippingAddress,
                                        style: GoogleFonts.inter(color: AbzioTheme.textSecondary),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _StatusPill(
                                            label: order.status.toUpperCase(),
                                            color: Colors.blue,
                                          ),
                                          if (order.refundStatus.trim().isNotEmpty)
                                            _StatusPill(
                                              label: 'REFUND ${order.refundStatus.toUpperCase()}',
                                              color: order.refundStatus.toLowerCase() == 'refunded'
                                                  ? Colors.green
                                                  : order.refundStatus.toLowerCase() == 'rejected'
                                                      ? Colors.red
                                                      : Colors.orange,
                                            ),
                                          _StatusPill(
                                            label: riderName.toUpperCase(),
                                            color: riderName == 'Unassigned'
                                                ? Colors.grey
                                                : Colors.green,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                SizedBox(
                                  width: 220,
                                  child: DropdownButtonFormField<String>(
                                    initialValue: order.status,
                                    decoration: const InputDecoration(
                                      labelText: 'Update status',
                                    ),
                                    items: const [
                                      'Placed',
                                      'Confirmed',
                                      'Packed',
                                      'Ready for pickup',
                                      'Assigned',
                                      'Picked up',
                                      'Out for delivery',
                                      'Delivered',
                                      'Cancelled',
                                    ]
                                        .map(
                                          (value) => DropdownMenuItem(
                                            value: value,
                                            child: Text(value),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      if (value != null && value != order.status) {
                                        unawaited(_setOrderStatus(order, value));
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${order.items.length} item(s) - ${_formatCurrency(order.totalAmount)}',
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _assignRider(order),
                                  icon: const Icon(Icons.person_add_alt_1_outlined),
                                  label: Text(order.riderId == null ? 'Assign Rider' : 'Reassign Rider'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                    _Pager(
                      currentPage: safePage,
                      pageCount: pageCount,
                      onPrevious: safePage > 0
                          ? () => setState(() => _orderPage = safePage - 1)
                          : null,
                      onNext: safePage + 1 < pageCount
                          ? () => setState(() => _orderPage = safePage + 1)
                          : null,
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildVendors() {
    final filtered = _filteredStores;
    final pageCount = _pageCount(filtered);
    final safePage = _vendorPage >= pageCount ? pageCount - 1 : _vendorPage;
    final visible = _pageSlice(filtered, safePage);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FilterPanel(
          title: 'Vendor management',
          subtitle: 'Activate stores, feature them, view revenue, and manage payouts.',
          children: [
            SizedBox(
              width: 320,
              child: TextField(
                controller: _vendorSearchController,
                decoration: const InputDecoration(
                  hintText: 'Search store, owner, city, or address',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String>(
                initialValue: _vendorStatusFilter,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const ['All', 'Approved', 'Pending', 'Rejected']
                    .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                    .toList(),
                onChanged: (value) => setState(() {
                  _vendorStatusFilter = value ?? 'All';
                  _vendorPage = 0;
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Vendors',
          subtitle: '${filtered.length} result(s)',
          child: filtered.isEmpty
              ? const AbzioEmptyCard(
                  title: 'No vendors match this filter',
                  subtitle: 'Try another search term or approval status.',
                )
              : Column(
                  children: [
                    ...visible.map((store) {
                      final storeOrders =
                          _orders.where((order) => order.storeId == store.id).toList();
                      final revenue = storeOrders.fold<double>(
                        0,
                        (sum, order) => sum + order.totalAmount,
                      );
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AbzioTheme.grey200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    store.name,
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${store.city.isEmpty ? 'Unknown city' : store.city} - ${store.ownerId}',
                                    style: GoogleFonts.inter(color: AbzioTheme.textSecondary),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    store.address,
                                    style: GoogleFonts.inter(color: AbzioTheme.textSecondary),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _StatusPill(
                                        label: store.approvalStatus.toUpperCase(),
                                        color: store.isApproved ? Colors.green : Colors.orange,
                                      ),
                                      _StatusPill(
                                        label: store.isActive ? 'ACTIVE' : 'INACTIVE',
                                        color: store.isActive ? Colors.blue : Colors.grey,
                                      ),
                                      if (store.isFeatured)
                                        const _StatusPill(
                                          label: 'FEATURED',
                                          color: AbzioTheme.accentColor,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Revenue ${_formatCurrency(revenue)}',
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: () => _toggleStoreApproval(store),
                                  child: Text(store.isApproved ? 'Move to Pending' : 'Approve'),
                                ),
                                OutlinedButton(
                                  onPressed: () => _toggleStoreActive(store),
                                  child: Text(store.isActive ? 'Deactivate' : 'Activate'),
                                ),
                                OutlinedButton(
                                  onPressed: () => _toggleFeatured(store),
                                  child: Text(store.isFeatured ? 'Unfeature' : 'Feature'),
                                ),
                                OutlinedButton(
                                  onPressed: () => _adjustCommission(store),
                                  child: const Text('Commission'),
                                ),
                                ElevatedButton(
                                  onPressed: () => _processPayout(store),
                                  child: const Text('Mark payout paid'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                    _Pager(
                      currentPage: safePage,
                      pageCount: pageCount,
                      onPrevious: safePage > 0
                          ? () => setState(() => _vendorPage = safePage - 1)
                          : null,
                      onNext: safePage + 1 < pageCount
                          ? () => setState(() => _vendorPage = safePage + 1)
                          : null,
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildRiders() {
    final filtered = _filteredRiders;
    final pageCount = _pageCount(filtered);
    final safePage = _riderPage >= pageCount ? pageCount - 1 : _riderPage;
    final visible = _pageSlice(filtered, safePage);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FilterPanel(
          title: 'Rider management',
          subtitle: 'Approve riders, activate them, and monitor live delivery workload.',
          children: [
            SizedBox(
              width: 320,
              child: TextField(
                controller: _riderSearchController,
                decoration: const InputDecoration(
                  hintText: 'Search rider, phone, or city',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String>(
                initialValue: _riderStatusFilter,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const ['All', 'Approved', 'Pending', 'Active', 'Inactive']
                    .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                    .toList(),
                onChanged: (value) => setState(() {
                  _riderStatusFilter = value ?? 'All';
                  _riderPage = 0;
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Riders',
          subtitle: '${filtered.length} result(s)',
          child: filtered.isEmpty
              ? const AbzioEmptyCard(
                  title: 'No riders match this filter',
                  subtitle: 'Try another status or search term.',
                )
              : Column(
                  children: [
                    ...visible.map((rider) {
                      final activeDeliveries = _activeDeliveriesForRider(rider.id);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AbzioTheme.grey200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    rider.name,
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${rider.phone ?? rider.email} - ${rider.riderCity ?? rider.city ?? 'Unknown city'}',
                                    style: GoogleFonts.inter(color: AbzioTheme.textSecondary),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _StatusPill(
                                        label: rider.riderApprovalStatus.toUpperCase(),
                                        color: rider.riderApprovalStatus == 'approved'
                                            ? Colors.green
                                            : Colors.orange,
                                      ),
                                      _StatusPill(
                                        label: rider.isActive ? 'ACTIVE' : 'INACTIVE',
                                        color: rider.isActive ? Colors.blue : Colors.grey,
                                      ),
                                      _StatusPill(
                                        label: '$activeDeliveries LIVE',
                                        color: AbzioTheme.accentColor,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: () => _toggleRiderApproval(rider),
                                  child: Text(
                                    rider.riderApprovalStatus == 'approved'
                                        ? 'Move to Pending'
                                        : 'Approve',
                                  ),
                                ),
                                OutlinedButton(
                                  onPressed: () => _toggleUserActive(rider),
                                  child: Text(rider.isActive ? 'Deactivate' : 'Activate'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                    _Pager(
                      currentPage: safePage,
                      pageCount: pageCount,
                      onPrevious: safePage > 0
                          ? () => setState(() => _riderPage = safePage - 1)
                          : null,
                      onNext: safePage + 1 < pageCount
                          ? () => setState(() => _riderPage = safePage + 1)
                          : null,
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildUsers() {
    final filtered = _filteredUsers;
    final pageCount = _pageCount(filtered);
    final safePage = _userPage >= pageCount ? pageCount - 1 : _userPage;
    final visible = _pageSlice(filtered, safePage);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FilterPanel(
          title: 'User management',
          subtitle: 'Manage activation and role assignments across the marketplace.',
          children: [
            SizedBox(
              width: 320,
              child: TextField(
                controller: _userSearchController,
                decoration: const InputDecoration(
                  hintText: 'Search name, email, phone, or city',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String>(
                initialValue: _userRoleFilter,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const ['All', 'customer', 'user', 'vendor', 'rider', 'admin']
                    .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                    .toList(),
                onChanged: (value) => setState(() {
                  _userRoleFilter = value ?? 'All';
                  _userPage = 0;
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Users',
          subtitle: '${filtered.length} result(s)',
          child: filtered.isEmpty
              ? const AbzioEmptyCard(
                  title: 'No users match this filter',
                  subtitle: 'Try another role or search term.',
                )
              : Column(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Name')),
                          DataColumn(label: Text('Role')),
                          DataColumn(label: Text('Contact')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Store')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: visible.map((user) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(user.name.isEmpty ? 'Unnamed user' : user.name),
                                    Text(
                                      user.city ?? '-',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: AbzioTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(
                                DropdownButton<String>(
                                  value: user.role,
                                  underline: const SizedBox.shrink(),
                                  items: const [
                                    'customer',
                                    'user',
                                    'vendor',
                                    'rider',
                                    'admin',
                                  ]
                                      .map(
                                        (role) => DropdownMenuItem(
                                          value: role,
                                          child: Text(role),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (role) {
                                    if (role != null && role != user.role) {
                                      unawaited(_changeUserRole(user, role));
                                    }
                                  },
                                ),
                              ),
                              DataCell(Text(user.phone ?? user.email)),
                              DataCell(
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _StatusPill(
                                      label: user.isActive ? 'ACTIVE' : 'BLOCKED',
                                      color: user.isActive ? Colors.green : Colors.red,
                                    ),
                                    if (user.role == 'rider') ...[
                                      const SizedBox(height: 6),
                                      _StatusPill(
                                        label: user.riderApprovalStatus.toUpperCase(),
                                        color: user.riderApprovalStatus == 'approved'
                                            ? Colors.blue
                                            : Colors.orange,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              DataCell(Text(user.storeId ?? '-')),
                              DataCell(
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    TextButton(
                                      onPressed: () => _toggleUserActive(user),
                                      child: Text(user.isActive ? 'Disable' : 'Enable'),
                                    ),
                                    if (user.role == 'rider')
                                      TextButton(
                                        onPressed: () => _toggleRiderApproval(user),
                                        child: Text(
                                          user.riderApprovalStatus == 'approved'
                                              ? 'Move to pending'
                                              : 'Approve rider',
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Pager(
                      currentPage: safePage,
                      pageCount: pageCount,
                      onPrevious: safePage > 0
                          ? () => setState(() => _userPage = safePage - 1)
                          : null,
                      onNext: safePage + 1 < pageCount
                          ? () => setState(() => _userPage = safePage + 1)
                          : null,
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildProducts() {
    final filtered = _filteredProducts;
    final pageCount = _pageCount(filtered);
    final safePage = _productPage >= pageCount ? pageCount - 1 : _productPage;
    final visible = _pageSlice(filtered, safePage);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FilterPanel(
          title: 'Product management',
          subtitle: 'Search, filter, and control catalog visibility across stores.',
          children: [
            SizedBox(
              width: 320,
              child: TextField(
                controller: _productSearchController,
                decoration: const InputDecoration(
                  hintText: 'Search name, brand, category, or store',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String>(
                initialValue: _productStatusFilter,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const ['All', 'Active', 'Hidden']
                    .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                    .toList(),
                onChanged: (value) => setState(() {
                  _productStatusFilter = value ?? 'All';
                  _productPage = 0;
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Products',
          subtitle: '${filtered.length} result(s)',
          child: filtered.isEmpty
              ? const AbzioEmptyCard(
                  title: 'No products match this filter',
                  subtitle: 'Try another visibility filter or search term.',
                )
              : Column(
                  children: [
                    ...visible.map((product) {
                      final store = _storeForId(product.storeId);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 56,
                            height: 56,
                            child: product.images.isEmpty
                                ? const DecoratedBox(
                                    decoration: BoxDecoration(color: Color(0xFFF3F3F3)),
                                    child: Icon(Icons.image_outlined),
                                  )
                                : Image.network(product.images.first, fit: BoxFit.cover),
                          ),
                        ),
                        title: Text(
                          product.name,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${product.brand.isEmpty ? 'ABZORA' : product.brand} - ${product.category} - ${store?.name ?? product.storeId}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Wrap(
                          spacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              _formatCurrency(product.price),
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                            ),
                            OutlinedButton(
                              onPressed: () => _toggleProductVisibility(product),
                              child: Text(product.isActive ? 'Hide' : 'Activate'),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    _Pager(
                      currentPage: safePage,
                      pageCount: pageCount,
                      onPrevious: safePage > 0
                          ? () => setState(() => _productPage = safePage - 1)
                          : null,
                      onNext: safePage + 1 < pageCount
                          ? () => setState(() => _productPage = safePage + 1)
                          : null,
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildPayouts() {
    final payouts = _sortedPayouts;
    final pageCount = _pageCount(payouts);
    final safePage = _payoutPage >= pageCount ? pageCount - 1 : _payoutPage;
    final visible = _pageSlice(payouts, safePage);
    final totalPending = _stores.fold<double>(
      0,
      (sum, store) => sum + _pendingPayoutForStore(store.id),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilder<AdminFinanceSummary>(
          future: _actor == null ? Future.value(const AdminFinanceSummary(
            totalCommission: 0,
            totalRevenue: 0,
            payoutsDone: 0,
            vendorSettlementsDone: 0,
            riderSettlementsDone: 0,
            failedSettlements: 0,
            vendorPending: 0,
            riderPending: 0,
            pendingWithdrawalAmount: 0,
          )) : _db.getAdminFinance(actor: _actor!),
          builder: (context, financeSnapshot) {
            final finance = financeSnapshot.data;
            final vendorPending = finance?.vendorPending ?? totalPending;
            final riderPending = finance?.riderPending ?? 0;
            final totalCommission = finance?.totalCommission ?? 0;
            final payoutsDone = finance?.payoutsDone ?? _payouts.fold<double>(0, (sum, payout) => sum + payout.amount);
            final transactions = finance?.transactions ?? const <WalletTransaction>[];
            final withdrawalRequests = finance?.withdrawalRequests ?? const <WithdrawalRequestSummary>[];
            final fraudAlerts = finance?.fraudAlerts ?? const <FraudAlertSummary>[];
            final flaggedUsers = finance?.flaggedUsers ?? 0;
            final failedSettlements = finance?.failedSettlements ?? 0;
            final pendingWithdrawalAmount = finance?.pendingWithdrawalAmount ?? 0;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _MetricCard(title: 'Processed Payouts', value: '${_payouts.length}'),
                    _MetricCard(title: 'Vendor Pending', value: _formatCurrency(vendorPending)),
                    _MetricCard(title: 'Rider Pending', value: _formatCurrency(riderPending)),
                    _MetricCard(title: 'Pending Withdrawals', value: _formatCurrency(pendingWithdrawalAmount)),
                    _MetricCard(title: 'Commission Earned', value: _formatCurrency(totalCommission)),
                    _MetricCard(title: 'Settlements Done', value: _formatCurrency(payoutsDone)),
                    _MetricCard(title: 'Failed Settlements', value: failedSettlements.toStringAsFixed(0)),
                    _MetricCard(title: 'Open Fraud Alerts', value: '${fraudAlerts.length}'),
                    _MetricCard(title: 'Flagged Users', value: '$flaggedUsers'),
                  ],
                ),
                const SizedBox(height: 16),
                _Panel(
                  title: 'Finance actions',
                  subtitle: 'Run automated settlements and review withdrawal approvals.',
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _runScheduledSettlements('vendor'),
                        icon: const Icon(Icons.storefront_outlined),
                        label: const Text('Run vendor settlements'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _settleRiderPayouts,
                        icon: const Icon(Icons.delivery_dining_outlined),
                        label: const Text('Settle rider payouts'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _runScheduledSettlements('rider'),
                        icon: const Icon(Icons.schedule_outlined),
                        label: const Text('Retry rider cron run'),
                      ),
                      if (transactions.isNotEmpty)
                        Chip(
                          avatar: const Icon(Icons.receipt_long_outlined, size: 18),
                          label: Text('${transactions.length} recent transactions'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (withdrawalRequests.isNotEmpty)
                  _Panel(
                    title: 'Pending withdrawal approvals',
                    subtitle: 'Approve or reject vendor and rider cash-out requests.',
                    child: Column(
                      children: withdrawalRequests.map((request) {
                        final subject = request.walletType == 'vendor'
                            ? (request.storeId.isEmpty ? request.userId : request.storeId)
                            : request.riderId;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            request.walletType == 'vendor'
                                ? Icons.storefront_outlined
                                : Icons.delivery_dining_outlined,
                          ),
                          title: Text(
                            '${request.walletType.toUpperCase()} • ${_formatCurrency(request.amount)}',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${request.note.isEmpty ? 'Awaiting approval' : request.note}\n$subject',
                            style: GoogleFonts.inter(color: AbzioTheme.textSecondary),
                          ),
                          isThreeLine: true,
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: () => _rejectWithdrawal(request),
                                child: const Text('Reject'),
                              ),
                              FilledButton(
                                onPressed: () => _approveWithdrawal(request),
                                child: const Text('Approve'),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                if (withdrawalRequests.isNotEmpty) const SizedBox(height: 16),
                if (fraudAlerts.isNotEmpty)
                  _Panel(
                    title: 'Fraud alerts',
                    subtitle: 'Review suspicious payout, order, and account activity.',
                    child: Column(
                      children: fraudAlerts.take(12).map((alert) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            switch (alert.type) {
                              'withdrawal' => Icons.account_balance_wallet_outlined,
                              'refund' => Icons.undo_rounded,
                              'account' => Icons.security_outlined,
                              _ => Icons.shopping_bag_outlined,
                            },
                            color: switch (alert.severity.toLowerCase()) {
                              'critical' => Colors.red,
                              'high' => Colors.deepOrange,
                              'medium' => Colors.orange,
                              _ => Colors.blueGrey,
                            },
                          ),
                          title: Text(
                            '${alert.type.toUpperCase()} • RISK ${alert.riskScore}',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            alert.message.isEmpty
                                ? (alert.reasons.isEmpty ? 'Risk rule matched.' : alert.reasons.join(' '))
                                : alert.message,
                            style: GoogleFonts.inter(color: AbzioTheme.textSecondary),
                          ),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: () => _updateFraudAlert(alert, 'reviewing'),
                                child: const Text('Review'),
                              ),
                              FilledButton(
                                onPressed: () => _updateFraudAlert(alert, 'resolved'),
                                child: const Text('Resolve'),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                if (fraudAlerts.isNotEmpty) const SizedBox(height: 16),
                if (transactions.isNotEmpty)
                  _Panel(
                    title: 'Recent finance activity',
                    subtitle: 'Latest commission, order credit, and payout records.',
                    child: Column(
                      children: transactions.take(8).map((transaction) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.payments_outlined),
                          title: Text(
                            '${transaction.userType.toUpperCase()} • ${transaction.type}',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            transaction.note.isEmpty ? transaction.status : transaction.note,
                            style: GoogleFonts.inter(color: AbzioTheme.textSecondary),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _formatCurrency(transaction.amount.abs()),
                                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                transaction.createdAt.isEmpty
                                    ? transaction.status
                                    : _formatIsoMoment(transaction.createdAt),
                                style: GoogleFonts.inter(
                                  color: AbzioTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<RefundRequest>>(
          future: _actor == null ? Future.value(const <RefundRequest>[]) : _db.getRefundRequests(actor: _actor!),
          builder: (context, snapshot) {
            final refunds = snapshot.data ?? const <RefundRequest>[];
            final pendingRefunds = refunds.where((request) => request.status.toLowerCase() == 'pending').toList();
            return _Panel(
              title: 'Refund requests',
              subtitle: '${pendingRefunds.length} pending request(s)',
              child: pendingRefunds.isEmpty
                  ? const AbzioEmptyCard(
                      title: 'No pending refunds',
                      subtitle: 'Refund approvals will appear here when customers submit requests.',
                    )
                  : Column(
                      children: pendingRefunds.map((request) {
                        final order = _orders.cast<OrderModel?>().firstWhere(
                              (item) => item?.id == request.orderId,
                              orElse: () => null,
                            );
                        final customer = _userForId(request.userId);
                        final orderLabel = order == null
                            ? request.orderId
                            : (order.invoiceNumber.isEmpty ? order.id : order.invoiceNumber);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AbzioTheme.grey200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          orderLabel,
                                          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${customer?.name ?? request.userId} • ${_formatDate(DateTime.tryParse(request.createdAt) ?? DateTime.now())}',
                                          style: GoogleFonts.inter(color: AbzioTheme.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const _StatusPill(label: 'PENDING', color: Colors.orange),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                request.reason,
                                style: GoogleFonts.inter(color: AbzioTheme.textPrimary),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _StatusPill(
                                    label: 'RISK ${request.fraudScore}',
                                    color: request.fraudScore > 60
                                        ? Colors.red
                                        : request.fraudScore >= 30
                                            ? Colors.orange
                                            : Colors.green,
                                  ),
                                  _StatusPill(
                                    label: request.fraudDecision.toUpperCase(),
                                    color: request.fraudDecision.toLowerCase() == 'reject'
                                        ? Colors.red
                                        : request.fraudDecision.toLowerCase() == 'review'
                                            ? Colors.orange
                                            : Colors.green,
                                  ),
                                ],
                              ),
                              if (request.fraudReasons.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  request.fraudReasons.join(' '),
                                  style: GoogleFonts.inter(
                                    color: AbzioTheme.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  FilledButton.icon(
                                    onPressed: () => _approveRefund(request),
                                    icon: const Icon(Icons.check_circle_outline),
                                    label: const Text('Approve refund'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => _rejectRefund(request),
                                    icon: const Icon(Icons.close_rounded),
                                    label: const Text('Reject'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            );
          },
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Vendor payouts',
          subtitle: 'Track vendor earnings, commissions, and payout processing.',
          child: Column(
            children: [
              ..._stores.map((store) {
                final pending = _pendingPayoutForStore(store.id);
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AbzioTheme.grey200),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              store.name,
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Commission ${(store.commissionRate * 100).toStringAsFixed(0)}% - Pending ${_formatCurrency(pending)}',
                              style: GoogleFonts.inter(color: AbzioTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () => _adjustCommission(store),
                        child: const Text('Adjust commission'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: pending <= 0 ? null : () => _processPayout(store),
                        child: const Text('Mark payout paid'),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Payout history',
          subtitle: '${payouts.length} payout record(s)',
          child: payouts.isEmpty
              ? const AbzioEmptyCard(
                  title: 'No payouts processed yet',
                  subtitle: 'Processed vendor settlements will appear here.',
                )
              : Column(
                  children: [
                    ...visible.map((payout) {
                      final store = _storeForId(payout.storeId);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.payments_outlined),
                        title: Text(
                          store?.name ?? payout.storeId,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${payout.periodLabel} - ${payout.orderIds.length} order(s)',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatCurrency(payout.amount),
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              _formatDate(payout.createdAt),
                              style: GoogleFonts.inter(
                                color: AbzioTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    _Pager(
                      currentPage: safePage,
                      pageCount: pageCount,
                      onPrevious: safePage > 0
                          ? () => setState(() => _payoutPage = safePage - 1)
                          : null,
                      onNext: safePage + 1 < pageCount
                          ? () => setState(() => _payoutPage = safePage + 1)
                          : null,
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildSupport() {
    final chats = _filteredSupportChats;
    final selected = _selectedSupportChat;
    final unreadTotal = _supportUnreadCount();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FilterPanel(
          title: 'Support desk',
          subtitle:
              'Monitor support chats, reply quickly, and resolve tickets without leaving the workspace.',
          children: [
            SizedBox(
              width: 280,
              child: TextField(
                controller: _supportSearchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText:
                      'Search by name, phone, issue, order, or message',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            _SupportSegmentChip(
              label: 'Unread replies',
              selected: false,
              count: unreadTotal,
              onTap: () {},
            ),
            _SupportSegmentChip(
              label: 'Active',
              selected: false,
              count: _supportChatCount(status: 'open') +
                  _supportChatCount(status: 'waiting'),
              onTap: () {},
            ),
            _SupportSegmentChip(
              label: 'Resolved',
              selected: false,
              count: _supportChatCount(status: 'closed'),
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 1380) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 300,
                    child: _buildSupportSidebar(),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 360,
                    child: _buildSupportQueue(chats, selected),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSupportConversationWorkspace(selected),
                  ),
                ],
              );
            }
            if (constraints.maxWidth >= 980) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 360,
                    child: _buildSupportQueue(
                      chats,
                      selected,
                      includeSidebarFilters: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSupportConversationWorkspace(selected),
                  ),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSupportSidebar(compact: true),
                const SizedBox(height: 16),
                _buildSupportQueue(
                  chats,
                  selected,
                  includeSidebarFilters: true,
                ),
                const SizedBox(height: 16),
                _buildSupportConversationWorkspace(selected),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSupportSidebar({bool compact = false}) {
    final statusAllSelected = _supportStatusFilter == 'all';
    final waitingSelected = _supportStatusFilter == 'waiting';
    final openSelected = _supportStatusFilter == 'open';
    final closedSelected = _supportStatusFilter == 'closed';
    final allTypeSelected = _supportTypeFilter == 'all';

    return _Panel(
      title: 'Support filters',
      subtitle: 'Jump between queues and keep unread conversations visible.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SupportFilterItem(
            label: 'All chats',
            subtitle: 'Every support conversation',
            icon: Icons.inbox_rounded,
            count: _supportChatCount(),
            unreadCount: _supportUnreadCount(),
            selected: statusAllSelected && allTypeSelected,
            onTap: () => setState(() {
              _supportStatusFilter = 'all';
              _supportTypeFilter = 'all';
            }),
          ),
          const SizedBox(height: 10),
          _SupportFilterItem(
            label: 'Open',
            subtitle: 'Chats actively handled',
            icon: Icons.mark_chat_read_rounded,
            count: _supportChatCount(status: 'open'),
            unreadCount: _supportUnreadCount(status: 'open'),
            selected: openSelected,
            onTap: () => setState(() => _supportStatusFilter = 'open'),
          ),
          const SizedBox(height: 10),
          _SupportFilterItem(
            label: 'Waiting',
            subtitle: 'Customers awaiting a reply',
            icon: Icons.schedule_send_rounded,
            count: _supportChatCount(status: 'waiting'),
            unreadCount: _supportUnreadCount(status: 'waiting'),
            selected: waitingSelected,
            onTap: () => setState(() => _supportStatusFilter = 'waiting'),
          ),
          const SizedBox(height: 10),
          _SupportFilterItem(
            label: 'Resolved',
            subtitle: 'Closed conversations',
            icon: Icons.task_alt_rounded,
            count: _supportChatCount(status: 'closed'),
            unreadCount: _supportUnreadCount(status: 'closed'),
            selected: closedSelected,
            onTap: () => setState(() => _supportStatusFilter = 'closed'),
          ),
          const SizedBox(height: 16),
          Text(
            'Issue categories',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              color: AbzioTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SupportSegmentChip(
                label: 'All',
                selected: allTypeSelected,
                count: _supportChatCount(),
                onTap: () => setState(() => _supportTypeFilter = 'all'),
              ),
              _SupportSegmentChip(
                label: 'Order',
                selected: _supportTypeFilter == 'order',
                count: _supportChatCount(type: 'order'),
                onTap: () => setState(() => _supportTypeFilter = 'order'),
              ),
              _SupportSegmentChip(
                label: 'Payment',
                selected: _supportTypeFilter == 'payment',
                count: _supportChatCount(type: 'payment'),
                onTap: () => setState(() => _supportTypeFilter = 'payment'),
              ),
              _SupportSegmentChip(
                label: 'Custom',
                selected: _supportTypeFilter == 'custom',
                count: _supportChatCount(type: 'custom'),
                onTap: () => setState(() => _supportTypeFilter = 'custom'),
              ),
              _SupportSegmentChip(
                label: 'General',
                selected: _supportTypeFilter == 'general',
                count: _supportChatCount(type: 'general'),
                onTap: () => setState(() => _supportTypeFilter = 'general'),
              ),
            ],
          ),
          if (compact) ...[
            const SizedBox(height: 14),
            Text(
              'Tap a card to open the full conversation and ticket details.',
              style: GoogleFonts.inter(
                color: AbzioTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSupportQueue(
    List<SupportChat> chats,
    SupportChat? selected, {
    bool includeSidebarFilters = false,
  }) {
    return _Panel(
      title: 'Conversation queue',
      subtitle: '${chats.length} matching conversation(s)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (includeSidebarFilters) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SupportCompactFilterChip(
                  label: 'All',
                  selected: _supportStatusFilter == 'all',
                  onTap: () => setState(() => _supportStatusFilter = 'all'),
                ),
                _SupportCompactFilterChip(
                  label: 'Open',
                  selected: _supportStatusFilter == 'open',
                  onTap: () => setState(() => _supportStatusFilter = 'open'),
                ),
                _SupportCompactFilterChip(
                  label: 'Waiting',
                  selected: _supportStatusFilter == 'waiting',
                  onTap: () => setState(() => _supportStatusFilter = 'waiting'),
                ),
                _SupportCompactFilterChip(
                  label: 'Resolved',
                  selected: _supportStatusFilter == 'closed',
                  onTap: () => setState(() => _supportStatusFilter = 'closed'),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (chats.isEmpty)
            const AbzioEmptyCard(
              title: 'No conversations match',
              subtitle:
                  'Try another search or switch filters to view more support activity.',
            )
          else
            Column(
              children: chats
                  .map(
                    (chat) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SupportChatCard(
                        chat: chat,
                        isSelected: selected?.id == chat.id,
                        onTap: () => _selectSupportChat(chat),
                        timestampLabel: _formatIsoMoment(
                          chat.lastMessageAt.isEmpty
                              ? chat.updatedAt
                              : chat.lastMessageAt,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildSupportConversationWorkspace(SupportChat? selected) {
    if (selected == null) {
      return const _Panel(
        title: 'Active conversation',
        subtitle: 'Select a conversation to start responding',
        child: AbzioEmptyCard(
          title: 'No conversation selected',
          subtitle:
              'Choose a ticket from the queue to review messages, timeline, and ticket details.',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSupportHeaderCard(selected),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 7,
              child: _buildSupportMessagesPanel(selected),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 4,
              child: _buildSupportTicketDetailsPanel(selected),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSupportComposer(selected),
      ],
    );
  }

  Widget _buildSupportHeaderCard(SupportChat chat) {
    final statusColor = chat.status == 'waiting'
        ? const Color(0xFFD97706)
        : chat.status == 'closed'
            ? const Color(0xFF8A8A8A)
            : const Color(0xFF1F9D55);

    return _Panel(
      title: chat.userName.isEmpty ? chat.userId : chat.userName,
      subtitle:
          '${chat.userPhone.isEmpty ? 'No phone number' : chat.userPhone} • ${_supportTypeLabel(chat.type)}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusPill(
                  label: chat.status.toUpperCase(),
                  color: statusColor,
                ),
                _StatusPill(
                  label: _supportTypeLabel(chat.type),
                  color: AbzioTheme.accentColor,
                ),
                if ((chat.orderId ?? '').isNotEmpty)
                  _StatusPill(
                    label: 'Order ${chat.orderId}',
                    color: const Color(0xFF2563EB),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (chat.status == 'closed')
            OutlinedButton.icon(
              onPressed: () => _reopenSupportConversation(chat),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reopen ticket'),
            )
          else
            ElevatedButton.icon(
              onPressed: () => _closeSupportConversation(chat),
              icon: const Icon(Icons.task_alt_rounded),
              label: const Text('Mark resolved'),
            ),
        ],
      ),
    );
  }

  Widget _buildSupportMessagesPanel(SupportChat chat) {
    return _Panel(
      title: 'Conversation',
      subtitle: 'Realtime customer and admin messages',
      child: Container(
        height: 520,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFBFAF7),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AbzioTheme.grey200),
        ),
        child: StreamBuilder<List<SupportMessage>>(
          stream: _actor == null
              ? const Stream.empty()
              : _db.watchSupportMessages(chatId: chat.id, actor: _actor!),
          builder: (context, snapshot) {
            final messages = snapshot.data ?? const <SupportMessage>[];
            if (snapshot.connectionState == ConnectionState.waiting &&
                messages.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (messages.isEmpty) {
              return const Center(
                child: Text('No messages yet.'),
              );
            }
            return ListView.separated(
              itemCount: messages.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final message = messages[index];
                final isAdminMessage = message.senderRole == 'admin';
                return Align(
                  alignment: isAdminMessage
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 420),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isAdminMessage
                          ? AbzioTheme.accentColor.withValues(alpha: 0.18)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isAdminMessage
                            ? AbzioTheme.accentColor.withValues(alpha: 0.20)
                            : AbzioTheme.grey200,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.text.isEmpty
                              ? 'Attachment shared'
                              : message.text,
                          style: GoogleFonts.inter(height: 1.45),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatIsoMoment(message.timestamp),
                          style: GoogleFonts.inter(
                            color: AbzioTheme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildSupportTicketDetailsPanel(SupportChat chat) {
    final timeline = _supportTimelineFor(chat.id);
    return _Panel(
      title: 'Ticket details',
      subtitle: 'Context, ownership, and timeline',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SupportDetailRow(label: 'Ticket ID', value: chat.ticketId),
          _SupportDetailRow(label: 'Chat ID', value: chat.id),
          _SupportDetailRow(
            label: 'Issue',
            value: _supportTypeLabel(chat.type),
          ),
          _SupportDetailRow(
            label: 'Status',
            value: chat.status.toUpperCase(),
          ),
          _SupportDetailRow(
            label: 'Order',
            value: (chat.orderId ?? '').isEmpty ? 'Not linked' : chat.orderId!,
          ),
          _SupportDetailRow(
            label: 'Created',
            value: _formatIsoMoment(chat.createdAt),
          ),
          _SupportDetailRow(
            label: 'Updated',
            value: _formatIsoMoment(chat.updatedAt),
          ),
          _SupportDetailRow(
            label: 'Unread',
            value: '${chat.unreadCountAdmin} pending for admin',
          ),
          const SizedBox(height: 8),
          Text(
            'Action history',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (timeline.isEmpty)
            Text(
              'No activity history yet.',
              style: GoogleFonts.inter(color: AbzioTheme.textSecondary),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: timeline
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(top: 5),
                            decoration: const BoxDecoration(
                              color: AbzioTheme.accentColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.message,
                                  style: GoogleFonts.inter(
                                    color: AbzioTheme.textSecondary,
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDate(entry.timestamp),
                                  style: GoogleFonts.inter(
                                    color: AbzioTheme.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildSupportComposer(SupportChat chat) {
    return _Panel(
      title: 'Reply',
      subtitle: chat.status == 'closed'
          ? 'Reopen the ticket to send another response.'
          : 'Send a realtime reply to the customer.',
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _supportReplyController,
              enabled: chat.status != 'closed',
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Reply to customer',
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: chat.status == 'closed' ? null : _sendSupportReply,
            icon: const Icon(Icons.send_rounded),
            label: const Text('Send'),
          ),
        ],
      ),
    );
  }

  String _supportTypeLabel(String type) {
    switch (type) {
      case 'order':
        return 'Order issue';
      case 'payment':
        return 'Payment issue';
      case 'custom':
        return 'Custom clothing';
      default:
        return 'General support';
    }
  }
  Widget _buildAnalytics() {
    final analytics = _analytics;
    final topProducts = <String, int>{};
    for (final order in _orders) {
      for (final item in order.items) {
        final matches =
            _products.where((candidate) => candidate.id == item.productId).toList();
        final label = matches.isEmpty ? item.productName : matches.first.name;
        topProducts.update(label, (value) => value + item.quantity, ifAbsent: () => item.quantity);
      }
    }
    final sortedTopProducts = topProducts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final recentStats = _recentAiDailyStats;
    final todayRequests = _todayAiStat?.totalRequests ?? 0;
    final todayLogicRequests = _todayAiStat?.logicRequests ?? 0;
    final dailyCostAlertThreshold = _settings.aiDailyCostLimit * 0.8;
    final dailyCostLimit = _settings.aiDailyCostLimit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _MetricCard(
              title: 'AI Requests Today',
              value: '$todayRequests',
            ),
            _MetricCard(
              title: 'AI Cost Today',
              value: _formatAiCost(_todayAiCost),
            ),
            _MetricCard(
              title: 'Active AI Users',
              value: '$_todayActiveAiUsers',
            ),
            _MetricCard(
              title: 'Avg Cost / User',
              value: _formatAiCost(_averageAiCostPerUser),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'AI operations snapshot',
          subtitle: 'Monitor blended support routing, export usage data, and watch cost health in real time.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _StatusPill(
                    label: '${_logicHandledRate.toStringAsFixed(0)}% handled without AI',
                    color: const Color(0xFF1F9D55),
                  ),
                  _StatusPill(
                    label: '${(100 - _logicHandledRate).toStringAsFixed(0)}% advanced AI usage',
                    color: const Color(0xFFD4AF37),
                  ),
                  _StatusPill(
                    label: '$todayLogicRequests logic requests today',
                    color: const Color(0xFF2563EB),
                  ),
                  _StatusPill(
                    label: _settings.aiAssistantEnabled
                        ? 'AI enabled · limit ${_formatAiCost(dailyCostLimit)}'
                        : 'AI disabled',
                    color: _settings.aiAssistantEnabled
                        ? const Color(0xFF111111)
                        : const Color(0xFF8A8A8A),
                  ),
                ],
              ),
              if (_todayAiCost >= dailyCostAlertThreshold) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _todayAiCost >= dailyCostLimit
                        ? const Color(0xFFFDECEC)
                        : const Color(0xFFFFF4D8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _todayAiCost >= dailyCostLimit
                          ? const Color(0xFFE7B8B8)
                          : const Color(0xFFF0D48A),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _todayAiCost >= dailyCostLimit
                            ? Icons.block_rounded
                            : Icons.warning_amber_rounded,
                        color: _todayAiCost >= dailyCostLimit
                            ? const Color(0xFFB42318)
                            : const Color(0xFFD97706),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _todayAiCost >= dailyCostLimit
                              ? 'Daily AI spend has reached the hard limit of ${_formatAiCost(dailyCostLimit)}. Advanced AI requests are now blocked until the next day.'
                              : 'Daily AI spend is above 80% of the limit (${_formatAiCost(dailyCostAlertThreshold)}). Review expensive queries and heavy users below.',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: _aiUsageLogs.isEmpty ? null : _exportAiUsageCsv,
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Export CSV'),
                  ),
                  if (_topExpensiveQueries.isNotEmpty)
                    Text(
                      'Highest request cost: ${_formatAiCost(_topExpensiveQueries.first.cost)}',
                      style: GoogleFonts.inter(
                        color: AbzioTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Panel(
                title: 'AI Requests per Day',
                subtitle: 'Total support requests routed through the hybrid engine.',
                child: recentStats.isEmpty
                    ? const AbzioEmptyCard(
                        title: 'No AI activity yet',
                        subtitle: 'Request and routing trends will appear here once support traffic starts.',
                      )
                    : _MiniBarChart(
                        points: recentStats
                            .map(
                              (stat) => AnalyticsPoint(
                                label: stat.date.substring(5),
                                value: stat.totalRequests.toDouble(),
                              ),
                            )
                            .toList(),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _Panel(
                title: 'Cost per Day',
                subtitle: 'Estimated advanced-model spend from AI-routed support.',
                child: recentStats.isEmpty
                    ? const AbzioEmptyCard(
                        title: 'No cost data yet',
                        subtitle: 'Estimated AI cost will appear here when advanced AI requests run.',
                      )
                    : _MiniBarChart(
                        points: recentStats
                            .map(
                              (stat) => AnalyticsPoint(
                                label: stat.date.substring(5),
                                value: stat.totalCost,
                              ),
                            )
                            .toList(),
                        barColor: const Color(0xFF111111),
                        valueFormatter: _formatAiCostCompact,
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Panel(
                title: 'Top AI Users',
                subtitle: 'Users generating the highest volume of advanced AI requests.',
                child: _topAiUsers.isEmpty
                    ? const AbzioEmptyCard(
                        title: 'No AI users yet',
                        subtitle: 'Heavy-user monitoring will appear here once the assistant is active.',
                      )
                    : Column(
                        children: _topAiUsers.map((entry) {
                          final usage = entry.key;
                          final user = entry.value;
                          final avgCost = usage.aiMessages == 0
                              ? 0.0
                              : _aiUsageLogs
                                      .where((log) => log.userId == usage.userId)
                                      .fold<double>(0, (sum, log) => sum + log.cost) /
                                  usage.aiMessages;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              user?.name.isNotEmpty == true ? user!.name : usage.userId,
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              '${usage.aiMessages} AI messages · ${usage.totalMessages} total support messages',
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _formatAiCost(avgCost),
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  usage.dailyUsage > 12 ? 'Heavy user' : 'Normal load',
                                  style: GoogleFonts.inter(
                                    color: usage.dailyUsage > 12
                                        ? const Color(0xFFD97706)
                                        : AbzioTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _Panel(
                title: 'Intent Breakdown',
                subtitle: 'Which support intents are hitting the system most often.',
                child: _intentBreakdown.isEmpty
                    ? const AbzioEmptyCard(
                        title: 'No intent data yet',
                        subtitle: 'Intent distribution will appear here once support logs accumulate.',
                      )
                    : Column(
                        children: _intentBreakdown.take(6).map((entry) {
                          final percent = _aiUsageLogs.isEmpty
                              ? 0
                              : ((entry.value / _aiUsageLogs.length) * 100).round();
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              entry.key,
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                            ),
                            trailing: Text(
                              '$percent% · ${entry.value} requests',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                color: AbzioTheme.textSecondary,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Panel(
                title: 'Top Expensive Queries',
                subtitle: 'Most costly advanced AI prompts so ops can tighten routing and prompts.',
                child: _topExpensiveQueries.isEmpty
                    ? const AbzioEmptyCard(
                        title: 'No AI-heavy queries yet',
                        subtitle: 'The costliest prompts will appear here once advanced AI requests run.',
                      )
                    : Column(
                        children: _topExpensiveQueries.map((log) {
                          final user = _userForId(log.userId);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              log.message,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              '${user?.name ?? log.userId} · ${log.intentType} · ${log.tokensUsed} tokens',
                            ),
                            trailing: Text(
                              _formatAiCost(log.cost),
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _Panel(
                title: 'Optimization Insights',
                subtitle: 'Quick opportunities to reduce spend while keeping responses fast.',
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.auto_graph_rounded),
                      title: Text(
                        '${_logicHandledRate.toStringAsFixed(0)}% queries handled without AI',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text(
                        'Routing simple intents through backend logic is already cutting model usage significantly.',
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.groups_2_outlined),
                      title: Text(
                        '$_todayActiveAiUsers active AI users today',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        _todayActiveAiUsers == 0
                            ? 'No AI traffic yet today.'
                            : 'Average spend per active AI user is ${_formatAiCost(_averageAiCostPerUser)}.',
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.lightbulb_outline_rounded),
                      title: Text(
                        'Most common intent: ${_intentBreakdown.isEmpty ? 'N/A' : _intentBreakdown.first.key}',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text(
                        'Use this to prioritize canned flows, better fallback prompts, and cache expansion.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Panel(
                title: 'Marketplace Revenue Trend',
                subtitle: 'Weekly marketplace performance snapshot.',
                child: analytics == null
                    ? const AbzioEmptyCard(
                        title: 'No revenue data yet',
                        subtitle: 'Marketplace revenue analytics will appear here once orders start moving.',
                      )
                    : _MiniBarChart(
                        points: analytics.weeklySales,
                        barColor: AbzioTheme.accentColor,
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _Panel(
                title: 'Top Stores & Products',
                subtitle: 'Cross-check business growth with AI usage patterns.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (analytics == null || analytics.topStores.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 14),
                        child: Text('No store leaders yet.'),
                      )
                    else
                      ...analytics.topStores.take(3).map((store) {
                        final revenue = _orders
                            .where((order) => order.storeId == store.id)
                            .fold<double>(0, (sum, order) => sum + order.totalAmount);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            store.name,
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(store.city.isEmpty ? 'Unknown city' : store.city),
                          trailing: Text(
                            _formatCurrency(revenue),
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                          ),
                        );
                      }),
                    const Divider(height: 24),
                    if (sortedTopProducts.isEmpty)
                      const Text('No top products yet.')
                    else
                      ...sortedTopProducts.take(3).map((entry) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            entry.key,
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                          ),
                          trailing: Text(
                            '${entry.value} sold',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              color: AbzioTheme.textSecondary,
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Panel(
          title: 'Platform features',
          subtitle: 'Enable or pause key marketplace experiences.',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _FeatureSwitchCard(
                label: 'Custom clothing',
                value: _settings.customTailoringEnabled,
                onChanged: (value) => _toggleFeature('custom', value),
              ),
              _FeatureSwitchCard(
                label: 'Offers',
                value: _settings.offersEnabled,
                onChanged: (value) => _toggleFeature('offers', value),
              ),
              _FeatureSwitchCard(
                label: 'Reels',
                value: _settings.reelsEnabled,
                onChanged: (value) => _toggleFeature('reels', value),
              ),
              _FeatureSwitchCard(
                label: 'Checkout',
                value: _settings.checkoutEnabled,
                onChanged: (value) => _toggleFeature('checkout', value),
              ),
              _FeatureSwitchCard(
                label: 'Marketplace',
                value: _settings.marketplaceEnabled,
                onChanged: (value) => _toggleFeature('marketplace', value),
              ),
              _FeatureSwitchCard(
                label: 'Rider dispatch',
                value: _settings.riderDispatchEnabled,
                onChanged: (value) => _toggleFeature('dispatch', value),
              ),
              _FeatureSwitchCard(
                label: 'AI assistant',
                value: _settings.aiAssistantEnabled,
                onChanged: (value) => _toggleFeature('ai', value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'City availability',
          subtitle: 'Control where the marketplace is currently active.',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _settings.cities.entries.map((entry) {
              return FilterChip(
                label: Text(entry.key),
                selected: entry.value,
                onSelected: (value) => _toggleCity(entry.key, value),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'AI cost controls',
          subtitle: 'Control the hard daily AI budget and automatic 80% warning threshold.',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _aiCostThresholdController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Daily AI budget limit',
                    prefixText: '\$',
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _saveAiCostThreshold,
                icon: const Icon(Icons.savings_outlined),
                label: const Text('Save threshold'),
              ),
              Text(
                'Warning starts at ${_formatAiCost(_settings.aiDailyCostLimit * 0.8)} · hard cap ${_formatAiCost(_settings.aiDailyCostLimit)}',
                style: GoogleFonts.inter(
                  color: AbzioTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Open disputes',
          subtitle: 'Customer and vendor escalations requiring review.',
          child: _disputes.isEmpty
              ? const AbzioEmptyCard(
                  title: 'No disputes',
                  subtitle: 'Escalations will appear here when they are raised.',
                )
              : Column(
                  children: _disputes.take(8).map((dispute) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.report_problem_outlined),
                      title: Text(
                        dispute.reason,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${dispute.type} - ${dispute.status} - ${_formatCurrency(dispute.amount)}',
                      ),
                      trailing: Text(
                        _formatDate(dispute.createdAt),
                        style: GoogleFonts.inter(
                          color: AbzioTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

class _KycQueueItem {
  const _KycQueueItem({
    required this.id,
    required this.name,
    required this.role,
    required this.city,
    required this.status,
    required this.submittedAt,
    required this.phone,
    this.autoReviewStatus = 'pending_review',
    this.confidenceScore = 0,
    this.flags = const [],
    this.riskScore = 0,
    this.riskDecision = 'review',
    this.riskReasons = const [],
  });

  final String id;
  final String name;
  final String role;
  final String city;
  final String status;
  final String submittedAt;
  final String phone;
  final String autoReviewStatus;
  final double confidenceScore;
  final List<String> flags;
  final int riskScore;
  final String riskDecision;
  final List<String> riskReasons;
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 4),
            Text(subtitle, style: GoogleFonts.inter(color: AbzioTheme.textSecondary)),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(color: AbzioTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 24),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(subtitle, style: GoogleFonts.inter(color: AbzioTheme.textSecondary)),
            const SizedBox(height: 16),
            Wrap(spacing: 12, runSpacing: 12, children: children),
          ],
        ),
      ),
    );
  }
}

class _SupportFilterItem extends StatelessWidget {
  const _SupportFilterItem({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.count,
    required this.unreadCount,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final int count;
  final int unreadCount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AbzioTheme.accentColor.withValues(alpha: 0.10)
              : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? AbzioTheme.accentColor.withValues(alpha: 0.24)
                : AbzioTheme.grey200,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AbzioTheme.accentColor.withValues(alpha: 0.10),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AbzioTheme.accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AbzioTheme.accentColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        '$count',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          color: AbzioTheme.accentColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: AbzioTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: AbzioTheme.accentColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$unreadCount',
                  style: GoogleFonts.inter(
                    color: Colors.black,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SupportSegmentChip extends StatelessWidget {
  const _SupportSegmentChip({
    required this.label,
    required this.selected,
    required this.count,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AbzioTheme.accentColor.withValues(alpha: 0.16),
      labelStyle: GoogleFonts.inter(
        fontWeight: FontWeight.w700,
        color: selected ? Colors.black : AbzioTheme.textSecondary,
      ),
      side: BorderSide(
        color: selected
            ? AbzioTheme.accentColor.withValues(alpha: 0.32)
            : AbzioTheme.grey200,
      ),
      backgroundColor: Colors.white,
    );
  }
}

class _SupportCompactFilterChip extends StatelessWidget {
  const _SupportCompactFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AbzioTheme.accentColor.withValues(alpha: 0.16),
      labelStyle: GoogleFonts.inter(
        fontWeight: FontWeight.w700,
        color: selected ? Colors.black : AbzioTheme.textSecondary,
      ),
      side: BorderSide(
        color: selected
            ? AbzioTheme.accentColor.withValues(alpha: 0.32)
            : AbzioTheme.grey200,
      ),
      backgroundColor: Colors.white,
    );
  }
}

class _FeatureSwitchCard extends StatelessWidget {
  const _FeatureSwitchCard({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AbzioTheme.grey200),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            ),
            Switch(
              value: value,
              activeThumbColor: AbzioTheme.accentColor,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.currentPage,
    required this.pageCount,
    this.onPrevious,
    this.onNext,
  });

  final int currentPage;
  final int pageCount;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          'Page ${currentPage + 1} of $pageCount',
          style: GoogleFonts.inter(color: AbzioTheme.textSecondary),
        ),
        const SizedBox(width: 12),
        IconButton(onPressed: onPrevious, icon: const Icon(Icons.chevron_left_rounded)),
        IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right_rounded)),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SupportChatCard extends StatelessWidget {
  const _SupportChatCard({
    required this.chat,
    required this.isSelected,
    required this.onTap,
    required this.timestampLabel,
  });

  final SupportChat chat;
  final bool isSelected;
  final VoidCallback onTap;
  final String timestampLabel;

  @override
  Widget build(BuildContext context) {
    final statusColor = chat.status == 'waiting'
        ? const Color(0xFFD97706)
        : chat.status == 'closed'
            ? const Color(0xFF8A8A8A)
            : const Color(0xFF1F9D55);
    final icon = switch (chat.type) {
      'order' => Icons.receipt_long_rounded,
      'payment' => Icons.payments_outlined,
      'custom' => Icons.design_services_rounded,
      _ => Icons.support_agent_rounded,
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AbzioTheme.accentColor.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? AbzioTheme.accentColor.withValues(alpha: 0.22)
                : AbzioTheme.grey200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isSelected ? 0.06 : 0.03),
              blurRadius: isSelected ? 18 : 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4D8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AbzioTheme.accentColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.userName.isEmpty ? chat.userId : chat.userName,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (chat.unreadCountAdmin > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: AbzioTheme.accentColor,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${chat.unreadCountAdmin}',
                            style: GoogleFonts.inter(
                              color: Colors.black,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    chat.userPhone.isEmpty ? 'No phone number' : chat.userPhone,
                    style: GoogleFonts.inter(
                      color: AbzioTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _StatusPill(label: chat.status.toUpperCase(), color: statusColor),
                      _StatusPill(
                        label: chat.type.toUpperCase(),
                        color: AbzioTheme.accentColor,
                      ),
                      if ((chat.orderId ?? '').isNotEmpty)
                        _StatusPill(
                          label: chat.orderId!,
                          color: const Color(0xFF2563EB),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    chat.lastMessage.isEmpty ? 'Support ticket created' : chat.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AbzioTheme.textSecondary,
                      fontWeight: chat.unreadCountAdmin > 0 ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    timestampLabel,
                    style: GoogleFonts.inter(
                      color: AbzioTheme.textSecondary,
                      fontSize: 11,
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
}

class _SupportDetailRow extends StatelessWidget {
  const _SupportDetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 98,
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: AbzioTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchMetric extends StatelessWidget {
  const _SearchMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
          Text('$value', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _MiniBarChart extends StatelessWidget {
  const _MiniBarChart({
    required this.points,
    this.barColor = AbzioTheme.accentColor,
    this.valueFormatter,
  });

  final List<AnalyticsPoint> points;
  final Color barColor;
  final String Function(double value)? valueFormatter;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const AbzioEmptyCard(
        title: 'No chart data',
        subtitle: 'Sales analytics will appear here when transactions are available.',
      );
    }
    final maxValue = points.fold<double>(
      0,
      (max, point) => point.value > max ? point.value : max,
    );
    return SizedBox(
      height: 220,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: points.map((point) {
          final ratio = maxValue == 0 ? 0.1 : (point.value / maxValue).clamp(0.1, 1.0);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    valueFormatter?.call(point.value) ?? point.value.toStringAsFixed(0),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AbzioTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 140 * ratio,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    point.label,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AbzioTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}


