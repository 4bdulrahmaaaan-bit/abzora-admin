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
import '../../utils/app_error_text.dart';
import '../../utils/app_mode_routes.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/state_views.dart';
import 'admin_ar_moderation_section.dart';
import 'admin_banners_section.dart';
import 'admin_cms_section.dart';
import 'admin_categories_section.dart';

enum AdminWebSection {
  dashboard,
  operations,
  banners,
  cms,
  categories,
  kyc,
  support,
  orders,
  vendors,
  riders,
  users,
  products,
  arModeration,
  payouts,
  analytics,
  pricing,
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
  final _pricingOrderValueController = TextEditingController(text: '1200');
  final _pricingDistanceController = TextEditingController(text: '4');

  late AdminWebSection _tab;
  AdminAnalytics? _analytics;
  PlatformSettings _settings = const PlatformSettings();
  PricingConfigModel _pricingConfig = const PricingConfigModel();
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
  List<OpsAlertItem> _opsAlerts = [];
  List<OpsActionLogEntry> _opsLogs = [];
  List<OpsMetricSnapshot> _opsMetrics = [];
  OpsLiveSnapshot _opsLive = const OpsLiveSnapshot();
  Map<String, dynamic> _lastPricingSimulation = const {};
  Map<String, dynamic> _dispatchSlaOverview = const {};
  List<Map<String, dynamic>> _dispatchBatches = const [];
  Map<String, dynamic> _dispatchRebalance = const {};

  bool _loading = true;
  bool _runningSearch = false;
  bool _pinVerified = !kIsWeb;
  String? _loadError;
  final Set<String> _dataWarnings = <String>{};

  String _userRoleFilter = 'All';
  String _vendorStatusFilter = 'All';
  String _vendorCityFilter = 'All';
  String _vendorRevenueFilter = 'All';
  String _vendorRiskFilter = 'All';
  String _riderStatusFilter = 'All';
  String _riderCityFilter = 'All';
  String _riderVehicleFilter = 'All';
  String _riderRiskFilter = 'All';
  String _orderStatusFilter = 'All';
  String _orderZoneFilter = 'All';
  String _orderPriorityFilter = 'All';
  String _orderRiderFilter = 'All';
  String _orderDateRangeFilter = 'All';
  String _productStatusFilter = 'All';
  String _supportStatusFilter = 'all';
  String _supportTypeFilter = 'all';
  String _pricingUserType = 'new';
  String _pricingDemandLevel = 'normal';
  String _productWorkspaceMode = 'catalog';
  String? _selectedVariantProductId;

  int _vendorPage = 0;
  int _userPage = 0;
  int _riderPage = 0;
  int _orderPage = 0;
  int _productPage = 0;
  int _payoutPage = 0;
  String? _selectedSupportChatId;
  final Set<String> _selectedOrderIds = <String>{};
  OrderModel? _activeOrderDrawerOrder;
  Store? _activeVendorDrawerStore;
  AppUser? _activeRiderDrawerUser;
  final Set<String> _selectedOpsAlertIds = <String>{};
  final Set<String> _expandedOpsAlertIds = <String>{};
  final ScrollController _opsAuditScrollController = ScrollController();

  AppUser? get _actor => context.read<AuthProvider>().user;
  bool get _usesBackendCommerce => _db.usesBackendCommerce;

  bool _isVendorUser(AppUser user) => hasVendorOperationsAccess(user);

