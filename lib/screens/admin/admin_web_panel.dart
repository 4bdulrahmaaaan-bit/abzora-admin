import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
import 'admin_dashboard_v2_section.dart';
import 'admin_onboarding_analytics_section.dart';
import 'admin_trials_section.dart';
import 'admin_finance_section.dart';
import 'admin_inventory_section.dart';
import 'admin_fraud_section.dart';
import 'admin_notifications_section.dart';
import 'admin_coupons_section.dart';
import 'admin_disputes_section.dart';
import 'admin_activity_log_section.dart';
import 'admin_analytics_section.dart';
import 'admin_payout_center_screen.dart';
import 'admin_configuration_section.dart';
import 'admin_kyc_section.dart';
import 'admin_rider_intelligence_section.dart';
import 'admin_system_health_section.dart';
import 'admin_automation_section.dart';
import 'admin_backup_section.dart';
import 'admin_compliance_section.dart';
import 'admin_security_section.dart';
import 'admin_vendor_onboarding_section.dart';
import 'admin_rider_onboarding_section.dart';
part 'widgets/admin_shared_widgets.dart';
part 'sections/admin_dashboard_section.dart';
part 'sections/admin_support_section.dart';
part 'sections/admin_commerce_section_v2.dart';
part 'sections/admin_operations_kyc_section_v2.dart';
part 'sections/admin_support_helpers_section.dart';
part 'sections/admin_settings_pricing_ar_section_v2.dart';

enum AdminWebSection {
  dashboard,
  trials,
  finance,
  inventory,
  fraud,
  notifications,
  coupons,
  disputes,
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
  activityLogs,
  configuration,
  systemHealth,
  automations,
  backups,
  compliance,
  security,
  vendorOnboarding,
  riderOnboarding,
  onboardingAnalytics,
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
  List<AppNotification> _notifications = [];
  List<VendorKycRequest> _vendorRequests = [];
  List<RiderKycRequest> _riderRequests = [];
  List<DisputeRecord> _disputes = [];
  List<ActivityLogEntry> _activityLogs = [];
  List<SupportChat> _supportChats = [];
  List<OpsAlertItem> _opsAlerts = [];
  List<OpsActionLogEntry> _opsLogs = [];
  List<OpsMetricSnapshot> _opsMetrics = [];
  OpsLiveSnapshot _opsLive = const OpsLiveSnapshot();
  Map<String, dynamic> _lastPricingSimulation = const {};
  Map<String, dynamic> _dispatchSlaOverview = const {};
  List<Map<String, dynamic>> _dispatchBatches = const [];
  Map<String, dynamic> _dispatchRebalance = const {};

  bool _loading = true;
  bool _dashboardLoaded = false;
  bool _commerceLoaded = false;
  bool _notificationsLoaded = false;
  bool _kycLoaded = false;
  bool _supportLoaded = false;
  bool _disputesLoaded = false;
  bool _activityLoaded = false;
  bool _opsLoaded = false;
  bool _settingsLoaded = false;
  bool _runningSearch = false;
  bool _pinVerified = !kIsWeb;
  // True if initState ran _load() but _actor was null (auth not yet restored).
  // didChangeDependencies will retry once auth finishes.
  bool _pendingLoadAfterAuth = false;
  String? _loadError;
  final Map<AdminWebSection, Set<String>> _dataWarningsBySection =
      <AdminWebSection, Set<String>>{};

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

  Set<String> _warningsFor(AdminWebSection section) {
    return _dataWarningsBySection[section] ?? const <String>{};
  }

  void _clearWarningsFor(AdminWebSection section) {
    _dataWarningsBySection.remove(section);
  }

  void _addWarningFor(AdminWebSection section, String message) {
    _dataWarningsBySection
        .putIfAbsent(section, () => <String>{})
        .add(message);
  }

  int _vendorPage = 0;
  int _userPage = 0;
  int _riderPage = 0;
  int _orderPage = 0;
  int _productPage = 0;
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
      final actor = _actor;
      if (actor == null) {
        // Auth session not restored yet. Set a pending flag so that
        // didChangeDependencies retries once AuthProvider signals ready.
        if (mounted) {
          setState(() {
            _pendingLoadAfterAuth = true;
            _loading = false;
          });
        }
        return;
      }
      await _ensurePinIfNeeded();
      if (mounted && _pinVerified) {
        await _bootstrapInitialSection();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Retry the load if auth completed after initState's postFrameCallback
    // returned a null actor. This covers the browser-refresh race condition
    // where the panel is mounted before _restoreSession() finishes.
    if (_pendingLoadAfterAuth) {
      final actor = _actor;
      if (actor != null) {
        _pendingLoadAfterAuth = false;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          await _ensurePinIfNeeded();
          if (mounted && _pinVerified) {
            await _bootstrapInitialSection();
          }
        });
      }
    }
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
        default:
          break;
      }
    });
  }

  void _selectTab(AdminWebSection section) {
    if (!mounted) {
      return;
    }
    setState(() {
      _tab = section;
      _loadError = null;
      _clearWarningsFor(section);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_ensureSectionLoaded(section));
    });
  }

  Future<void> _ensurePinIfNeeded() async {
    final actor = _actor;
    if (actor == null || !context.read<AuthProvider>().isAdmin) {
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
    try {
      await _ensureSectionLoaded(_tab, force: true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppErrorText.from(error))));
      }
    }
  }

  Future<void> _bootstrapInitialSection() async {
    final actor = _actor;
    if (actor == null) {
      return;
    }
    final section = _tab;
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = true;
      _loadError = null;
      _clearWarningsFor(section);
    });
    try {
      await _ensureSectionLoaded(section, force: true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _addWarningFor(section, AppErrorText.from(error));
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _ensureSectionLoaded(
    AdminWebSection section, {
    bool force = false,
  }) async {
    switch (section) {
      case AdminWebSection.dashboard:
        await _loadDashboardSummary(force: force);
        break;
      case AdminWebSection.trials:
        break;
      case AdminWebSection.orders:
      case AdminWebSection.vendors:
      case AdminWebSection.riders:
      case AdminWebSection.users:
      case AdminWebSection.products:
      case AdminWebSection.arModeration:
      case AdminWebSection.payouts:
        await _loadCommerceBundle(force: force);
        break;
      case AdminWebSection.kyc:
        await _loadKycBundle(force: force);
        break;
      case AdminWebSection.notifications:
        await _loadNotificationsBundle(force: force);
        break;
      case AdminWebSection.support:
        await _loadSupportBundle(force: force);
        break;
      case AdminWebSection.disputes:
        await _loadDisputesBundle(force: force);
        break;
      case AdminWebSection.activityLogs:
        await _loadActivityBundle(force: force);
        break;
      case AdminWebSection.settings:
      case AdminWebSection.pricing:
        await _loadSettingsBundle(force: force);
        break;
      case AdminWebSection.operations:
        await _loadOperationsBundle(force: force);
        break;
      case AdminWebSection.finance:
      case AdminWebSection.inventory:
      case AdminWebSection.fraud:
      case AdminWebSection.coupons:
      case AdminWebSection.banners:
      case AdminWebSection.cms:
      case AdminWebSection.categories:
      case AdminWebSection.vendorOnboarding:
      case AdminWebSection.riderOnboarding:
      case AdminWebSection.onboardingAnalytics:
      case AdminWebSection.analytics:
      case AdminWebSection.configuration:
      case AdminWebSection.systemHealth:
      case AdminWebSection.automations:
      case AdminWebSection.backups:
      case AdminWebSection.compliance:
      case AdminWebSection.security:
        break;
    }
  }

  Future<void> _loadDashboardSummary({bool force = false}) async {
    if (_dashboardLoaded && !force) {
      return;
    }
    final actor = _actor;
    if (actor == null) {
      return;
    }
    try {
      final analytics = await _db.getAdminAnalytics();
      if (!mounted) {
        return;
      }
      setState(() {
        _analytics = analytics;
        _dashboardLoaded = true;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _analytics = AdminAnalytics(
          totalRevenue: 0,
          platformCommissionRevenue: 0,
          vendorPayouts: 0,
          riderPayouts: 0,
          totalOrders: 0,
          ordersToday: 0,
          topStores: const [],
          dailySales: const [],
          weeklySales: const [],
        );
        _dashboardLoaded = true;
        _addWarningFor(
          AdminWebSection.dashboard,
          'Dashboard metrics are temporarily unavailable. Showing a fallback view.',
        );
      });
      debugPrint('Admin dashboard load failed: $error');
    }
  }

  Future<void> _loadCommerceBundle({bool force = false}) async {
    if (_commerceLoaded && !force) {
      return;
    }
    final actor = _actor;
    if (actor == null) {
      return;
    }
    try {
      final results = await Future.wait([
        _db.getUsers(actor: actor),
        _db.getAdminStores(),
        _db.getAllProducts(actor: actor),
        _db.getAllOrders(actor: actor),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _users = results[0] as List<AppUser>;
        _stores = results[1] as List<Store>;
        _products = results[2] as List<Product>;
        if (_selectedVariantProductId == null ||
            !_products.any(
              (product) => product.id == _selectedVariantProductId,
            )) {
          _selectedVariantProductId = _products.isNotEmpty
              ? _products.first.id
              : null;
        }
        _orders = results[3] as List<OrderModel>;
        _commerceLoaded = true;
      });
    } catch (_) {
      rethrow;
    }
  }

  Future<void> _loadKycBundle({bool force = false}) async {
    if (_kycLoaded && !force) {
      return;
    }
    final actor = _actor;
    if (actor == null) {
      return;
    }
    try {
      final results = await Future.wait([
        _onboardingService.getVendorRequests(actor: actor),
        _onboardingService.getRiderRequests(actor: actor),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _vendorRequests = results[0] as List<VendorKycRequest>;
        _riderRequests = results[1] as List<RiderKycRequest>;
        _kycLoaded = true;
      });
    } catch (_) {
      rethrow;
    }
  }

  Future<void> _loadNotificationsBundle({bool force = false}) async {
    if (_notificationsLoaded && !force) {
      return;
    }
    final actor = _actor;
    if (actor == null) {
      return;
    }
    try {
      final notifications = await _safeNotifications(actor);
      if (!mounted) {
        return;
      }
      setState(() {
        _notifications = notifications;
        _notificationsLoaded = true;
      });
    } catch (_) {
      rethrow;
    }
  }

  Future<void> _loadSupportBundle({bool force = false}) async {
    if (_supportLoaded && !force) {
      return;
    }
    final actor = _actor;
    if (actor == null) {
      return;
    }
    try {
      final results = await Future.wait([
        _db.getSupportChats(actor: actor),
        _safeActivityLogs(actor),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _supportChats = results[0] as List<SupportChat>;
        _activityLogs = results[1] as List<ActivityLogEntry>;
        _selectedSupportChatId ??= _supportChats.isEmpty
            ? null
            : _supportChats.first.id;
        _supportLoaded = true;
        _activityLoaded = true;
      });
    } catch (_) {
      rethrow;
    }
  }

  Future<void> _loadDisputesBundle({bool force = false}) async {
    if (_disputesLoaded && !force) {
      return;
    }
    final actor = _actor;
    if (actor == null) {
      return;
    }
    try {
      final disputes = await _safeDisputes(actor);
      if (!mounted) {
        return;
      }
      setState(() {
        _disputes = disputes;
        _disputesLoaded = true;
      });
    } catch (_) {
      rethrow;
    }
  }

  Future<void> _loadActivityBundle({bool force = false}) async {
    if (_activityLoaded && !force) {
      return;
    }
    final actor = _actor;
    if (actor == null) {
      return;
    }
    try {
      final activityLogs = await _safeActivityLogs(actor);
      if (!mounted) {
        return;
      }
      setState(() {
        _activityLogs = activityLogs;
        _activityLoaded = true;
      });
    } catch (_) {
      rethrow;
    }
  }

  Future<void> _loadSettingsBundle({bool force = false}) async {
    if (_settingsLoaded && !force) {
      return;
    }
    final actor = _actor;
    if (actor == null) {
      return;
    }
    try {
      final results = await Future.wait([
        _safePlatformSettings(actor),
        _safePricingConfig(actor),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = results[0] as PlatformSettings;
        _pricingConfig = results[1] as PricingConfigModel;
        _aiCostThresholdController.text = _settings.aiDailyCostLimit
            .toStringAsFixed(2);
        _settingsLoaded = true;
      });
    } catch (_) {
      rethrow;
    }
  }

  Future<void> _loadOperationsBundle({bool force = false}) async {
    if (_opsLoaded && !force) {
      return;
    }
    final actor = _actor;
    if (actor == null) {
      return;
    }
    try {
      final results = await Future.wait([
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
        _opsAlerts = results[0] as List<OpsAlertItem>;
        _opsLogs = results[1] as List<OpsActionLogEntry>;
        _opsMetrics = results[2] as List<OpsMetricSnapshot>;
        _opsLive = results[3] as OpsLiveSnapshot;
        _dispatchSlaOverview = results[4] as Map<String, dynamic>;
        _dispatchBatches = results[5] as List<Map<String, dynamic>>;
        _dispatchRebalance = results[6] as Map<String, dynamic>;
        _opsLoaded = true;
      });
    } catch (_) {
      rethrow;
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

  Future<void> _deleteStore(Store store) async {
    final vendorLabel = store.name.isEmpty ? 'vendor' : store.name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete $vendorLabel?'),
        content: const Text('Delete this vendor and all products linked to the store? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB42318)),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await _db.deleteStore(store.id, actor: _actor);
    if (!mounted) {
      return;
    }
    if (_activeVendorDrawerStore?.id == store.id) {
      setState(() => _activeVendorDrawerStore = null);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted $vendorLabel.')),
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
      _addWarningFor(
        AdminWebSection.operations,
        'Live alert queue is temporarily unavailable.',
      );
      return const <OpsAlertItem>[];
    }
  }

  Future<List<OpsActionLogEntry>> _safeOpsLogs(AppUser actor) async {
    try {
      return await _db.getOpsLogs(actor: actor, limit: 120);
    } catch (_) {
      _addWarningFor(
        AdminWebSection.operations,
        'Operations audit stream is temporarily unavailable.',
      );
      return const <OpsActionLogEntry>[];
    }
  }

  Future<List<OpsMetricSnapshot>> _safeOpsMetrics(AppUser actor) async {
    try {
      return await _db.getOpsMetrics(actor: actor, type: 'hourly', limit: 24);
    } catch (_) {
      _addWarningFor(
        AdminWebSection.operations,
        'Live ops metrics are temporarily unavailable.',
      );
      return const <OpsMetricSnapshot>[];
    }
  }

  Future<OpsLiveSnapshot> _safeOpsLive(AppUser actor) async {
    try {
      return await _db.getOpsLive(actor: actor);
    } catch (_) {
      _addWarningFor(
        AdminWebSection.operations,
        'Live dispatch snapshot is temporarily unavailable.',
      );
      return const OpsLiveSnapshot();
    }
  }

  Future<Map<String, dynamic>> _safeDispatchSla(AppUser actor) async {
    try {
      return await _db.getDispatchSlaOverview(actor: actor);
    } catch (_) {
      _addWarningFor(
        AdminWebSection.operations,
        'Dispatch SLA overview is temporarily unavailable.',
      );
      return const {};
    }
  }

  Future<List<Map<String, dynamic>>> _safeDispatchBatches(AppUser actor) async {
    try {
      return await _db.getDispatchBatches(actor: actor);
    } catch (_) {
      _addWarningFor(
        AdminWebSection.operations,
        'Dispatch batches are temporarily unavailable.',
      );
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
        status: !product.isActive
            ? ProductStatus.active
            : ProductStatus.inactive,
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
      text: product.colorVariants
          .map((variant) => '${variant.name}: ${variant.stock}')
          .join('\n'),
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
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Apply'),
          ),
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
      final nextStock =
          stockByName[variant.name.toLowerCase()] ?? variant.stock;
      final nextSizeStocks =
          variant.sizeStocks.isEmpty && variant.sizes.isNotEmpty
          ? [
              for (final size in variant.sizes)
                ProductVariantSizeStock(
                  sizeName: size,
                  stockQuantity: (nextStock / variant.sizes.length).floor(),
                ),
            ]
          : variant.sizeStocks;
      return variant.copyWith(stock: nextStock, sizeStocks: nextSizeStocks);
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
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Apply'),
          ),
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
          final stock = parts.length > 1
              ? int.tryParse(parts.sublist(1).join(':').trim()) ?? 0
              : 0;
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
    final nameController = TextEditingController(
      text: duplicate
          ? ''
          : initial?.colorName.isNotEmpty == true
          ? initial!.colorName
          : initial?.name ?? '',
    );
    final hexController = TextEditingController(
      text: duplicate ? '' : initial?.hex ?? '#C6A769',
    );
    final skuController = TextEditingController(
      text: duplicate ? '' : initial?.sku ?? '',
    );
    final barcodeController = TextEditingController(
      text: duplicate ? '' : initial?.barcode ?? '',
    );
    final priceController = TextEditingController(
      text: duplicate ? '' : (initial?.price?.toStringAsFixed(0) ?? ''),
    );
    final discountController = TextEditingController(
      text: duplicate ? '' : (initial?.discountPrice?.toStringAsFixed(0) ?? ''),
    );
    final stockController = TextEditingController(
      text: duplicate ? '' : initial?.stock.toString() ?? '0',
    );
    final thumbnailController = TextEditingController(
      text: duplicate
          ? ''
          : (initial?.thumbnail.isNotEmpty == true
                ? initial!.thumbnail
                : initial?.imageUrl ?? ''),
    );
    final galleryController = TextEditingController(
      text: duplicate ? '' : (initial?.images.join('\n') ?? ''),
    );
    final sizesController = TextEditingController(
      text: duplicate ? '' : (initial?.sizes.join(', ') ?? ''),
    );
    final sizeStocksController = TextEditingController(
      text: duplicate
          ? ''
          : (initial?.sizeStocks
                    .map((item) => '${item.sizeName}:${item.stockQuantity}')
                    .join('\n') ??
                ''),
    );
    final etaController = TextEditingController(
      text: duplicate
          ? ''
          : (initial?.deliveryInfo['etaLabel']?.toString() ?? ''),
    );
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
                        decoration: const InputDecoration(
                          labelText: 'Color Name',
                        ),
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
                        decoration: const InputDecoration(
                          labelText: 'Price Override',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: discountController,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setDialogState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Discount Price',
                        ),
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
                      onSelected: (value) =>
                          setDialogState(() => active = value),
                    ),
                    FilterChip(
                      label: const Text('Same Day'),
                      selected: sameDayEligible,
                      onSelected: (value) =>
                          setDialogState(() => sameDayEligible = value),
                    ),
                    FilterChip(
                      label: const Text('Free Returns'),
                      selected: freeReturns,
                      onSelected: (value) =>
                          setDialogState(() => freeReturns = value),
                    ),
                    FilterChip(
                      label: const Text('COD'),
                      selected: cashOnDelivery,
                      onSelected: (value) =>
                          setDialogState(() => cashOnDelivery = value),
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
                    hex: hexController.text.trim().isEmpty
                        ? '#C6A769'
                        : hexController.text.trim(),
                    imageUrl: thumbnailController.text.trim(),
                    sku: skuController.text.trim(),
                    barcode: barcodeController.text.trim(),
                    price: double.tryParse(priceController.text.trim()),
                    discountPrice: double.tryParse(
                      discountController.text.trim(),
                    ),
                    stock: int.tryParse(stockController.text.trim()) ?? 0,
                    status: active ? 'active' : 'inactive',
                    thumbnail: thumbnailController.text.trim(),
                    images: _parseCsvList(galleryController.text),
                    sizes: _parseCsvList(sizesController.text),
                    sizeStocks: _parseVariantSizeStocks(
                      sizeStocksController.text,
                    ),
                    deliveryInfo: {
                      'sameDayEligible': sameDayEligible,
                      'freeReturns': freeReturns,
                      'cashOnDelivery': cashOnDelivery,
                      'etaLabel': etaController.text.trim(),
                    },
                    createdAt:
                        initial?.createdAt ?? DateTime.now().toIso8601String(),
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

  Widget _buildLiveDiscountPreview(
    String sellingPriceText,
    String originalPriceText,
  ) {
    final sellingPrice = double.tryParse(sellingPriceText.trim());
    final originalPrice = double.tryParse(originalPriceText.trim());
    final hasValidPrices =
        sellingPrice != null &&
        sellingPrice > 0 &&
        originalPrice != null &&
        originalPrice > 0;
    final safeSellingPrice = sellingPrice ?? 0;
    final safeOriginalPrice = originalPrice ?? 0;
    final discountPercent =
        hasValidPrices && safeOriginalPrice > safeSellingPrice
        ? (((safeOriginalPrice - safeSellingPrice) / safeOriginalPrice) * 100)
              .round()
        : 0;
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: 'â‚¹',
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
              color: hasValidPrices
                  ? const Color(0xFF111111)
                  : AbzioTheme.grey500,
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
    await _db.updateProduct(
      product.copyWith(colorVariants: updatedVariants),
      actor: _actor,
    );
    await _load();
  }

  Future<void> _reorderVariants(
    Product product,
    int oldIndex,
    int newIndex,
  ) async {
    final variants = [...product.colorVariants];
    final item = variants.removeAt(oldIndex);
    variants.insert(newIndex, item);
    await _db.updateProduct(
      product.copyWith(colorVariants: variants),
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
      status: product.status,
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
    return 'â‚¹${buffer.toString()}';
  }

  String _formatAiCost(double value) {
    return '\$${value.toStringAsFixed(value >= 1 ? 2 : 4)}';
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
    return '${_formatDate(parsed)} Â· ${DateFormat('hh:mm a').format(parsed)}';
  }


  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isInitialized || auth.isSessionRestoring || auth.isLoading) {
      return const Scaffold(
        backgroundColor: AbzioTheme.backgroundColor,
        body: Center(
          child: AbzioLoadingView(
            title: 'Verifying admin access',
            subtitle: 'Checking your session before loading the control center.',
          ),
        ),
      );
    }
    if (!auth.isAdmin) {
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
                                if (_warningsFor(_tab).isNotEmpty) ...[
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
      (AdminWebSection.trials, Icons.dry_cleaning_outlined, 'Trials'),
      (
        AdminWebSection.finance,
        Icons.account_balance_wallet_outlined,
        'Finance',
      ),
      (AdminWebSection.inventory, Icons.inventory_2_outlined, 'Inventory'),
      (AdminWebSection.fraud, Icons.security_rounded, 'Fraud'),
      (AdminWebSection.notifications, Icons.campaign_rounded, 'Notifications'),
      (AdminWebSection.coupons, Icons.local_offer_rounded, 'Platform Coupons'),
      (AdminWebSection.disputes, Icons.gavel_rounded, 'Disputes'),
      (AdminWebSection.operations, Icons.emergency_outlined, 'Operations'),
      (AdminWebSection.banners, Icons.view_carousel_outlined, 'Banners'),
      (AdminWebSection.cms, Icons.edit_note_outlined, 'CMS'),
      (AdminWebSection.categories, Icons.category_outlined, 'Categories'),
      (AdminWebSection.kyc, Icons.verified_user_outlined, 'KYC Requests'),
      (AdminWebSection.support, Icons.support_agent_rounded, 'Support'),
      (AdminWebSection.orders, Icons.receipt_long_outlined, 'Orders'),
      (AdminWebSection.vendors, Icons.storefront_outlined, 'Vendors'),
      (AdminWebSection.vendorOnboarding, Icons.storefront, 'Vendor Onboarding'),
      (AdminWebSection.riders, Icons.delivery_dining_outlined, 'Riders'),
      (AdminWebSection.riderOnboarding, Icons.two_wheeler, 'Rider Onboarding'),
      (
        AdminWebSection.onboardingAnalytics,
        Icons.analytics_outlined,
        'Onboarding Analytics',
      ),
      (AdminWebSection.users, Icons.people_alt_outlined, 'Users'),
      (AdminWebSection.products, Icons.inventory_2_outlined, 'Products'),
      (AdminWebSection.arModeration, Icons.view_in_ar_rounded, 'AR Moderation'),
      (AdminWebSection.analytics, Icons.insights_outlined, 'Analytics'),
      (AdminWebSection.pricing, Icons.tune_outlined, 'Pricing'),
      if (!_usesBackendCommerce)
        (AdminWebSection.payouts, Icons.payments_outlined, 'Payouts'),
      if (!_usesBackendCommerce)
        (AdminWebSection.settings, Icons.settings_outlined, 'Settings'),
      (AdminWebSection.configuration, Icons.tune, 'Platform Config'),
      (AdminWebSection.activityLogs, Icons.history, 'Activity Logs'),
      (
        AdminWebSection.systemHealth,
        Icons.monitor_heart_outlined,
        'System Health',
      ),
      (AdminWebSection.automations, Icons.smart_toy_outlined, 'Automations'),
      (AdminWebSection.backups, Icons.backup_outlined, 'Backups'),
      (AdminWebSection.compliance, Icons.verified_user_outlined, 'Compliance'),
      (AdminWebSection.security, Icons.security_outlined, 'Security'),
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
                        onTap: () => _selectTab(item.$1),
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
                onPressed: () => _selectTab(AdminWebSection.kyc),
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
        return AdminDashboardV2Section(
          analytics: _analytics,
          orders: _orders,
          users: _users,
          stores: _stores,
          revenueToday: _revenueToday,
          pendingKycCount: _pendingKycCount,
          activeRiderCount: _activeRiderCount,
          onSearchGlobal: (query) {
            _globalSearchController.text = query;
            _runGlobalSearch();
          },
          onNavigate: (sectionStr) {
            final target = AdminWebSection.values.firstWhere(
              (s) => s.name == sectionStr,
              orElse: () => AdminWebSection.dashboard,
            );
            _selectTab(target);
          },
        );
      case AdminWebSection.trials:
        return const AdminTrialsSection();
      case AdminWebSection.finance:
        return const AdminFinanceSection();
      case AdminWebSection.inventory:
        return const AdminInventorySection();
      case AdminWebSection.fraud:
        return const AdminFraudSection();
      case AdminWebSection.notifications:
        return const AdminNotificationsSection();
      case AdminWebSection.coupons:
        return const AdminCouponsSection();
      case AdminWebSection.disputes:
        return const AdminDisputesSection();
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
      case AdminWebSection.vendorOnboarding:
        return const AdminVendorOnboardingSection();
      case AdminWebSection.riderOnboarding:
        return const AdminRiderOnboardingSection();
      case AdminWebSection.onboardingAnalytics:
        return const AdminOnboardingAnalyticsSection();
      case AdminWebSection.kyc:
        return const AdminKycSection();
      case AdminWebSection.support:
        return _buildSupport();
      case AdminWebSection.orders:
        return _buildOrders();
      case AdminWebSection.vendors:
        return _buildVendors();
      case AdminWebSection.riders:
        return const AdminRiderIntelligenceSection();
      case AdminWebSection.users:
        return _buildUsers();
      case AdminWebSection.products:
        return _buildProducts();
      case AdminWebSection.arModeration:
        return _buildArModeration();
      case AdminWebSection.payouts:
        return _buildPayouts();
      case AdminWebSection.analytics:
        return const AdminAnalyticsSection();
      case AdminWebSection.pricing:
        return _buildPricingControlPanel();
      case AdminWebSection.settings:
        return _buildSettings();
      case AdminWebSection.activityLogs:
        return const AdminActivityLogSection();
      case AdminWebSection.configuration:
        return const AdminConfigurationSection();
      case AdminWebSection.systemHealth:
        return const AdminSystemHealthSection();
      case AdminWebSection.automations:
        return const AdminAutomationSection();
      case AdminWebSection.backups:
        return const AdminBackupSection();
      case AdminWebSection.compliance:
        return const AdminComplianceSection();
      case AdminWebSection.security:
        return const AdminSecuritySection();
    }
  }

  Widget _buildDataWarningsBanner() {
    final warnings = _warningsFor(_tab);
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
          ...warnings.map(
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

  // ignore: unused_element â€” Superseded by AdminDashboardV2Section; retained for reference.
  Widget _buildDashboard() {
    if (!_dashboardLoaded && _analytics == null) {
      return const AbzioLoadingView(
        title: 'Loading dashboard summary',
        subtitle: 'Fetching platform metrics only.',
      );
    }
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

    return AdminDashboardSection(
      analytics: analytics,
      vendorCount: vendorCount,
      activeRiderCount: _activeRiderCount,
      pendingKycCount: _pendingKycCount,
      revenueToday: _revenueToday,
      recentOrders: recentOrders,
      searchQuery: searchQuery,
      suggestions: suggestions,
      onSearchGlobal: (value) {
        _globalSearchController.text = value;
        _runGlobalSearch();
      },
      onNavigate: (value) {
        switch (value) {
          case 'operations':
            _selectTab(AdminWebSection.operations);
            break;
          default:
            break;
        }
      },
      formatCurrency: _formatCurrency,
      storeForId: _storeForId,
      buildOrderStatusChip: _buildOrderStatusChip,
      buildInsightTile: _buildInsightTile,
      searchResults: _searchResults,
      notifications: _notifications,
      activityLogs: _activityLogs,
      activeVendorDrawerStore: _activeVendorDrawerStore,
      formatDate: _formatDate,
      activityIconFor: _activityIconFor,
      buildVendorDetailDrawer: _buildVendorDetailDrawer,
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

  Widget _buildPayouts() {
    if (!_commerceLoaded) {
      return const AbzioLoadingView(
        title: 'Loading payouts',
        subtitle: 'Fetching users, stores, and wallet context.',
      );
    }
    return FutureBuilder<AdminFinanceSummary>(
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
        final finance =
            financeSnapshot.data ??
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
            );
        return AdminPayoutCenterScreen(
          finance: finance,
          users: _users,
          stores: _stores,
          onRefresh: () => _load(),
        );
      },
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