  bool _isRiderUser(AppUser user) => hasRiderOperationsAccess(user);

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
    _pricingOrderValueController.dispose();
    _pricingDistanceController.dispose();
    _opsAuditScrollController.dispose();
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
      _dataWarnings.clear();
    });
    try {
      final results = await Future.wait([
        _db.getAdminAnalytics(),
        _safePlatformSettings(actor),
        _safePricingConfig(actor),
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
        _safeOpsAlerts(actor),
        _safeOpsLogs(actor),
        _safeOpsMetrics(actor),
        _safeOpsLive(actor),
        _safeDispatchSla(actor),
        _safeDispatchBatches(actor),
        _safeDispatchRebalance(actor),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _analytics = results[0] as AdminAnalytics;
        _settings = results[1] as PlatformSettings;
        _pricingConfig = results[2] as PricingConfigModel;
        _aiCostThresholdController.text = _settings.aiDailyCostLimit
            .toStringAsFixed(2);
        _users = results[3] as List<AppUser>;
        _stores = results[4] as List<Store>;
        _products = results[5] as List<Product>;
        if (_selectedVariantProductId == null ||
            !_products.any((product) => product.id == _selectedVariantProductId)) {
          _selectedVariantProductId = _products.isNotEmpty ? _products.first.id : null;
        }
        _orders = results[6] as List<OrderModel>;
        _payouts = results[7] as List<PayoutModel>;
        _notifications = results[8] as List<AppNotification>;
        _vendorRequests = results[9] as List<VendorKycRequest>;
        _riderRequests = results[10] as List<RiderKycRequest>;
        _supportChats = results[11] as List<SupportChat>;
        _disputes = results[12] as List<DisputeRecord>;
        _activityLogs = results[13] as List<ActivityLogEntry>;
        _aiUsageLogs = results[14] as List<AiUsageLogEntry>;
        _aiDailyStats = results[15] as List<AiDailyStat>;
        _userAiUsageStats = results[16] as List<UserAiUsageStat>;
        _opsAlerts = results[17] as List<OpsAlertItem>;
        _opsLogs = results[18] as List<OpsActionLogEntry>;
        _opsMetrics = results[19] as List<OpsMetricSnapshot>;
        _opsLive = results[20] as OpsLiveSnapshot;
        _dispatchSlaOverview = results[21] as Map<String, dynamic>;
        _dispatchBatches = results[22] as List<Map<String, dynamic>>;
        _dispatchRebalance = results[23] as Map<String, dynamic>;
        _selectedSupportChatId ??= _supportChats.isEmpty
            ? null
            : _supportChats.first.id;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _loadError = AppErrorText.from(error);
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
    await _db.updateUser(
      user.copyWith(isActive: !user.isActive),
      actor: _actor,
    );
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

  Future<void> _toggleStoreActive(Store store) async {
    await _db.saveStore(
      store.copyWith(isActive: !store.isActive),
      actor: _actor,
    );
    await _load();
  }

  Future<void> _toggleFeatured(Store store) async {
    await _db.saveStore(
      store.copyWith(isFeatured: !store.isFeatured),
      actor: _actor,
    );
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
        (double.tryParse(controller.text.trim()) ??
            (store.commissionRate * 100)) /
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
    final settled = await _db.settleRiderPayouts(
      actor: actor,
      periodLabel: 'Admin rider settlement',
    );
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
    final result = await _db.runScheduledSettlements(
      walletType: walletType,
      actor: actor,
    );
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Withdrawal approved.')));
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
            decoration: const InputDecoration(hintText: 'Add a short reason'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Withdrawal rejected.')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppErrorText.from(error))));
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

  Future<PricingConfigModel> _safePricingConfig(AppUser actor) async {
    try {
      return await _db.getAdminPricingConfig(actor: actor);
    } catch (_) {
      return const PricingConfigModel();
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

  Future<List<OpsAlertItem>> _safeOpsAlerts(AppUser actor) async {
    try {
      return await _db.getOpsAlerts(actor: actor, limit: 60);
    } catch (_) {
      _dataWarnings.add('Live alert queue is temporarily unavailable.');
      return const <OpsAlertItem>[];
    }
  }

  Future<List<OpsActionLogEntry>> _safeOpsLogs(AppUser actor) async {
    try {
      return await _db.getOpsLogs(actor: actor, limit: 120);
    } catch (_) {
      _dataWarnings.add('Operations audit stream is temporarily unavailable.');
      return const <OpsActionLogEntry>[];
    }
  }

  Future<List<OpsMetricSnapshot>> _safeOpsMetrics(AppUser actor) async {
    try {
      return await _db.getOpsMetrics(actor: actor, type: 'hourly', limit: 24);
    } catch (_) {
      _dataWarnings.add('Live ops metrics are temporarily unavailable.');
      return const <OpsMetricSnapshot>[];
    }
  }

  Future<OpsLiveSnapshot> _safeOpsLive(AppUser actor) async {
    try {
      return await _db.getOpsLive(actor: actor);
    } catch (_) {
      _dataWarnings.add('Live dispatch snapshot is temporarily unavailable.');
      return const OpsLiveSnapshot();
    }
  }

  Future<Map<String, dynamic>> _safeDispatchSla(AppUser actor) async {
    try {
      return await _db.getDispatchSlaOverview(actor: actor);
    } catch (_) {
      _dataWarnings.add('Dispatch SLA overview is temporarily unavailable.');
      return const {};
    }
  }

  Future<List<Map<String, dynamic>>> _safeDispatchBatches(AppUser actor) async {
    try {
      return await _db.getDispatchBatches(actor: actor);
    } catch (_) {
      _dataWarnings.add('Dispatch batches are temporarily unavailable.');
      return const [];
    }
  }

  Future<Map<String, dynamic>> _safeDispatchRebalance(AppUser actor) async {
    try {
      return await _db.triggerDispatchRebalance(actor: actor);
    } catch (_) {
      return const {};
    }
  }

  Future<void> _updatePricingScope({
    required String endpoint,
    required Map<String, dynamic> body,
    String successMessage = 'Pricing updated.',
  }) async {
    final actor = _actor;
    if (actor == null) {
      return;
    }
    final updated = await _db.updateAdminPricingScope(
      endpoint: endpoint,
      body: body,
      actor: actor,
    );
    if (!mounted) {
      return;
    }
    setState(() => _pricingConfig = updated);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(successMessage)));
    await _load();
  }

  Future<void> _runPricingSimulation({
    required double orderValue,
    required double distanceKm,
    required String userType,
    required String demandLevel,
  }) async {
    final actor = _actor;
    if (actor == null) {
      return;
    }
    final result = await _db.simulateAdminPricing(
      actor: actor,
      body: {
        'orderValue': orderValue,
        'distance': distanceKm,
        'userType': userType,
        'demandLevel': demandLevel,
      },
    );
    if (!mounted) {
      return;
    }
    setState(() => _lastPricingSimulation = result);
  }

  Future<void> _runOpsAction({
    required Future<void> Function() action,
    required String successMessage,
  }) async {
    try {
      await action();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Action failed: $error')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Refund request rejected.')));
      await _load();
    } finally {
      controller.dispose();
    }
  }

  Future<void> _assignRider(OrderModel order) async {
    final riders =
        _users
            .where(
              (user) =>
                  _isRiderUser(user) &&
                  user.riderApprovalStatus == 'approved' &&
                  user.isActive,
            )
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
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
    if (shouldAssign != true ||
        selectedId == null ||
        selectedId == order.riderId) {
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
        basePrice: product.basePrice,
        dynamicPrice: product.dynamicPrice,
        originalPrice: product.originalPrice,
        demandScore: product.demandScore,
        viewCount: product.viewCount,
        cartCount: product.cartCount,
        purchaseCount: product.purchaseCount,
        images: product.images,
        sizes: product.sizes,
        stock: product.stock,
        category: product.category,
        subcategory: product.subcategory,
        isActive: !product.isActive,
        createdAt: product.createdAt,
        rating: product.rating,
        reviewCount: product.reviewCount,
        lastPriceUpdated: product.lastPriceUpdated,
        isCustomTailoring: product.isCustomTailoring,
        outfitType: product.outfitType,
        fabric: product.fabric,
        model3d: product.model3d,
        attributes: product.attributes,
        attributeTemplateKey: product.attributeTemplateKey,
        attributeTemplateVersion: product.attributeTemplateVersion,
        structuredAttributes: product.structuredAttributes,
        arAsset: product.arAsset,
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

  Product? get _selectedVariantProduct {
    if (_products.isEmpty) {
      return null;
    }
    if (_selectedVariantProductId == null) {
      return _products.first;
    }
    return _products.cast<Product?>().firstWhere(
          (product) => product?.id == _selectedVariantProductId,
          orElse: () => _products.first,
        );
  }

  Future<void> _setProductWorkspaceMode(String mode) async {
    setState(() => _productWorkspaceMode = mode);
  }

  Future<void> _bulkUpdateVariantStock(Product product) async {
    final stockMapController = TextEditingController(
      text: product.colorVariants.map((variant) => '${variant.name}: ${variant.stock}').join('\n'),
    );
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Bulk Update Stock - ${product.name}'),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: stockMapController,
            maxLines: 12,
            decoration: const InputDecoration(
              labelText: 'Variant stock map',
              helperText: 'Format: Black: 10\nBrown: 5',
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Apply')),
        ],
      ),
    );
    if (result != true) {
      stockMapController.dispose();
      return;
    }

    final stockByName = <String, int>{};
    for (final line in stockMapController.text.split(RegExp(r'[\r\n]+'))) {
      final value = line.trim();
      if (value.isEmpty || !value.contains(':')) {
        continue;
      }
      final parts = value.split(':');
      final name = parts.first.trim();
      final stock = int.tryParse(parts.sublist(1).join(':').trim()) ?? 0;
      if (name.isNotEmpty) {
        stockByName[name.toLowerCase()] = stock;
      }
    }

    final updatedVariants = product.colorVariants.map((variant) {
      final nextStock = stockByName[variant.name.toLowerCase()] ?? variant.stock;
      final nextSizeStocks = variant.sizeStocks.isEmpty && variant.sizes.isNotEmpty
          ? [
              for (final size in variant.sizes)
                ProductVariantSizeStock(
                  sizeName: size,
                  stockQuantity: (nextStock / variant.sizes.length).floor(),
                ),
            ]
          : variant.sizeStocks;
      return variant.copyWith(
        stock: nextStock,
        sizeStocks: nextSizeStocks,
      );
    }).toList();

    stockMapController.dispose();
    await _db.updateProduct(
      product.copyWith(colorVariants: updatedVariants),
      actor: _actor,
    );
    await _load();
  }

  Future<void> _bulkReplaceVariantImages(Product product) async {
    final variantNameController = TextEditingController();
    final imagesController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Bulk Replace Variant Images - ${product.name}'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: variantNameController,
                decoration: const InputDecoration(labelText: 'Color name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: imagesController,
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: 'Gallery image URLs',
                  helperText: 'One URL per line',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Apply')),
        ],
      ),
    );
    if (result != true) {
      variantNameController.dispose();
      imagesController.dispose();
      return;
    }

    final variantName = variantNameController.text.trim().toLowerCase();
    final images = imagesController.text
        .split(RegExp(r'[\r\n]+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    final updatedVariants = product.colorVariants.map((variant) {
      if (variant.name.toLowerCase() != variantName) {
        return variant;
      }
      return variant.copyWith(
        images: images,
        thumbnail: images.isNotEmpty ? images.first : variant.thumbnail,
        imageUrl: images.isNotEmpty ? images.first : variant.imageUrl,
      );
    }).toList();

    variantNameController.dispose();
    imagesController.dispose();
    await _db.updateProduct(
      product.copyWith(colorVariants: updatedVariants),
      actor: _actor,
    );
    await _load();
  }

  List<String> _parseCsvList(String raw) {
    return raw
        .split(RegExp(r'[,\n\r]+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
  }

  List<ProductVariantSizeStock> _parseVariantSizeStocks(String raw) {
    return raw
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) {
          final parts = line.split(':');
          final sizeName = parts.first.trim();
          final stock = parts.length > 1 ? int.tryParse(parts.sublist(1).join(':').trim()) ?? 0 : 0;
          return ProductVariantSizeStock(
            sizeName: sizeName,
            stockQuantity: stock,
          );
        })
        .where((item) => item.sizeName.isNotEmpty)
        .toList();
  }

  Future<ProductColorVariant?> _openVariantEditor({
    required Product product,
    ProductColorVariant? initial,
    bool duplicate = false,
  }) async {
    final nameController = TextEditingController(text: duplicate ? '' : initial?.colorName.isNotEmpty == true ? initial!.colorName : initial?.name ?? '');
    final hexController = TextEditingController(text: duplicate ? '#C6A769' : initial?.hex ?? '#C6A769');
    final skuController = TextEditingController(text: duplicate ? '' : initial?.sku ?? '');
    final barcodeController = TextEditingController(text: duplicate ? '' : initial?.barcode ?? '');
    final priceController = TextEditingController(text: duplicate ? '' : (initial?.price?.toStringAsFixed(0) ?? ''));
    final discountController = TextEditingController(text: duplicate ? '' : (initial?.discountPrice?.toStringAsFixed(0) ?? ''));
    final stockController = TextEditingController(text: duplicate ? '0' : initial?.stock.toString() ?? '0');
    final thumbnailController = TextEditingController(
      text: duplicate ? '' : (initial?.thumbnail.isNotEmpty == true ? initial!.thumbnail : initial?.imageUrl ?? ''),
    );
    final galleryController = TextEditingController(
      text: duplicate ? '' : (initial?.images.join('\n') ?? ''),
    );
    final sizesController = TextEditingController(
      text: duplicate ? '' : (initial?.sizes.join(', ') ?? ''),
    );
    final sizeStocksController = TextEditingController(
      text: duplicate ? '' : (initial?.sizeStocks.map((item) => '${item.sizeName}:${item.stockQuantity}').join('\n') ?? ''),
    );
    final etaController = TextEditingController(text: duplicate ? '' : (initial?.deliveryInfo['etaLabel']?.toString() ?? ''));
    bool sameDayEligible = initial?.deliveryInfo['sameDayEligible'] != false;
    bool freeReturns = initial?.deliveryInfo['freeReturns'] != false;
    bool cashOnDelivery = initial?.deliveryInfo['cashOnDelivery'] != false;
    bool active = (initial?.status ?? 'active') == 'active';

    final result = await showDialog<ProductColorVariant?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          scrollable: true,
          title: Text(initial == null ? 'Add Variant' : 'Edit Variant'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Color Name'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 110,
                      child: TextField(
                        controller: hexController,
                        decoration: const InputDecoration(labelText: 'Hex'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: skuController,
                        decoration: const InputDecoration(labelText: 'SKU'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: barcodeController,
                        decoration: const InputDecoration(labelText: 'Barcode'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setDialogState(() {}),
                        decoration: const InputDecoration(labelText: 'Price Override'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: discountController,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setDialogState(() {}),
                        decoration: const InputDecoration(labelText: 'Discount Price'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildLiveDiscountPreview(
                  priceController.text,
                  discountController.text,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: stockController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Variant Stock'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: thumbnailController,
                  decoration: const InputDecoration(labelText: 'Thumbnail URL'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: galleryController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Gallery Images',
                    helperText: 'One URL per line',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sizesController,
                  decoration: const InputDecoration(
                    labelText: 'Sizes',
                    helperText: 'Comma separated: S, M, L, XL',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sizeStocksController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Size Stock Map',
                    helperText: 'Format: S:10\\nM:8\\nL:4',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: etaController,
                  decoration: const InputDecoration(labelText: 'ETA Label'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('Active'),
                      selected: active,
                      onSelected: (value) => setDialogState(() => active = value),
                    ),
                    FilterChip(
                      label: const Text('Same Day'),
                      selected: sameDayEligible,
                      onSelected: (value) => setDialogState(() => sameDayEligible = value),
                    ),
                    FilterChip(
                      label: const Text('Free Returns'),
                      selected: freeReturns,
                      onSelected: (value) => setDialogState(() => freeReturns = value),
                    ),
                    FilterChip(
                      label: const Text('COD'),
                      selected: cashOnDelivery,
                      onSelected: (value) => setDialogState(() => cashOnDelivery = value),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  ProductColorVariant(
                    variantId: initial?.variantId ?? '',
                    productId: product.id,
                    name: name,
                    colorName: name,
                    hex: hexController.text.trim().isEmpty ? '#C6A769' : hexController.text.trim(),
                    imageUrl: thumbnailController.text.trim(),
                    sku: skuController.text.trim(),
                    barcode: barcodeController.text.trim(),
                    price: double.tryParse(priceController.text.trim()),
                    discountPrice: double.tryParse(discountController.text.trim()),
                    stock: int.tryParse(stockController.text.trim()) ?? 0,
                    status: active ? 'active' : 'inactive',
                    thumbnail: thumbnailController.text.trim(),
                    images: _parseCsvList(galleryController.text),
                    sizes: _parseCsvList(sizesController.text),
                    sizeStocks: _parseVariantSizeStocks(sizeStocksController.text),
                    deliveryInfo: {
                      'sameDayEligible': sameDayEligible,
                      'freeReturns': freeReturns,
                      'cashOnDelivery': cashOnDelivery,
                      'etaLabel': etaController.text.trim(),
                    },
                    createdAt: initial?.createdAt ?? DateTime.now().toIso8601String(),
                    updatedAt: DateTime.now().toIso8601String(),
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    hexController.dispose();
    skuController.dispose();
    barcodeController.dispose();
    priceController.dispose();
    discountController.dispose();
    stockController.dispose();
    thumbnailController.dispose();
    galleryController.dispose();
    sizesController.dispose();
    sizeStocksController.dispose();
    etaController.dispose();
    return result;
  }

  Widget _buildLiveDiscountPreview(String sellingPriceText, String originalPriceText) {
    final sellingPrice = double.tryParse(sellingPriceText.trim());
    final originalPrice = double.tryParse(originalPriceText.trim());
    final hasValidPrices =
        sellingPrice != null && sellingPrice > 0 && originalPrice != null && originalPrice > 0;
    final safeSellingPrice = sellingPrice ?? 0;
    final safeOriginalPrice = originalPrice ?? 0;
    final discountPercent = hasValidPrices && safeOriginalPrice > safeSellingPrice
        ? (((safeOriginalPrice - safeSellingPrice) / safeOriginalPrice) * 100).round()
        : 0;
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F7F1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7DDCA)),
      ),
      child: Row(
        children: [
          Text(
            'Live discount preview',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111111),
            ),
          ),
          const Spacer(),
          Text(
            hasValidPrices
                ? '${formatter.format(safeSellingPrice)}  ${formatter.format(safeOriginalPrice)}  $discountPercent% OFF'
                : 'Enter both prices to preview discount',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: hasValidPrices ? const Color(0xFF111111) : AbzioTheme.grey500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editVariant(Product product, int index) async {
    if (index < 0 || index >= product.colorVariants.length) {
      return;
    }
    final updatedVariant = await _openVariantEditor(
      product: product,
      initial: product.colorVariants[index],
    );
    if (updatedVariant == null) {
      return;
    }
    final updatedVariants = [...product.colorVariants];
    updatedVariants[index] = updatedVariant;
    await _db.updateProduct(product.copyWith(colorVariants: updatedVariants), actor: _actor);
    await _load();
  }

  Future<void> _reorderVariants(Product product, int oldIndex, int newIndex) async {
    final variants = [...product.colorVariants];
    final item = variants.removeAt(oldIndex);
    variants.insert(newIndex, item);
    await _db.updateProduct(product.copyWith(colorVariants: variants), actor: _actor);
    await _load();
  }

  Future<void> _sendSupportReply() async {
    final actor = _actor;
    final chat = _selectedSupportChat;
    final text = _supportReplyController.text.trim();
    if (actor == null || chat == null || text.isEmpty) {
      return;
    }
    await _db.sendSupportMessage(chatId: chat.id, text: text, actor: actor);
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
    final nextCities = Map<String, bool>.from(_settings.cities)
      ..[city] = enabled;
    final nextRegions = Map<String, bool>.from(
      _settings.regionVendorAvailability,
    )..[city] = enabled;
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

  Product _cloneProductWithArAsset(
    Product product,
    Map<String, dynamic> arAsset,
  ) {
    return Product(
      id: product.id,
      storeId: product.storeId,
      name: product.name,
      brand: product.brand,
      description: product.description,
      price: product.price,
      basePrice: product.basePrice,
      dynamicPrice: product.dynamicPrice,
      originalPrice: product.originalPrice,
      demandScore: product.demandScore,
      viewCount: product.viewCount,
      cartCount: product.cartCount,
      purchaseCount: product.purchaseCount,
      images: product.images,
      sizes: product.sizes,
      stock: product.stock,
      category: product.category,
      subcategory: product.subcategory,
      isActive: product.isActive,
      createdAt: product.createdAt,
      rating: product.rating,
      reviewCount: product.reviewCount,
      lastPriceUpdated: product.lastPriceUpdated,
      isCustomTailoring: product.isCustomTailoring,
      outfitType: product.outfitType,
      fabric: product.fabric,
      model3d: product.model3d,
      attributes: product.attributes,
      attributeTemplateKey: product.attributeTemplateKey,
      attributeTemplateVersion: product.attributeTemplateVersion,
      structuredAttributes: product.structuredAttributes,
      arAsset: arAsset,
      customizations: product.customizations,
      measurements: product.measurements,
      addons: product.addons,
      measurementProfileLabel: product.measurementProfileLabel,
      neededBy: product.neededBy,
      tailoringDeliveryMode: product.tailoringDeliveryMode,
      tailoringExtraCost: product.tailoringExtraCost,
    );
  }

  Future<void> _approveArAsset(Product product) async {
    final merged = Map<String, dynamic>.from(product.arAsset)
      ..['status'] = 'approved'
      ..['failureReason'] = ''
      ..['generatedAt'] = DateTime.now().toIso8601String();
    await _db.updateProduct(
      _cloneProductWithArAsset(product, merged),
      actor: _actor,
    );
    await _load();
  }

  Future<void> _rejectArAsset(Product product) async {
    final merged = Map<String, dynamic>.from(product.arAsset)
      ..['status'] = 'rejected'
      ..['failureReason'] = 'manual_rejection'
      ..['generatedAt'] = DateTime.now().toIso8601String();
    await _db.updateProduct(
      _cloneProductWithArAsset(product, merged),
      actor: _actor,
    );
    await _load();
  }

  Future<void> _regenerateArAsset(Product product) async {
    await _db.generateProductArAsset(product.id, actor: _actor);
    await _load();
  }

  Future<void> _saveArAlignment(
    Product product,
    Map<String, dynamic> editorPatch,
  ) async {
    final anchors = Map<String, dynamic>.from(
      product.arAsset['anchors'] as Map? ?? const {},
    );
    final left = Map<String, dynamic>.from(
      anchors['left_shoulder'] as Map? ?? const {'x': 0.33, 'y': 0.2},
    );
    final right = Map<String, dynamic>.from(
      anchors['right_shoulder'] as Map? ?? const {'x': 0.67, 'y': 0.2},
    );
    left['x'] = (editorPatch['leftShoulderX'] as num?)?.toDouble() ?? left['x'];
    right['x'] =
        (editorPatch['rightShoulderX'] as num?)?.toDouble() ?? right['x'];
    anchors['left_shoulder'] = left;
    anchors['right_shoulder'] = right;

    final merged = Map<String, dynamic>.from(product.arAsset)
      ..['status'] = 'pending'
      ..['anchors'] = anchors
      ..['editor'] = {
        'offsetX': (editorPatch['offsetX'] as num?)?.toDouble() ?? 0,
        'offsetY': (editorPatch['offsetY'] as num?)?.toDouble() ?? 0,
        'scale': (editorPatch['scale'] as num?)?.toDouble() ?? 1,
        'rotation': (editorPatch['rotation'] as num?)?.toDouble() ?? 0,
      };

    await _db.updateProduct(
      _cloneProductWithArAsset(product, merged),
      actor: _actor,
    );
    await _load();
  }

  Future<void> _bulkApproveArAssets(List<Product> products) async {
    for (final product in products) {
      final merged = Map<String, dynamic>.from(product.arAsset)
        ..['status'] = 'approved'
        ..['failureReason'] = ''
        ..['generatedAt'] = DateTime.now().toIso8601String();
      await _db.updateProduct(
        _cloneProductWithArAsset(product, merged),
        actor: _actor,
      );
    }
    await _load();
  }

  Future<void> _bulkRegenerateArAssets(List<Product> products) async {
    for (final product in products) {
      await _db.generateProductArAsset(product.id, actor: _actor);
    }
    await _load();
  }

  List<AppUser> get _filteredUsers {
    final query = _userSearchController.text.trim().toLowerCase();
    final filtered =
        _users.where((user) {
          final matchesRole =
              _userRoleFilter == 'All' || user.role == _userRoleFilter;
          final haystack =
              '${user.name} ${user.email} ${user.phone ?? ''} ${user.city ?? ''}'
                  .toLowerCase();
          final matchesQuery = query.isEmpty || haystack.contains(query);
          return matchesRole && matchesQuery;
        }).toList()..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
    return filtered;
  }

  List<Store> get _filteredStores {
    final query = _vendorSearchController.text.trim().toLowerCase();
    final filtered =
        _stores.where((store) {
          final matchesStatus =
              _vendorStatusFilter == 'All' ||
              (_vendorStatusFilter == 'Approved' && store.isApproved) ||
              (_vendorStatusFilter == 'Pending' &&
                  store.approvalStatus == 'pending') ||
              (_vendorStatusFilter == 'Rejected' &&
                  store.approvalStatus == 'rejected');
          final haystack =
              '${store.name} ${store.address} ${store.city} ${store.ownerId}'
                  .toLowerCase();
          final matchesQuery = query.isEmpty || haystack.contains(query);
          return matchesStatus && matchesQuery;
        }).toList()..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
    return filtered;
  }

  List<AppUser> get _filteredRiders {
    final query = _riderSearchController.text.trim().toLowerCase();
    final filtered =
        _users.where((user) {
          final isRider = _isRiderUser(user);
          if (!isRider) {
            return false;
          }
          final matchesStatus =
              _riderStatusFilter == 'All' ||
              (_riderStatusFilter == 'Approved' &&
                  user.riderApprovalStatus == 'approved') ||
              (_riderStatusFilter == 'Pending' &&
                  user.riderApprovalStatus == 'pending') ||
              (_riderStatusFilter == 'Active' && user.isActive) ||
              (_riderStatusFilter == 'Inactive' && !user.isActive);
          final haystack =
              '${user.name} ${user.phone ?? ''} ${user.city ?? ''} ${user.riderCity ?? ''}'
                  .toLowerCase();
          final matchesQuery = query.isEmpty || haystack.contains(query);
          return matchesStatus && matchesQuery;
        }).toList()..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
    return filtered;
  }

  List<OrderModel> get _filteredOrders {
    final query = _orderSearchController.text.trim().toLowerCase();
    final filtered = _orders.where((order) {
      final invoice = order.invoiceNumber.isEmpty
          ? order.id
          : order.invoiceNumber;
      final matchesStatus =
          _orderStatusFilter == 'All' || order.status == _orderStatusFilter;
      final haystack =
          '$invoice ${order.shippingAddress} ${order.storeId} ${order.userId}'
              .toLowerCase();
      final matchesQuery = query.isEmpty || haystack.contains(query);
      return matchesStatus && matchesQuery;
    }).toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return filtered;
  }

  List<Product> get _filteredProducts {
    final query = _productSearchController.text.trim().toLowerCase();
    final filtered = _products.where((product) {
      final matchesStatus =
          _productStatusFilter == 'All' ||
          (_productStatusFilter == 'Active' && product.isActive) ||
          (_productStatusFilter == 'Hidden' && !product.isActive);
      final haystack =
          '${product.name} ${product.brand} ${product.category} ${product.storeId}'
              .toLowerCase();
      final matchesQuery = query.isEmpty || haystack.contains(query);
      return matchesStatus && matchesQuery;
    }).toList()..sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
    return filtered;
  }

  List<PayoutModel> get _sortedPayouts {
    final payouts = _payouts.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return payouts;
  }

  List<SupportChat> get _filteredSupportChats {
    final query = _supportSearchController.text.trim().toLowerCase();
    final filtered =
        _supportChats.where((chat) {
          final matchesStatus =
              _supportStatusFilter == 'all' ||
              chat.status == _supportStatusFilter;
          final matchesType =
              _supportTypeFilter == 'all' || chat.type == _supportTypeFilter;
          final haystack =
              '${chat.userName} ${chat.userPhone} ${chat.type} ${chat.lastMessage} ${chat.id} ${chat.orderId ?? ''}'
                  .toLowerCase();
          final matchesQuery = query.isEmpty || haystack.contains(query);
          return matchesStatus && matchesType && matchesQuery;
        }).toList()..sort((a, b) {
          final statusWeight = _supportWeight(
            a.status,
          ).compareTo(_supportWeight(b.status));
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
            _isRiderUser(user) &&
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

  int _supportUnreadCount({String? status, String? type}) {
    return _supportChats
        .where((chat) {
          final matchesStatus = status == null || chat.status == status;
          final matchesType = type == null || chat.type == type;
          return matchesStatus && matchesType;
        })
        .fold<int>(0, (sum, chat) => sum + chat.unreadCountAdmin);
  }

  int _supportChatCount({String? status, String? type}) {
    return _supportChats.where((chat) {
      final matchesStatus = status == null || chat.status == status;
      final matchesType = type == null || chat.type == type;
      return matchesStatus && matchesType;
    }).length;
  }

  List<ActivityLogEntry> _supportTimelineFor(String chatId) {
    final entries =
        _activityLogs
            .where(
              (entry) =>
                  entry.targetType == 'support_chat' &&
                  entry.targetId == chatId,
            )
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
    return '₹${buffer.toString()}';
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
    if (escaped.contains(',') ||
        escaped.contains('"') ||
        escaped.contains('\n')) {
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
      return DateFormat('yyyy-MM-dd').format(parsed) == _todayKey &&
          usage.dailyUsage > 0;
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
    final items =
        _userAiUsageStats
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
              subtitle:
                  'This workspace is restricted to Abianzo platform administrators.',
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
                      subtitle:
                          'Preparing platform analytics, vendor approvals, and operational controls.',
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
                      child: Stack(
                        children: [
                          Scrollbar(
                            thumbVisibility: true,
                            child: ListView(
                              padding: const EdgeInsets.all(24),
                              children: [
                                if (_tab == AdminWebSection.dashboard ||
                                    _tab == AdminWebSection.operations ||
                                    _tab == AdminWebSection.orders ||
                                    _tab == AdminWebSection.vendors ||
                                    _tab == AdminWebSection.riders)
                                  const SizedBox(height: 64),
                                _buildHeader(context),
                                if (_dataWarnings.isNotEmpty) ...[
                                  const SizedBox(height: 14),
                                  _buildDataWarningsBanner(),
                                ],
                                const SizedBox(height: 20),
                                _buildTabContent(context),
                              ],
                            ),
                          ),
                          if (_tab == AdminWebSection.dashboard)
                            Positioned(
                              top: 0,
                              left: 24,
                              right: 24,
                              child: _buildCriticalAlertBar(
                                message: _dashboardCriticalMessage(),
                                severity: _dashboardCriticalSeverity(),
                              ),
                            ),
                          if (_tab == AdminWebSection.operations)
                            Positioned(
                              top: 0,
                              left: 24,
                              right: 24,
                              child: _buildOperationsStickyToolbar(),
                            ),
                          if (_tab == AdminWebSection.orders)
                            Positioned(
                              top: 0,
                              left: 24,
                              right: 24,
                              child: _buildOrdersStickyToolbar(),
                            ),
                          if (_tab == AdminWebSection.vendors)
                            Positioned(
                              top: 0,
                              left: 24,
                              right: 24,
                              child: _buildVendorsStickyToolbar(),
                            ),
                          if (_tab == AdminWebSection.riders)
                            Positioned(
                              top: 0,
                              left: 24,
                              right: 24,
                              child: _buildRidersStickyToolbar(),
                            ),
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
      (AdminWebSection.operations, Icons.emergency_outlined, 'Operations'),
      (AdminWebSection.banners, Icons.view_carousel_outlined, 'Banners'),
      (AdminWebSection.cms, Icons.edit_note_outlined, 'CMS'),
      (AdminWebSection.categories, Icons.category_outlined, 'Categories'),
      (AdminWebSection.kyc, Icons.verified_user_outlined, 'KYC Requests'),
      (AdminWebSection.support, Icons.support_agent_rounded, 'Support'),
      (AdminWebSection.orders, Icons.receipt_long_outlined, 'Orders'),
      (AdminWebSection.vendors, Icons.storefront_outlined, 'Vendors'),
      (AdminWebSection.riders, Icons.delivery_dining_outlined, 'Riders'),
      (AdminWebSection.users, Icons.people_alt_outlined, 'Users'),
      (AdminWebSection.products, Icons.inventory_2_outlined, 'Products'),
      (AdminWebSection.arModeration, Icons.view_in_ar_rounded, 'AR Moderation'),
      (AdminWebSection.analytics, Icons.insights_outlined, 'Analytics'),
      (AdminWebSection.pricing, Icons.tune_outlined, 'Pricing'),
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
                      'ABIANZO ADMIN',
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
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(right: 4),
                child: Column(
                  children: items.map((item) {
                    final selected = _tab == item.$1;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => setState(() => _tab = item.$1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? AbzioTheme.accentColor.withValues(alpha: 0.16)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selected
                                  ? AbzioTheme.accentColor.withValues(
                                      alpha: 0.3,
                                    )
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
                              Expanded(
                                child: Text(
                                  item.$3,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    color: selected
                                        ? AbzioTheme.textPrimary
                                        : AbzioTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
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
          width: MediaQuery.sizeOf(context).width < 900 ? double.infinity : 580,
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  label: 'Global admin search',
                  textField: true,
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
                              tooltip: 'Run search',
                              onPressed: _runGlobalSearch,
                              icon: const Icon(Icons.arrow_forward_rounded),
                            ),
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
      case AdminWebSection.operations:
        return _buildOperations();
      case AdminWebSection.banners:
        return _usesBackendCommerce
            ? const AdminBannersSection()
            : _buildBackendUnavailableState(
                title: 'Banner tools need backend mode',
                subtitle:
                    'Homepage banner management is available only when the admin panel is connected to the backend API.',
              );
      case AdminWebSection.cms:
        return _usesBackendCommerce
            ? const AdminCmsSection()
            : _buildBackendUnavailableState(
                title: 'CMS tools need backend mode',
                subtitle:
                    'Static pages, FAQs, announcements, and navigation editing are available only when the admin panel is connected to the backend API.',
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
      case AdminWebSection.arModeration:
        return _buildArModeration();
      case AdminWebSection.payouts:
        return _buildPayouts();
      case AdminWebSection.analytics:
        return _buildAnalytics();
      case AdminWebSection.pricing:
        return _buildPricingControlPanel();
      case AdminWebSection.settings:
        return _buildSettings();
    }
  }

  Widget _buildOperationsStickyToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AbzioTheme.grey200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.circle, color: Color(0xFF12B76A), size: 10),
          const SizedBox(width: 8),
          Text(
            'LIVE',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 12),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: () => _runOpsAction(
              action: () => _db.triggerOpsDetection(actor: _actor!),
              successMessage: 'Ops detection cycle triggered.',
            ),
            icon: const Icon(Icons.radar_rounded, size: 16),
            label: const Text('Run Detection'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Refresh'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _openOpsSimulationDialog,
            icon: const Icon(Icons.science_outlined, size: 16),
            label: const Text('Simulation'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => setState(() => _tab = AdminWebSection.operations),
            icon: const Icon(Icons.auto_awesome_outlined, size: 16),
            label: const Text('AI Assist'),
          ),
        ],
      ),
    );
  }

  Future<void> _openOpsSimulationDialog() async {
    final ordersController = TextEditingController(text: '300');
    final ridersController = TextEditingController(text: '60');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Run Ops Simulation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ordersController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Orders (N)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ridersController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Riders (M)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Run'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    final orders = int.tryParse(ordersController.text.trim()) ?? 300;
    final riders = int.tryParse(ridersController.text.trim()) ?? 60;
    await _runOpsAction(
      action: () async {
        final output = await _db.runOpsSimulation(
          actor: _actor!,
          orders: orders,
          riders: riders,
        );
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Simulation complete: delay ${output.delayPercent.toStringAsFixed(1)}%, dispatch ${output.dispatchSuccessPercent.toStringAsFixed(1)}%',
            ),
          ),
        );
      },
      successMessage: 'Simulation complete.',
    );
  }

  Widget _buildOrdersStickyToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AbzioTheme.grey200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 280,
            child: TextField(
              controller: _orderSearchController,
              decoration: const InputDecoration(
                hintText: 'Search order, customer, vendor, rider, zone',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _ordersFilterMenu('Status', _orderStatusFilter, const [
            'All',
            'Placed',
            'Assigned',
            'Processing',
            'Delivered',
            'Cancelled',
          ], (v) => setState(() => _orderStatusFilter = v)),
          const SizedBox(width: 8),
          _ordersFilterMenu('Zone', _orderZoneFilter, const [
            'All',
            'Central',
            'North',
            'South',
            'East',
            'West',
          ], (v) => setState(() => _orderZoneFilter = v)),
          const SizedBox(width: 8),
          _ordersFilterMenu('Priority', _orderPriorityFilter, const [
            'All',
            'High',
            'Medium',
            'Low',
          ], (v) => setState(() => _orderPriorityFilter = v)),
          const SizedBox(width: 8),
          _ordersFilterMenu('Rider', _orderRiderFilter, const [
            'All',
            'Assigned',
            'Unassigned',
          ], (v) => setState(() => _orderRiderFilter = v)),
          const SizedBox(width: 8),
          _ordersFilterMenu('Date', _orderDateRangeFilter, const [
            'All',
            'Today',
            'Last 7 days',
            'Last 30 days',
          ], (v) => setState(() => _orderDateRangeFilter = v)),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _ordersFilterMenu(
    String label,
    String value,
    List<String> items,
    ValueChanged<String> onChanged,
  ) {
    return SizedBox(
      width: 128,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(labelText: label, isDense: true),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }

  Widget _buildVendorsStickyToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AbzioTheme.grey200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 320,
            child: TextField(
              controller: _vendorSearchController,
              decoration: const InputDecoration(
                hintText: 'Search store, owner, city, or vendor ID',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _ordersFilterMenu('Status', _vendorStatusFilter, const [
            'All',
            'Approved',
            'Pending',
            'Suspended',
            'High Risk',
          ], (v) => setState(() => _vendorStatusFilter = v)),
          const SizedBox(width: 8),
          _ordersFilterMenu('City', _vendorCityFilter, const [
            'All',
            'Chennai',
            'Bengaluru',
            'Hyderabad',
            'Mumbai',
          ], (v) => setState(() => _vendorCityFilter = v)),
          const SizedBox(width: 8),
          _ordersFilterMenu('Revenue', _vendorRevenueFilter, const [
            'All',
            'High',
            'Mid',
            'Low',
          ], (v) => setState(() => _vendorRevenueFilter = v)),
          const SizedBox(width: 8),
          _ordersFilterMenu('Risk', _vendorRiskFilter, const [
            'All',
            'Healthy',
            'Warning',
            'Intervention',
          ], (v) => setState(() => _vendorRiskFilter = v)),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () => setState(() => _tab = AdminWebSection.kyc),
            icon: const Icon(Icons.verified_user_outlined, size: 16),
            label: const Text('KYC Queue'),
          ),
        ],
      ),
    );
  }

  Widget _buildRidersStickyToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AbzioTheme.grey200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 320,
            child: TextField(
              controller: _riderSearchController,
              decoration: const InputDecoration(
                hintText: 'Search rider, phone, city, or rider ID',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _ordersFilterMenu('Status', _riderStatusFilter, const [
            'All',
            'LIVE',
            'BUSY',
            'OFFLINE',
            'DELAYED',
            'HIGH RISK',
          ], (v) => setState(() => _riderStatusFilter = v)),
          const SizedBox(width: 8),
          _ordersFilterMenu('City', _riderCityFilter, const [
            'All',
            'Chennai',
            'Bengaluru',
            'Hyderabad',
            'Mumbai',
          ], (v) => setState(() => _riderCityFilter = v)),
          const SizedBox(width: 8),
          _ordersFilterMenu('Vehicle', _riderVehicleFilter, const [
            'All',
            'Bike',
            'Scooter',
            'EV',
          ], (v) => setState(() => _riderVehicleFilter = v)),
          const SizedBox(width: 8),
          _ordersFilterMenu('Risk', _riderRiskFilter, const [
            'All',
            'Healthy',
            'Warning',
            'Intervention',
          ], (v) => setState(() => _riderRiskFilter = v)),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildDataWarningsBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9C99A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Limited live visibility',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF7B4B00),
            ),
          ),
          const SizedBox(height: 6),
          ..._dataWarnings.map(
            (warning) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                '- $warning',
                style: GoogleFonts.inter(
                  color: const Color(0xFF7B4B00),
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackendUnavailableState({
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: AbzioEmptyCard(title: title, subtitle: subtitle),
      ),
    );
  }

  Widget _buildDashboard() {
    final analytics = _analytics;
    final vendorCount = _users.where(_isVendorUser).length;
    final recentOrders = _orders.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final searchQuery = _globalSearchController.text.trim().toLowerCase();
    final userSuggestions = _users
        .where(
          (u) =>
              u.name.toLowerCase().contains(searchQuery) ||
              u.email.toLowerCase().contains(searchQuery),
        )
        .take(2)
        .map((u) => 'User: ${u.name}')
        .toList();
    final vendorSuggestions = _stores
        .where((s) => s.name.toLowerCase().contains(searchQuery))
        .take(2)
        .map((s) => 'Vendor: ${s.name}')
        .toList();
    final orderSuggestions = _orders
        .where((o) => o.id.toLowerCase().contains(searchQuery))
        .take(2)
        .map((o) => 'Order: ${o.id}')
        .toList();
    final riderSuggestions = _users
        .where(
          (u) =>
              hasRiderOperationsAccess(u) &&
              u.name.toLowerCase().contains(searchQuery),
        )
        .take(2)
        .map((u) => 'Rider: ${u.name}')
        .toList();
    final suggestions = <String>[
      ...userSuggestions,
      ...vendorSuggestions,
      ...orderSuggestions,
      ...riderSuggestions,
    ];

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (searchQuery.isNotEmpty && suggestions.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AbzioTheme.grey200),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: suggestions
                      .map(
                        (item) => InkWell(
                          onTap: () {
                            _globalSearchController.text = item
                                .split(':')
                                .last
                                .trim();
                            _runGlobalSearch();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F6F2),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              item,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            if (searchQuery.isNotEmpty && suggestions.isNotEmpty)
              const SizedBox(height: 16),
            SizedBox(
              height: 136,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _MetricCard(
                    title: 'Total Orders',
                    value: analytics?.totalOrders.toString() ?? '0',
                  ),
                  _MetricCard(
                    title: 'Revenue Today',
                    value: _formatCurrency(_revenueToday),
                  ),
                  _MetricCard(title: 'Total Vendors', value: '$vendorCount'),
                  _MetricCard(
                    title: 'Active Riders',
                    value: '$_activeRiderCount',
                  ),
                  _MetricCard(title: 'Pending KYC', value: '$_pendingKycCount'),
                  _MetricCard(
                    title: 'Total Revenue',
                    value: analytics == null
                        ? '₹0'
                        : _formatCurrency(analytics.totalRevenue),
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
                    subtitle:
                        'Latest marketplace transactions with fulfillment visibility.',
                    child: recentOrders.isEmpty
                        ? const AbzioEmptyCard(
                            title: 'No active order updates',
                            subtitle: 'Platform running smoothly.',
                          )
                        : Column(
                            children: recentOrders.take(8).map((order) {
                              final invoice = order.invoiceNumber.isEmpty
                                  ? order.id
                                  : order.invoiceNumber;
                              final store = _storeForId(order.storeId);
                              final status = order.status.trim();
                              final eta = order.deliveryPromise.trim().isEmpty
                                  ? 'ETA recalculating'
                                  : order.deliveryPromise;
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  'Order ID: $invoice',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  'Vendor: ${store?.name ?? order.storeId} | Amount: ${_formatCurrency(order.totalAmount)} | ETA: $eta',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [_buildOrderStatusChip(status)],
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
                    title: 'AI Operational Insights',
                    subtitle:
                        'Suggested interventions based on live marketplace behavior.',
                    child:
                        (_searchResults.users.isEmpty &&
                            _searchResults.stores.isEmpty &&
                            _searchResults.orders.isEmpty)
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInsightTile(
                                'Increase riders in Zone B',
                                Icons.electric_bike_rounded,
                              ),
                              _buildInsightTile(
                                'Sneakers trending across premium category',
                                Icons.trending_up_rounded,
                              ),
                              _buildInsightTile(
                                'Vendor return anomaly detected',
                                Icons.warning_amber_rounded,
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: OutlinedButton(
                                  onPressed: () => setState(
                                    () => _tab = AdminWebSection.operations,
                                  ),
                                  child: const Text('Review'),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SearchMetric(
                                label: 'Users',
                                value: _searchResults.users.length,
                              ),
                              _SearchMetric(
                                label: 'Stores',
                                value: _searchResults.stores.length,
                              ),
                              _SearchMetric(
                                label: 'Orders',
                                value: _searchResults.orders.length,
                              ),
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
                    title: 'Live activity feed',
                    subtitle:
                        'Realtime operational actions across users, vendors, riders, and payouts.',
                    child: _notifications.isEmpty && _activityLogs.isEmpty
                        ? const AbzioEmptyCard(
                            title: 'No alerts right now',
                            subtitle: 'Platform running smoothly',
                          )
                        : Column(
                            children: [
                              ..._notifications.take(4).map((notification) {
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    _activityIconFor(notification.title),
                                    color: const Color(0xFF9C7222),
                                  ),
                                  title: Text(
                                    notification.title,
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                    ),
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
                              }),
                              ..._activityLogs.take(4).map((entry) {
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    _activityIconFor(entry.action),
                                    color: const Color(0xFF9C7222),
                                  ),
                                  title: Text(
                                    entry.action
                                        .replaceAll('_', ' ')
                                        .toUpperCase(),
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    entry.message,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Text(
                                    _formatDate(entry.timestamp),
                                    style: GoogleFonts.inter(
                                      color: AbzioTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _Panel(
                    title: 'Recent admin actions',
                    subtitle: 'Fast scan trail of operational interventions.',
                    child: _activityLogs.isEmpty
                        ? const AbzioEmptyCard(
                            title: 'No actions recorded yet',
                            subtitle:
                                'Admin activity will appear here once actions are triggered.',
                          )
                        : Column(
                            children: _activityLogs.take(8).map((entry) {
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.bolt_rounded),
                                title: Text(
                                  entry.message,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  '${entry.actorRole} - ${entry.targetType}',
                                  style: GoogleFonts.inter(
                                    color: AbzioTheme.textSecondary,
                                  ),
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
        ),
        if (_activeVendorDrawerStore != null)
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            child: _buildVendorDetailDrawer(_activeVendorDrawerStore!),
          ),
      ],
    );
  }

  Widget _buildCriticalAlertBar({
    required String message,
    required String severity,
  }) {
    final color = severity == 'CRITICAL'
        ? const Color(0xFFD92D20)
        : severity == 'WARNING'
        ? const Color(0xFFDC6803)
        : const Color(0xFF667085);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111111),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            severity,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: color,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _dashboardCriticalMessage() {
    final delayedCount = _orders.where((order) {
      final status = order.status.toLowerCase();
      return status.contains('delay') || status.contains('late');
    }).length;
    if (delayedCount > 0) {
      return '$delayedCount delayed deliveries need immediate attention';
    }
    if (_pendingKycCount > 0) {
      return 'Vendor or rider KYC pending for review';
    }
    return 'Platform running smoothly';
  }

  String _dashboardCriticalSeverity() {
    final delayedCount = _orders.where((order) {
      final status = order.status.toLowerCase();
      return status.contains('delay') || status.contains('late');
    }).length;
    if (delayedCount > 0) {
      return 'CRITICAL';
    }
    if (_pendingKycCount > 0) {
      return 'WARNING';
    }
    return 'NORMAL';
  }

  Widget _buildInsightTile(String text, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFAF6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF9C7222)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderStatusChip(String status) {
    final normalized = status.toLowerCase();
    Color color;
    String label;
    if (normalized.contains('deliver')) {
      color = const Color(0xFF067647);
      label = 'Delivered';
    } else if (normalized.contains('delay') || normalized.contains('late')) {
      color = const Color(0xFFD92D20);
      label = 'Delayed';
    } else if (normalized.contains('cancel')) {
      color = const Color(0xFFB42318);
      label = 'Cancelled';
    } else {
      color = const Color(0xFF175CD3);
      label = 'Processing';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  IconData _activityIconFor(String value) {
    final text = value.toLowerCase();
    if (text.contains('vendor') && text.contains('approve')) {
      return Icons.store_mall_directory_outlined;
    }
    if (text.contains('cancel') || text.contains('refund')) {
      return Icons.restart_alt_rounded;
    }
    if (text.contains('payout') || text.contains('payment')) {
      return Icons.payments_outlined;
    }
    if (text.contains('rider') || text.contains('dispatch')) {
      return Icons.delivery_dining_outlined;
    }
    return Icons.bolt_rounded;
  }

  Color _opsSeverityColor(String severity) {
    switch (severity.toUpperCase()) {
      case 'CRITICAL':
        return const Color(0xFFD92D20);
      case 'HIGH':
        return const Color(0xFFDC6803);
      case 'MEDIUM':
        return const Color(0xFF2563EB);
      default:
        return const Color(0xFF667085);
    }
  }

  Widget _buildOperations() {
    final alerts = _opsAlerts;
    final logs = _opsLogs;
    final metrics = _opsMetrics.toList()
      ..sort((a, b) => a.bucketStartAt.compareTo(b.bucketStartAt));
    final live = _opsLive;
    final criticalCount = live.alertCounts['CRITICAL'] ?? 0;
    final highCount = live.alertCounts['HIGH'] ?? 0;
    final mediumCount = live.alertCounts['MEDIUM'] ?? 0;
    final lowCount = live.alertCounts['LOW'] ?? 0;
    final delayedDispatches = live.dispatch
        .where(
          (task) => (task['status']?.toString().toLowerCase() ?? '').contains(
            'delay',
          ),
        )
        .length;
    final failedPayments = alerts
        .where((a) => a.type.toLowerCase().contains('payment'))
        .length;
    final metricPoints = metrics
        .take(12)
        .map(
          (entry) => AnalyticsPoint(
            label: DateFormat('HH:mm').format(entry.bucketStartAt),
            value: entry.delayPercent,
          ),
        )
        .toList();
    final retrySpikes = logs
        .where((entry) => entry.status.toLowerCase().contains('retry'))
        .length;
    final vendorFailures = alerts
        .where((entry) => entry.entityType.toLowerCase().contains('vendor'))
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _MetricCard(title: 'Critical Alerts', value: '$criticalCount'),
            _MetricCard(title: 'High Alerts', value: '$highCount'),
            _MetricCard(
              title: 'Live Orders',
              value: '${live.liveOrders.length}',
            ),
            _MetricCard(
              title: 'Delayed Dispatches',
              value: '$delayedDispatches',
            ),
            _MetricCard(title: 'Failed Payments', value: '$failedPayments'),
            _MetricCard(title: 'Active Riders', value: '${live.riders.length}'),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _Panel(
                title: 'Priority Alert Queue',
                subtitle:
                    'Critical incidents with run actions, reassignment, and payment recovery.',
                child: alerts.isEmpty
                    ? const AbzioEmptyCard(
                        title: 'No alerts right now',
                        subtitle: 'Dispatch queue operating normally.',
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: _selectedOpsAlertIds.isEmpty
                                    ? null
                                    : () async {
                                        for (final alertId
                                            in _selectedOpsAlertIds) {
                                          await _runOpsAction(
                                            action: () => _db.runOpsAlertAction(
                                              actor: _actor!,
                                              alertId: alertId,
                                            ),
                                            successMessage:
                                                'Bulk action executed.',
                                          );
                                        }
                                      },
                                child: const Text('Bulk Run Action'),
                              ),
                              OutlinedButton(
                                onPressed: _selectedOpsAlertIds.isEmpty
                                    ? null
                                    : () => setState(
                                        () => _selectedOpsAlertIds.clear(),
                                      ),
                                child: const Text('Clear Selection'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...alerts.take(12).map((alert) {
                            final isCritical =
                                alert.severity.toUpperCase() == 'CRITICAL';
                            final color = _opsSeverityColor(alert.severity);
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border(
                                  left: BorderSide(
                                    color: isCritical
                                        ? const Color(0xFFD92D20)
                                        : AbzioTheme.grey200,
                                    width: isCritical ? 4 : 1,
                                  ),
                                  top: BorderSide(color: AbzioTheme.grey200),
                                  right: BorderSide(color: AbzioTheme.grey200),
                                  bottom: BorderSide(color: AbzioTheme.grey200),
                                ),
                                boxShadow: isCritical
                                    ? [
                                        BoxShadow(
                                          color: const Color(
                                            0xFFD92D20,
                                          ).withValues(alpha: 0.12),
                                          blurRadius: 14,
                                          offset: const Offset(0, 6),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: _selectedOpsAlertIds.contains(
                                          alert.alertId,
                                        ),
                                        onChanged: (value) => setState(() {
                                          if (value == true) {
                                            _selectedOpsAlertIds.add(
                                              alert.alertId,
                                            );
                                          } else {
                                            _selectedOpsAlertIds.remove(
                                              alert.alertId,
                                            );
                                          }
                                        }),
                                      ),
                                      Expanded(
                                        child: Text(
                                          '${alert.type} | Order ${alert.orderId.isEmpty ? '-' : alert.orderId}',
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      _StatusPill(
                                        label:
                                            '${alert.severity} ${alert.score.toStringAsFixed(0)}',
                                        color: color,
                                      ),
                                      IconButton(
                                        onPressed: () => setState(() {
                                          if (_expandedOpsAlertIds.contains(
                                            alert.alertId,
                                          )) {
                                            _expandedOpsAlertIds.remove(
                                              alert.alertId,
                                            );
                                          } else {
                                            _expandedOpsAlertIds.add(
                                              alert.alertId,
                                            );
                                          }
                                        }),
                                        icon: Icon(
                                          _expandedOpsAlertIds.contains(
                                                alert.alertId,
                                              )
                                              ? Icons.expand_less
                                              : Icons.expand_more,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    alert.message,
                                    style: GoogleFonts.inter(
                                      color: AbzioTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Time ${DateFormat('dd MMM HH:mm').format(alert.createdAt)} | Assigned ${alert.payload['assignedOperator'] ?? 'Ops Desk'} | Retry ${alert.retryCount}/${alert.maxRetries}',
                                    style: GoogleFonts.inter(
                                      color: AbzioTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (_expandedOpsAlertIds.contains(
                                    alert.alertId,
                                  )) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Entity ${alert.entityType}:${alert.entityId} | Action ${alert.action} | Status ${alert.actionStatus}',
                                      style: GoogleFonts.inter(
                                        color: AbzioTheme.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      FilledButton.icon(
                                        onPressed: () => _runOpsAction(
                                          action: () => _db.runOpsAlertAction(
                                            actor: _actor!,
                                            alertId: alert.alertId,
                                          ),
                                          successMessage:
                                              'Run action triggered.',
                                        ),
                                        icon: const Icon(
                                          Icons.play_arrow_rounded,
                                        ),
                                        label: const Text('Run Action'),
                                      ),
                                      if (alert.orderId.trim().isNotEmpty) ...[
                                        OutlinedButton(
                                          onPressed: () => _runOpsAction(
                                            action: () => _db.opsReassignOrder(
                                              actor: _actor!,
                                              orderId: alert.orderId,
                                            ),
                                            successMessage: 'Order reassigned.',
                                          ),
                                          child: const Text('Reassign'),
                                        ),
                                        OutlinedButton(
                                          onPressed: () => _runOpsAction(
                                            action: () => _db.opsRetryPayment(
                                              actor: _actor!,
                                              orderId: alert.orderId,
                                            ),
                                            successMessage:
                                                'Retry payment queued.',
                                          ),
                                          child: const Text('Retry Payment'),
                                        ),
                                        OutlinedButton(
                                          onPressed: () => _runOpsAction(
                                            action: () => _db.opsForceDispatch(
                                              actor: _actor!,
                                              orderId: alert.orderId,
                                            ),
                                            successMessage:
                                                'Force dispatch triggered.',
                                          ),
                                          child: const Text('Force Dispatch'),
                                        ),
                                        OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(
                                              0xFFB42318,
                                            ),
                                            side: const BorderSide(
                                              color: Color(0xFFB42318),
                                            ),
                                          ),
                                          onPressed: () => _runOpsAction(
                                            action: () => _db.opsCancelOrder(
                                              actor: _actor!,
                                              orderId: alert.orderId,
                                            ),
                                            successMessage: 'Order cancelled.',
                                          ),
                                          child: const Text('Cancel Order'),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  _Panel(
                    title: 'Live Dispatch Snapshot',
                    subtitle: 'Realtime incident health by severity band.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _StatusPill(
                              label: 'Critical $criticalCount',
                              color: _opsSeverityColor('CRITICAL'),
                            ),
                            _StatusPill(
                              label: 'High $highCount',
                              color: _opsSeverityColor('HIGH'),
                            ),
                            _StatusPill(
                              label: 'Medium $mediumCount',
                              color: _opsSeverityColor('MEDIUM'),
                            ),
                            _StatusPill(
                              label: 'Low $lowCount',
                              color: _opsSeverityColor('LOW'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (live.dispatch.isEmpty)
                          const Text(
                            'Dispatch queue operating normally.',
                            style: TextStyle(color: AbzioTheme.grey600),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Panel(
                    title: 'Delay Trend Analytics',
                    subtitle:
                        'Hourly delay percent, retry spikes, and vendor response failures.',
                    child: metricPoints.isEmpty
                        ? const AbzioEmptyCard(
                            title: 'No delay trend yet',
                            subtitle: 'Platform running smoothly',
                          )
                        : Column(
                            children: [
                              _MiniBarChart(
                                points: metricPoints,
                                barColor: const Color(0xFFDC6803),
                                valueFormatter: (v) =>
                                    '${v.toStringAsFixed(0)}%',
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _StatusPill(
                                    label: 'Retry spikes $retrySpikes',
                                    color: const Color(0xFFB42318),
                                  ),
                                  _StatusPill(
                                    label: 'Vendor failures $vendorFailures',
                                    color: const Color(0xFFDC6803),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 16),
                  _Panel(
                    title: 'Ops Audit Log',
                    subtitle:
                        'Started, retried, failed, resolved, and escalated actions.',
                    child: logs.isEmpty
                        ? const AbzioEmptyCard(
                            title: 'No operation logs',
                            subtitle: 'Platform running smoothly',
                          )
                        : SizedBox(
                            height: 280,
                            child: ListView(
                              controller: _opsAuditScrollController,
                              children: logs.take(18).map((entry) {
                                final s = entry.status.toLowerCase();
                                final icon = s.contains('fail')
                                    ? Icons.error_outline
                                    : s.contains('retry')
                                    ? Icons.refresh_rounded
                                    : s.contains('resolve')
                                    ? Icons.check_circle_outline
                                    : s.contains('escalat')
                                    ? Icons.priority_high_rounded
                                    : Icons.play_arrow_rounded;
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(icon),
                                  title: Text(
                                    '${entry.action} | ${entry.status}',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${entry.entityType}:${entry.entityId} | attempt ${entry.attempt}',
                                  ),
                                  trailing: Text(
                                    DateFormat(
                                      'dd MMM HH:mm',
                                    ).format(entry.createdAt),
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
                  const SizedBox(height: 16),
                  _Panel(
                    title: 'AI Operational Insights',
                    subtitle:
                        'Intelligence recommendations for live operations.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInsightTile(
                          'Vendor response latency spike detected in Chennai.',
                          Icons.store_mall_directory_outlined,
                        ),
                        _buildInsightTile(
                          'Retry success probability low for payment queue.',
                          Icons.payments_outlined,
                        ),
                        _buildInsightTile(
                          'Rider shortage predicted in Zone B.',
                          Icons.delivery_dining_outlined,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton(
                              onPressed: () => _runOpsAction(
                                action: () =>
                                    _db.triggerOpsDetection(actor: _actor!),
                                successMessage: 'Auto resolve initiated.',
                              ),
                              child: const Text('Auto Resolve'),
                            ),
                            OutlinedButton(
                              onPressed: () => setState(
                                () => _tab = AdminWebSection.support,
                              ),
                              child: const Text('Escalate'),
                            ),
                            OutlinedButton(
                              onPressed: () => setState(
                                () => _tab = AdminWebSection.operations,
                              ),
                              child: const Text('Open Incident'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
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
      ..._riderRequests.map((request) {
        final verification = Map<String, dynamic>.from(
          (request.metadata['verification'] as Map?) ??
              const <String, dynamic>{},
        );
        final status = (verification['status'] ?? '').toString();
        final confidence =
            (verification['confidenceScore'] as num?)?.toDouble() ?? 0;
        final matchScore = (verification['matchScore'] as num?)?.toInt() ?? 0;
        final flags = List<String>.from(
          (verification['flags'] as List?) ?? const [],
        );
        return _KycQueueItem(
          id: request.id,
          name: request.name,
          role: 'Rider',
          city: request.city,
          status: request.status,
          submittedAt: request.createdAt,
          phone: request.phone,
          autoReviewStatus: status == 'auto_verified'
              ? 'auto_verified'
              : 'pending_review',
          confidenceScore: confidence,
          flags: flags,
          riskScore: matchScore,
          riskDecision: status == 'auto_verified' ? 'approve' : 'review',
          riskReasons: flags,
        );
      }),
    ]..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

    final pending = allRequests
        .where((item) => item.status == 'pending')
        .toList();
    final approved = allRequests
        .where((item) => item.status == 'approved')
        .length;
    final rejected = allRequests
        .where((item) => item.status == 'rejected')
        .length;
    final flagged = allRequests
        .where((item) => item.autoReviewStatus == 'fraud_flagged')
        .length;

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
                    onPressed: () =>
                        Navigator.of(context).pushNamed('/admin-kyc'),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Open full KYC review'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        setState(() => _tab = AdminWebSection.dashboard),
                    icon: const Icon(Icons.dashboard_outlined),
                    label: const Text('Back to dashboard'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              pending.isEmpty
                  ? const AbzioEmptyCard(
                      title: 'No pending requests',
                      subtitle:
                          'New partner applications will appear here automatically.',
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
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            '${item.role} - ${item.city.isEmpty ? 'Unknown city' : item.city} - ${item.phone}'
                            '${item.confidenceScore > 0 ? ' - ${item.confidenceScore.toStringAsFixed(0)}% OCR confidence' : ''}'
                            '${item.riskScore > 0 ? '\nRisk ${item.riskScore} (${item.riskDecision.toUpperCase()})' : ''}'
                            '${item.flags.isNotEmpty
                                ? '\n${item.flags.take(2).join(' • ')}'
                                : item.riskReasons.isNotEmpty
                                ? '\n${item.riskReasons.take(2).join(' • ')}'
                                : ''}',
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
    final base = _filteredOrders;
    final filtered = base.where((order) {
      if (_orderStatusFilter != 'All' &&
          order.status.toLowerCase() != _orderStatusFilter.toLowerCase()) {
        return false;
      }
      if (_orderRiderFilter == 'Assigned' &&
          (order.riderId == null || order.riderId!.isEmpty)) {
        return false;
      }
      if (_orderRiderFilter == 'Unassigned' &&
          (order.riderId != null && order.riderId!.isNotEmpty)) {
        return false;
      }
      if (_orderDateRangeFilter == 'Today') {
        final now = DateTime.now();
        if (order.timestamp.year != now.year ||
            order.timestamp.month != now.month ||
            order.timestamp.day != now.day) {
          return false;
        }
      }
      if (_orderDateRangeFilter == 'Last 7 days' &&
          DateTime.now().difference(order.timestamp).inDays > 7) {
        return false;
      }
      if (_orderDateRangeFilter == 'Last 30 days' &&
          DateTime.now().difference(order.timestamp).inDays > 30) {
        return false;
      }
      if (_orderPriorityFilter != 'All') {
        final p = _orderPriorityFor(order);
        if (p != _orderPriorityFilter.toUpperCase()) return false;
      }
      if (_orderZoneFilter != 'All') {
        final zone = _orderZoneFor(order);
        if (zone != _orderZoneFilter) return false;
      }
      return true;
    }).toList();
    final pageCount = _pageCount(filtered);
    final safePage = _orderPage >= pageCount ? pageCount - 1 : _orderPage;
    final visible = _pageSlice(filtered, safePage);
    final liveOrders = filtered.where((o) => !_isOrderDone(o)).length;
    final delayed = filtered.where((o) => _isDelayedOrder(o)).length;
    final awaitingRider = filtered
        .where((o) => (o.riderId ?? '').trim().isEmpty)
        .length;
    final refundPending = filtered
        .where((o) => o.refundStatus.toLowerCase().contains('pending'))
        .length;
    final deliveredToday = filtered
        .where(
          (o) =>
              o.status.toLowerCase() == 'delivered' &&
              DateTime.now().difference(o.timestamp).inDays == 0,
        )
        .length;
    final failedDeliveries = filtered
        .where((o) => o.status.toLowerCase().contains('cancel'))
        .length;

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricCard(title: 'Live Orders', value: '$liveOrders'),
                _MetricCard(title: 'Delayed Orders', value: '$delayed'),
                _MetricCard(title: 'Awaiting Rider', value: '$awaitingRider'),
                _MetricCard(title: 'Refund Pending', value: '$refundPending'),
                _MetricCard(title: 'Delivered Today', value: '$deliveredToday'),
                _MetricCard(
                  title: 'Failed Deliveries',
                  value: '$failedDeliveries',
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Panel(
              title: 'Fulfillment Queue',
              subtitle: '${filtered.length} operational order(s)',
              child: filtered.isEmpty
                  ? const AbzioEmptyCard(
                      title: 'No order incidents right now',
                      subtitle: 'Platform running smoothly',
                    )
                  : Column(
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: _selectedOrderIds.isEmpty
                                  ? null
                                  : () => _bulkOrderStatus('Assigned'),
                              child: const Text('assign riders'),
                            ),
                            OutlinedButton(
                              onPressed: _selectedOrderIds.isEmpty
                                  ? null
                                  : () => _bulkOrderStatus('Out for delivery'),
                              child: const Text('dispatch'),
                            ),
                            OutlinedButton(
                              onPressed: _selectedOrderIds.isEmpty
                                  ? null
                                  : () => _bulkOrderStatus('Cancelled'),
                              child: const Text('cancel'),
                            ),
                            OutlinedButton(
                              onPressed: _selectedOrderIds.isEmpty
                                  ? null
                                  : () => _bulkOrderStatus('Delivered'),
                              child: const Text('mark delivered'),
                            ),
                            OutlinedButton(
                              onPressed: () =>
                                  setState(() => _selectedOrderIds.clear()),
                              child: const Text('clear selection'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...visible.map((order) {
                          final invoice = order.invoiceNumber.isEmpty
                              ? order.id
                              : order.invoiceNumber;
                          final store = _storeForId(order.storeId);
                          final customer = _userForId(order.userId);
                          final riderName =
                              order.assignedDeliveryPartner == 'Unassigned'
                              ? 'Unassigned'
                              : order.assignedDeliveryPartner;
                          final priority = _orderPriorityFor(order);
                          final healthScore = _orderHealthScore(order);
                          final borderColor = _orderBorderColor(order.status);
                          final isCritical =
                              priority == 'HIGH' || healthScore < 45;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: borderColor.withValues(alpha: 0.52),
                                width: isCritical ? 1.8 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      (isCritical
                                              ? const Color(0xFFD92D20)
                                              : Colors.black)
                                          .withValues(
                                            alpha: isCritical ? 0.12 : 0.04,
                                          ),
                                  blurRadius: isCritical ? 18 : 12,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Checkbox(
                                      value: _selectedOrderIds.contains(
                                        order.id,
                                      ),
                                      onChanged: (value) => setState(() {
                                        if (value == true) {
                                          _selectedOrderIds.add(order.id);
                                        } else {
                                          _selectedOrderIds.remove(order.id);
                                        }
                                      }),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Order $invoice',
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Customer: ${customer?.name ?? order.userId} | Vendor: ${store?.name ?? order.storeId}',
                                            style: GoogleFonts.inter(
                                              color: AbzioTheme.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Address: ${order.shippingAddress}',
                                            style: GoogleFonts.inter(
                                              color: AbzioTheme.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Items: ${order.items.length} | Value: ${_formatCurrency(order.totalAmount)} | ETA: ${order.deliveryPromise.isEmpty ? 'Recalculating' : order.deliveryPromise}',
                                            style: GoogleFonts.inter(
                                              color: AbzioTheme.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              _StatusPill(
                                                label: order.status
                                                    .toUpperCase(),
                                                color: Colors.blue,
                                              ),
                                              if (order.refundStatus
                                                  .trim()
                                                  .isNotEmpty)
                                                _StatusPill(
                                                  label:
                                                      'REFUND ${order.refundStatus.toUpperCase()}',
                                                  color:
                                                      order.refundStatus
                                                              .toLowerCase() ==
                                                          'refunded'
                                                      ? Colors.green
                                                      : order.refundStatus
                                                                .toLowerCase() ==
                                                            'rejected'
                                                      ? Colors.red
                                                      : Colors.orange,
                                                ),
                                              _StatusPill(
                                                label: riderName.toUpperCase(),
                                                color: riderName == 'Unassigned'
                                                    ? Colors.grey
                                                    : Colors.green,
                                              ),
                                              _StatusPill(
                                                label: 'PRIORITY $priority',
                                                color: priority == 'HIGH'
                                                    ? const Color(0xFFB42318)
                                                    : priority == 'MEDIUM'
                                                    ? const Color(0xFFDC6803)
                                                    : const Color(0xFF175CD3),
                                              ),
                                              _StatusPill(
                                                label:
                                                    'HEALTH ${healthScore.toStringAsFixed(0)}',
                                                color: healthScore >= 75
                                                    ? const Color(0xFF067647)
                                                    : healthScore >= 45
                                                    ? const Color(0xFFDC6803)
                                                    : const Color(0xFFB42318),
                                              ),
                                              ..._orderPriorityChips(order),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          _buildOrderTimeline(order.status),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    SizedBox(
                                      width: 220,
                                      child: Column(
                                        children: [
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton.icon(
                                              onPressed: () =>
                                                  _assignRider(order),
                                              icon: const Icon(
                                                Icons.person_add_alt_1_outlined,
                                              ),
                                              label: Text(
                                                order.riderId == null
                                                    ? 'Assign Rider'
                                                    : 'Reassign Rider',
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          PopupMenuButton<String>(
                                            onSelected: (value) =>
                                                _handleOrderQuickAction(
                                                  order,
                                                  value,
                                                ),
                                            itemBuilder: (_) => const [
                                              PopupMenuItem(
                                                value: 'details',
                                                child: Text('Open Details'),
                                              ),
                                              PopupMenuItem(
                                                value: 'refund',
                                                child: Text('Refund'),
                                              ),
                                              PopupMenuItem(
                                                value: 'escalate',
                                                child: Text('Escalate'),
                                              ),
                                              PopupMenuItem(
                                                value: 'vendor',
                                                child: Text('Contact Vendor'),
                                              ),
                                              PopupMenuItem(
                                                value: 'rider',
                                                child: Text('Contact Rider'),
                                              ),
                                              PopupMenuItem(
                                                value: 'timeline',
                                                child: Text('View Timeline'),
                                              ),
                                              PopupMenuItem(
                                                value: 'retry',
                                                child: Text('Retry Payment'),
                                              ),
                                              PopupMenuItem(
                                                value: 'zone',
                                                child: Text('Reassign Zone'),
                                              ),
                                              PopupMenuItem(
                                                value: 'cancel',
                                                child: Text('Cancel Order'),
                                              ),
                                            ],
                                            child: const Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 10,
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.more_horiz_rounded,
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text('Quick Actions'),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
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
            const SizedBox(height: 16),
            _Panel(
              title: 'AI Order Insights',
              subtitle:
                  'Risk intelligence for proactive fulfillment intervention.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInsightTile(
                    'High cancellation probability on zone-heavy evening orders.',
                    Icons.warning_amber_rounded,
                  ),
                  _buildInsightTile(
                    'Vendor delay risk detected in custom-stitch segment.',
                    Icons.store_mall_directory_outlined,
                  ),
                  _buildInsightTile(
                    'Traffic may impact ETA for west corridor routes.',
                    Icons.traffic_outlined,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_activeOrderDrawerOrder != null)
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            child: _buildOrderDetailDrawer(_activeOrderDrawerOrder!),
          ),
      ],
    );
  }

  Widget _buildVendors() {
    final base = _filteredStores;
    final filtered = base.where((store) {
      if (_vendorStatusFilter == 'Approved' && !store.isApproved) return false;
      if (_vendorStatusFilter == 'Pending' &&
          store.approvalStatus.toLowerCase() != 'pending') {
        return false;
      }
      if (_vendorStatusFilter == 'Suspended' && store.isActive) return false;
      if (_vendorStatusFilter == 'High Risk' && _vendorHealthScore(store) >= 45) {
        return false;
      }
      if (_vendorCityFilter != 'All' &&
          !store.city.toLowerCase().contains(_vendorCityFilter.toLowerCase())) {
        return false;
      }
      if (_vendorRiskFilter == 'Healthy' && _vendorHealthScore(store) < 75) {
        return false;
      }
      if (_vendorRiskFilter == 'Warning' &&
          (_vendorHealthScore(store) >= 75 || _vendorHealthScore(store) < 45)) {
        return false;
      }
      if (_vendorRiskFilter == 'Intervention' &&
          _vendorHealthScore(store) >= 45) {
        return false;
      }
      return true;
    }).toList();
    final pageCount = _pageCount(filtered);
    final safePage = _vendorPage >= pageCount ? pageCount - 1 : _vendorPage;
    final visible = _pageSlice(filtered, safePage);
    final totalVendors = filtered.length;
    final activeVendors = filtered.where((s) => s.isActive).length;
    final pendingKyc = filtered
        .where((s) => s.approvalStatus.toLowerCase() == 'pending')
        .length;
    final suspended = filtered.where((s) => !s.isActive).length;
    final totalRevenue = filtered.fold<double>(
      0,
      (sum, s) => sum + _storeRevenue(s),
    );
    final pendingPayouts = filtered.fold<double>(
      0,
      (sum, s) => sum + (s.walletBalance > 0 ? s.walletBalance : 0),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _MetricCard(title: 'Total Vendors', value: '$totalVendors'),
            _MetricCard(title: 'Active Vendors', value: '$activeVendors'),
            _MetricCard(title: 'Pending KYC', value: '$pendingKyc'),
            _MetricCard(title: 'Suspended Vendors', value: '$suspended'),
            _MetricCard(
              title: 'Total Revenue',
              value: _formatCurrency(totalRevenue),
            ),
            _MetricCard(
              title: 'Pending Payouts',
              value: _formatCurrency(pendingPayouts),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Seller Intelligence Workspace',
          subtitle: '${filtered.length} result(s)',
          child: filtered.isEmpty
              ? const AbzioEmptyCard(
                  title: 'No vendors match this filter',
                  subtitle: 'Try another search term or approval status.',
                )
              : Column(
                  children: [
                    ...visible.map((store) {
                      final storeOrders = _orders
                          .where((order) => order.storeId == store.id)
                          .toList();
                      final revenue = _storeRevenue(store);
                      final health = _vendorHealthScore(store);
                      final cancelRate = storeOrders.isEmpty
                          ? 0
                          : (storeOrders
                                        .where(
                                          (o) => o.status
                                              .toLowerCase()
                                              .contains('cancel'),
                                        )
                                        .length /
                                    storeOrders.length) *
                                100;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AbzioTheme.grey200),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (health < 45
                                          ? const Color(0xFFB42318)
                                          : Colors.black)
                                      .withValues(
                                        alpha: health < 45 ? 0.12 : 0.04,
                                      ),
                              blurRadius: 14,
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 24,
                              child: Text(
                                store.name.isEmpty
                                    ? 'V'
                                    : store.name[0].toUpperCase(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    store.name,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Owner ${store.ownerId} • ${store.city.isEmpty ? 'Unknown city' : store.city}',
                                    style: GoogleFonts.inter(
                                      color: AbzioTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _StatusPill(
                                        label: store.isApproved
                                            ? 'APPROVED'
                                            : 'PENDING',
                                        color: store.isApproved
                                            ? const Color(0xFF067647)
                                            : const Color(0xFFDC6803),
                                      ),
                                      if (store.isFeatured)
                                        const _StatusPill(
                                          label: 'FEATURED',
                                          color: Color(0xFFB57A12),
                                        ),
                                      _StatusPill(
                                        label: store.isActive
                                            ? 'ACTIVE'
                                            : 'SUSPENDED',
                                        color: store.isActive
                                            ? const Color(0xFF175CD3)
                                            : const Color(0xFFB42318),
                                      ),
                                      _StatusPill(
                                        label: health < 45
                                            ? 'HIGH RISK'
                                            : health < 75
                                            ? 'WARNING'
                                            : 'HEALTHY',
                                        color: health < 45
                                            ? const Color(0xFFB42318)
                                            : health < 75
                                            ? const Color(0xFFDC6803)
                                            : const Color(0xFF067647),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Revenue ${_formatCurrency(revenue)} • Orders ${storeOrders.length} • Commission ${(store.commissionRate * 100).toStringAsFixed(0)}% • Payout ${_formatCurrency(store.walletBalance)}',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Health Score: ${health.toStringAsFixed(0)} | Rating ${store.rating.toStringAsFixed(1)} | Cancellation ${cancelRate.toStringAsFixed(1)}%',
                                    style: GoogleFonts.inter(
                                      color: AbzioTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ElevatedButton(
                                  onPressed: () => setState(
                                    () => _activeVendorDrawerStore = store,
                                  ),
                                  child: const Text('View Vendor'),
                                ),
                                OutlinedButton(
                                  onPressed: () => _toggleFeatured(store),
                                  child: Text(
                                    store.isFeatured ? 'Unfeature' : 'Feature',
                                  ),
                                ),
                                OutlinedButton(
                                  onPressed: () => _adjustCommission(store),
                                  child: const Text('Commission'),
                                ),
                                OutlinedButton(
                                  onPressed: () => ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Assign manager to ${store.name}',
                                          ),
                                        ),
                                      ),
                                  child: const Text('Assign Manager'),
                                ),
                                OutlinedButton(
                                  onPressed: () => ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Analytics opened for ${store.name}',
                                          ),
                                        ),
                                      ),
                                  child: const Text('Open Analytics'),
                                ),
                                ElevatedButton(
                                  onPressed: () => _processPayout(store),
                                  child: const Text('Mark payout paid'),
                                ),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFB42318),
                                    side: const BorderSide(
                                      color: Color(0xFFB42318),
                                    ),
                                  ),
                                  onPressed: () => _toggleStoreActive(store),
                                  child: Text(
                                    store.isActive ? 'Suspend' : 'Activate',
                                  ),
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
    final base = _filteredRiders;
    final filtered = base.where((rider) {
      final status = _riderLiveStatus(rider);
      if (_riderStatusFilter != 'All' && status != _riderStatusFilter) {
        return false;
      }
      if (_riderCityFilter != 'All' &&
          !(rider.riderCity ?? rider.city ?? '').toLowerCase().contains(
            _riderCityFilter.toLowerCase(),
          )) {
        return false;
      }
      if (_riderRiskFilter == 'Healthy' && _riderPerformanceScore(rider) < 75) {
        return false;
      }
      if (_riderRiskFilter == 'Warning' &&
          (_riderPerformanceScore(rider) >= 75 ||
              _riderPerformanceScore(rider) < 45)) {
        return false;
      }
      if (_riderRiskFilter == 'Intervention' &&
          _riderPerformanceScore(rider) >= 45) {
        return false;
      }
      return true;
    }).toList();
    final pageCount = _pageCount(filtered);
    final safePage = _riderPage >= pageCount ? pageCount - 1 : _riderPage;
    final visible = _pageSlice(filtered, safePage);
    final onlineRiders = filtered
        .where((r) => _riderLiveStatus(r) == 'LIVE')
        .length;
    final activeDeliveries = filtered.fold<int>(
      0,
      (sum, r) => sum + _activeDeliveriesForRider(r.id),
    );
    final delayedDeliveries = _orders.where((o) => _isDelayedOrder(o)).length;
    final avgDeliveryTime =
        28 - ((onlineRiders / (filtered.isEmpty ? 1 : filtered.length)) * 6);
    final fleetUtilization = filtered.isEmpty
        ? 0
        : (activeDeliveries / filtered.length) * 100;
    final earningsToday = filtered.fold<double>(
      0,
      (sum, r) => sum + _riderWeeklyEarnings(r) / 7,
    );

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricCard(title: 'Online Riders', value: '$onlineRiders'),
                _MetricCard(
                  title: 'Active Deliveries',
                  value: '$activeDeliveries',
                ),
                _MetricCard(
                  title: 'Delayed Deliveries',
                  value: '$delayedDeliveries',
                ),
                _MetricCard(
                  title: 'Avg Delivery Time',
                  value: '${avgDeliveryTime.toStringAsFixed(0)} min',
                ),
                _MetricCard(
                  title: 'Fleet Utilization',
                  value: '${fleetUtilization.toStringAsFixed(0)}%',
                ),
                _MetricCard(
                  title: 'Earnings Today',
                  value: _formatCurrency(earningsToday),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Panel(
              title: 'Fleet Operations',
              subtitle: '${filtered.length} result(s)',
              child: filtered.isEmpty
                  ? const AbzioEmptyCard(
                      title: 'No riders match this filter',
                      subtitle: 'Try another status or search term.',
                    )
                  : Column(
                      children: [
                        ...visible.map((rider) {
                          final activeDeliveries = _activeDeliveriesForRider(
                            rider.id,
                          );
                          final performance = _riderPerformanceScore(rider);
                          final status = _riderLiveStatus(rider);
                          final statusColor = _riderStatusColor(status);
                          final rating = (4.1 + (performance / 200)).clamp(
                            3.5,
                            5.0,
                          );
                          final deliveries = 320 + (performance * 8).toInt();
                          final speed = (18 + ((100 - performance) / 8))
                              .clamp(14, 34)
                              .toDouble();
                          final weeklyEarnings = _riderWeeklyEarnings(rider);
                          final battery = _riderBatteryLevel(rider);
                          final lastActive = _riderLastActiveLabel(rider);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AbzioTheme.grey200),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      (status == 'HIGH RISK'
                                              ? const Color(0xFFB42318)
                                              : Colors.black)
                                          .withValues(
                                            alpha: status == 'HIGH RISK'
                                                ? 0.12
                                                : 0.04,
                                          ),
                                  blurRadius: 14,
                                  offset: const Offset(0, 7),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  child: Text(
                                    rider.name.isEmpty
                                        ? 'R'
                                        : rider.name[0].toUpperCase(),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        rider.name,
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${rider.phone ?? rider.email} • ${rider.riderCity ?? rider.city ?? 'Unknown city'} • ${rider.riderVehicleType ?? 'Bike'} • ${2 + (performance / 35).floor()}y exp',
                                        style: GoogleFonts.inter(
                                          color: AbzioTheme.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _StatusPill(
                                            label: status,
                                            color: statusColor,
                                          ),
                                          _StatusPill(
                                            label: rider.riderApprovalStatus
                                                .toUpperCase(),
                                            color:
                                                rider.riderApprovalStatus ==
                                                    'approved'
                                                ? Colors.green
                                                : Colors.orange,
                                          ),
                                          _StatusPill(
                                            label: '$activeDeliveries LIVE',
                                            color: AbzioTheme.accentColor,
                                          ),
                                          _StatusPill(
                                            label:
                                                'Performance ${performance.toStringAsFixed(0)}',
                                            color: performance >= 75
                                                ? const Color(0xFF067647)
                                                : performance >= 45
                                                ? const Color(0xFFDC6803)
                                                : const Color(0xFFB42318),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Rating ${rating.toStringAsFixed(1)} | Deliveries $deliveries | Avg speed ${speed.toStringAsFixed(0)} min | Weekly ${_formatCurrency(weeklyEarnings)}',
                                        style: GoogleFonts.inter(
                                          color: AbzioTheme.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Battery ${battery == null ? "--" : "$battery%"} | Signal ${_riderSignalQuality(rider)} | Last active $lastActive',
                                        style: GoogleFonts.inter(
                                          color: AbzioTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ElevatedButton(
                                      onPressed: () => setState(
                                        () => _activeRiderDrawerUser = rider,
                                      ),
                                      child: const Text('View Rider'),
                                    ),
                                    OutlinedButton(
                                      onPressed: () =>
                                          _assignOrderToRider(rider),
                                      child: const Text('Assign Order'),
                                    ),
                                    OutlinedButton(
                                      onPressed: () =>
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Contact sent to ${rider.name}',
                                              ),
                                            ),
                                          ),
                                      child: const Text('Contact'),
                                    ),
                                    OutlinedButton(
                                      onPressed: () =>
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Performance view opened for ${rider.name}',
                                              ),
                                            ),
                                          ),
                                      child: const Text('Performance'),
                                    ),
                                    OutlinedButton(
                                      onPressed: () =>
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Earnings view opened for ${rider.name}',
                                              ),
                                            ),
                                          ),
                                      child: const Text('Earnings'),
                                    ),
                                    OutlinedButton(
                                      onPressed: () =>
                                          _toggleRiderApproval(rider),
                                      child: Text(
                                        rider.riderApprovalStatus == 'approved'
                                            ? 'Move to Pending'
                                            : 'Approve',
                                      ),
                                    ),
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFFB42318,
                                        ),
                                        side: const BorderSide(
                                          color: Color(0xFFB42318),
                                        ),
                                      ),
                                      onPressed: () => _toggleUserActive(rider),
                                      child: Text(
                                        rider.isActive ? 'Suspend' : 'Activate',
                                      ),
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
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Panel(
                    title: 'Live Operations Panel',
                    subtitle:
                        'Dispatch intelligence and rider coverage alerts.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInsightTile(
                          'Live dispatch queue updated with ${_opsLive.dispatch.length} tasks across ${_dispatchBatches.length} active batches.',
                          Icons.route_outlined,
                        ),
                        _buildInsightTile(
                          'Delayed orders detected: $delayedDeliveries | SLA breach risk ${((_dispatchSlaOverview['slaBreachRisk'] ?? 0) as num).toStringAsFixed(0)}%',
                          Icons.warning_amber_rounded,
                        ),
                        _buildInsightTile(
                          'Hotspot demand zones: ${(_dispatchSlaOverview['hotspotZones'] as List?)?.join(', ') ?? 'N/A'}',
                          Icons.location_on_outlined,
                        ),
                        _buildInsightTile(
                          'Low rider coverage areas: ${(_dispatchSlaOverview['lowCoverageZones'] as List?)?.join(', ') ?? 'N/A'}',
                          Icons.person_search_outlined,
                        ),
                        _buildInsightTile(
                          'Auto-dispatch health: ${((_dispatchSlaOverview['dispatchHealthScore'] ?? 0) as num).toStringAsFixed(0)} | Rebalance ${(_dispatchRebalance['status'] ?? 'stable').toString()}',
                          Icons.hub_outlined,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _Panel(
                    title: 'Smart Alerts',
                    subtitle: 'AI-assisted rider intervention signals.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInsightTile(
                          'Rider inactive for 3 days: ${_opsAlerts.where((a) => (a.message.toLowerCase().contains('inactive') || a.type.toLowerCase().contains('inactive'))).length}',
                          Icons.person_off_outlined,
                        ),
                        _buildInsightTile(
                          'Multiple late deliveries detected: ${_opsAlerts.where((a) => a.message.toLowerCase().contains('delay')).length}',
                          Icons.schedule_rounded,
                        ),
                        _buildInsightTile(
                          'Battery critically low during delivery: ${_opsAlerts.where((a) => a.message.toLowerCase().contains('battery')).length}',
                          Icons.battery_alert_rounded,
                        ),
                        _buildInsightTile(
                          'Complaint spike/fraud risk alerts: ${_opsAlerts.where((a) => a.message.toLowerCase().contains('complaint') || a.message.toLowerCase().contains('fraud')).length}',
                          Icons.report_problem_outlined,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        if (_activeRiderDrawerUser != null)
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            child: _buildRiderDetailDrawer(_activeRiderDrawerUser!),
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
          subtitle:
              'Manage activation and role assignments across the marketplace.',
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
                items:
                    const [
                          'All',
                          'customer',
                          'user',
                          'vendor',
                          'rider',
                          'admin',
                        ]
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
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
                                    Text(
                                      user.name.isEmpty
                                          ? 'Unnamed user'
                                          : user.name,
                                    ),
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
                                  items:
                                      const [
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
                                      label: user.isActive
                                          ? 'ACTIVE'
                                          : 'BLOCKED',
                                      color: user.isActive
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                    if (_isRiderUser(user)) ...[
                                      const SizedBox(height: 6),
                                      _StatusPill(
                                        label: user.riderApprovalStatus
                                            .toUpperCase(),
                                        color:
                                            user.riderApprovalStatus ==
                                                'approved'
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
                                      child: Text(
                                        user.isActive ? 'Disable' : 'Enable',
                                      ),
                                    ),
                                    if (_isRiderUser(user))
                                      TextButton(
                                        onPressed: () =>
                                            _toggleRiderApproval(user),
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
        _Panel(
          title: 'Products workspace',
          subtitle: 'Switch between catalog management and color-variant inventory.',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ChoiceChip(
                label: const Text('Catalog'),
                selected: _productWorkspaceMode == 'catalog',
                onSelected: (_) => _setProductWorkspaceMode('catalog'),
              ),
              ChoiceChip(
                label: const Text('Variants & Inventory'),
                selected: _productWorkspaceMode == 'variants',
                onSelected: (_) => _setProductWorkspaceMode('variants'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_productWorkspaceMode == 'variants') ...[
          _buildVariantWorkspace(),
          const SizedBox(height: 16),
        ],
        _FilterPanel(
          title: 'Product management',
          subtitle:
              'Search, filter, and control catalog visibility across stores.',
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
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
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
                                    decoration: BoxDecoration(
                                      color: Color(0xFFF3F3F3),
                                    ),
                                    child: Icon(Icons.image_outlined),
                                  )
                                : Image.network(
                                    product.images.first,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                        title: Text(
                          product.name,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${product.brand.isEmpty ? 'Abianzo' : product.brand} - ${product.category} - ${store?.name ?? product.storeId}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Wrap(
                          spacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              _formatCurrency(product.price),
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            OutlinedButton(
                              onPressed: () =>
                                  _toggleProductVisibility(product),
                              child: Text(
                                product.isActive ? 'Hide' : 'Activate',
                              ),
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

  Widget _buildVariantWorkspace() {
    final product = _selectedVariantProduct;
    final variants = product?.colorVariants ?? const <ProductColorVariant>[];
    final totalStock = variants.fold<int>(0, (sum, variant) => sum + variant.stock);
    final outOfStockCount = variants.where((variant) => variant.stock <= 0).length;
    final ProductColorVariant? topVariant = variants.isEmpty
        ? null
        : variants.reduce((current, next) => next.stock > current.stock ? next : current);
    return _Panel(
      title: 'Variants & inventory',
      subtitle: product == null
          ? 'No products available'
          : '${variants.length} color variant(s) for ${product.name}',
      child: product == null
          ? const AbzioEmptyCard(
              title: 'No products available',
              subtitle: 'Create a product first to manage its color variants.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: product.id,
                        decoration: const InputDecoration(labelText: 'Select Product'),
                        items: _products
                            .map(
                              (item) => DropdownMenuItem<String>(
                                value: item.id,
                                child: Text(item.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() => _selectedVariantProductId = value);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _bulkUpdateVariantStock(product),
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: const Text('Bulk Stock'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _bulkReplaceVariantImages(product),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Bulk Images'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _Panel(
                  title: 'Color performance snapshot',
                  subtitle: 'Estimated signals based on current catalog and inventory mix.',
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _MetricCard(title: 'Total stock', value: totalStock.toString()),
                      _MetricCard(title: 'Out of stock colors', value: outOfStockCount.toString()),
                      _MetricCard(
                        title: 'Top color',
                        value: topVariant == null ? '-' : (topVariant.colorName.isNotEmpty ? topVariant.colorName : topVariant.name),
                      ),
                      _MetricCard(
                        title: 'Estimated sales by color',
                        value: product.purchaseCount <= 0 || totalStock <= 0
                            ? '0'
                            : '${product.purchaseCount}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _adminChip('${variants.length} variants'),
                    _adminChip('${variants.where((variant) => variant.stock <= 0).length} out of stock'),
                    _adminChip('${variants.fold<int>(0, (sum, variant) => sum + variant.images.length)} gallery images'),
                  ],
                ),
                const SizedBox(height: 12),
                if (variants.isEmpty)
                  const AbzioEmptyCard(
                    title: 'No color variants yet',
                    subtitle:
                        'Open the product editor to add colors, sizes, galleries, and SKU details.',
                  )
                else
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: variants.length,
                    onReorderItem: (oldIndex, newIndex) => _reorderVariants(product, oldIndex, newIndex),
                    itemBuilder: (context, index) {
                      final variant = variants[index];
                      final variantName = variant.colorName.isNotEmpty ? variant.colorName : variant.name;
                      final createdLabel = variant.createdAt == null
                          ? 'Saved'
                          : DateFormat('dd MMM yyyy').format(
                              DateTime.tryParse(variant.createdAt ?? '') ?? DateTime.now(),
                            );
                      return Container(
                        key: ValueKey('${variant.variantId.isEmpty ? variantName : variant.variantId}-$index'),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE9DECB)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ReorderableDragStartListener(
                              index: index,
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7F1E5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.drag_indicator_rounded, color: Color(0xFF8B7A5B)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 56,
                                height: 56,
                                child: variant.thumbnail.isNotEmpty
                                    ? AbzioNetworkImage(
                                        imageUrl: variant.thumbnail,
                                        fallbackLabel: variantName,
                                      )
                                    : Container(
                                        color: const Color(0xFFF3F3F3),
                                        child: const Icon(Icons.palette_outlined, size: 18),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    variantName,
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'SKU ${variant.sku.isEmpty ? 'Auto' : variant.sku} • Stock ${variant.stock} • ${variant.status.toUpperCase()}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AbzioTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _adminChip('${variant.images.length + (variant.thumbnail.isNotEmpty ? 1 : 0)} images'),
                                      _adminChip('${variant.sizes.length} sizes'),
                                      _adminChip(createdLabel),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () => _editVariant(product, index),
                                        icon: const Icon(Icons.edit_outlined, size: 18),
                                        label: const Text('Edit'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () => _bulkReplaceVariantImages(product),
                                        icon: const Icon(Icons.photo_library_outlined, size: 18),
                                        label: const Text('Bulk Images'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _formatCurrency(variant.price ?? product.price),
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () => _editVariant(product, index),
                                  child: const Text('Edit Sizes'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
    );
  }

  Widget _adminChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5EFE2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF8B7A5B),
        ),
      ),
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
          future: _actor == null
              ? Future.value(
                  const AdminFinanceSummary(
                    totalCommission: 0,
                    totalRevenue: 0,
                    payoutsDone: 0,
                    vendorSettlementsDone: 0,
                    riderSettlementsDone: 0,
                    failedSettlements: 0,
                    vendorPending: 0,
                    riderPending: 0,
                    pendingWithdrawalAmount: 0,
                  ),
                )
              : _db.getAdminFinance(actor: _actor!),
          builder: (context, financeSnapshot) {
            final finance = financeSnapshot.data;
            final vendorPending = finance?.vendorPending ?? totalPending;
            final riderPending = finance?.riderPending ?? 0;
            final totalCommission = finance?.totalCommission ?? 0;
            final payoutsDone =
                finance?.payoutsDone ??
                _payouts.fold<double>(0, (sum, payout) => sum + payout.amount);
            final transactions =
                finance?.transactions ?? const <WalletTransaction>[];
            final withdrawalRequests =
                finance?.withdrawalRequests ??
                const <WithdrawalRequestSummary>[];
            final fraudAlerts =
                finance?.fraudAlerts ?? const <FraudAlertSummary>[];
            final flaggedUsers = finance?.flaggedUsers ?? 0;
            final failedSettlements = finance?.failedSettlements ?? 0;
            final pendingWithdrawalAmount =
                finance?.pendingWithdrawalAmount ?? 0;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _MetricCard(
                      title: 'Processed Payouts',
                      value: '${_payouts.length}',
                    ),
                    _MetricCard(
                      title: 'Vendor Pending',
                      value: _formatCurrency(vendorPending),
                    ),
                    _MetricCard(
                      title: 'Rider Pending',
                      value: _formatCurrency(riderPending),
                    ),
                    _MetricCard(
                      title: 'Pending Withdrawals',
                      value: _formatCurrency(pendingWithdrawalAmount),
                    ),
                    _MetricCard(
                      title: 'Commission Earned',
                      value: _formatCurrency(totalCommission),
                    ),
                    _MetricCard(
                      title: 'Settlements Done',
                      value: _formatCurrency(payoutsDone),
                    ),
                    _MetricCard(
                      title: 'Failed Settlements',
                      value: failedSettlements.toStringAsFixed(0),
                    ),
                    _MetricCard(
                      title: 'Open Fraud Alerts',
                      value: '${fraudAlerts.length}',
                    ),
                    _MetricCard(title: 'Flagged Users', value: '$flaggedUsers'),
                  ],
                ),
                const SizedBox(height: 16),
                _Panel(
                  title: 'Finance actions',
                  subtitle:
                      'Run automated settlements and review withdrawal approvals.',
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
                          avatar: const Icon(
                            Icons.receipt_long_outlined,
                            size: 18,
                          ),
                          label: Text(
                            '${transactions.length} recent transactions',
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (withdrawalRequests.isNotEmpty)
                  _Panel(
                    title: 'Pending withdrawal approvals',
                    subtitle:
                        'Approve or reject vendor and rider cash-out requests.',
                    child: Column(
                      children: withdrawalRequests.map((request) {
                        final subject = request.walletType == 'vendor'
                            ? (request.storeId.isEmpty
                                  ? request.userId
                                  : request.storeId)
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
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            '${request.note.isEmpty ? 'Awaiting approval' : request.note}\n$subject',
                            style: GoogleFonts.inter(
                              color: AbzioTheme.textSecondary,
                            ),
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
                    subtitle:
                        'Review suspicious payout, order, and account activity.',
                    child: Column(
                      children: fraudAlerts.take(12).map((alert) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            switch (alert.type) {
                              'withdrawal' =>
                                Icons.account_balance_wallet_outlined,
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
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            alert.message.isEmpty
                                ? (alert.reasons.isEmpty
                                      ? 'Risk rule matched.'
                                      : alert.reasons.join(' '))
                                : alert.message,
                            style: GoogleFonts.inter(
                              color: AbzioTheme.textSecondary,
                            ),
                          ),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: () =>
                                    _updateFraudAlert(alert, 'reviewing'),
                                child: const Text('Review'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    _updateFraudAlert(alert, 'resolved'),
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
                    subtitle:
                        'Latest commission, order credit, and payout records.',
                    child: Column(
                      children: transactions.take(8).map((transaction) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.payments_outlined),
                          title: Text(
                            '${transaction.userType.toUpperCase()} • ${transaction.type}',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            transaction.note.isEmpty
                                ? transaction.status
                                : transaction.note,
                            style: GoogleFonts.inter(
                              color: AbzioTheme.textSecondary,
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _formatCurrency(transaction.amount.abs()),
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                ),
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
          future: _actor == null
              ? Future.value(const <RefundRequest>[])
              : _db.getRefundRequests(actor: _actor!),
          builder: (context, snapshot) {
            final refunds = snapshot.data ?? const <RefundRequest>[];
            final pendingRefunds = refunds
                .where((request) => request.status.toLowerCase() == 'pending')
                .toList();
            return _Panel(
              title: 'Refund requests',
              subtitle: '${pendingRefunds.length} pending request(s)',
              child: pendingRefunds.isEmpty
                  ? const AbzioEmptyCard(
                      title: 'No pending refunds',
                      subtitle:
                          'Refund approvals will appear here when customers submit requests.',
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
                            : (order.invoiceNumber.isEmpty
                                  ? order.id
                                  : order.invoiceNumber);
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          orderLabel,
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${customer?.name ?? request.userId} • ${_formatDate(DateTime.tryParse(request.createdAt) ?? DateTime.now())}',
                                          style: GoogleFonts.inter(
                                            color: AbzioTheme.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const _StatusPill(
                                    label: 'PENDING',
                                    color: Colors.orange,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                request.reason,
                                style: GoogleFonts.inter(
                                  color: AbzioTheme.textPrimary,
                                ),
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
                                    color:
                                        request.fraudDecision.toLowerCase() ==
                                            'reject'
                                        ? Colors.red
                                        : request.fraudDecision.toLowerCase() ==
                                              'review'
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
                                    icon: const Icon(
                                      Icons.check_circle_outline,
                                    ),
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
          subtitle:
              'Track vendor earnings, commissions, and payout processing.',
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
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Commission ${(store.commissionRate * 100).toStringAsFixed(0)}% - Pending ${_formatCurrency(pending)}',
                              style: GoogleFonts.inter(
                                color: AbzioTheme.textSecondary,
                              ),
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
                        onPressed: pending <= 0
                            ? null
                            : () => _processPayout(store),
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
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                              ),
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
                  hintText: 'Search by name, phone, issue, order, or message',
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
              count:
                  _supportChatCount(status: 'open') +
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
                  SizedBox(width: 300, child: _buildSupportSidebar()),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 360,
                    child: _buildSupportQueue(chats, selected),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: _buildSupportConversationWorkspace(selected)),
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
                  Expanded(child: _buildSupportConversationWorkspace(selected)),
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
            Expanded(flex: 7, child: _buildSupportMessagesPanel(selected)),
            const SizedBox(width: 16),
            Expanded(flex: 4, child: _buildSupportTicketDetailsPanel(selected)),
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
              return const Center(child: Text('No messages yet.'));
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
          _SupportDetailRow(label: 'Status', value: chat.status.toUpperCase()),
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

  bool _isOrderDone(OrderModel order) {
    final s = order.status.toLowerCase();
    return s == 'delivered' || s == 'cancelled' || s == 'completed';
  }

  bool _isDelayedOrder(OrderModel order) {
    final s = order.status.toLowerCase();
    return s.contains('delay') || s.contains('late');
  }

  String _orderZoneFor(OrderModel order) {
    final parts = order.shippingAddress.split(',');
    if (parts.isEmpty) return 'Central';
    final zone = parts.last.trim();
    if (zone.isEmpty) return 'Central';
    return zone.length > 12 ? zone.substring(0, 12) : zone;
  }

  String _orderPriorityFor(OrderModel order) {
    if (_isDelayedOrder(order) || order.status.toLowerCase().contains('cancel')) {
      return 'HIGH';
    }
    if ((order.riderId ?? '').isEmpty ||
        order.refundStatus.toLowerCase().contains('pending')) {
      return 'MEDIUM';
    }
    return 'LOW';
  }

  double _orderHealthScore(OrderModel order) {
    var score = 82.0;
    if (_isDelayedOrder(order)) score -= 32;
    if (order.status.toLowerCase().contains('cancel')) score -= 40;
    if ((order.riderId ?? '').isEmpty) score -= 12;
    if (order.refundStatus.toLowerCase().contains('pending')) score -= 16;
    return score.clamp(5, 98).toDouble();
  }

  Color _orderBorderColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('cancel')) return const Color(0xFFB42318);
    if (s.contains('deliver')) return const Color(0xFF067647);
    if (s.contains('assign') || s.contains('picked')) {
      return const Color(0xFFB57A12);
    }
    return const Color(0xFF175CD3);
  }

  List<Widget> _orderPriorityChips(OrderModel order) {
    final chips = <Widget>[];
    if (order.totalAmount >= 5000) {
      chips.add(
        const _StatusPill(label: 'VIP CUSTOMER', color: Color(0xFF7A5AF8)),
      );
    }
    if (order.paymentMethod.toLowerCase().contains('cod')) {
      chips.add(
        const _StatusPill(label: 'PAYMENT ISSUE', color: Color(0xFFDC6803)),
      );
    }
    if (_isDelayedOrder(order)) {
      chips.add(
        const _StatusPill(label: 'HIGH DELAY', color: Color(0xFFB42318)),
      );
    }
    if (order.refundStatus.toLowerCase().contains('pending')) {
      chips.add(
        const _StatusPill(label: 'RETURN RISK', color: Color(0xFFB54708)),
      );
    }
    if (order.items.length > 3) {
      chips.add(
        const _StatusPill(label: 'MULTI-VENDOR', color: Color(0xFF175CD3)),
      );
    }
    if (order.status.toLowerCase().contains('cancel')) {
      chips.add(
        const _StatusPill(label: 'FRAUD CHECK', color: Color(0xFF7A271A)),
      );
    }
    return chips;
  }

  Widget _buildOrderTimeline(String status) {
    final steps = ['Placed', 'Confirmed', 'Packed', 'Pickup', 'Delivery'];
    final index = switch (status.toLowerCase()) {
      'placed' => 0,
      'confirmed' => 1,
      'packed' => 2,
      'ready for pickup' || 'assigned' || 'picked up' => 3,
      'out for delivery' || 'delivered' => 4,
      _ => 0,
    };
    return Row(
      children: List.generate(steps.length, (i) {
        final completed = i <= index;
        final current = i == index;
        return Expanded(
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: completed
                      ? (current
                            ? AbzioTheme.accentColor
                            : const Color(0xFF067647))
                      : AbzioTheme.grey300,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  steps[i],
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: completed
                        ? const Color(0xFF111111)
                        : AbzioTheme.grey500,
                    fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Future<void> _bulkOrderStatus(String status) async {
    final selected = _orders
        .where((o) => _selectedOrderIds.contains(o.id))
        .toList();
    for (final order in selected) {
      await _setOrderStatus(order, status);
    }
    if (!mounted) return;
    setState(() => _selectedOrderIds.clear());
  }

  void _handleOrderQuickAction(OrderModel order, String action) {
    if (action == 'details') {
      setState(() => _activeOrderDrawerOrder = order);
      return;
    }
    if (action == 'cancel') {
      unawaited(_setOrderStatus(order, 'Cancelled'));
      return;
    }
    if (action == 'refund') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Refund workflow opened.')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$action action queued for ${order.id}')),
    );
  }

  Widget _buildOrderDetailDrawer(OrderModel order) {
    final customer = _userForId(order.userId);
    final vendor = _storeForId(order.storeId);
    return Material(
      elevation: 12,
      child: Container(
        width: 420,
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Order Detail Panel',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      setState(() => _activeOrderDrawerOrder = null),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _SupportDetailRow(label: 'Order', value: order.id),
            _SupportDetailRow(
              label: 'Customer',
              value: customer?.name ?? order.userId,
            ),
            _SupportDetailRow(
              label: 'Vendor',
              value: vendor?.name ?? order.storeId,
            ),
            _SupportDetailRow(
              label: 'Payment',
              value:
                  '${order.paymentMethod} • ${order.refundStatus.isEmpty ? 'No refund' : order.refundStatus}',
            ),
            _SupportDetailRow(
              label: 'Rider',
              value: order.assignedDeliveryPartner,
            ),
            _SupportDetailRow(
              label: 'ETA',
              value: order.deliveryPromise.isEmpty
                  ? 'Recalculating'
                  : order.deliveryPromise,
            ),
            _SupportDetailRow(label: 'Address', value: order.shippingAddress),
            const SizedBox(height: 12),
            Text(
              'Incident Logs',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              '- Dispatch check completed\n- Payment verification synced\n- Risk scan complete',
              style: TextStyle(color: AbzioTheme.grey600),
            ),
            const SizedBox(height: 12),
            Text(
              'Escalation History',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              '- No active escalations',
              style: TextStyle(color: AbzioTheme.grey600),
            ),
            const SizedBox(height: 12),
            Text(
              'Internal Notes',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextField(
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Add operational note...',
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _storeRevenue(Store store) {
    final orders = _orders.where((o) => o.storeId == store.id).toList();
    return orders.fold<double>(0, (sum, o) => sum + o.totalAmount);
  }

  double _vendorHealthScore(Store store) {
    final orders = _orders.where((o) => o.storeId == store.id).toList();
    if (orders.isEmpty) return 78;
    final cancelled = orders
        .where((o) => o.status.toLowerCase().contains('cancel'))
        .length;
    final refundPending = orders
        .where((o) => o.refundStatus.toLowerCase().contains('pending'))
        .length;
    final cancelRate = cancelled / orders.length;
    final refundRate = refundPending / orders.length;
    final ratingPenalty = (5 - store.rating).clamp(0, 5) * 6;
    final score = 100 - (cancelRate * 42) - (refundRate * 28) - ratingPenalty;
    return score.clamp(12, 96).toDouble();
  }

  Widget _buildVendorDetailDrawer(Store store) {
    final revenue = _storeRevenue(store);
    final health = _vendorHealthScore(store);
    return Material(
      elevation: 14,
      child: Container(
        width: 430,
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Vendor Detail Drawer',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      setState(() => _activeVendorDrawerStore = null),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _SupportDetailRow(label: 'Store', value: store.name),
            _SupportDetailRow(label: 'Owner', value: store.ownerId),
            _SupportDetailRow(
              label: 'City',
              value: store.city.isEmpty ? 'Unknown' : store.city,
            ),
            _SupportDetailRow(
              label: 'Status',
              value: store.isApproved ? 'APPROVED' : 'PENDING',
            ),
            _SupportDetailRow(
              label: 'Revenue',
              value: _formatCurrency(revenue),
            ),
            _SupportDetailRow(
              label: 'Payout',
              value: _formatCurrency(store.walletBalance),
            ),
            _SupportDetailRow(
              label: 'Commission',
              value: '${(store.commissionRate * 100).toStringAsFixed(0)}%',
            ),
            _SupportDetailRow(
              label: 'Health',
              value: health.toStringAsFixed(0),
            ),
            const SizedBox(height: 12),
            Text(
              'Payout History',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              '- Weekly settlement processed\n- Last payout verified',
              style: TextStyle(color: AbzioTheme.grey600),
            ),
            const SizedBox(height: 12),
            Text(
              'KYC Documents',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              '- PAN verified\n- GST pending reconfirmation',
              style: TextStyle(color: AbzioTheme.grey600),
            ),
            const SizedBox(height: 12),
            Text(
              'Disputes & Fraud Flags',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              '- Return anomaly under review',
              style: TextStyle(color: AbzioTheme.grey600),
            ),
          ],
        ),
      ),
    );
  }

  String _riderLiveStatus(AppUser rider) {
    if (!rider.isActive) return 'OFFLINE';
    final active = _activeDeliveriesForRider(rider.id);
    final score = _riderPerformanceScore(rider);
    final hasRiskAlert = _opsAlerts.any((a) {
      final sameEntity =
          a.entityId == rider.id ||
          a.payload['riderId']?.toString() == rider.id;
      return sameEntity && a.severity.toUpperCase() == 'CRITICAL';
    });
    if (score < 45 || hasRiskAlert) return 'HIGH RISK';
    if (_orders.any((o) => o.riderId == rider.id && _isDelayedOrder(o))) {
      return 'DELAYED';
    }
    if (active > 0) return 'BUSY';
    return 'LIVE';
  }

  Color _riderStatusColor(String status) {
    switch (status) {
      case 'LIVE':
        return const Color(0xFF067647);
      case 'BUSY':
        return const Color(0xFF175CD3);
      case 'OFFLINE':
        return const Color(0xFF98A2B3);
      case 'DELAYED':
        return const Color(0xFFDC6803);
      case 'HIGH RISK':
        return const Color(0xFFB42318);
      default:
        return const Color(0xFF667085);
    }
  }

  double _riderPerformanceScore(AppUser rider) {
    final riderOrders = _orders.where((o) => o.riderId == rider.id).toList();
    if (riderOrders.isEmpty) return rider.isActive ? 74 : 52;
    final cancelled = riderOrders
        .where((o) => o.status.toLowerCase().contains('cancel'))
        .length;
    final delayed = riderOrders.where((o) => _isDelayedOrder(o)).length;
    final cancelRate = cancelled / riderOrders.length;
    final delayRate = delayed / riderOrders.length;
    final score =
        100 - (cancelRate * 40) - (delayRate * 30) - (rider.isActive ? 0 : 20);
    return score.clamp(18, 96).toDouble();
  }

  double _riderWeeklyEarnings(AppUser rider) {
    final now = DateTime.now();
    final deliveredLast7d = _orders.where((o) {
      return o.riderId == rider.id &&
          o.status.toLowerCase() == 'delivered' &&
          now.difference(o.timestamp).inDays <= 7;
    });
    return deliveredLast7d.fold<double>(
      0,
      (sum, o) => sum + ((o.totalAmount * 0.08).clamp(40, 260)),
    );
  }

  int? _riderBatteryLevel(AppUser rider) {
    for (final alert in _opsAlerts) {
      final sameEntity =
          alert.entityId == rider.id ||
          alert.payload['riderId']?.toString() == rider.id;
      if (!sameEntity) continue;
      final battery = alert.payload['battery'];
      if (battery is num) {
        return battery.toInt().clamp(0, 100);
      }
      final parsed = int.tryParse((battery ?? '').toString());
      if (parsed != null) {
        return parsed.clamp(0, 100);
      }
    }
    return null;
  }

  String _riderSignalQuality(AppUser rider) {
    for (final alert in _opsAlerts) {
      final sameEntity =
          alert.entityId == rider.id ||
          alert.payload['riderId']?.toString() == rider.id;
      if (!sameEntity) continue;
      final value =
          alert.payload['networkQuality'] ?? alert.payload['signalQuality'];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return 'N/A';
  }

  String _riderLastActiveLabel(AppUser rider) {
    DateTime? latest;
    for (final order in _orders) {
      if (order.riderId != rider.id) continue;
      final stamp = order.riderLocationUpdatedAt;
      if (stamp == null || stamp.trim().isEmpty) continue;
      final parsed = DateTime.tryParse(stamp);
      if (parsed == null) continue;
      if (latest == null || parsed.isAfter(latest)) {
        latest = parsed;
      }
    }
    final userParsed = DateTime.tryParse(rider.locationUpdatedAt ?? '');
    if (userParsed != null && (latest == null || userParsed.isAfter(latest))) {
      latest = userParsed;
    }
    if (latest == null) {
      return rider.isActive ? 'recently' : 'offline';
    }
    final diff = DateTime.now().difference(latest);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<void> _assignOrderToRider(AppUser rider) async {
    final actor = _actor;
    if (actor == null) {
      return;
    }
    final pending = _orders
        .where((o) => (o.riderId ?? '').isEmpty && !_isOrderDone(o))
        .toList();
    if (pending.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No unassigned orders available.')),
      );
      return;
    }
    final target = pending.first;
    await _db.assignRiderToOrder(target.id, rider, actor: actor);
    await _load();
  }

  Widget _buildRiderDetailDrawer(AppUser rider) {
    final perf = _riderPerformanceScore(rider);
    final earnings = _riderWeeklyEarnings(rider);
    final active = _activeDeliveriesForRider(rider.id);
    final riderOrders = _orders.where((o) => o.riderId == rider.id).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    OrderModel? latestOrderWithLocation;
    for (final order in riderOrders) {
      if (order.riderLatitude != null && order.riderLongitude != null) {
        latestOrderWithLocation = order;
        break;
      }
    }
    final lat = latestOrderWithLocation?.riderLatitude;
    final lng = latestOrderWithLocation?.riderLongitude;
    return Material(
      elevation: 14,
      child: Container(
        width: 430,
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Rider Detail Drawer',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      setState(() => _activeRiderDrawerUser = null),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _SupportDetailRow(label: 'Rider', value: rider.name),
            _SupportDetailRow(
              label: 'Phone',
              value: rider.phone ?? rider.email,
            ),
            _SupportDetailRow(
              label: 'City',
              value: rider.riderCity ?? rider.city ?? 'Unknown',
            ),
            _SupportDetailRow(
              label: 'Vehicle',
              value: rider.riderVehicleType ?? 'Bike',
            ),
            _SupportDetailRow(label: 'Status', value: _riderLiveStatus(rider)),
            _SupportDetailRow(
              label: 'Performance',
              value: perf.toStringAsFixed(0),
            ),
            _SupportDetailRow(label: 'Active Orders', value: '$active'),
            _SupportDetailRow(
              label: 'Weekly Earnings',
              value: _formatCurrency(earnings),
            ),
            const SizedBox(height: 12),
            Text(
              'Live GPS Map',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFF8F6F2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  lat == null || lng == null
                      ? 'Live location unavailable'
                      : 'Tracking ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'KYC / Complaints / Fraud Flags',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              '- KYC verified\n- Complaint ratio normal\n- No fraud flags',
              style: TextStyle(color: AbzioTheme.grey600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArModeration() {
    return AdminArModerationSection(
      products: _products,
      onApprove: _approveArAsset,
      onReject: _rejectArAsset,
      onRegenerate: _regenerateArAsset,
      onSaveAlignment: _saveArAlignment,
      onBulkApprove: _bulkApproveArAssets,
      onBulkRegenerate: _bulkRegenerateArAssets,
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
              decoration: const InputDecoration(hintText: 'Reply to customer'),
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
        final matches = _products
            .where((candidate) => candidate.id == item.productId)
            .toList();
        final label = matches.isEmpty ? item.productName : matches.first.name;
        topProducts.update(
          label,
          (value) => value + item.quantity,
          ifAbsent: () => item.quantity,
        );
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
            _MetricCard(title: 'AI Requests Today', value: '$todayRequests'),
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
          subtitle:
              'Monitor blended support routing, export usage data, and watch cost health in real time.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _StatusPill(
                    label:
                        '${_logicHandledRate.toStringAsFixed(0)}% handled without AI',
                    color: const Color(0xFF1F9D55),
                  ),
                  _StatusPill(
                    label:
                        '${(100 - _logicHandledRate).toStringAsFixed(0)}% advanced AI usage',
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
                subtitle:
                    'Total support requests routed through the hybrid engine.',
                child: recentStats.isEmpty
                    ? const AbzioEmptyCard(
                        title: 'No AI activity yet',
                        subtitle:
                            'Request and routing trends will appear here once support traffic starts.',
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
                subtitle:
                    'Estimated advanced-model spend from AI-routed support.',
                child: recentStats.isEmpty
                    ? const AbzioEmptyCard(
                        title: 'No cost data yet',
                        subtitle:
                            'Estimated AI cost will appear here when advanced AI requests run.',
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
                subtitle:
                    'Users generating the highest volume of advanced AI requests.',
                child: _topAiUsers.isEmpty
                    ? const AbzioEmptyCard(
                        title: 'No AI users yet',
                        subtitle:
                            'Heavy-user monitoring will appear here once the assistant is active.',
                      )
                    : Column(
                        children: _topAiUsers.map((entry) {
                          final usage = entry.key;
                          final user = entry.value;
                          final avgCost = usage.aiMessages == 0
                              ? 0.0
                              : _aiUsageLogs
                                        .where(
                                          (log) => log.userId == usage.userId,
                                        )
                                        .fold<double>(
                                          0,
                                          (sum, log) => sum + log.cost,
                                        ) /
                                    usage.aiMessages;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              user?.name.isNotEmpty == true
                                  ? user!.name
                                  : usage.userId,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                              ),
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
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  usage.dailyUsage > 12
                                      ? 'Heavy user'
                                      : 'Normal load',
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
                subtitle:
                    'Which support intents are hitting the system most often.',
                child: _intentBreakdown.isEmpty
                    ? const AbzioEmptyCard(
                        title: 'No intent data yet',
                        subtitle:
                            'Intent distribution will appear here once support logs accumulate.',
                      )
                    : Column(
                        children: _intentBreakdown.take(6).map((entry) {
                          final percent = _aiUsageLogs.isEmpty
                              ? 0
                              : ((entry.value / _aiUsageLogs.length) * 100)
                                    .round();
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              entry.key,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                              ),
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
                subtitle:
                    'Most costly advanced AI prompts so ops can tighten routing and prompts.',
                child: _topExpensiveQueries.isEmpty
                    ? const AbzioEmptyCard(
                        title: 'No AI-heavy queries yet',
                        subtitle:
                            'The costliest prompts will appear here once advanced AI requests run.',
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
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '${user?.name ?? log.userId} · ${log.intentType} · ${log.tokensUsed} tokens',
                            ),
                            trailing: Text(
                              _formatAiCost(log.cost),
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
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
                title: 'Optimization Insights',
                subtitle:
                    'Quick opportunities to reduce spend while keeping responses fast.',
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
                        subtitle:
                            'Marketplace revenue analytics will appear here once orders start moving.',
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
                            .fold<double>(
                              0,
                              (sum, order) => sum + order.totalAmount,
                            );
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            store.name,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            store.city.isEmpty ? 'Unknown city' : store.city,
                          ),
                          trailing: Text(
                            _formatCurrency(revenue),
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                            ),
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
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                            ),
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
        const SizedBox(height: 16),
        _Panel(
          title: 'Smart Insights',
          subtitle: 'AI-assisted seller intelligence suggestions.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInsightTile(
                'High return rate detected.',
                Icons.assignment_return_outlined,
              ),
              _buildInsightTile(
                'Vendor response time declining.',
                Icons.schedule_rounded,
              ),
              _buildInsightTile(
                'Luxury products trending upward.',
                Icons.trending_up_rounded,
              ),
              _buildInsightTile(
                'Potential fake inventory risk.',
                Icons.warning_amber_rounded,
              ),
            ],
          ),
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
          subtitle:
              'Control the hard daily AI budget and automatic 80% warning threshold.',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _aiCostThresholdController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
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
                  subtitle:
                      'Escalations will appear here when they are raised.',
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

  double _pricingValue(
    Map<String, dynamic> section,
    String key,
    double fallback,
  ) {
    final value = section[key];
    if (value is num) {
      return value.toDouble();
    }
    return fallback;
  }

  bool _pricingToggle(Map<String, dynamic> section, String key, bool fallback) {
    final value = section[key];
    if (value is bool) {
      return value;
    }
    return fallback;
  }

  Future<void> _editPricingNumber({
    required String title,
    required String endpoint,
    required String fieldKey,
    required double currentValue,
    required double min,
    required double max,
    bool percent = false,
  }) async {
    final controller = TextEditingController(
      text: percent
          ? (currentValue * 100).toStringAsFixed(0)
          : currentValue.toStringAsFixed(
              currentValue.truncateToDouble() == currentValue ? 0 : 2,
            ),
    );
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: percent ? 'Percent value' : 'Numeric value',
              prefixText: percent ? '' : '₹ ',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        return;
      }
      final parsed = double.tryParse(controller.text.trim());
      if (parsed == null) {
        return;
      }
      final normalized = percent ? parsed / 100 : parsed;
      final clamped = normalized.clamp(min, max).toDouble();
      await _updatePricingScope(
        endpoint: endpoint,
        body: {fieldKey: clamped},
        successMessage: '$title updated.',
      );
    } finally {
      controller.dispose();
    }
  }

  Widget _pricingMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required VoidCallback onEdit,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),
        ],
      ),
    );
  }

  Widget _buildPricingControlPanel() {
    final commission = _pricingConfig.commission;
    final delivery = _pricingConfig.deliveryFees;
    final trial = _pricingConfig.trialPricing;
    final discounts = _pricingConfig.discounts;
    final rider = _pricingConfig.riderPayouts;
    final rules = _pricingConfig.dynamicRules;
    final simulationOutputs = Map<String, dynamic>.from(
      _lastPricingSimulation['outputs'] as Map? ?? const {},
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Panel(
          title: 'Pricing control center',
          subtitle:
              'Live controls for revenue, fees, commissions, and rider payouts.',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatusBadge(
                label: _pricingConfig.updatedBy.isEmpty
                    ? 'Awaiting first pricing update'
                    : 'Updated by ${_pricingConfig.updatedBy}',
                color: AbzioTheme.accentColor,
              ),
              _StatusBadge(
                label: _pricingConfig.updatedAt == null
                    ? 'No timestamp yet'
                    : 'Last change ${DateFormat('dd MMM, hh:mm a').format(_pricingConfig.updatedAt!.toLocal())}',
                color: Colors.white,
                foreground: AbzioTheme.textPrimary,
                borderColor: AbzioTheme.grey300,
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
                title: 'Commission control',
                subtitle: 'Ready-made, custom, and SLA incentives.',
                child: Column(
                  children: [
                    _pricingMetricTile(
                      title: 'Ready-made default',
                      value:
                          '${(_pricingValue(commission, 'defaultCommissionReadyMade', 0.18) * 100).toStringAsFixed(0)}%',
                      subtitle: 'Applied to standard marketplace orders.',
                      onEdit: () => _editPricingNumber(
                        title: 'Ready-made commission',
                        endpoint: '/admin/pricing/commission',
                        fieldKey: 'defaultCommissionReadyMade',
                        currentValue: _pricingValue(
                          commission,
                          'defaultCommissionReadyMade',
                          0.18,
                        ),
                        min: 0.15,
                        max: 0.20,
                        percent: true,
                      ),
                    ),
                    _pricingMetricTile(
                      title: 'Custom default',
                      value:
                          '${(_pricingValue(commission, 'defaultCommissionCustom', 0.24) * 100).toStringAsFixed(0)}%',
                      subtitle: 'Applied to tailoring and custom orders.',
                      onEdit: () => _editPricingNumber(
                        title: 'Custom commission',
                        endpoint: '/admin/pricing/commission',
                        fieldKey: 'defaultCommissionCustom',
                        currentValue: _pricingValue(
                          commission,
                          'defaultCommissionCustom',
                          0.24,
                        ),
                        min: 0.20,
                        max: 0.30,
                        percent: true,
                      ),
                    ),
                    _pricingMetricTile(
                      title: 'High-performer adjustment',
                      value:
                          '${(_pricingValue(commission, 'highPerformerAdjustment', -0.03) * 100).toStringAsFixed(0)}%',
                      subtitle: 'Reward strong vendors with a lower take rate.',
                      onEdit: () => _editPricingNumber(
                        title: 'High performer adjustment',
                        endpoint: '/admin/pricing/commission',
                        fieldKey: 'highPerformerAdjustment',
                        currentValue: _pricingValue(
                          commission,
                          'highPerformerAdjustment',
                          -0.03,
                        ),
                        min: -0.05,
                        max: 0,
                        percent: true,
                      ),
                    ),
                    _pricingMetricTile(
                      title: 'Low SLA adjustment',
                      value:
                          '${(_pricingValue(commission, 'lowSlaAdjustment', 0.05) * 100).toStringAsFixed(0)}%',
                      subtitle: 'Penalty uplift for weak on-time performance.',
                      onEdit: () => _editPricingNumber(
                        title: 'Low SLA adjustment',
                        endpoint: '/admin/pricing/commission',
                        fieldKey: 'lowSlaAdjustment',
                        currentValue: _pricingValue(
                          commission,
                          'lowSlaAdjustment',
                          0.05,
                        ),
                        min: 0,
                        max: 0.05,
                        percent: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _Panel(
                title: 'Delivery pricing',
                subtitle: 'Same-day fees, surge, and peak-hour adjustments.',
                child: Column(
                  children: [
                    _pricingMetricTile(
                      title: '0-2 km fee',
                      value:
                          '₹${_pricingValue(delivery, 'slabUpTo2Km', 49).toStringAsFixed(0)}',
                      subtitle: 'Short radius same-day delivery.',
                      onEdit: () => _editPricingNumber(
                        title: '0-2 km delivery fee',
                        endpoint: '/admin/pricing/delivery',
                        fieldKey: 'slabUpTo2Km',
                        currentValue: _pricingValue(
                          delivery,
                          'slabUpTo2Km',
                          49,
                        ),
                        min: 39,
                        max: 500,
                      ),
                    ),
                    _pricingMetricTile(
                      title: '2-5 km fee',
                      value:
                          '₹${_pricingValue(delivery, 'slab2To5Km', 69).toStringAsFixed(0)}',
                      subtitle: 'Mid-range same-day delivery.',
                      onEdit: () => _editPricingNumber(
                        title: '2-5 km delivery fee',
                        endpoint: '/admin/pricing/delivery',
                        fieldKey: 'slab2To5Km',
                        currentValue: _pricingValue(delivery, 'slab2To5Km', 69),
                        min: 39,
                        max: 500,
                      ),
                    ),
                    _pricingMetricTile(
                      title: '5+ km fee',
                      value:
                          '₹${_pricingValue(delivery, 'slabAbove5Km', 79).toStringAsFixed(0)}',
                      subtitle: 'Long-radius same-day delivery.',
                      onEdit: () => _editPricingNumber(
                        title: '5+ km delivery fee',
                        endpoint: '/admin/pricing/delivery',
                        fieldKey: 'slabAbove5Km',
                        currentValue: _pricingValue(
                          delivery,
                          'slabAbove5Km',
                          79,
                        ),
                        min: 39,
                        max: 500,
                      ),
                    ),
                    SwitchListTile.adaptive(
                      value: _pricingToggle(delivery, 'surgeEnabled', true),
                      onChanged: (value) => _updatePricingScope(
                        endpoint: '/admin/pricing/delivery',
                        body: {'surgeEnabled': value},
                        successMessage: 'Surge pricing updated.',
                      ),
                      title: const Text('Enable surge pricing'),
                      subtitle: const Text(
                        'Apply demand-based fee surcharges live.',
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
                title: 'Trial and discount control',
                subtitle: 'Trial-home pricing and customer offer levers.',
                child: Column(
                  children: [
                    _pricingMetricTile(
                      title: 'Trial fee',
                      value:
                          '₹${_pricingValue(trial, 'trialFee', 99).toStringAsFixed(0)}',
                      subtitle: 'Applied to try-at-home experiences.',
                      onEdit: () => _editPricingNumber(
                        title: 'Trial fee',
                        endpoint: '/admin/pricing/trial',
                        fieldKey: 'trialFee',
                        currentValue: _pricingValue(trial, 'trialFee', 99),
                        min: 0,
                        max: 5000,
                      ),
                    ),
                    SwitchListTile.adaptive(
                      value: _pricingToggle(trial, 'refundable', true),
                      onChanged: (value) => _updatePricingScope(
                        endpoint: '/admin/pricing/trial',
                        body: {'refundable': value},
                        successMessage: 'Trial refundability updated.',
                      ),
                      title: const Text('Refundable trial fee'),
                    ),
                    SwitchListTile.adaptive(
                      value: _pricingToggle(trial, 'waiveOnPurchase', true),
                      onChanged: (value) => _updatePricingScope(
                        endpoint: '/admin/pricing/trial',
                        body: {'waiveOnPurchase': value},
                        successMessage: 'Trial waive-on-purchase updated.',
                      ),
                      title: const Text('Waive on purchase'),
                    ),
                    const Divider(),
                    SwitchListTile.adaptive(
                      value: _pricingToggle(
                        discounts,
                        'discountsEnabled',
                        true,
                      ),
                      onChanged: (value) => _updatePricingScope(
                        endpoint: '/admin/pricing/discount',
                        body: {'discountsEnabled': value},
                        successMessage: 'Discount toggle updated.',
                      ),
                      title: const Text('Enable discounts'),
                    ),
                    _pricingMetricTile(
                      title: 'First-order discount',
                      value:
                          '₹${_pricingValue(discounts, 'firstOrderDiscount', 100).toStringAsFixed(0)}',
                      subtitle: 'Applied to first-time eligible customers.',
                      onEdit: () => _editPricingNumber(
                        title: 'First-order discount',
                        endpoint: '/admin/pricing/discount',
                        fieldKey: 'firstOrderDiscount',
                        currentValue: _pricingValue(
                          discounts,
                          'firstOrderDiscount',
                          100,
                        ),
                        min: 0,
                        max: 10000,
                      ),
                    ),
                    _pricingMetricTile(
                      title: 'Max discount percent',
                      value:
                          '${(_pricingValue(discounts, 'maxDiscountPercent', 0.10) * 100).toStringAsFixed(0)}%',
                      subtitle: 'System-wide cap for discounting.',
                      onEdit: () => _editPricingNumber(
                        title: 'Max discount percent',
                        endpoint: '/admin/pricing/discount',
                        fieldKey: 'maxDiscountPercent',
                        currentValue: _pricingValue(
                          discounts,
                          'maxDiscountPercent',
                          0.10,
                        ),
                        min: 0.10,
                        max: 0.15,
                        percent: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _Panel(
                title: 'Rider payout and dynamic rules',
                subtitle:
                    'Protect supply while keeping unit economics healthy.',
                child: Column(
                  children: [
                    _pricingMetricTile(
                      title: 'Base rider payout',
                      value:
                          '₹${_pricingValue(rider, 'basePayout', 30).toStringAsFixed(0)}',
                      subtitle: 'Minimum same-day payout per order.',
                      onEdit: () => _editPricingNumber(
                        title: 'Base rider payout',
                        endpoint: '/admin/pricing/rider',
                        fieldKey: 'basePayout',
                        currentValue: _pricingValue(rider, 'basePayout', 30),
                        min: 30,
                        max: 1000,
                      ),
                    ),
                    _pricingMetricTile(
                      title: 'Peak bonus',
                      value:
                          '₹${_pricingValue(rider, 'peakBonus', 10).toStringAsFixed(0)}',
                      subtitle: 'Applied during busy windows.',
                      onEdit: () => _editPricingNumber(
                        title: 'Peak bonus',
                        endpoint: '/admin/pricing/rider',
                        fieldKey: 'peakBonus',
                        currentValue: _pricingValue(rider, 'peakBonus', 10),
                        min: 0,
                        max: 200,
                      ),
                    ),
                    _pricingMetricTile(
                      title: 'Trial payout base',
                      value:
                          '₹${_pricingValue(rider, 'trialPayoutBase', 60).toStringAsFixed(0)}',
                      subtitle: 'Two-trip try-at-home payout floor.',
                      onEdit: () => _editPricingNumber(
                        title: 'Trial payout base',
                        endpoint: '/admin/pricing/rider',
                        fieldKey: 'trialPayoutBase',
                        currentValue: _pricingValue(
                          rider,
                          'trialPayoutBase',
                          60,
                        ),
                        min: 60,
                        max: 500,
                      ),
                    ),
                    SwitchListTile.adaptive(
                      value: _pricingToggle(
                        rules,
                        'highDemandLowRidersEnabled',
                        true,
                      ),
                      onChanged: (value) => _updatePricingScope(
                        endpoint: '/admin/pricing',
                        body: {
                          'scope': 'dynamicRules',
                          'updates': {'highDemandLowRidersEnabled': value},
                        },
                        successMessage: 'Demand surge rule updated.',
                      ),
                      title: const Text('High demand + low riders surge'),
                    ),
                    SwitchListTile.adaptive(
                      value: _pricingToggle(
                        rules,
                        'lowConversionBoostEnabled',
                        true,
                      ),
                      onChanged: (value) => _updatePricingScope(
                        endpoint: '/admin/pricing',
                        body: {
                          'scope': 'dynamicRules',
                          'updates': {'lowConversionBoostEnabled': value},
                        },
                        successMessage: 'Low conversion relief updated.',
                      ),
                      title: const Text('Low conversion fee relief'),
                    ),
                    SwitchListTile.adaptive(
                      value: _pricingToggle(
                        rules,
                        'highReturnPromoteTrialEnabled',
                        true,
                      ),
                      onChanged: (value) => _updatePricingScope(
                        endpoint: '/admin/pricing',
                        body: {
                          'scope': 'dynamicRules',
                          'updates': {'highReturnPromoteTrialEnabled': value},
                        },
                        successMessage: 'Trial-promotion rule updated.',
                      ),
                      title: const Text('High return trial promotion'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Pricing simulation',
          subtitle:
              'Preview commission, fees, payout, and profit before shipping changes.',
          child: Column(
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 180,
                    child: TextField(
                      controller: _pricingOrderValueController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Order value',
                        prefixText: '₹ ',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: TextField(
                      controller: _pricingDistanceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Distance',
                        suffixText: 'km',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      initialValue: _pricingUserType,
                      items: const [
                        DropdownMenuItem(value: 'new', child: Text('New user')),
                        DropdownMenuItem(
                          value: 'repeat',
                          child: Text('Repeat user'),
                        ),
                        DropdownMenuItem(
                          value: 'low_conversion',
                          child: Text('Low conversion'),
                        ),
                        DropdownMenuItem(
                          value: 'high_return',
                          child: Text('High return'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _pricingUserType = value);
                      },
                      decoration: const InputDecoration(labelText: 'User type'),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      initialValue: _pricingDemandLevel,
                      items: const [
                        DropdownMenuItem(
                          value: 'normal',
                          child: Text('Normal demand'),
                        ),
                        DropdownMenuItem(
                          value: 'elevated',
                          child: Text('Elevated demand'),
                        ),
                        DropdownMenuItem(
                          value: 'high',
                          child: Text('High demand'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _pricingDemandLevel = value);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Demand level',
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _runPricingSimulation(
                      orderValue:
                          double.tryParse(
                            _pricingOrderValueController.text.trim(),
                          ) ??
                          1200,
                      distanceKm:
                          double.tryParse(
                            _pricingDistanceController.text.trim(),
                          ) ??
                          4,
                      userType: _pricingUserType,
                      demandLevel: _pricingDemandLevel,
                    ),
                    icon: const Icon(Icons.calculate_outlined),
                    label: const Text('Run simulation'),
                  ),
                ],
              ),
              if (simulationOutputs.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _MetricCard(
                      title: 'Commission',
                      value:
                          '${(((simulationOutputs['commissionPercent'] ?? 0) as num).toDouble() * 100).toStringAsFixed(1)}%',
                    ),
                    _MetricCard(
                      title: 'Delivery fee',
                      value: _formatCurrency(
                        ((simulationOutputs['deliveryFee'] ?? 0) as num)
                            .toDouble(),
                      ),
                    ),
                    _MetricCard(
                      title: 'Rider payout',
                      value: _formatCurrency(
                        ((simulationOutputs['riderEarnings'] ?? 0) as num)
                            .toDouble(),
                      ),
                    ),
                    _MetricCard(
                      title: 'Profit',
                      value: _formatCurrency(
                        ((simulationOutputs['platformProfit'] ?? 0) as num)
                            .toDouble(),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Pricing audit log',
          subtitle: 'Every pricing change with old and new values.',
          child: _pricingConfig.auditLogs.isEmpty
              ? const Text('No pricing changes logged yet.')
              : Column(
                  children: _pricingConfig.auditLogs.take(8).map((entry) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.history_rounded),
                      title: Text(
                        '${entry.scope} · ${entry.action}',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${entry.adminEmail.isEmpty ? entry.adminId : entry.adminEmail} · ${entry.changedFields.join(', ')}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        DateFormat(
                          'dd MMM, hh:mm a',
                        ).format(entry.timestamp.toLocal()),
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
            Text(
              title,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.inter(color: AbzioTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.value});

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
                style: GoogleFonts.inter(
                  color: AbzioTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
    this.foreground = Colors.white,
    this.borderColor,
  });

  final String label;
  final Color color;
  final Color foreground;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: foreground,
          fontWeight: FontWeight.w700,
          fontSize: 12,
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
            Text(
              title,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.inter(color: AbzioTheme.textSecondary),
            ),
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
              child: Text(
                label,
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
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
        IconButton(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

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
          color: isSelected
              ? AbzioTheme.accentColor.withValues(alpha: 0.08)
              : Colors.white,
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
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
                      _StatusPill(
                        label: chat.status.toUpperCase(),
                        color: statusColor,
                      ),
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
                    chat.lastMessage.isEmpty
                        ? 'Support ticket created'
                        : chat.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AbzioTheme.textSecondary,
                      fontWeight: chat.unreadCountAdmin > 0
                          ? FontWeight.w700
                          : FontWeight.w500,
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
  const _SupportDetailRow({required this.label, required this.value});

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
  const _SearchMetric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '$value',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
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
        subtitle:
            'Sales analytics will appear here when transactions are available.',
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
          final ratio = maxValue == 0
              ? 0.1
              : (point.value / maxValue).clamp(0.1, 1.0);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    valueFormatter?.call(point.value) ??
                        point.value.toStringAsFixed(0),
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

