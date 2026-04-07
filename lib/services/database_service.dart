import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../models/outfit_recommendation_model.dart';
import 'backend_commerce_service.dart';
import 'firebase_database_service.dart';
import 'kyc_ai_service.dart';
import 'payment_service.dart';
import 'product_realtime_service.dart';
import 'support_action_engine.dart';
import 'support_ai_service.dart';

enum _SupportActionType {
  trackOrder,
  cancelOrder,
  requestReturn,
  requestRefund,
  updateAddress,
  customHelp,
  paymentHelp,
  generalReply,
}

enum _SupportIntent {
  trackOrder,
  cancelOrder,
  returnItem,
  refund,
  addressChange,
  sizeHelp,
  aiNeeded,
}

class _SupportActionPlan {
  const _SupportActionPlan({
    required this.action,
    this.orderId,
    this.address,
    this.reason,
  });

  final _SupportActionType action;
  final String? orderId;
  final String? address;
  final String? reason;
}

class _RefundFraudAssessment {
  const _RefundFraudAssessment({
    required this.score,
    required this.decision,
    required this.reasons,
  });

  final int score;
  final String decision;
  final List<String> reasons;
}

class DatabaseService {
  static const String superAdminRole = 'super_admin';
  static const String riderRole = 'rider';

  final ProductRealtimeService _productService = ProductRealtimeService();
  final PaymentService _paymentService = PaymentService();
  final BackendCommerceService _backendCommerce = BackendCommerceService();
  final KycAiService _kycAi = const KycAiService();
  final SupportAiService _supportAi = const SupportAiService();
  final SupportActionEngine _supportActions = const SupportActionEngine();

  FirebaseDatabase get _rtdb => FirebaseDatabaseService.instance;

  bool get usesBackendCommerce => _backendCommerce.isConfigured;

  String _paymentPreferenceKey(String userId) => 'payment_pref_$userId';

  DatabaseReference _ref(String path) => _rtdb.ref(path);

  Map<String, dynamic>? _asMap(Object? value) {
    if (value is! Map) {
      return null;
    }
    return Map<String, dynamic>.from(
      value.map((key, item) => MapEntry(key.toString(), item)),
    );
  }

  List<MapEntry<String, Map<String, dynamic>>> _asCollectionEntries(Object? value) {
    final map = _asMap(value);
    if (map == null) {
      return const [];
    }
    return map.entries
        .where((entry) => entry.value is Map)
        .map((entry) => MapEntry(entry.key, _asMap(entry.value)!))
        .toList();
  }

  _SupportActionType _toPrivateActionType(SupportActionType action) {
    return switch (action) {
      SupportActionType.trackOrder => _SupportActionType.trackOrder,
      SupportActionType.cancelOrder => _SupportActionType.cancelOrder,
      SupportActionType.requestReturn => _SupportActionType.requestReturn,
      SupportActionType.requestRefund => _SupportActionType.requestRefund,
      SupportActionType.updateAddress => _SupportActionType.updateAddress,
      SupportActionType.customHelp => _SupportActionType.customHelp,
      SupportActionType.paymentHelp => _SupportActionType.paymentHelp,
      SupportActionType.generalReply => _SupportActionType.generalReply,
    };
  }

  SupportActionType _toPublicActionType(_SupportActionType action) {
    return switch (action) {
      _SupportActionType.trackOrder => SupportActionType.trackOrder,
      _SupportActionType.cancelOrder => SupportActionType.cancelOrder,
      _SupportActionType.requestReturn => SupportActionType.requestReturn,
      _SupportActionType.requestRefund => SupportActionType.requestRefund,
      _SupportActionType.updateAddress => SupportActionType.updateAddress,
      _SupportActionType.customHelp => SupportActionType.customHelp,
      _SupportActionType.paymentHelp => SupportActionType.paymentHelp,
      _SupportActionType.generalReply => SupportActionType.generalReply,
    };
  }

  Future<List<T>> _fetchCollection<T>(
    String path,
    T Function(Map<String, dynamic> map, String id) mapper,
  ) async {
    final snapshot = await _ref(path)
        .get()
        .timeout(const Duration(seconds: 10), onTimeout: () => throw TimeoutException('$path request timed out.'));
    return _asCollectionEntries(snapshot.value).map((entry) => mapper(entry.value, entry.key)).toList();
  }

  Future<List<T>> _fetchQueryCollection<T>(
    Query query,
    T Function(Map<String, dynamic> map, String id) mapper,
  ) async {
    final snapshot = await query
        .get()
        .timeout(const Duration(seconds: 10), onTimeout: () => throw TimeoutException('Query request timed out.'));
    return _asCollectionEntries(snapshot.value).map((entry) => mapper(entry.value, entry.key)).toList();
  }

  Stream<List<T>> _watchCollection<T>(
    String path,
    T Function(Map<String, dynamic> map, String id) mapper,
  ) {
    return _ref(path).onValue.map(
      (event) => _asCollectionEntries(event.snapshot.value).map((entry) => mapper(entry.value, entry.key)).toList(),
    );
  }

  Stream<List<T>> _watchQueryCollection<T>(
    Query query,
    T Function(Map<String, dynamic> map, String id) mapper,
  ) {
    return query.onValue.map(
      (event) => _asCollectionEntries(event.snapshot.value).map((entry) => mapper(entry.value, entry.key)).toList(),
    );
  }

  Future<T?> _fetchDocument<T>(
    String path,
    T Function(Map<String, dynamic> map, String id) mapper,
  ) async {
    final snapshot = await _ref(path)
        .get()
        .timeout(const Duration(seconds: 10), onTimeout: () => throw TimeoutException('$path request timed out.'));
    final map = _asMap(snapshot.value);
    if (map == null) {
      return null;
    }
    return mapper(map, snapshot.key ?? path.split('/').last);
  }

  int _orderTimestampValue(OrderModel order) => order.timestamp.millisecondsSinceEpoch;

  List<AppNotification> _sortedNotifications(Iterable<AppNotification> notifications) {
    final deduped = <String, AppNotification>{};
    for (final notification in notifications) {
      deduped[notification.id] = notification;
    }
    final items = deduped.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return items;
  }

  String _growthSegmentFor({
    required int orderCount,
    required double totalSpend,
    required bool cartAbandoned,
  }) {
    if (orderCount >= 5 || totalSpend >= 15000) {
      return 'vip';
    }
    if (orderCount >= 2) {
      return 'frequent_buyer';
    }
    if (cartAbandoned) {
      return 'at_risk';
    }
    return orderCount == 0 ? 'new' : 'active';
  }

  List<String> _behaviorFlagsFor(UserActivitySummary summary) {
    final flags = <String>[];
    final now = DateTime.now();
    final lastActive = DateTime.tryParse(summary.lastActiveAt ?? '');
    final lastCart = DateTime.tryParse(summary.lastCartActivityAt ?? '');

    if (summary.orderCount == 0) {
      flags.add('new_user');
    }
    if (summary.orderCount >= 3 || summary.totalSpend >= 8000) {
      flags.add('repeat_customer');
    }
    if (summary.cartAbandoned &&
        summary.cartItemCount > 0 &&
        lastCart != null &&
        now.difference(lastCart).inHours >= 2) {
      flags.add('cart_abandonment');
    }
    if (lastActive == null || now.difference(lastActive).inDays >= 7) {
      flags.add('inactive_user');
    }
    if ((summary.lastViewedProductId ?? '').trim().isNotEmpty) {
      flags.add('product_interest');
    }
    return flags;
  }

  Future<List<Product>> _marketingRecommendationsForUser(AppUser user) async {
    final memory = await getUserMemory(user.id);
    final summary = await getUserActivitySummary(user.id);
    final preferredStyle = memory?.preferredStyle.trim() ?? '';
    final category = preferredStyle.isNotEmpty ? null : summary.favoriteCategory;
    final catalog = await getStylistCatalog(limit: 20, category: category);
    final personalized = await personalizeProductsForUser(catalog, user: user);
    return personalized.take(3).toList();
  }

  Future<Map<String, dynamic>> _marketingContextForUser(AppUser user) async {
    final summary = await getUserActivitySummary(user.id);
    final memory = await getUserMemory(user.id);
    final bodyProfile = await getBodyProfile(user.id);
    final latestOrder = await getLatestUserOrder(user.id);
    final products = await _marketingRecommendationsForUser(user);
    return {
      'segment': summary.segment,
      'behaviorFlags': summary.behaviorFlags,
      'favoriteCategory': summary.favoriteCategory,
      'preferredStyle': memory?.preferredStyle,
      'size': memory?.size ?? bodyProfile?.recommendedSize,
      'lastOrderId': latestOrder?.id,
      'productIds': products.map((item) => item.id).toList(),
      'productNames': products.map((item) => item.name).toList(),
      'deepLink':
          products.isEmpty ? null : '/product/${products.first.id}',
    };
  }

  Future<UserActivitySummary> getUserActivitySummary(String userId) async {
    if (_backendCommerce.isConfigured) {
      return UserActivitySummary(
        userId: userId,
        segment: 'active',
      );
    }
    final summary = await _fetchDocument(
      'userActivity/$userId/summary',
      (map, _) => UserActivitySummary.fromMap(map, userId),
    );
    return summary ?? UserActivitySummary(userId: userId);
  }

  Future<void> _saveUserActivitySummary(UserActivitySummary summary) async {
    if (_backendCommerce.isConfigured) {
      return;
    }
    await _ref('userActivity/${summary.userId}/summary').set(summary.toMap());
  }

  Future<void> _logUserActivityEvent({
    required String userId,
    required String type,
    Map<String, dynamic> payload = const {},
  }) async {
    if (_backendCommerce.isConfigured) {
      return;
    }
    final eventId = 'evt-${DateTime.now().millisecondsSinceEpoch}';
    await _ref('userActivity/$userId/events/$eventId').set({
      'id': eventId,
      'type': type,
      'payload': payload,
      'timestamp': _nowIso(),
    });
  }

  Future<void> trackUserLogin(AppUser user) async {
    if (_backendCommerce.isConfigured) {
      return;
    }
    final nowIso = _nowIso();
    final existing = await getUserActivitySummary(user.id);
    final updated = existing.copyWith(
      loginCount: existing.loginCount + 1,
      lastLoginAt: nowIso,
      lastActiveAt: nowIso,
      segment: _growthSegmentFor(
        orderCount: existing.orderCount,
        totalSpend: existing.totalSpend,
        cartAbandoned: existing.cartAbandoned,
      ),
    );
    await _saveUserActivitySummary(
      updated.copyWith(
        behaviorFlags: _behaviorFlagsFor(updated),
      ),
    );
    await _logUserActivityEvent(
      userId: user.id,
      type: 'login',
      payload: {
        'phone': user.phone,
        'city': user.city,
      },
    );
    unawaited(runGrowthAutomationForUser(user));
  }

  Future<void> trackCartActivity({
    required AppUser user,
    required List<OrderItem> items,
    required String action,
  }) async {
    if (_backendCommerce.isConfigured) {
      return;
    }
    final nowIso = _nowIso();
    final existing = await getUserActivitySummary(user.id);
    final cartAbandoned = items.isNotEmpty;
    final updated = existing.copyWith(
      cartItemCount: items.fold<int>(0, (sum, item) => sum + item.quantity),
      lastCartActivityAt: nowIso,
      lastActiveAt: nowIso,
      cartAbandoned: cartAbandoned,
      cartAbandonedAt: cartAbandoned ? nowIso : null,
      favoriteCategory: existing.favoriteCategory,
      segment: _growthSegmentFor(
        orderCount: existing.orderCount,
        totalSpend: existing.totalSpend,
        cartAbandoned: cartAbandoned,
      ),
    );
    await _saveUserActivitySummary(
      updated.copyWith(
        behaviorFlags: _behaviorFlagsFor(updated),
      ),
    );
    await _logUserActivityEvent(
      userId: user.id,
      type: 'cart_$action',
      payload: {
        'itemCount': updated.cartItemCount,
        'items': items.take(3).map((item) => item.productName).toList(),
      },
    );
    if (cartAbandoned) {
      unawaited(runGrowthAutomationForUser(user));
    }
  }

  Future<void> trackOrderPlacedForGrowth({
    required AppUser user,
    required OrderModel order,
  }) async {
    if (_backendCommerce.isConfigured) {
      return;
    }
    final nowIso = _nowIso();
    final existing = await getUserActivitySummary(user.id);
    final favoriteCategory = order.items.isEmpty
        ? existing.favoriteCategory
        : (await _fetchDocument(
              'products/${order.items.first.productId}',
              (map, id) => Product.fromMap(map, id),
            ))
                ?.category ??
            existing.favoriteCategory;
    final updated = existing.copyWith(
      orderCount: existing.orderCount + 1,
      totalSpend: existing.totalSpend + order.totalAmount,
      lastOrderAt: nowIso,
      lastActiveAt: nowIso,
      cartItemCount: 0,
      cartAbandoned: false,
      cartAbandonedAt: null,
      favoriteCategory: favoriteCategory,
      segment: _growthSegmentFor(
        orderCount: existing.orderCount + 1,
        totalSpend: existing.totalSpend + order.totalAmount,
        cartAbandoned: false,
      ),
    );
    await _saveUserActivitySummary(
      updated.copyWith(
        behaviorFlags: _behaviorFlagsFor(updated),
      ),
    );
    await _logUserActivityEvent(
      userId: user.id,
      type: 'order_placed',
      payload: {
        'orderId': order.id,
        'totalAmount': order.totalAmount,
        'status': order.status,
      },
    );
    unawaited(runGrowthAutomationForUser(user));
  }

  Future<String> ensureReferralCode(AppUser user) async {
    if (_backendCommerce.isConfigured) {
      final existing = (user.referralCode ?? '').trim();
      if (existing.isNotEmpty) {
        return existing;
      }
      final seed = '${(user.phone ?? user.id).replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase()}ABZ';
      return seed.length > 10 ? seed.substring(0, 10) : seed.padRight(8, 'X');
    }
    final ref = _ref('users/${user.id}/growth/referralCode');
    final existing = await ref.get();
    final code = (existing.value as String?)?.trim();
    if (code != null && code.isNotEmpty) {
      await _ref('users/${user.id}/referralCode').set(code);
      return code;
    }
    final seed = '${(user.phone ?? user.id).replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase()}ABZ';
    final generated = seed.length > 10 ? seed.substring(0, 10) : seed.padRight(8, 'X');
    await _ref('').update({
      'users/${user.id}/growth/referralCode': generated,
      'users/${user.id}/referralCode': generated,
    });
    return generated;
  }

  double _referrerRewardForCompletedInvites(int completedInvites) {
    if (completedInvites >= 10) {
      return 150;
    }
    if (completedInvites >= 4) {
      return 100;
    }
    return 75;
  }

  String _referralTierForCompletedInvites(int completedInvites) {
    if (completedInvites >= 10) {
      return 'Gold';
    }
    if (completedInvites >= 4) {
      return 'Silver';
    }
    return 'Bronze';
  }

  int _invitesToNextReferralTier(int completedInvites) {
    if (completedInvites < 4) {
      return 4 - completedInvites;
    }
    if (completedInvites < 10) {
      return 10 - completedInvites;
    }
    return 0;
  }

  double _referralProgress(int completedInvites) {
    if (completedInvites >= 10) {
      return 1;
    }
    if (completedInvites < 4) {
      return (completedInvites / 4).clamp(0, 1).toDouble();
    }
    return ((completedInvites - 4) / 6).clamp(0, 1).toDouble();
  }

  Future<SmartCreditDecision> getSmartCreditDecision({
    required AppUser user,
    required double cartValue,
  }) async {
    final availableCredits = user.walletBalance.clamp(0, 75).toDouble();
    if (availableCredits <= 0) {
      return const SmartCreditDecision(
        availableCredits: 0,
        appliedCredits: 0,
        autoApplied: false,
        eligible: false,
        message: 'No referral credits available right now.',
      );
    }
    if (cartValue < 499) {
      return SmartCreditDecision(
        availableCredits: availableCredits,
        appliedCredits: 0,
        autoApplied: false,
        eligible: false,
        message: 'Referral credits unlock on orders of Rs 499 or more.',
      );
    }

    final summary = await getUserActivitySummary(user.id);
    final lastOrderAt = DateTime.tryParse(summary.lastOrderAt ?? '');
    final inactiveDays =
        lastOrderAt == null ? 999 : DateTime.now().difference(lastOrderAt).inDays;
    final isNewUser = summary.orderCount == 0 || summary.segment == 'new';
    final isRepeatInactive = summary.orderCount > 0 && inactiveDays >= 7;

    var suggested = 0.0;
    var autoApplied = false;
    if (isNewUser || isRepeatInactive) {
      suggested = 75;
      autoApplied = true;
    } else if (cartValue >= 499 && cartValue <= 700) {
      suggested = 75;
      autoApplied = true;
    } else if (cartValue > 700 && cartValue <= 1500) {
      suggested = cartValue < 1000 ? 50 : 30;
      autoApplied = false;
    } else {
      suggested = 0;
      autoApplied = false;
    }

    final applied = suggested.clamp(0, availableCredits).toDouble();
    if (applied <= 0) {
      return SmartCreditDecision(
        availableCredits: availableCredits,
        appliedCredits: 0,
        autoApplied: false,
        eligible: true,
        message: 'You can keep your Rs ${availableCredits.toStringAsFixed(0)} credits for a smaller order.',
      );
    }
    return SmartCreditDecision(
      availableCredits: availableCredits,
      appliedCredits: applied,
      autoApplied: autoApplied,
      eligible: true,
      message: autoApplied
          ? 'Rs ${applied.toStringAsFixed(0)} credits applied automatically'
          : 'Use Rs ${applied.toStringAsFixed(0)} credits?',
    );
  }

  Future<bool> applyReferralCode({
    required AppUser actor,
    required String code,
  }) async {
    if (_backendCommerce.isConfigured) {
      return false;
    }
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) {
      throw StateError('Enter a valid referral code.');
    }
    if ((actor.referredBy ?? '').trim().isNotEmpty) {
      throw StateError('A referral code has already been applied to this account.');
    }

    final users = await _fetchCollection('users', (map, _) => AppUser.fromMap(map));
    AppUser? referrer;
    for (final candidate in users) {
      final candidateCode = (candidate.referralCode ?? '').trim().toUpperCase();
      if (candidateCode == normalized) {
        referrer = candidate;
        break;
      }
    }
    if (referrer == null) {
      throw StateError('This referral code could not be found.');
    }
    if (referrer.id == actor.id) {
      throw StateError('You cannot use your own referral code.');
    }
    if ((referrer.phone ?? '').trim().isNotEmpty &&
        (referrer.phone ?? '').trim() == (actor.phone ?? '').trim()) {
      throw StateError('This referral cannot be applied to the same phone number.');
    }

    final existing = await _fetchDocument(
      'referrals/${referrer.id}/${actor.id}',
      (map, id) => ReferralRecord.fromMap(map, id),
    );
    if (existing != null) {
      throw StateError('This referral has already been linked.');
    }

    final nowIso = _nowIso();
    final record = ReferralRecord(
      id: actor.id,
      referrerId: referrer.id,
      referredUserId: actor.id,
      referralCode: normalized,
      status: 'pending',
      createdAt: nowIso,
    );

    await _ref('').update({
      'users/${actor.id}/referredBy': referrer.id,
      'referrals/${referrer.id}/${actor.id}': record.toMap(),
    });
    return true;
  }

  Future<List<ReferralRecord>> getReferralHistory(String userId) async {
    if (_backendCommerce.isConfigured) {
      return const <ReferralRecord>[];
    }
    final items = await _fetchCollection(
      'referrals/$userId',
      (map, id) => ReferralRecord.fromMap(map, id),
    );
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<ReferralDashboardData> getReferralDashboard(AppUser user) async {
    if (_backendCommerce.isConfigured) {
      final code = await ensureReferralCode(user);
      const completedCount = 0;
      return ReferralDashboardData(
        referralCode: code,
        invitedCount: 0,
        completedCount: completedCount,
        pendingCount: 0,
        earnedCredits: 0,
        walletBalance: user.walletBalance,
        tier: _referralTierForCompletedInvites(completedCount),
        nextTierProgress: _referralProgress(completedCount),
        invitesToNextTier: _invitesToNextReferralTier(completedCount),
        history: const <ReferralRecord>[],
      );
    }
    final code = await ensureReferralCode(user);
    final history = await getReferralHistory(user.id);
    final completed = history.where((item) => item.rewardGiven).toList();
    final pending = history.where((item) => !item.rewardGiven).toList();
    final completedCount = completed.length;
    return ReferralDashboardData(
      referralCode: code,
      invitedCount: history.length,
      completedCount: completedCount,
      pendingCount: pending.length,
      earnedCredits: completed.fold<double>(0, (sum, item) => sum + item.referrerReward),
      walletBalance: user.walletBalance,
      tier: _referralTierForCompletedInvites(completedCount),
      nextTierProgress: _referralProgress(completedCount),
      invitesToNextTier: _invitesToNextReferralTier(completedCount),
      history: history,
    );
  }

  Future<void> _processReferralRewardIfEligible({
    required AppUser actor,
    required OrderModel order,
  }) async {
    if (_backendCommerce.isConfigured) {
      return;
    }
    final referrerId = (actor.referredBy ?? '').trim();
    if (referrerId.isEmpty || order.totalAmount < 499) {
      return;
    }

    final orders = await getUserOrdersOnce(actor.id);
    if (orders.length != 1) {
      return;
    }

    final referrer = await getUser(referrerId);
    if (referrer == null || referrer.id == actor.id) {
      return;
    }

    final existing = await _fetchDocument(
      'referrals/$referrerId/${actor.id}',
      (map, id) => ReferralRecord.fromMap(map, id),
    );
    final nowIso = _nowIso();
    final fraudFlags = <String>[
      if ((referrer.phone ?? '').trim().isNotEmpty &&
          (referrer.phone ?? '').trim() == (actor.phone ?? '').trim())
        'same_phone',
    ];
    if (fraudFlags.isNotEmpty) {
      final blockedRecord = (existing ??
              ReferralRecord(
                id: actor.id,
                referrerId: referrerId,
                referredUserId: actor.id,
                referralCode: referrer.referralCode ?? '',
                createdAt: nowIso,
              ))
          .toMap()
        ..addAll({
          'status': 'blocked',
          'fraudFlags': fraudFlags,
          'qualifyingOrderId': order.id,
          'qualifyingOrderAmount': order.totalAmount,
        });
      await _ref('referrals/$referrerId/${actor.id}').set(blockedRecord);
      return;
    }
    if (existing?.rewardGiven == true) {
      return;
    }

    final completedBefore = await getReferralHistory(referrerId);
    final referrerReward =
        _referrerRewardForCompletedInvites(completedBefore.where((item) => item.rewardGiven).length + 1);
    const friendReward = 75.0;
    final updatedRecord = ReferralRecord(
      id: actor.id,
      referrerId: referrerId,
      referredUserId: actor.id,
      referralCode: existing?.referralCode ?? referrer.referralCode ?? '',
      status: 'completed',
      rewardGiven: true,
      referrerReward: referrerReward,
      friendReward: friendReward,
      createdAt: existing?.createdAt ?? nowIso,
      completedAt: nowIso,
      qualifyingOrderId: order.id,
      qualifyingOrderAmount: order.totalAmount,
      fraudFlags: existing?.fraudFlags ?? const <String>[],
    );

    await _ref('').update({
      'users/$referrerId/walletBalance': referrer.walletBalance + referrerReward,
      'users/${actor.id}/walletBalance': actor.walletBalance + friendReward,
      'referrals/$referrerId/${actor.id}': updatedRecord.toMap(),
    });
  }

  Future<void> _saveGrowthOffer(GrowthOffer offer) async {
    if (_backendCommerce.isConfigured) {
      return;
    }
    await _ref('offers/${offer.userId}/${offer.id}').set(offer.toMap());
  }

  Future<void> _saveGrowthTrigger(GrowthTrigger trigger) async {
    if (_backendCommerce.isConfigured) {
      return;
    }
    await _ref('triggers/${trigger.userId}/${trigger.id}').set(trigger.toMap());
  }

  Future<bool> _hasRecentGrowthTrigger(
    String userId,
    String type, {
    Duration window = const Duration(hours: 24),
  }) async {
    if (_backendCommerce.isConfigured) {
      return false;
    }
    final triggers = await _fetchCollection(
      'triggers/$userId',
      (map, id) => GrowthTrigger.fromMap(map, id),
    );
    final cutoff = DateTime.now().subtract(window);
    return triggers.any((trigger) {
      final createdAt = DateTime.tryParse(trigger.createdAt);
      return trigger.type == type && createdAt != null && createdAt.isAfter(cutoff);
    });
  }

  Future<List<GrowthOffer>> getGrowthOffersForUser(AppUser user) async {
    if (_backendCommerce.isConfigured) {
      return const <GrowthOffer>[];
    }
    final offers = await _fetchCollection(
      'offers/${user.id}',
      (map, id) => GrowthOffer.fromMap(map, id),
    );
    offers.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return offers;
  }

  String _couponCodePrefixForType(String type) {
    switch (type) {
      case 'new_user':
        return 'NEW';
      case 'cart_recovery':
        return 'CART';
      case 'winback':
        return 'COME';
      case 'high_value':
        return 'VIP';
      default:
        return 'ABZ';
    }
  }

  String _generatePersonalizedCouponCode(String type) {
    final prefix = _couponCodePrefixForType(type);
    final suffix = Random().nextInt(9000) + 1000;
    return '$prefix$suffix';
  }

  bool _isGrowthOfferActiveForCart(GrowthOffer offer, double cartValue) {
    if (offer.isClaimed) {
      return false;
    }
    final expiresAt = DateTime.tryParse(offer.expiresAt ?? '');
    if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
      return false;
    }
    return cartValue >= offer.minOrderValue;
  }

  double _effectiveOfferValue(GrowthOffer offer, double cartValue) {
    final percentValue = cartValue * (offer.discountPercent / 100);
    return max(offer.discountAmount, percentValue);
  }

  Future<GrowthOffer?> _findExistingEligibleCoupon({
    required AppUser user,
    required double cartValue,
  }) async {
    final offers = await getGrowthOffersForUser(user);
    final eligible = offers
        .where((offer) => _isGrowthOfferActiveForCart(offer, cartValue))
        .toList()
      ..sort((a, b) => _effectiveOfferValue(b, cartValue).compareTo(_effectiveOfferValue(a, cartValue)));
    return eligible.isEmpty ? null : eligible.first;
  }

  Future<GrowthOffer?> getPersonalizedCouponForCheckout({
    required AppUser user,
    required double cartValue,
  }) async {
    if (cartValue <= 0) {
      return null;
    }

    final existing = await _findExistingEligibleCoupon(user: user, cartValue: cartValue);
    if (existing != null) {
      return existing;
    }

    final summary = await getUserActivitySummary(user.id);
    final now = DateTime.now();
    final lastOrderAt = DateTime.tryParse(summary.lastOrderAt ?? '');
    final daysSinceLastOrder = lastOrderAt == null ? 999 : now.difference(lastOrderAt).inDays;
    final isNewUser = summary.orderCount == 0 || summary.segment == 'new';
    final isHighValueUser = summary.orderCount >= 5 || summary.totalSpend >= 15000;

    String? type;
    String title = '';
    String subtitle = '';
    double discountAmount = 0;
    double minOrderValue = 499;
    bool autoApply = false;

    if (isNewUser) {
      type = 'new_user';
      title = 'Special offer for you';
      subtitle = 'Your first ABZORA order unlocks a premium welcome coupon.';
      discountAmount = 100;
      autoApply = cartValue >= 499;
    } else if (summary.cartAbandoned) {
      type = 'cart_recovery';
      title = 'Your bag deserves a comeback';
      subtitle = 'Complete this order soon and use a focused recovery reward.';
      discountAmount = 75;
      autoApply = cartValue >= 499;
    } else if (daysSinceLastOrder > 7) {
      type = 'winback';
      title = 'A little welcome back reward';
      subtitle = 'We saved a lighter offer to bring you back in style.';
      discountAmount = 50;
      autoApply = false;
    } else if (isHighValueUser) {
      type = 'high_value';
      title = 'Private offer for a valued member';
      subtitle = 'A small premium nudge for your next elevated checkout.';
      discountAmount = 30;
      autoApply = false;
    }

    if (type == null) {
      return null;
    }

    final offer = GrowthOffer(
      id: 'offer-coupon-${now.millisecondsSinceEpoch}',
      userId: user.id,
      type: type,
      title: title,
      subtitle: subtitle,
      code: _generatePersonalizedCouponCode(type),
      discountPercent: 0,
      discountAmount: min(75, discountAmount),
      minOrderValue: minOrderValue,
      autoApply: autoApply,
      createdAt: now.toIso8601String(),
      expiresAt: now.add(Duration(hours: type == 'new_user' ? 48 : 24)).toIso8601String(),
      metadata: {
        'engine': 'ai_coupon',
        'cartValue': cartValue,
        'userType': isNewUser ? 'new' : 'repeat',
      },
    );
    await _saveGrowthOffer(offer);
    return offer;
  }

  Future<GrowthOffer?> validateCouponForUser({
    required AppUser user,
    required String code,
    required double cartValue,
  }) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) {
      return null;
    }
    final offers = await getGrowthOffersForUser(user);
    for (final offer in offers) {
      if (offer.code.toUpperCase() == normalized && _isGrowthOfferActiveForCart(offer, cartValue)) {
        return offer;
      }
    }
    return null;
  }

  Future<void> markGrowthOfferClaimed({
    required String userId,
    required String code,
  }) async {
    final offers = await _fetchCollection(
      'offers/$userId',
      (map, id) => GrowthOffer.fromMap(map, id),
    );
    final match = offers.where((offer) => offer.code.toUpperCase() == code.trim().toUpperCase()).toList();
    if (match.isEmpty) {
      return;
    }
    final offer = match.first;
    await _ref('offers/$userId/${offer.id}/isClaimed').set(true);
  }

  Future<MasterPricingDecision> getMasterPricingDecision({
    required AppUser user,
    required List<OrderItem> items,
    double extraCharges = 0,
    String? couponCode,
    bool useReferralCredits = true,
  }) async {
    var originalPrice = 0.0;
    var dynamicPrice = 0.0;

    for (final item in items) {
      originalPrice += item.price * item.quantity;
      final product = await _fetchDocument(
        'products/${item.productId}',
        (map, id) => Product.fromMap(map, id),
      );
      final effectivePrice = product == null ? item.price : _decorateProduct(product).effectivePrice;
      dynamicPrice += effectivePrice * item.quantity;
    }

    final dynamicAdjustment = dynamicPrice - originalPrice;
    final maxDiscountCap = dynamicPrice * 0.30;

    GrowthOffer? coupon;
    double manualCouponAmount = 0;
    if ((couponCode ?? '').trim().isNotEmpty) {
      final normalizedCode = couponCode!.trim().toUpperCase();
      coupon = await validateCouponForUser(
        user: user,
        code: normalizedCode,
        cartValue: dynamicPrice,
      );
      if (coupon == null) {
        if (normalizedCode == 'ABZORA10') {
          manualCouponAmount = dynamicPrice * 0.10;
        } else if (normalizedCode == 'ELITE20') {
          manualCouponAmount = dynamicPrice * 0.20;
        }
      }
    } else {
      coupon = await getPersonalizedCouponForCheckout(
        user: user,
        cartValue: dynamicPrice,
      );
      if (coupon != null && !coupon.autoApply) {
        coupon = null;
      }
    }

    var couponAmount = coupon == null ? manualCouponAmount : _effectiveOfferValue(coupon, dynamicPrice);
    final creditDecision = await getSmartCreditDecision(
      user: user,
      cartValue: dynamicPrice,
    );
    var creditsApplied = useReferralCredits ? creditDecision.appliedCredits : 0.0;

    final totalRequestedDiscount = couponAmount + creditsApplied;
    if (totalRequestedDiscount > maxDiscountCap) {
      final allowedDiscount = maxDiscountCap;
      couponAmount = min(couponAmount, allowedDiscount);
      creditsApplied = min(creditsApplied, max(0.0, allowedDiscount - couponAmount));
    }

    final discountedSubtotal = max(0.0, dynamicPrice - couponAmount - creditsApplied);
    final taxAmount = discountedSubtotal * 0.05;
    final finalPrice = discountedSubtotal + taxAmount + extraCharges;

    return MasterPricingDecision(
      originalPrice: originalPrice,
      dynamicPrice: dynamicPrice,
      dynamicAdjustment: dynamicAdjustment,
      couponAmount: couponAmount,
      couponCode: coupon?.code ?? (manualCouponAmount > 0 ? couponCode : null),
      creditsApplied: creditsApplied,
      discountedSubtotal: discountedSubtotal,
      taxAmount: taxAmount,
      extraCharges: extraCharges,
      finalPrice: finalPrice,
      maxDiscountCap: maxDiscountCap,
      summary: 'Base ${originalPrice.toStringAsFixed(0)}, dynamic ${dynamicPrice.toStringAsFixed(0)}, credits ${creditsApplied.toStringAsFixed(0)}, coupon ${couponAmount.toStringAsFixed(0)}',
    );
  }

  Future<void> logMasterPricingDecision({
    required AppUser user,
    required MasterPricingDecision decision,
    String? orderId,
  }) async {
    final now = DateTime.now();
    final logId = 'price-${now.millisecondsSinceEpoch}';
    await _ref('pricing_logs/$logId').set({
      'id': logId,
      'userId': user.id,
      'orderId': orderId,
      'originalPrice': decision.originalPrice,
      'dynamicPrice': decision.dynamicPrice,
      'finalPrice': decision.finalPrice,
      'creditsUsed': decision.creditsApplied,
      'couponUsed': decision.couponCode,
      'couponAmount': decision.couponAmount,
      'timestamp': now.toIso8601String(),
      'summary': decision.summary,
    });
  }

  Future<List<GrowthTrigger>> getGrowthTriggersForUser(AppUser user) async {
    final triggers = await _fetchCollection(
      'triggers/${user.id}',
      (map, id) => GrowthTrigger.fromMap(map, id),
    );
    triggers.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return triggers;
  }

  Future<String?> getPreferredPaymentMethod(String userId) async {
    if (_backendCommerce.isConfigured) {
      final prefs = await SharedPreferences.getInstance();
      final local = prefs.getString(_paymentPreferenceKey(userId))?.trim();
      return (local == null || local.isEmpty) ? null : local;
    }
    final snapshot = await _ref('users/$userId/preferences/preferredPaymentMethod')
        .get()
        .timeout(const Duration(seconds: 8), onTimeout: () => throw TimeoutException('Preferred payment method request timed out.'));
    final value = snapshot.value?.toString().trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  Future<void> savePreferredPaymentMethod(String userId, String method) async {
    final normalized = method.trim();
    if (_backendCommerce.isConfigured) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_paymentPreferenceKey(userId), normalized);
      return;
    }
    await _ref('users/$userId/preferences/preferredPaymentMethod').set(normalized);
  }

  Future<void> trackAiStylistConversion({
    required AppUser user,
    required Product product,
    required String eventType,
    String? recommendedSize,
    String? orderId,
    Map<String, dynamic> metadata = const {},
  }) async {
    if (_backendCommerce.isConfigured) {
      return;
    }
    final now = DateTime.now();
    final logId = 'ai-style-${now.millisecondsSinceEpoch}';
    await _ref('aiStylistAnalytics/$logId').set({
      'id': logId,
      'userId': user.id,
      'productId': product.id,
      'eventType': eventType,
      'recommendedSize': recommendedSize,
      'orderId': orderId,
      'price': product.effectivePrice,
      'timestamp': now.toIso8601String(),
      'metadata': metadata,
    });
  }

  Future<void> runGrowthAutomationForUser(AppUser user) async {
    final settings = await getPlatformSettings();
    if (!settings.offersEnabled) {
      return;
    }

    final summary = await getUserActivitySummary(user.id);
    final now = DateTime.now();
    final lastActive = DateTime.tryParse(summary.lastActiveAt ?? '');
    final lastCartActivity = DateTime.tryParse(summary.lastCartActivityAt ?? '');
    final isInactive = lastActive == null || now.difference(lastActive).inDays >= 7;
    final hasAbandonedCart = summary.cartAbandoned &&
        summary.cartItemCount > 0 &&
        lastCartActivity != null &&
        now.difference(lastCartActivity).inHours >= 2;
    final isFrequentBuyer = summary.orderCount >= 3 || summary.totalSpend >= 8000;
    final marketingContext = await _marketingContextForUser(user);
    final recommendedNames =
        List<String>.from(marketingContext['productNames'] as List? ?? const []);
    final recommendedIds =
        List<String>.from(marketingContext['productIds'] as List? ?? const []);
    final deepLink = marketingContext['deepLink']?.toString();
    final leadingProductName =
        recommendedNames.isEmpty ? 'new arrivals' : recommendedNames.first;

    if (summary.orderCount == 0 &&
        !await _hasRecentGrowthTrigger(user.id, 'welcome_offer', window: const Duration(days: 7))) {
      final offer = GrowthOffer(
        id: 'offer-welcome-${now.millisecondsSinceEpoch}',
        userId: user.id,
        type: 'welcome',
        title: 'Welcome to ABZORA',
        subtitle: 'Start with a premium first-order saving curated for your style.',
        code: _generatePersonalizedCouponCode('new_user'),
        discountPercent: 0,
        discountAmount: 100,
        minOrderValue: 499,
        autoApply: true,
        createdAt: now.toIso8601String(),
        expiresAt: now.add(const Duration(days: 5)).toIso8601String(),
        metadata: {
          'productIds': recommendedIds,
          'deepLink': deepLink,
        },
      );
      await _saveGrowthOffer(offer);
      await _saveGrowthTrigger(
        GrowthTrigger(
          id: 'trigger-welcome-${now.millisecondsSinceEpoch}',
          userId: user.id,
          type: 'welcome_offer',
          status: 'ready',
          title: 'Welcome journey',
          message: 'New user should receive a first-order personalized offer.',
          actionType: 'push_notification',
          createdAt: now.toIso8601String(),
          metadata: {
            'offerCode': offer.code,
            'productIds': recommendedIds,
            'deepLink': deepLink,
          },
        ),
      );
      _addNotification(
        AppNotification(
          id: 'growth-welcome-${now.millisecondsSinceEpoch}',
          title: 'Your first look deserves a reward',
          body: 'Use ${offer.code} on $leadingProductName and get Rs 100 off your first eligible order.',
          type: 'growth',
          isRead: false,
          timestamp: now,
          audienceRole: 'user',
          userId: user.id,
        ),
      );
    }

    if (hasAbandonedCart && !await _hasRecentGrowthTrigger(user.id, 'cart_abandonment')) {
      final offer = GrowthOffer(
        id: 'offer-cart-${now.millisecondsSinceEpoch}',
        userId: user.id,
        type: 'cart_recovery',
        title: 'Complete your checkout',
        subtitle: 'Your bag is waiting. Use COMPLETE10 for a gentle nudge.',
        code: _generatePersonalizedCouponCode('cart_recovery'),
        discountPercent: 0,
        discountAmount: 75,
        minOrderValue: 499,
        autoApply: true,
        createdAt: now.toIso8601String(),
        expiresAt: now.add(const Duration(days: 2)).toIso8601String(),
        metadata: {
          'productIds': recommendedIds,
          'deepLink': deepLink,
        },
      );
      await _saveGrowthOffer(offer);
      await _saveGrowthTrigger(
        GrowthTrigger(
          id: 'trigger-cart-${now.millisecondsSinceEpoch}',
          userId: user.id,
          type: 'cart_abandonment',
          status: 'ready',
          title: 'Recover abandoned cart',
          message: 'User has items waiting in the bag.',
          actionType: 'discount_push',
          createdAt: now.toIso8601String(),
          metadata: {
            'offerCode': offer.code,
            'discountAmount': offer.discountAmount,
            'productIds': recommendedIds,
            'deepLink': deepLink,
          },
        ),
      );
      _addNotification(
        AppNotification(
          id: 'growth-cart-${now.millisecondsSinceEpoch}',
          title: 'Your bag is waiting',
          body: 'Finish checkout with ${offer.code} and save Rs 75 on picks like $leadingProductName.',
          type: 'growth',
          isRead: false,
          timestamp: now,
          audienceRole: 'user',
          userId: user.id,
        ),
      );
    }

    if (isInactive && !await _hasRecentGrowthTrigger(user.id, 'inactive_user', window: const Duration(days: 3))) {
      final offer = GrowthOffer(
        id: 'offer-winback-${now.millisecondsSinceEpoch}',
        userId: user.id,
        type: 'winback',
        title: 'Come back to fresh picks',
        subtitle: 'We saved new styles you might like.',
        code: _generatePersonalizedCouponCode('winback'),
        discountPercent: 0,
        discountAmount: 50,
        minOrderValue: 499,
        createdAt: now.toIso8601String(),
        expiresAt: now.add(const Duration(days: 3)).toIso8601String(),
        metadata: {
          'productIds': recommendedIds,
          'deepLink': deepLink,
        },
      );
      await _saveGrowthOffer(offer);
      await _saveGrowthTrigger(
        GrowthTrigger(
          id: 'trigger-winback-${now.millisecondsSinceEpoch}',
          userId: user.id,
          type: 'inactive_user',
          status: 'ready',
          title: 'Win back user',
          message: 'User has been inactive for at least 7 days.',
          actionType: 'push_notification',
          createdAt: now.toIso8601String(),
          metadata: {
            'offerCode': offer.code,
            'productIds': recommendedIds,
            'deepLink': deepLink,
          },
        ),
      );
      _addNotification(
        AppNotification(
          id: 'growth-winback-${now.millisecondsSinceEpoch}',
          title: 'New looks are waiting',
          body: 'Come back to ABZORA, explore $leadingProductName, and use ${offer.code} for Rs 50 off.',
          type: 'growth',
          isRead: false,
          timestamp: now,
          audienceRole: 'user',
          userId: user.id,
        ),
      );
    }

    if (isFrequentBuyer &&
        !await _hasRecentGrowthTrigger(user.id, 'referral_offer', window: const Duration(days: 5))) {
      final referralCode = await ensureReferralCode(user);
      final vipOffer = GrowthOffer(
        id: 'offer-vip-${now.millisecondsSinceEpoch}',
        userId: user.id,
        type: 'vip_reward',
        title: 'VIP style reward',
        subtitle: 'Your loyalty unlocked an elevated offer on your next order.',
        code: _generatePersonalizedCouponCode('high_value'),
        discountPercent: 0,
        discountAmount: 30,
        minOrderValue: 499,
        createdAt: now.toIso8601String(),
        expiresAt: now.add(const Duration(days: 4)).toIso8601String(),
        metadata: {
          'productIds': recommendedIds,
          'deepLink': deepLink,
        },
      );
      await _saveGrowthOffer(vipOffer);
      await _saveGrowthTrigger(
        GrowthTrigger(
          id: 'trigger-referral-${now.millisecondsSinceEpoch}',
          userId: user.id,
          type: 'referral_offer',
          status: 'ready',
          title: 'Promote referral',
          message: 'High-value user is ready for a referral nudge.',
          actionType: 'referral',
          createdAt: now.toIso8601String(),
          metadata: {
            'referralCode': referralCode,
            'offerCode': vipOffer.code,
            'productIds': recommendedIds,
            'deepLink': deepLink,
          },
        ),
      );
      _addNotification(
        AppNotification(
          id: 'growth-referral-${now.millisecondsSinceEpoch}',
          title: 'VIP reward unlocked',
          body: 'Use ${vipOffer.code} on $leadingProductName for Rs 30 off, then invite friends with $referralCode to reward both wardrobes.',
          type: 'growth',
          isRead: false,
          timestamp: now,
          audienceRole: 'user',
          userId: user.id,
        ),
      );
    }

    if ((summary.lastViewedProductId ?? '').trim().isNotEmpty &&
        !hasAbandonedCart &&
        !await _hasRecentGrowthTrigger(user.id, 'product_interest', window: const Duration(days: 2))) {
      final offer = GrowthOffer(
        id: 'offer-interest-${now.millisecondsSinceEpoch}',
        userId: user.id,
        type: 'product_interest',
        title: 'Picked for your recent interest',
        subtitle: 'A focused offer on the styles you have been exploring.',
        code: summary.segment == 'vip' ? 'STYLE12' : 'STYLE8',
        discountPercent: summary.segment == 'vip' ? 12 : 8,
        createdAt: now.toIso8601String(),
        expiresAt: now.add(const Duration(days: 2)).toIso8601String(),
        metadata: {
          'productIds': recommendedIds,
          'deepLink': deepLink,
        },
      );
      await _saveGrowthOffer(offer);
      await _saveGrowthTrigger(
        GrowthTrigger(
          id: 'trigger-interest-${now.millisecondsSinceEpoch}',
          userId: user.id,
          type: 'product_interest',
          status: 'ready',
          title: 'Product interest detected',
          message: 'Recent browsing suggests a conversion opportunity.',
          actionType: 'personalized_offer',
          createdAt: now.toIso8601String(),
          metadata: {
            'offerCode': offer.code,
            'productIds': recommendedIds,
            'deepLink': deepLink,
          },
        ),
      );
      _addNotification(
        AppNotification(
          id: 'growth-interest-${now.millisecondsSinceEpoch}',
          title: 'Based on what you viewed',
          body: 'You might love $leadingProductName. Use ${offer.code} while it lasts.',
          type: 'growth',
          isRead: false,
          timestamp: now,
          audienceRole: 'user',
          userId: user.id,
        ),
      );
    }
  }

  Future<void> runMarketingAutomationSweep() async {
    final users = await _fetchCollection('users', (map, _) => AppUser.fromMap(map));
    for (final user in users.where((item) => item.isActive)) {
      await runGrowthAutomationForUser(user);
    }
  }

  Future<List<Product>> personalizeProductsForUser(
    List<Product> products, {
    AppUser? user,
  }) async {
    if (user == null || products.isEmpty) {
      return products;
    }
    if (_backendCommerce.isConfigured) {
      final summary = await getUserActivitySummary(user.id);
      final recentOrders = await getUserOrdersOnce(user.id);
      final orderedCategories = <String>{};
      for (final order in recentOrders.take(5)) {
        for (final item in order.items) {
          final matched = products.where((product) => product.id == item.productId);
          if (matched.isNotEmpty && matched.first.category.isNotEmpty) {
            orderedCategories.add(matched.first.category.toLowerCase());
          }
        }
      }

      int score(Product product) {
        var total = 0;
        total += (product.purchaseCount * 2);
        total += (product.rating * 5).round();
        if (summary.favoriteCategory != null &&
            product.category.toLowerCase() == summary.favoriteCategory!.toLowerCase()) {
          total += 25;
        }
        if (orderedCategories.contains(product.category.toLowerCase())) {
          total += 20;
        }
        if (product.isCustomTailoring) {
          total += 6;
        }
        return total;
      }

      final ranked = [...products]..sort((a, b) => score(b).compareTo(score(a)));
      return ranked;
    }
    final summary = await getUserActivitySummary(user.id);
    final viewMap = _asMap((await _ref('users/${user.id}/productViews').get()).value) ?? const <String, dynamic>{};
    final recentOrders = await getUserOrdersOnce(user.id);
    final orderedCategories = <String>{};
    for (final order in recentOrders.take(5)) {
      for (final item in order.items) {
        final product = await _fetchDocument(
          'products/${item.productId}',
          (map, id) => Product.fromMap(map, id),
        );
        if (product != null && product.category.isNotEmpty) {
          orderedCategories.add(product.category.toLowerCase());
        }
      }
    }

    int score(Product product) {
      var total = 0;
      final viewed = _asMap(viewMap[product.id]);
      total += ((viewed?['count'] as num?)?.toInt() ?? 0) * 8;
      total += (product.purchaseCount * 2);
      total += (product.rating * 5).round();
      if (summary.favoriteCategory != null &&
          product.category.toLowerCase() == summary.favoriteCategory!.toLowerCase()) {
        total += 25;
      }
      if (orderedCategories.contains(product.category.toLowerCase())) {
        total += 20;
      }
      if (product.isLimitedStock) {
        total += 8;
      }
      if (summary.segment == 'new' && product.hasDynamicDiscount) {
        total += 14;
      }
      return total;
    }

    final ranked = [...products]..sort((a, b) => score(b).compareTo(score(a)));
    return ranked;
  }

  bool isSuperAdmin(AppUser? actor) => actor != null && (actor.role == superAdminRole || actor.role == 'admin');
  bool isRider(AppUser? actor) => actor != null && actor.role == riderRole;

  bool canAccessStore(AppUser? actor, String storeId) {
    if (isSuperAdmin(actor)) {
      return true;
    }
    return actor != null && actor.role == 'vendor' && actor.storeId == storeId;
  }

  bool canAccessAssignedOrder(AppUser? actor, OrderModel order) {
    if (isSuperAdmin(actor)) {
      return true;
    }
    return isRider(actor) && order.riderId == actor!.id;
  }

  String _normalizeVendorStatus(String value) {
    final normalized = value.trim().toLowerCase().replaceAll('_', ' ');
    switch (normalized) {
      case 'placed':
        return 'Placed';
      case 'confirmed':
        return 'Confirmed';
      case 'packed':
        return 'Packed';
      case 'ready for pickup':
        return 'Ready for pickup';
      default:
        return value;
    }
  }

  String _validatedVendorOrderStatus(String current, String next) {
    final from = _normalizeVendorStatus(current);
    final to = _normalizeVendorStatus(next);
    if (from == to) {
      throw StateError('Order status is already $to.');
    }
    const allowed = <String, String>{
      'Placed': 'Confirmed',
      'Confirmed': 'Packed',
      'Packed': 'Ready for pickup',
    };
    final expected = allowed[from];
    if (expected == null || to != expected) {
      throw StateError('Vendor status transition is not allowed.');
    }
    return to;
  }

  String _normalizeRiderDeliveryStatus(String value) {
    final normalized = value.trim().toLowerCase().replaceAll('_', ' ');
    switch (normalized) {
      case 'assigned':
        return 'Assigned';
      case 'ready for pickup':
        return 'Ready for pickup';
      case 'picked up':
        return 'Picked up';
      case 'out for delivery':
        return 'Out for delivery';
      case 'delivered':
        return 'Delivered';
      default:
        return value;
    }
  }

  String _validatedRiderDeliveryStatus(OrderModel order, String next) {
    final from = _normalizeRiderDeliveryStatus(order.deliveryStatus);
    final to = _normalizeRiderDeliveryStatus(next);
    if (from == to) {
      throw StateError('Delivery status is already $to.');
    }
    const allowed = <String, Set<String>>{
      'Assigned': {'Picked up'},
      'Ready for pickup': {'Picked up'},
      'Picked up': {'Out for delivery'},
      'Out for delivery': {'Delivered'},
    };
    final expected = allowed[from];
    if (expected == null || !expected.contains(to)) {
      throw StateError('Rider delivery transition is not allowed.');
    }
    return to;
  }

  void _requireSuperAdmin(AppUser? actor) {
    if (!isSuperAdmin(actor)) {
      throw StateError('Super admin privileges required.');
    }
  }

  void _requireStoreAccess(AppUser? actor, String storeId) {
    if (!canAccessStore(actor, storeId)) {
      throw StateError('Cross-store access denied.');
    }
  }

  void _requireRiderAccess(AppUser? actor, OrderModel order) {
    if (!canAccessAssignedOrder(actor, order)) {
      throw StateError('Rider access denied.');
    }
  }

  String _buildTrackingId(String storeId) {
    final seed = DateTime.now().millisecondsSinceEpoch.toString();
    return 'TRK-${storeId.toUpperCase()}-${seed.substring(seed.length - 6)}';
  }

  String _buildInvoiceNumber(String storeId) {
    final date = DateFormat('yyMMdd').format(DateTime.now());
    final suffix = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
    return 'INV-$date-${storeId.toUpperCase()}-$suffix';
  }

  String _trackingKeyForStatus(String status) {
    final normalized = status.trim().toLowerCase();
    if (normalized == 'placed' || normalized == 'pending') {
      return 'Order Placed';
    }
    if (normalized == 'confirmed') {
      return 'Confirmed';
    }
    if (normalized == 'packed') {
      return 'Packed';
    }
    if (normalized == 'shipped' || normalized == 'out for delivery' || normalized == 'assigned') {
      return 'Out for Delivery';
    }
    if (normalized == 'delivered') {
      return 'Delivered';
    }
    return status;
  }

  String _nowIso() => DateTime.now().toIso8601String();

  Future<void> _ensureOrderIdAvailable(String orderId) async {
    final snapshot = await _ref('orders/$orderId').get();
    if (snapshot.exists) {
      throw StateError('Order already exists for id $orderId.');
    }
  }

  String _buildDeterministicOrderId(String storeId, String idempotencyKey) {
    final encoded = base64Url.encode(utf8.encode(idempotencyKey)).replaceAll('=', '');
    final cleaned = encoded.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    final length = cleaned.length > 24 ? 24 : cleaned.length;
    final safe = cleaned.substring(0, length);
    return 'ord-$storeId-$safe';
  }

  Future<void> _ensurePaymentReferenceAvailable(String userId, String? paymentReference, {String? orderId}) async {
    final reference = paymentReference?.trim();
    if (reference == null || reference.isEmpty) {
      return;
    }
    final claimKey = Uri.encodeComponent(reference);
    final snapshot = await _ref('paymentClaims/$claimKey').get();
    final existing = _asMap(snapshot.value);
    if (existing != null) {
      final existingUserId = existing['userId']?.toString();
      final existingOrderId = existing['orderId']?.toString();
      if (existingUserId != userId || (existingOrderId != null && existingOrderId != orderId)) {
        throw StateError('This payment reference has already been used.');
      }
      if (existingOrderId == null && orderId == null) {
        throw StateError('This payment reference has already been claimed.');
      }
      return;
    }
  }

  Future<OrderModel?> _findOrderByIdempotencyKey(String userId, String idempotencyKey) async {
    final claim = await _fetchDocument(
      'idempotencyClaims/$userId/${Uri.encodeComponent(idempotencyKey)}',
      (map, _) => map,
    );
    final orderId = claim?['orderId']?.toString();
    if (orderId == null || orderId.isEmpty) {
      return null;
    }
    return _fetchDocument('orders/$orderId', (map, id) => OrderModel.fromMap(map, id));
  }

  Map<String, String> _trackingTimestampsForStatus(OrderModel order, String status, String timestamp) {
    final timestamps = Map<String, String>.from(order.trackingTimestamps);
    timestamps[_trackingKeyForStatus(status)] = timestamp;
    return timestamps;
  }

  Future<void> _queueActivityLogWrite(
    Map<String, dynamic> updates, {
    required String action,
    required String targetType,
    required String targetId,
    required String message,
    required AppUser actor,
    String? timestamp,
  }) async {
    final entry = ActivityLogEntry(
      id: 'log-${DateTime.now().millisecondsSinceEpoch}',
      actorId: actor.id,
      actorRole: actor.role,
      action: action,
      targetType: targetType,
      targetId: targetId,
      message: message,
      timestamp: DateTime.tryParse(timestamp ?? '') ?? DateTime.now(),
    );
    final payload = {
      ...entry.toMap(),
      'createdAt': entry.timestamp.toIso8601String(),
    };
    updates['activityLogs/${entry.id}'] = payload;
    updates['logs/${entry.id}'] = payload;
    if (isSuperAdmin(actor)) {
      updates['adminLogs/${entry.id}'] = {
        ...payload,
        'userId': actor.id,
      };
    }
  }

  String _occasionFor(Product product) {
    final text = '${product.name} ${product.description} ${product.category}'.toLowerCase();
    if (text.contains('wedding') || text.contains('sherwani') || text.contains('tuxedo')) {
      return 'Wedding';
    }
    if (text.contains('formal') || text.contains('office') || text.contains('blazer')) {
      return 'Formal';
    }
    if (text.contains('party') || text.contains('evening')) {
      return 'Party';
    }
    return 'Everyday';
  }

  void _addNotification(AppNotification notification) {
    if (_backendCommerce.isConfigured) {
      unawaited(_backendCommerce.createAdminNotification(notification));
      return;
    }
    unawaited(_ref('notifications/${notification.id}').set(notification.toMap()));
  }

  String _kycFingerprint(String value) {
    final normalized = value.trim().toUpperCase();
    if (normalized.isEmpty) {
      return '';
    }
    return base64Url.encode(utf8.encode(normalized));
  }

  Future<bool> _reserveKycFingerprint({
    required String documentType,
    required String normalizedNumber,
    required String actorId,
  }) async {
    final fingerprint = _kycFingerprint(normalizedNumber);
    if (fingerprint.isEmpty) {
      return true;
    }
    try {
      await _ref('kycDocumentIndex/$documentType/$fingerprint').set(actorId);
      return true;
    } catch (error) {
      if (error.toString().toLowerCase().contains('permission-denied')) {
        return false;
      }
      rethrow;
    }
  }

  Future<KycVerificationSummary> _finalizeVendorKycVerification({
    required KycVerificationSummary verification,
    required AppUser actor,
    required VendorKycRequest request,
  }) async {
    final flags = <String>[...verification.flags];
    final duplicateMatches = <String>[...verification.duplicateMatches];
    var duplicateDetected = verification.duplicateDetected;

    if (verification.aadhaarValid) {
      final reserved = await _reserveKycFingerprint(
        documentType: 'aadhaar',
        normalizedNumber: verification.aadhaarNumber,
        actorId: actor.id,
      );
      if (!reserved) {
        duplicateDetected = true;
        flags.add('Aadhaar is already linked to another partner account.');
        duplicateMatches.add('aadhaar');
      }
    }

    if (verification.panValid) {
      final reserved = await _reserveKycFingerprint(
        documentType: 'pan',
        normalizedNumber: verification.panNumber,
        actorId: actor.id,
      );
      if (!reserved) {
        duplicateDetected = true;
      flags.add('PAN is already linked to another partner account.');
      duplicateMatches.add('pan');
      }
    }

    final gpsValid = request.latitude.abs() > 0.01 && request.longitude.abs() > 0.01;
    final normalizedOwnerName = request.ownerName.trim().toLowerCase();
    final normalizedExtractedName = verification.extractedName.trim().toLowerCase();
    final nameMatch = normalizedOwnerName.isNotEmpty &&
        normalizedExtractedName.isNotEmpty &&
        (normalizedOwnerName == normalizedExtractedName ||
            normalizedOwnerName.contains(normalizedExtractedName) ||
            normalizedExtractedName.contains(normalizedOwnerName));
    final addressMatch =
        request.address.trim().isNotEmpty && request.city.trim().isNotEmpty;
    final suspiciousBehavior =
        verification.selfieRetryCount >= 3 || actor.createdAt == null || actor.createdAt!.isEmpty;
    final multipleAccounts = duplicateMatches.length > 1;

    var riskScore = 0;
    final riskReasons = <String>[];
    if (verification.aadhaarValid) {
      riskScore += 25;
      riskReasons.add('Aadhaar format verified.');
    } else {
      riskReasons.add('Aadhaar format failed validation.');
    }
    if (verification.panValid) {
      riskScore += 20;
      riskReasons.add('PAN format verified.');
    } else {
      riskReasons.add('PAN format failed validation.');
    }
    if (nameMatch) {
      riskScore += 15;
      riskReasons.add('Uploaded name matches extracted document name.');
    } else {
      riskReasons.add('Document name did not fully match the submitted owner name.');
    }
    if (verification.faceVerified && verification.matchScore > 90) {
      riskScore += 25;
      riskReasons.add('Live selfie matched document photo strongly.');
    } else if (verification.matchScore > 0) {
      riskReasons.add('Face match was below the strong-match threshold.');
    } else {
      riskReasons.add('Face match data is unavailable.');
    }
    if (verification.livenessPassed) {
      riskScore += 10;
      riskReasons.add('Liveness verification passed.');
    } else {
      riskReasons.add('Liveness verification did not pass.');
    }
    if (gpsValid) {
      riskScore += 10;
      riskReasons.add('Store GPS coordinates were captured.');
    } else {
      riskReasons.add('GPS coordinates were missing or unclear.');
    }
    if (addressMatch) {
      riskScore += 5;
      riskReasons.add('Address and city details were completed.');
    } else {
      riskReasons.add('Address details were incomplete.');
    }
    if (duplicateMatches.contains('pan')) {
      riskScore -= 40;
      riskReasons.add('Duplicate PAN detected.');
    }
    if (multipleAccounts) {
      riskScore -= 30;
      riskReasons.add('Multiple accounts were linked to the same device or identity.');
    }
    if (suspiciousBehavior) {
      riskScore -= 20;
      riskReasons.add('Suspicious retry or account-age behavior was detected.');
    }
    riskScore = riskScore.clamp(0, 100);

    final riskDecision = riskScore >= 85
        ? 'approved'
        : riskScore >= 60
            ? 'review'
            : 'rejected';

    final autoReviewStatus = duplicateDetected
        ? 'fraud_flagged'
        : verification.confidenceScore >= 85 &&
                verification.aadhaarValid &&
                verification.panValid &&
                verification.livenessPassed &&
                verification.faceVerified &&
                verification.matchScore >= 85
            ? 'auto_verified'
            : 'pending_review';

    final reviewSummary = switch (autoReviewStatus) {
      'fraud_flagged' => 'Documents were flagged for duplicate or suspicious details.',
      'auto_verified' => 'Documents look strong for fast approval.',
      _ => riskDecision == 'rejected'
          ? 'Documents failed automated approval and should be rejected or re-submitted.'
          : 'Documents need manual review before approval.',
    };

    return verification.copyWith(
      duplicateDetected: duplicateDetected,
      duplicateMatches: duplicateMatches.toSet().toList(),
      flags: flags.toSet().toList(),
      autoReviewStatus: autoReviewStatus,
      reviewSummary: reviewSummary,
      riskScore: riskScore,
      riskDecision: riskDecision,
      riskReasons: riskReasons,
      gpsValid: gpsValid,
      nameMatch: nameMatch,
      addressMatch: addressMatch,
    );
  }

  Stream<List<Product>> watchAllProducts() {
    if (_backendCommerce.isConfigured) {
      return (() async* {
        yield await _backendCommerce.getProducts();
        while (true) {
          await Future<void>.delayed(const Duration(seconds: 20));
          yield await _backendCommerce.getProducts();
        }
      })();
    }
    return _productService.watchAll().map(
      (products) => products.map(_decorateProduct).toList(),
    );
  }

  Future<void> logActivity({
    required String action,
    required String targetType,
    required String targetId,
    required String message,
    required AppUser actor,
  }) async {
    final entry = ActivityLogEntry(
      id: 'log-${DateTime.now().millisecondsSinceEpoch}',
      actorId: actor.id,
      actorRole: actor.role,
      action: action,
      targetType: targetType,
      targetId: targetId,
      message: message,
      timestamp: DateTime.now(),
    );
    if (_backendCommerce.isConfigured) {
      await _backendCommerce.createAdminActivityLog(entry);
      return;
    }
    final payload = {
      ...entry.toMap(),
      'createdAt': entry.timestamp.toIso8601String(),
    };
    final updates = <String, dynamic>{
      'activityLogs/${entry.id}': payload,
      'logs/${entry.id}': payload,
    };
    if (isSuperAdmin(actor)) {
      updates['adminLogs/${entry.id}'] = {
        ...payload,
        'userId': actor.id,
      };
    }
    await _ref('').update(updates);
  }

  double _averageRating(List<ReviewModel> reviews) {
    if (reviews.isEmpty) {
      return 0;
    }
    final total = reviews.fold<double>(0, (runningTotal, review) => runningTotal + review.rating);
    return total / reviews.length;
  }

  double _clampUnit(double value) => value.clamp(0.0, 1.0).toDouble();

  DateTime? _parseInstant(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    return DateTime.tryParse(trimmed);
  }

  double _hoursBetween(DateTime? start, DateTime? end) {
    if (start == null || end == null || end.isBefore(start)) {
      return 0;
    }
    return end.difference(start).inMinutes / 60.0;
  }

  double _reviewSentimentScore(List<ReviewModel> reviews) {
    if (reviews.isEmpty) {
      return 0.5;
    }

    const positiveWords = <String>{
      'good',
      'great',
      'excellent',
      'amazing',
      'perfect',
      'fast',
      'love',
      'nice',
      'quality',
      'happy',
      'smooth',
      'premium',
      'best',
    };
    const negativeWords = <String>{
      'bad',
      'poor',
      'slow',
      'late',
      'worst',
      'damaged',
      'return',
      'refund',
      'broken',
      'delay',
      'issue',
      'problem',
      'cancel',
    };

    var total = 0.0;
    for (final review in reviews) {
      final normalized = review.comment.toLowerCase();
      var score = review.rating >= 4
          ? 0.75
          : review.rating <= 2
              ? 0.25
              : 0.5;
      for (final word in positiveWords) {
        if (normalized.contains(word)) {
          score += 0.05;
        }
      }
      for (final word in negativeWords) {
        if (normalized.contains(word)) {
          score -= 0.05;
        }
      }
      total += _clampUnit(score);
    }
    return total / reviews.length;
  }

  VendorPerformanceMetrics _buildVendorPerformanceMetrics(
    Store store,
    List<OrderModel> storeOrders,
    List<ReviewModel> storeReviews,
  ) {
    final totalOrders = storeOrders.length;
    final completedOrders = storeOrders.where((order) {
      final status = order.status.trim().toLowerCase();
      final delivery = order.deliveryStatus.trim().toLowerCase();
      return order.isDelivered || status == 'delivered' || delivery == 'delivered';
    }).length;
    final cancelledOrders =
        storeOrders.where((order) => order.status.trim().toLowerCase() == 'cancelled').length;
    final returnedOrders = storeOrders.where((order) {
      final status = order.returnStatus.trim().toLowerCase();
      return status.isNotEmpty && status != 'rejected';
    }).length;

    final deliveryHours = <double>[];
    final responseHours = <double>[];
    final customerFrequency = <String, int>{};
    var totalRevenue = 0.0;

    for (final order in storeOrders) {
      customerFrequency.update(order.userId, (value) => value + 1, ifAbsent: () => 1);
      final delivered = order.isDelivered ||
          order.status.trim().toLowerCase() == 'delivered' ||
          order.deliveryStatus.trim().toLowerCase() == 'delivered';
      if (delivered) {
        totalRevenue += order.totalAmount;
      }

      final placedAt = order.timestamp;
      final deliveredAt =
          _parseInstant(order.deliveredAt) ?? _parseInstant(order.trackingTimestamps['Delivered']);
      final firstResponseAt = _parseInstant(order.trackingTimestamps['Confirmed']) ??
          _parseInstant(order.trackingTimestamps['Packed']) ??
          _parseInstant(order.trackingTimestamps['Ready for pickup']) ??
          _parseInstant(order.updatedAt);

      final deliveryDelta = _hoursBetween(placedAt, deliveredAt);
      if (deliveryDelta > 0) {
        deliveryHours.add(deliveryDelta);
      }

      final responseDelta = _hoursBetween(placedAt, firstResponseAt);
      if (responseDelta > 0) {
        responseHours.add(responseDelta);
      }
    }

    final repeatCustomers = customerFrequency.values.where((count) => count > 1).length;
    final repeatCustomerRate =
        customerFrequency.isEmpty ? 0.0 : repeatCustomers / customerFrequency.length;

    double average(List<double> values) =>
        values.isEmpty ? 0.0 : values.reduce((left, right) => left + right) / values.length;

    return VendorPerformanceMetrics(
      totalOrders: totalOrders,
      completedOrders: completedOrders,
      cancellationRate: totalOrders == 0 ? 0.0 : cancelledOrders / totalOrders,
      returnRate: totalOrders == 0 ? 0.0 : returnedOrders / totalOrders,
      averageRating: storeReviews.isEmpty ? store.rating : _averageRating(storeReviews),
      reviewSentiment: _reviewSentimentScore(storeReviews),
      averageDeliveryHours: average(deliveryHours),
      averageResponseHours: average(responseHours),
      totalRevenue: totalRevenue,
      repeatCustomerRate: repeatCustomerRate,
      updatedAt: _nowIso(),
    );
  }

  int _calculateVendorScore(VendorPerformanceMetrics metrics) {
    final completionRate =
        metrics.totalOrders == 0 ? 0.0 : metrics.completedOrders / metrics.totalOrders;
    var score = 0.0;

    score += _clampUnit(completionRate) * 30;
    score += _clampUnit(1 - metrics.cancellationRate) * 20;
    score += _clampUnit(1 - metrics.returnRate) * 15;
    score += _clampUnit(metrics.averageRating / 5) * 20;
    score += _clampUnit(metrics.reviewSentiment) * 10;
    score += _clampUnit(1 - (metrics.averageDeliveryHours / 72)) * 10;
    score += _clampUnit(1 - (metrics.averageResponseHours / 24)) * 5;
    score += _clampUnit(metrics.totalRevenue / 50000) * 15;
    score += _clampUnit(metrics.repeatCustomerRate) * 10;

    if (metrics.cancellationRate >= 0.2) {
      score -= 20;
    }
    if (metrics.returnRate >= 0.15) {
      score -= 15;
    }

    return score.clamp(0, 100).round();
  }

  String _vendorVisibilityForScore(int score) {
    if (score >= 85) {
      return 'boosted';
    }
    if (score >= 70) {
      return 'normal';
    }
    if (score >= 50) {
      return 'lowered';
    }
    return 'reduced';
  }

  Future<void> refreshVendorRankings() async {
    final stores = await _fetchCollection('stores', (map, id) => Store.fromMap(map, id));
    if (stores.isEmpty) {
      return;
    }

    final orders = await getAllOrders();
    final reviews = await _fetchCollection('reviews', (map, id) => ReviewModel.fromMap(map, id));
    final scoredStores = stores.map((store) {
      final storeOrders = orders.where((order) => order.storeId == store.id).toList();
      final storeReviews = reviews
          .where((review) => review.targetType == 'store' && review.targetId == store.id)
          .toList();
      final metrics = _buildVendorPerformanceMetrics(store, storeOrders, storeReviews);
      final vendorScore = _calculateVendorScore(metrics);
      return store.copyWith(
        vendorScore: vendorScore.toDouble(),
        vendorVisibility: _vendorVisibilityForScore(vendorScore),
        performanceMetrics: metrics,
      );
    }).toList()
      ..sort((left, right) {
        final scoreCompare = right.vendorScore.compareTo(left.vendorScore);
        if (scoreCompare != 0) {
          return scoreCompare;
        }
        return right.performanceMetrics.totalRevenue.compareTo(left.performanceMetrics.totalRevenue);
      });

    final updates = <String, dynamic>{};
    for (var index = 0; index < scoredStores.length; index++) {
      final rankedStore = scoredStores[index].copyWith(vendorRank: index + 1);
      updates['stores/${rankedStore.id}/vendorScore'] = rankedStore.vendorScore;
      updates['stores/${rankedStore.id}/vendorRank'] = rankedStore.vendorRank;
      updates['stores/${rankedStore.id}/vendorVisibility'] = rankedStore.vendorVisibility;
      updates['stores/${rankedStore.id}/performanceMetrics'] =
          rankedStore.performanceMetrics.toMap();
      updates['vendorRankings/${rankedStore.id}'] = {
        'vendorId': rankedStore.id,
        'vendorScore': rankedStore.vendorScore,
        'rank': rankedStore.vendorRank,
        'visibility': rankedStore.vendorVisibility,
        'performanceMetrics': rankedStore.performanceMetrics.toMap(),
        'updatedAt': rankedStore.performanceMetrics.updatedAt,
      };
    }

    if (updates.isNotEmpty) {
      await _ref('').update(updates);
      unawaited(refreshVendorRankings());
    }
  }

  List<ReviewModel> _reviewsFor(String targetId, String targetType) {
    return const [];
  }

  Product _decorateProduct(Product product) {
    final reviews = _reviewsFor(product.id, 'product');
    if (reviews.isEmpty) {
      return product;
    }

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
      isActive: product.isActive,
      createdAt: product.createdAt,
      rating: _averageRating(reviews),
      reviewCount: reviews.length,
      lastPriceUpdated: product.lastPriceUpdated,
      isCustomTailoring: product.isCustomTailoring,
      outfitType: product.outfitType,
      fabric: product.fabric,
      customizations: product.customizations,
      measurements: product.measurements,
      addons: product.addons,
      measurementProfileLabel: product.measurementProfileLabel,
      neededBy: product.neededBy,
      tailoringDeliveryMode: product.tailoringDeliveryMode,
      tailoringExtraCost: product.tailoringExtraCost,
    );
  }

  double _normalizedDemandScore(Product product) {
    final weightedDemand =
        (product.viewCount * 0.2) + (product.cartCount * 0.3) + (product.purchaseCount * 0.5);
    return (weightedDemand.clamp(0.0, 100.0)).toDouble();
  }

  bool _isNewUser(AppUser user) {
    final createdAt = DateTime.tryParse(user.createdAt ?? '');
    if (createdAt == null) {
      return false;
    }
    return DateTime.now().difference(createdAt).inDays <= 14;
  }

  double _roundPriceForDisplay(double value) {
    final rounded = (value / 10).round() * 10;
    return rounded <= 0 ? value : rounded.toDouble();
  }

  bool _isReturningUser(AppUser user) => !_isNewUser(user);

  double _seasonalTrendMultiplier(Product product) {
    final month = DateTime.now().month;
    final category = product.category.toLowerCase();
    if ((category.contains('wedding') || category.contains('ethnic')) &&
        (month >= 10 || month <= 2)) {
      return 0.06;
    }
    if (category.contains('summer') && month >= 3 && month <= 6) {
      return 0.04;
    }
    if (category.contains('winter') && (month == 11 || month == 12 || month == 1)) {
      return 0.04;
    }
    return 0.0;
  }

  double _timeOfDayMultiplier() {
    final hour = DateTime.now().hour;
    if (hour >= 19 && hour <= 23) {
      return 0.04;
    }
    if (hour >= 0 && hour <= 6) {
      return -0.03;
    }
    return 0.0;
  }

  Product _dynamicProductForViewer(
    Product product, {
    AppUser? user,
    int userViewCount = 0,
    double vendorScore = 0,
  }) {
    final basePrice = product.basePrice ?? product.price;
    final demandScore =
        product.demandScore > 0 ? product.demandScore : _normalizedDemandScore(product);
    final highDemandIncrease = demandScore >= 85
        ? 0.15
        : demandScore >= 70
            ? 0.1
            : demandScore >= 55
                ? 0.05
                : 0.0;
    final lowDemandDiscount = demandScore <= 20 ? 0.10 : demandScore <= 35 ? 0.05 : 0.0;
    final stockIncrease = product.stock <= 5 ? 0.05 : 0.0;
    final vendorBoost = vendorScore >= 85 ? 0.03 : vendorScore >= 70 ? 0.01 : 0.0;
    final newUserDiscount = user != null && _isNewUser(user) ? 0.10 : 0.0;
    final returningUserDiscount = user != null && _isReturningUser(user) ? 0.05 : 0.0;
    final repeatViewDiscount = userViewCount >= 4 ? 0.05 : 0.0;
    final seasonalAdjustment = _seasonalTrendMultiplier(product);
    final timeAdjustment = _timeOfDayMultiplier();
    final rawMultiplier = 1 +
        highDemandIncrease +
        stockIncrease +
        vendorBoost +
        seasonalAdjustment +
        timeAdjustment -
        newUserDiscount -
        returningUserDiscount -
        repeatViewDiscount -
        lowDemandDiscount;
    final clampedMultiplier = rawMultiplier.clamp(0.8, 1.2).toDouble();
    final currentMultiplier =
        (product.dynamicPrice ?? basePrice) <= 0 ? 1.0 : (product.dynamicPrice ?? basePrice) / basePrice;
    final smoothedMultiplier =
        (currentMultiplier + clampedMultiplier) / (product.dynamicPrice == null ? 1 : 2);
    final boundedMultiplier = smoothedMultiplier.clamp(0.8, 1.2).toDouble();
    final dynamicPrice = _roundPriceForDisplay(basePrice * boundedMultiplier);
    final comparisonPrice = dynamicPrice < basePrice
        ? basePrice
        : product.originalPrice;

    return Product(
      id: product.id,
      storeId: product.storeId,
      name: product.name,
      brand: product.brand,
      description: product.description,
      price: product.price,
      basePrice: basePrice,
      dynamicPrice: dynamicPrice,
      originalPrice: comparisonPrice,
      demandScore: demandScore,
      viewCount: product.viewCount,
      cartCount: product.cartCount,
      purchaseCount: product.purchaseCount,
      images: product.images,
      sizes: product.sizes,
      stock: product.stock,
      category: product.category,
      isActive: product.isActive,
      createdAt: product.createdAt,
      rating: product.rating,
      reviewCount: product.reviewCount,
      lastPriceUpdated: _nowIso(),
      isCustomTailoring: product.isCustomTailoring,
      outfitType: product.outfitType,
      fabric: product.fabric,
      customizations: product.customizations,
      measurements: product.measurements,
      addons: product.addons,
      measurementProfileLabel: product.measurementProfileLabel,
      neededBy: product.neededBy,
      tailoringDeliveryMode: product.tailoringDeliveryMode,
      tailoringExtraCost: product.tailoringExtraCost,
    );
  }

  Store _decorateStore(Store store) {
    final reviews = _reviewsFor(store.id, 'store');
    if (reviews.isEmpty) {
      return store;
    }

    return Store(
      id: store.id,
      storeId: store.storeId,
      ownerId: store.ownerId,
      name: store.name,
      description: store.description,
      imageUrl: store.imageUrl,
      rating: _averageRating(reviews),
      reviewCount: reviews.length,
      address: store.address,
      city: store.city,
      isApproved: store.isApproved,
      isActive: store.isActive,
      isFeatured: store.isFeatured,
      approvalStatus: store.approvalStatus,
      logoUrl: store.logoUrl,
      bannerImageUrl: store.bannerImageUrl,
      tagline: store.tagline,
      commissionRate: store.commissionRate,
      walletBalance: store.walletBalance,
      latitude: store.latitude,
      longitude: store.longitude,
      category: store.category,
      vendorScore: store.vendorScore,
      vendorRank: store.vendorRank,
      vendorVisibility: store.vendorVisibility,
      performanceMetrics: store.performanceMetrics,
    );
  }

  Future<List<Store>> getStores() async {
    if (_backendCommerce.isConfigured) {
      final stores = await _backendCommerce.getStores();
      return stores.map(_decorateStore).toList();
    }
    final stores = await _fetchCollection('stores', (map, id) => Store.fromMap(map, id));
    return stores.where((store) => store.isApproved && store.isActive).map(_decorateStore).toList()
      ..sort((left, right) {
        final visibilityOrder = <String, int>{
          'boosted': 0,
          'normal': 1,
          'lowered': 2,
          'reduced': 3,
        };
        final visibilityCompare = (visibilityOrder[left.vendorVisibility] ?? 9)
            .compareTo(visibilityOrder[right.vendorVisibility] ?? 9);
        if (visibilityCompare != 0) {
          return visibilityCompare;
        }
        final rankCompare = left.vendorRank.compareTo(right.vendorRank);
        if (rankCompare != 0) {
          return rankCompare;
        }
        return right.vendorScore.compareTo(left.vendorScore);
      });
  }

  Future<List<Store>> getAdminStores() async {
    if (_backendCommerce.isConfigured) {
      return _backendCommerce.getAdminStores();
    }
    final stores = await _fetchCollection('stores', (map, id) => Store.fromMap(map, id));
    return stores.map(_decorateStore).toList()
      ..sort((left, right) => left.vendorRank.compareTo(right.vendorRank));
  }

  Future<Store?> getStoreByOwner(String ownerId) async {
    if (_backendCommerce.isConfigured) {
      return _backendCommerce.getOwnStore();
    }
    final stores = await getAdminStores();
    for (final store in stores) {
      if (store.ownerId == ownerId) {
        return store;
      }
    }
    return null;
  }

  Future<List<Product>> getProductsByStore(String storeId) async {
    if (_backendCommerce.isConfigured) {
      final products = await _backendCommerce.getProducts();
      return products.where((product) => product.storeId == storeId).map(_decorateProduct).toList();
    }
    final products = (await _productService.fetchAll()).map(_decorateProduct).toList();
    return products.where((product) => product.storeId == storeId).toList();
  }

  Future<List<Product>> getTrendingProducts() async {
    final products = (await _productService.fetchAll()).map(_decorateProduct).toList();
    return products.take(10).toList();
  }

  Future<List<Product>> getStylistCatalog({
    int limit = 60,
    String? category,
  }) async {
    final products = (await _productService.fetchAll())
        .map(_decorateProduct)
        .where((product) => product.isActive && product.stock > 0)
        .where((product) => category == null || category.isEmpty || product.category == category)
        .toList()
      ..sort((a, b) {
        final left = (b.demandScore * 100).round() + (b.purchaseCount * 4) + (b.rating * 10).round();
        final right = (a.demandScore * 100).round() + (a.purchaseCount * 4) + (a.rating * 10).round();
        return left.compareTo(right);
      });
    if (products.length <= limit) {
      return products;
    }
    return products.take(limit).toList();
  }

  Future<ProductPageResult> getProductsPage({
    int limit = 20,
    String? startAfterKey,
  }) async {
    if (_backendCommerce.isConfigured) {
      final products = (await _backendCommerce.getProducts()).map(_decorateProduct).toList();
      final startIndex = startAfterKey == null
          ? 0
          : products.indexWhere((item) => item.id == startAfterKey) + 1;
      final safeStart = startIndex < 0 ? 0 : startIndex;
      final pageItems = products.skip(safeStart).take(limit).toList();
      final lastKey = pageItems.isEmpty ? startAfterKey : pageItems.last.id;
      final hasMore = safeStart + pageItems.length < products.length;
      return ProductPageResult(
        items: pageItems,
        lastKey: lastKey,
        hasMore: hasMore,
      );
    }
    final page = await _productService.fetchPage(limit: limit, startAfterKey: startAfterKey);
    return ProductPageResult(
      items: page.items.map(_decorateProduct).toList(),
      lastKey: page.lastKey,
      hasMore: page.hasMore,
    );
  }

  Future<int> _userViewCountForProduct(String userId, String productId) async {
    final snapshot = await _ref('users/$userId/productViews/$productId/count').get();
    if (!snapshot.exists) {
      return 0;
    }
    return (snapshot.value as num?)?.toInt() ?? 0;
  }

  Future<Product> getDynamicPrice(Product product, {AppUser? user}) async {
    if (_backendCommerce.isConfigured) {
      final userViewCount = user == null ? 0 : 0;
      final stores = await _backendCommerce.getStores();
      final matchedStore = stores.where((store) => store.id == product.storeId);
      final store = matchedStore.isEmpty ? null : matchedStore.first;
      return _dynamicProductForViewer(
        _decorateProduct(product),
        user: user,
        userViewCount: userViewCount,
        vendorScore: store?.vendorScore ?? 0,
      );
    }
    final userViewCount =
        user == null ? 0 : await _userViewCountForProduct(user.id, product.id);
    final store = await _fetchDocument('stores/${product.storeId}', (map, id) => Store.fromMap(map, id));
    return _dynamicProductForViewer(
      _decorateProduct(product),
      user: user,
      userViewCount: userViewCount,
      vendorScore: store?.vendorScore ?? 0,
    );
  }

  Future<void> recordProductView(Product product, {AppUser? user}) async {
    if (_backendCommerce.isConfigured) {
      if (user != null) {
        final summary = await getUserActivitySummary(user.id);
        await _saveUserActivitySummary(
          summary.copyWith(
            productViewCount: summary.productViewCount + 1,
            lastProductViewAt: _nowIso(),
            lastActiveAt: _nowIso(),
            lastViewedProductId: product.id,
            favoriteCategory: product.category.isNotEmpty ? product.category : summary.favoriteCategory,
            segment: _growthSegmentFor(
              orderCount: summary.orderCount,
              totalSpend: summary.totalSpend,
              cartAbandoned: summary.cartAbandoned,
            ),
          ),
        );
        try {
          await _backendCommerce.trackOutfitInteraction(
            action: 'view',
            productId: product.id,
            itemIds: [product.id],
            metadata: {
              'source': 'product_view',
              'category': product.category,
            },
          );
        } catch (_) {
          // Style tracking should never block the product page.
        }
      }
      return;
    }
    final nowIso = _nowIso();
    final updatedProduct = Product(
      id: product.id,
      storeId: product.storeId,
      name: product.name,
      brand: product.brand,
      description: product.description,
      price: product.price,
      basePrice: product.basePrice ?? product.price,
      dynamicPrice: product.dynamicPrice,
      originalPrice: product.originalPrice,
      demandScore: product.demandScore > 0 ? product.demandScore : _normalizedDemandScore(product),
      viewCount: product.viewCount + 1,
      cartCount: product.cartCount,
      purchaseCount: product.purchaseCount,
      images: product.images,
      sizes: product.sizes,
      stock: product.stock,
      category: product.category,
      isActive: product.isActive,
      createdAt: product.createdAt,
      rating: product.rating,
      reviewCount: product.reviewCount,
      lastPriceUpdated: nowIso,
      isCustomTailoring: product.isCustomTailoring,
      outfitType: product.outfitType,
      fabric: product.fabric,
      customizations: product.customizations,
      measurements: product.measurements,
      addons: product.addons,
      measurementProfileLabel: product.measurementProfileLabel,
      neededBy: product.neededBy,
      tailoringDeliveryMode: product.tailoringDeliveryMode,
      tailoringExtraCost: product.tailoringExtraCost,
    );
    await _productService.update(updatedProduct);
    if (user == null) {
      unawaited(refreshDynamicPrice(updatedProduct));
      return;
    }
    final countRef = _ref('users/${user.id}/productViews/${product.id}');
    final snapshot = await countRef.get();
    final existing = _asMap(snapshot.value) ?? const <String, dynamic>{};
    final count = ((existing['count'] as num?)?.toInt() ?? 0) + 1;
    await countRef.set({
      'count': count,
      'lastViewedAt': nowIso,
      'productName': product.name,
    });
    final summary = await getUserActivitySummary(user.id);
    await _saveUserActivitySummary(
      summary.copyWith(
        productViewCount: summary.productViewCount + 1,
        lastProductViewAt: nowIso,
        lastActiveAt: nowIso,
        lastViewedProductId: product.id,
        favoriteCategory: product.category.isNotEmpty ? product.category : summary.favoriteCategory,
        segment: _growthSegmentFor(
          orderCount: summary.orderCount,
          totalSpend: summary.totalSpend,
          cartAbandoned: summary.cartAbandoned,
        ),
      ),
    );
    await _logUserActivityEvent(
      userId: user.id,
      type: 'product_view',
      payload: {
        'productId': product.id,
        'productName': product.name,
        'category': product.category,
      },
    );
    unawaited(refreshDynamicPrice(updatedProduct));
  }

  Future<void> recordProductCartIntent(Product product, {int quantity = 1}) async {
    if (quantity <= 0) {
      return;
    }
    if (_backendCommerce.isConfigured) {
      try {
        await _backendCommerce.trackOutfitInteraction(
          action: 'cart',
          productId: product.id,
          itemIds: List<String>.filled(quantity, product.id),
          metadata: {
            'source': 'cart_intent',
            'quantity': quantity,
            'category': product.category,
          },
        );
      } catch (_) {
        // Cart flow should stay responsive even if recommendation tracking fails.
      }
      return;
    }
    final nowIso = _nowIso();
    final updatedProduct = Product(
      id: product.id,
      storeId: product.storeId,
      name: product.name,
      brand: product.brand,
      description: product.description,
      price: product.price,
      basePrice: product.basePrice ?? product.price,
      dynamicPrice: product.dynamicPrice,
      originalPrice: product.originalPrice,
      demandScore: product.demandScore > 0 ? product.demandScore : _normalizedDemandScore(product),
      viewCount: product.viewCount,
      cartCount: product.cartCount + quantity,
      purchaseCount: product.purchaseCount,
      images: product.images,
      sizes: product.sizes,
      stock: product.stock,
      category: product.category,
      isActive: product.isActive,
      createdAt: product.createdAt,
      rating: product.rating,
      reviewCount: product.reviewCount,
      lastPriceUpdated: nowIso,
      isCustomTailoring: product.isCustomTailoring,
      outfitType: product.outfitType,
      fabric: product.fabric,
      customizations: product.customizations,
      measurements: product.measurements,
      addons: product.addons,
      measurementProfileLabel: product.measurementProfileLabel,
      neededBy: product.neededBy,
      tailoringDeliveryMode: product.tailoringDeliveryMode,
      tailoringExtraCost: product.tailoringExtraCost,
    );
    await _productService.update(updatedProduct);
    unawaited(refreshDynamicPrice(updatedProduct));
  }

  Future<void> refreshDynamicPrice(Product product) async {
    if (_backendCommerce.isConfigured) {
      return;
    }
    final store = await _fetchDocument('stores/${product.storeId}', (map, id) => Store.fromMap(map, id));
    final refreshed = _dynamicProductForViewer(
      _decorateProduct(product),
      vendorScore: store?.vendorScore ?? 0,
    );
    await _productService.update(
      Product(
        id: refreshed.id,
        storeId: refreshed.storeId,
        name: refreshed.name,
        brand: refreshed.brand,
        description: refreshed.description,
        price: refreshed.price,
        basePrice: refreshed.basePrice,
        dynamicPrice: refreshed.dynamicPrice,
        originalPrice: refreshed.originalPrice,
        demandScore: refreshed.demandScore,
        viewCount: refreshed.viewCount,
        cartCount: refreshed.cartCount,
        purchaseCount: refreshed.purchaseCount,
        images: refreshed.images,
        sizes: refreshed.sizes,
        stock: refreshed.stock,
        category: refreshed.category,
        isActive: refreshed.isActive,
        createdAt: refreshed.createdAt,
        rating: refreshed.rating,
        reviewCount: refreshed.reviewCount,
        lastPriceUpdated: refreshed.lastPriceUpdated,
        isCustomTailoring: refreshed.isCustomTailoring,
        outfitType: refreshed.outfitType,
        fabric: refreshed.fabric,
        customizations: refreshed.customizations,
        measurements: refreshed.measurements,
        addons: refreshed.addons,
        measurementProfileLabel: refreshed.measurementProfileLabel,
        neededBy: refreshed.neededBy,
        tailoringDeliveryMode: refreshed.tailoringDeliveryMode,
        tailoringExtraCost: refreshed.tailoringExtraCost,
      ),
    );
  }

  Future<void> refreshDynamicPricingForCatalog() async {
    final products = (await _productService.fetchAll()).map(_decorateProduct).toList();
    final orders = await getAllOrders();
    final users = await getUsers();
    final purchaseCounts = <String, int>{};
    for (final order in orders) {
      for (final item in order.items) {
        purchaseCounts.update(
          item.productId,
          (value) => value + item.quantity,
          ifAbsent: () => item.quantity,
        );
      }
    }
    final userViewTotals = <String, int>{};
    for (final user in users) {
      final snapshot = await _ref('users/${user.id}/productViews').get();
      final data = _asMap(snapshot.value);
      if (data == null) {
        continue;
      }
      for (final entry in data.entries) {
        final viewMap = _asMap(entry.value);
        final count = (viewMap?['count'] as num?)?.toInt() ?? 0;
        if (count <= 0) {
          continue;
        }
        userViewTotals.update(entry.key, (value) => value + count, ifAbsent: () => count);
      }
    }
    for (final product in products) {
      final enriched = Product(
        id: product.id,
        storeId: product.storeId,
        name: product.name,
        brand: product.brand,
        description: product.description,
        price: product.price,
        basePrice: product.basePrice ?? product.price,
        dynamicPrice: product.dynamicPrice,
        originalPrice: product.originalPrice,
        demandScore: product.demandScore,
        viewCount: userViewTotals[product.id] ?? product.viewCount,
        cartCount: product.cartCount,
        purchaseCount: purchaseCounts[product.id] ?? product.purchaseCount,
        images: product.images,
        sizes: product.sizes,
        stock: product.stock,
        category: product.category,
        isActive: product.isActive,
        createdAt: product.createdAt,
        rating: product.rating,
        reviewCount: product.reviewCount,
        lastPriceUpdated: product.lastPriceUpdated,
        isCustomTailoring: product.isCustomTailoring,
        outfitType: product.outfitType,
        fabric: product.fabric,
        customizations: product.customizations,
        measurements: product.measurements,
        addons: product.addons,
        measurementProfileLabel: product.measurementProfileLabel,
        neededBy: product.neededBy,
        tailoringDeliveryMode: product.tailoringDeliveryMode,
        tailoringExtraCost: product.tailoringExtraCost,
      );
      await refreshDynamicPrice(enriched);
    }
  }

  Future<List<Product>> searchProducts(SearchFilter filter) async {
    final products = (await _productService.fetchAll())
        .map(_decorateProduct)
        .where((product) => product.effectivePrice >= filter.priceRange.start && product.effectivePrice <= filter.priceRange.end)
        .where((product) => filter.category == 'All' || product.category == filter.category)
        .where((product) => filter.storeId == 'All' || product.storeId == filter.storeId)
        .where((product) => filter.occasion == 'All' || _occasionFor(product) == filter.occasion)
        .where((product) {
          final query = filter.query.trim().toLowerCase();
          if (query.isEmpty) {
            return true;
          }
          return '${product.name} ${product.description} ${product.category}'.toLowerCase().contains(query);
        })
        .toList();
    products.sort((a, b) => b.rating.compareTo(a.rating));
    return products;
  }

  Future<List<Product>> getCompleteTheLook(Product product) async {
    if (_backendCommerce.isConfigured) {
      try {
        final outfits = await _backendCommerce.getCompleteLook(
          product.id,
          userId: FirebaseAuth.instance.currentUser?.uid,
          authenticated: Firebase.apps.isNotEmpty && FirebaseAuth.instance.currentUser != null,
        );
        final seen = <String>{product.id};
        final items = <Product>[];
        for (final outfit in outfits) {
          for (final item in outfit.items) {
            if (seen.add(item.id)) {
              items.add(item);
            }
            if (items.length >= 3) {
              return items;
            }
          }
        }
      } catch (_) {
        // Fall through to the existing catalog-based logic below.
      }
    }
    final products = _backendCommerce.isConfigured
        ? await _backendCommerce.getProducts()
        : (await _productService.fetchAll()).map(_decorateProduct).toList();
    return products
        .where((candidate) => candidate.storeId == product.storeId && candidate.id != product.id)
        .take(3)
        .toList();
  }

  Future<List<OutfitRecommendation>> getOutfitRecommendations({
    AppUser? user,
    String? productId,
    String? occasion,
    String? budget,
    String? style,
    int limit = 6,
  }) async {
    if (_backendCommerce.isConfigured) {
      try {
        return await _backendCommerce.getOutfits(
          userId: user?.id,
          productId: productId,
          occasion: occasion,
          budget: budget,
          style: style,
          limit: limit,
          authenticated: Firebase.apps.isNotEmpty && FirebaseAuth.instance.currentUser != null,
        );
      } catch (_) {
        // Use local heuristic fallback below.
      }
    }

    final catalog = _backendCommerce.isConfigured
        ? await _backendCommerce.getProducts()
        : (await _productService.fetchAll()).map(_decorateProduct).toList();
    return _fallbackOutfitsFromCatalog(
      catalog,
      user: user,
      productId: productId,
      occasion: occasion,
      budget: budget,
      style: style,
      limit: limit,
    );
  }

  Future<void> trackOutfitInteraction({
    required String action,
    String? outfitId,
    String? productId,
    List<String> itemIds = const [],
    Map<String, dynamic> filters = const {},
    Map<String, dynamic> metadata = const {},
  }) async {
    if (!_backendCommerce.isConfigured) {
      return;
    }
    try {
      await _backendCommerce.trackOutfitInteraction(
        action: action,
        outfitId: outfitId,
        productId: productId,
        itemIds: itemIds,
        filters: filters,
        metadata: metadata,
      );
    } catch (_) {
      // Recommendation feedback is best-effort only.
    }
  }

  List<OutfitRecommendation> _fallbackOutfitsFromCatalog(
    List<Product> catalog, {
    AppUser? user,
    String? productId,
    String? occasion,
    String? budget,
    String? style,
    int limit = 6,
  }) {
    final normalizedOccasion = (occasion ?? '').trim().toLowerCase();
    final normalizedStyle = (style ?? '').trim().toLowerCase();
    final budgetCap = switch ((budget ?? '').trim().toLowerCase()) {
      'under ₹999' || 'under_999' => 999.0,
      'under ₹1999' || 'under_1999' => 1999.0,
      'under ₹2999' || 'under_2999' => 2999.0,
      _ => double.infinity,
    };

    String roleFor(Product product) {
      final text =
          '${product.category} ${product.name} ${product.description} ${product.outfitType ?? ''}'
              .toLowerCase();
      if (text.contains('shoe') ||
          text.contains('sneaker') ||
          text.contains('loafer') ||
          text.contains('sandal')) {
        return 'footwear';
      }
      if (text.contains('watch') ||
          text.contains('bag') ||
          text.contains('belt') ||
          text.contains('sunglass')) {
        return 'accessory';
      }
      if (text.contains('jeans') ||
          text.contains('pant') ||
          text.contains('trouser') ||
          text.contains('leggings') ||
          text.contains('churidar')) {
        return 'bottom';
      }
      if (text.contains('dress') ||
          text.contains('gown') ||
          text.contains('co-ord') ||
          text.contains('coord') ||
          text.contains('set')) {
        return 'onepiece';
      }
      return 'top';
    }

    String occasionFor(Product product) {
      final text = '${product.category} ${product.name} ${product.description}'.toLowerCase();
      if (text.contains('wedding') || text.contains('festive') || text.contains('lehenga') || text.contains('sherwani')) {
        return 'wedding';
      }
      if (text.contains('office') || text.contains('formal') || text.contains('blazer') || text.contains('tailored')) {
        return 'office';
      }
      if (text.contains('party') || text.contains('night') || text.contains('glam')) {
        return 'party';
      }
      return 'casual';
    }

    String styleFor(Product product) {
      final text = '${product.category} ${product.name} ${product.description}'.toLowerCase();
      if (text.contains('streetwear') || text.contains('oversized') || text.contains('cargo')) {
        return 'streetwear';
      }
      if (text.contains('formal') || text.contains('office') || text.contains('tailored')) {
        return 'formal';
      }
      if (text.contains('ethnic') || text.contains('kurta') || text.contains('lehenga') || text.contains('saree')) {
        return 'ethnic';
      }
      return 'minimal';
    }

    final filtered = catalog.where((product) {
      if (product.id == productId) {
        return true;
      }
      if (normalizedOccasion.isNotEmpty && occasionFor(product) != normalizedOccasion) {
        return false;
      }
      if (normalizedStyle.isNotEmpty && styleFor(product) != normalizedStyle) {
        return false;
      }
      if (product.price > budgetCap) {
        return false;
      }
      return product.stock > 0 && product.isActive;
    }).toList();

    if (filtered.isEmpty) {
      return const [];
    }

    final byRole = <String, List<Product>>{
      'top': [],
      'bottom': [],
      'footwear': [],
      'accessory': [],
      'onepiece': [],
    };
    for (final product in filtered) {
      byRole[roleFor(product)]!.add(product);
    }

    final bases = productId != null && productId.isNotEmpty
        ? filtered.where((item) => item.id == productId).take(1).toList()
        : [...byRole['top']!, ...byRole['onepiece']!];

    final outfits = <OutfitRecommendation>[];
    final seen = <String>{};
    for (final base in bases) {
      final role = roleFor(base);
      final items = <Product>[base];
      if (role != 'onepiece') {
        final bottom = byRole['bottom']!.firstWhere(
          (item) => item.id != base.id,
          orElse: () => Product(
            id: '',
            storeId: '',
            name: '',
            description: '',
            price: 0,
            images: const [],
            sizes: const [],
            stock: 0,
            category: '',
            isActive: false,
          ),
        );
        if (bottom.id.isNotEmpty) {
          items.add(bottom);
        }
      }
      final footwear = byRole['footwear']!.firstWhere(
        (item) => items.every((selected) => selected.id != item.id),
        orElse: () => Product(
          id: '',
          storeId: '',
          name: '',
          description: '',
          price: 0,
          images: const [],
          sizes: const [],
          stock: 0,
          category: '',
          isActive: false,
        ),
      );
      if (footwear.id.isNotEmpty) {
        items.add(footwear);
      }
      final key = items.map((item) => item.id).join('-');
      if (items.length < 2 || !seen.add(key)) {
        continue;
      }
      outfits.add(
        OutfitRecommendation(
          outfitId: key,
          title: '${occasionFor(base)[0].toUpperCase()}${occasionFor(base).substring(1)} Style Pick',
          items: items,
          totalPrice: items.fold<double>(0, (sum, item) => sum + item.price),
          matchScore: 72 + max(0, 8 - outfits.length),
          occasion: occasionFor(base),
          style: styleFor(base),
          reasoning: 'Matched from category pairing and availability.',
        ),
      );
      if (outfits.length >= limit) {
        break;
      }
    }
    return outfits;
  }

  Future<List<CustomBrand>> getCustomBrands() async {
    final brands = await _fetchCollection('brands', (map, id) => CustomBrand.fromMap(map, id));
    brands.removeWhere((brand) => brand.type != 'custom_clothing');
    return brands;
  }

  Future<List<CustomBrandProduct>> getCustomProductsByBrand(
    String brandId, {
    String? category,
  }) async {
    final products = await _fetchCollection(
      'custom_products',
      (map, id) => CustomBrandProduct.fromMap(map, id),
    );
    products.removeWhere((product) => product.brandId != brandId);
    if (category != null && category.trim().isNotEmpty) {
      final normalized = category.trim().toLowerCase();
      products.removeWhere((product) => product.category.toLowerCase() != normalized);
    }
    return products;
  }

  Future<String> placeCustomBrandOrder({
    required AppUser user,
    required CustomBrand brand,
    required CustomBrandProduct product,
    required Map<String, dynamic> customizationData,
    required double price,
  }) async {
    final orderId = 'cbo-${DateTime.now().millisecondsSinceEpoch}';
    final payload = <String, dynamic>{
      'user_id': user.id,
      'userId': user.id,
      'brand_id': brand.id,
      'brand_name': brand.name,
      'product_name': product.name,
      'customization_data': customizationData,
      'price': price,
      'totalAmount': price,
      'status': 'pending',
      'paymentMethod': 'COD',
      'timestamp': DateTime.now().toIso8601String(),
      'orderType': 'custom_clothing',
      'items': [
        {
          'productId': product.id,
          'productName': product.name,
          'quantity': 1,
          'price': price,
          'size': 'CUSTOM',
          'imageUrl': '',
          'isCustomTailoring': true,
          'measurementProfileLabel': customizationData['measurement_mode'] ?? 'custom',
        }
      ],
      'storeId': brand.id,
      'shippingLabel': user.name,
      'shippingAddress': user.address ?? '',
      'extraCharges': 0,
      'subtotal': price,
      'taxAmount': 0,
      'platformCommission': 0,
      'vendorEarnings': price,
      'payoutStatus': 'Pending',
      'trackingId': _buildTrackingId(brand.id),
      'deliveryStatus': 'Pending',
      'assignedDeliveryPartner': 'Unassigned',
      'invoiceNumber': _buildInvoiceNumber(brand.id),
    };
    await _ref('orders/$orderId').set(payload);
    return orderId;
  }

  Future<List<ReviewModel>> getProductReviews(String productId) async {
    if (_backendCommerce.isConfigured) {
      return _backendCommerce.getProductReviews(productId);
    }
    final reviews = await _fetchCollection('reviews', (map, id) => ReviewModel.fromMap(map, id));
    reviews.removeWhere((review) => review.targetId != productId || review.targetType != 'product');
    reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return reviews;
  }

  Future<List<ReviewModel>> getStoreReviews(String storeId) async {
    if (_backendCommerce.isConfigured) {
      return _backendCommerce.getStoreReviews(storeId);
    }
    final reviews = await _fetchCollection('reviews', (map, id) => ReviewModel.fromMap(map, id));
    reviews.removeWhere((review) => review.targetId != storeId || review.targetType != 'store');
    reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return reviews;
  }

  Future<void> saveReview(ReviewModel review) async {
    if (_backendCommerce.isConfigured) {
      await _backendCommerce.saveReview(review);
      return;
    }
    final resolvedReview = ReviewModel(
      id: review.id.isEmpty ? 'rev-${DateTime.now().millisecondsSinceEpoch}' : review.id,
      userId: review.userId,
      userName: review.userName,
      targetId: review.targetId,
      targetType: review.targetType,
      rating: review.rating,
      comment: review.comment,
      imagePath: review.imagePath,
      createdAt: review.createdAt,
    );
    await _ref('reviews/${resolvedReview.id}').set(resolvedReview.toMap());
    if (resolvedReview.targetType == 'store') {
      unawaited(refreshVendorRankings());
    }
  }

  Future<void> deleteReview(String reviewId) async {
    if (_backendCommerce.isConfigured) {
      await _backendCommerce.deleteReview(reviewId);
      return;
    }
    final existing = await _fetchDocument('reviews/$reviewId', (map, id) => ReviewModel.fromMap(map, id));
    await _ref('reviews/$reviewId').remove();
    if (existing?.targetType == 'store') {
      unawaited(refreshVendorRankings());
    }
  }

  Future<List<MeasurementProfile>> getMeasurementProfiles(String userId) async {
    if (_backendCommerce.isConfigured) {
      return const <MeasurementProfile>[];
    }
    try {
      final scopedProfiles = await _fetchCollection(
        'measurements/$userId',
        (map, id) => MeasurementProfile.fromMap(map, id),
      );
      if (scopedProfiles.isNotEmpty) {
        return scopedProfiles;
      }
      final legacyProfiles = await _fetchCollection(
        'measurementProfiles',
        (map, id) => MeasurementProfile.fromMap(map, id),
      );
      return legacyProfiles.where((profile) => profile.userId == userId).toList();
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        debugPrint('Measurement profiles unavailable for $userId: ${error.message}');
        return const <MeasurementProfile>[];
      }
      rethrow;
    }
  }

  Future<void> saveMeasurementProfile(MeasurementProfile profile) async {
    if (_backendCommerce.isConfigured) {
      return;
    }
    final resolvedProfile = MeasurementProfile(
      id: profile.id.isEmpty ? 'mp-${DateTime.now().millisecondsSinceEpoch}' : profile.id,
      userId: profile.userId,
      label: profile.label,
      method: profile.method,
      unit: profile.unit,
      chest: profile.chest,
      shoulder: profile.shoulder,
      waist: profile.waist,
      sleeve: profile.sleeve,
      length: profile.length,
      standardSize: profile.standardSize,
      recommendedSize: profile.recommendedSize,
      sourceProfileId: profile.sourceProfileId,
    );
    await _ref('measurements/${resolvedProfile.userId}/${resolvedProfile.id}').set(resolvedProfile.toMap());
  }

  Future<BodyProfile?> getBodyProfile(String userId) async {
    if (_backendCommerce.isConfigured) {
      return _backendCommerce.getBodyProfile();
    }
    final snapshot = await _ref('users/$userId/bodyProfile').get();
    if (!snapshot.exists) {
      return null;
    }
    final data = _asMap(snapshot.value);
    if (data == null || data.isEmpty) {
      return null;
    }
    return BodyProfile.fromMap(data);
  }

  Future<void> saveBodyProfile(String userId, BodyProfile profile) async {
    final resolved = profile.copyWith(
      updatedAt: profile.updatedAt.isEmpty
          ? DateTime.now().toIso8601String()
          : profile.updatedAt,
    );
    final existingMemory = await getUserMemory(userId);
    final memory = (existingMemory ??
            UserMemory(
              userId: userId,
              updatedAt: resolved.updatedAt,
            ))
        .copyWith(
          size: resolved.recommendedSize,
          updatedAt: resolved.updatedAt,
        );
    if (_backendCommerce.isConfigured) {
      await _backendCommerce.saveBodyProfile(resolved);
      return;
    }
    await _ref('').update({
      'users/$userId/bodyProfile': resolved.toMap(),
      'userMemory/$userId': memory.toMap(),
    });
  }

  Future<UserMemory?> getUserMemory(String userId) async {
    if (_backendCommerce.isConfigured) {
      return _backendCommerce.getUserMemory();
    }
    final snapshot = await _ref('userMemory/$userId').get();
    if (!snapshot.exists) {
      return null;
    }
    final data = _asMap(snapshot.value);
    if (data == null || data.isEmpty) {
      return null;
    }
    return UserMemory.fromMap(data, userId);
  }

  Future<void> saveUserMemory(String userId, UserMemory memory) async {
    final resolved = memory.copyWith(
      userId: userId,
      updatedAt: memory.updatedAt.isEmpty ? _nowIso() : memory.updatedAt,
    );
    if (_backendCommerce.isConfigured) {
      await _backendCommerce.saveUserMemory(resolved);
      return;
    }
    await _ref('userMemory/$userId').set(resolved.toMap());
  }

  Future<void> resetUserMemory(String userId) async {
    if (_backendCommerce.isConfigured) {
      await _backendCommerce.clearChatHistory();
      return;
    }
    await _ref('').update({
      'userMemory/$userId': null,
      'chatHistory/$userId': null,
    });
  }

  Future<List<ConversationMemoryMessage>> getChatHistory(
    String userId,
    String chatId, {
    int limit = 15,
  }) async {
    if (_backendCommerce.isConfigured) {
      final messages = await _backendCommerce.getChatHistory(chatId, limit: limit);
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return messages;
    }
    final messages = await _fetchQueryCollection(
      _ref('chatHistory/$userId/$chatId')
          .orderByChild('timestamp')
          .limitToLast(limit),
      (map, id) => ConversationMemoryMessage.fromMap(map, id),
    );
    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return messages;
  }

  Future<void> _saveChatHistoryEntry({
    required String userId,
    required String chatId,
    required ConversationMemoryMessage entry,
  }) async {
    if (_backendCommerce.isConfigured) {
      await _backendCommerce.appendChatHistoryEntry(chatId: chatId, entry: entry);
      return;
    }
    await _ref('chatHistory/$userId/$chatId/${entry.id}').set(entry.toMap());
    final history = await getChatHistory(userId, chatId, limit: 40);
    if (history.length <= 30) {
      return;
    }
    final overflow = history.length - 30;
    final updates = <String, dynamic>{};
    for (final item in history.take(overflow)) {
      updates['chatHistory/$userId/$chatId/${item.id}'] = null;
    }
    if (updates.isNotEmpty) {
      await _ref('').update(updates);
      unawaited(refreshVendorRankings());
    }
  }

  Future<void> deleteMeasurementProfile(String userId, String profileId) async {
    await _ref('measurements/$userId/$profileId').remove();
  }

  Future<void> addProduct(Product product, {AppUser? actor}) async {
    if (_backendCommerce.isConfigured) {
      await _backendCommerce.createProduct(product);
      return;
    }
    _requireStoreAccess(actor, product.storeId);
    final productId = product.id.isEmpty ? 'p${DateTime.now().millisecondsSinceEpoch}' : product.id;
    final resolvedProduct = Product(
      id: productId,
      storeId: product.storeId,
      name: product.name,
      brand: product.brand,
      description: product.description,
      price: product.price,
      basePrice: product.basePrice ?? product.price,
      dynamicPrice: product.dynamicPrice ?? product.price,
      originalPrice: product.originalPrice,
      demandScore: product.demandScore > 0 ? product.demandScore : _normalizedDemandScore(product),
      viewCount: product.viewCount,
      cartCount: product.cartCount,
      purchaseCount: product.purchaseCount,
      images: product.images,
      sizes: product.sizes,
      stock: product.stock,
      category: product.category,
      isActive: product.isActive,
      createdAt: product.createdAt ?? DateTime.now().toIso8601String(),
      rating: product.rating,
      reviewCount: product.reviewCount,
      lastPriceUpdated: product.lastPriceUpdated ?? _nowIso(),
      isCustomTailoring: product.isCustomTailoring,
      outfitType: product.outfitType,
      fabric: product.fabric,
      customizations: product.customizations,
      measurements: product.measurements,
      addons: product.addons,
      measurementProfileLabel: product.measurementProfileLabel,
      neededBy: product.neededBy,
      tailoringDeliveryMode: product.tailoringDeliveryMode,
      tailoringExtraCost: product.tailoringExtraCost,
    );
    await _productService.save(
      resolvedProduct,
    );
    if (actor != null) {
      await logActivity(
        action: 'add_product',
        targetType: 'product',
        targetId: resolvedProduct.id,
        message: 'Added product ${resolvedProduct.name} for store ${resolvedProduct.storeId}.',
        actor: actor,
      );
    }
  }

  Future<void> updateProduct(Product updatedProduct, {AppUser? actor}) async {
    if (_backendCommerce.isConfigured) {
      await _backendCommerce.updateProduct(updatedProduct);
      return;
    }
    _requireStoreAccess(actor, updatedProduct.storeId);
    if (actor != null && !isSuperAdmin(actor)) {
      final existing = (await _productService.fetchAll())
          .map(_decorateProduct)
          .cast<Product?>()
          .firstWhere((item) => item?.id == updatedProduct.id, orElse: () => null);
      if (existing == null) {
        await _productService.update(updatedProduct);
        return;
      }
      final sanitized = Product(
        id: existing.id,
        storeId: existing.storeId,
        name: updatedProduct.name,
        brand: updatedProduct.brand,
        description: updatedProduct.description,
        price: updatedProduct.price,
        basePrice: updatedProduct.basePrice ?? existing.basePrice ?? updatedProduct.price,
        dynamicPrice: updatedProduct.dynamicPrice ?? updatedProduct.price,
        originalPrice: updatedProduct.originalPrice,
        demandScore: updatedProduct.demandScore > 0 ? updatedProduct.demandScore : existing.demandScore,
        viewCount: existing.viewCount,
        cartCount: existing.cartCount,
        purchaseCount: existing.purchaseCount,
        images: updatedProduct.images,
        sizes: updatedProduct.sizes,
        stock: updatedProduct.stock,
        category: updatedProduct.category,
        isActive: updatedProduct.isActive,
        createdAt: existing.createdAt,
        rating: existing.rating,
        reviewCount: existing.reviewCount,
        lastPriceUpdated: existing.lastPriceUpdated,
        isCustomTailoring: updatedProduct.isCustomTailoring,
        outfitType: updatedProduct.outfitType,
        fabric: updatedProduct.fabric,
        customizations: updatedProduct.customizations,
        measurements: updatedProduct.measurements,
        addons: updatedProduct.addons,
        measurementProfileLabel: updatedProduct.measurementProfileLabel,
        neededBy: updatedProduct.neededBy,
        tailoringDeliveryMode: updatedProduct.tailoringDeliveryMode,
        tailoringExtraCost: updatedProduct.tailoringExtraCost,
      );
      await _productService.update(sanitized);
      await logActivity(
        action: 'update_product',
        targetType: 'product',
        targetId: sanitized.id,
        message: 'Updated product ${sanitized.name} for store ${sanitized.storeId}.',
        actor: actor,
      );
      return;
    }
    await _productService.update(updatedProduct);
    if (actor != null) {
      await logActivity(
        action: 'update_product',
        targetType: 'product',
        targetId: updatedProduct.id,
        message: 'Updated product ${updatedProduct.name} for store ${updatedProduct.storeId}.',
        actor: actor,
      );
    }
  }

  Future<void> deleteProduct(String productId, {AppUser? actor}) async {
    if (_backendCommerce.isConfigured) {
      await _backendCommerce.deleteProduct(productId);
      return;
    }
    final allProducts = (await _productService.fetchAll()).map(_decorateProduct).toList();
    final product = allProducts.cast<Product?>().firstWhere((item) => item?.id == productId, orElse: () => null);
    if (product == null) {
      return;
    }
    _requireStoreAccess(actor, product.storeId);
    await _productService.delete(productId);
    if (actor != null) {
      await logActivity(
        action: 'delete_product',
        targetType: 'product',
        targetId: productId,
        message: 'Deleted product $productId from store ${product.storeId}.',
        actor: actor,
      );
    }
  }

  Future<void> updateProductStock(String productId, int newStock) async {
    await _productService.updateStock(productId, newStock);
  }

  Future<void> placeOrder(OrderModel order) async {
    final resolvedOrderId = order.id.isEmpty ? 'ord-${DateTime.now().millisecondsSinceEpoch}' : order.id;
    await _ensureOrderIdAvailable(resolvedOrderId);
    if (order.paymentMethod.toUpperCase() != 'COD' && (order.paymentReference?.trim().isEmpty ?? true)) {
      throw StateError('A valid payment reference is required for online payments.');
    }
    await _ensurePaymentReferenceAvailable(order.userId, order.paymentReference, orderId: resolvedOrderId);
    if (order.paymentMethod.toUpperCase() != 'COD' && !order.isPaymentVerified) {
      throw StateError('Online payment must be verified before creating the order.');
    }
    final nowIso = _nowIso();
    final resolved = OrderModel(
      id: resolvedOrderId,
      userId: order.userId,
      storeId: order.storeId,
      riderId: order.riderId,
      totalAmount: order.totalAmount,
      status: order.status,
      paymentMethod: order.paymentMethod,
      timestamp: order.timestamp,
      items: order.items,
      shippingLabel: order.shippingLabel,
      shippingAddress: order.shippingAddress,
      extraCharges: order.extraCharges,
      subtotal: order.subtotal,
      taxAmount: order.taxAmount,
      platformCommission: order.platformCommission,
      vendorEarnings: order.vendorEarnings,
      payoutStatus: order.payoutStatus,
      payoutId: order.payoutId,
      trackingId: order.trackingId,
      deliveryStatus: order.deliveryStatus,
      assignedDeliveryPartner: order.assignedDeliveryPartner,
      invoiceNumber: order.invoiceNumber,
      orderType: order.orderType,
      trackingTimestamps: order.trackingTimestamps,
      riderLatitude: order.riderLatitude,
      riderLongitude: order.riderLongitude,
      riderLocationUpdatedAt: order.riderLocationUpdatedAt,
      createdAt: order.createdAt ?? nowIso,
      updatedAt: order.updatedAt ?? nowIso,
      deliveredAt: order.deliveredAt,
      isConfirmed: order.isConfirmed,
      isDelivered: order.isDelivered,
      payoutProcessed: order.payoutProcessed,
      paymentReference: order.paymentReference,
      idempotencyKey: order.idempotencyKey,
      isPaymentVerified: order.isPaymentVerified,
    );

    final notification = AppNotification(
      id: 'n-${DateTime.now().millisecondsSinceEpoch}',
      title: 'Order Placed',
      body: 'Your order ${resolved.invoiceNumber.isEmpty ? '#${resolved.id}' : resolved.invoiceNumber} has been placed successfully.',
      type: 'order',
      isRead: false,
      timestamp: DateTime.now(),
      audienceRole: 'user',
      userId: resolved.userId,
      storeId: resolved.storeId,
    );

    final updates = <String, dynamic>{
      'orders/${resolved.id}': resolved.toMap(),
      'notifications/${notification.id}': notification.toMap(),
    };
    if (resolved.idempotencyKey != null && resolved.idempotencyKey!.trim().isNotEmpty) {
      updates['idempotencyClaims/${resolved.userId}/${Uri.encodeComponent(resolved.idempotencyKey!)}'] = {
        'orderId': resolved.id,
        'idempotencyKey': resolved.idempotencyKey,
        'createdAt': nowIso,
      };
    }
    if (resolved.paymentReference != null && resolved.paymentReference!.trim().isNotEmpty) {
      updates['paymentClaims/${Uri.encodeComponent(resolved.paymentReference!)}'] = {
        'userId': resolved.userId,
        'paymentReference': resolved.paymentReference,
        'orderId': resolved.id,
        'createdAt': nowIso,
        'updatedAt': nowIso,
      };
    }

    await _ref('').update(updates);
    unawaited(refreshVendorRankings());
  }

  Future<OrderModel> placeOrdersForCart({
      required AppUser actor,
      required List<OrderItem> items,
      required String paymentMethod,
      required String shippingLabel,
      required String shippingAddress,
      required double extraCharges,
      double discountAmount = 0,
      double walletCreditUsed = 0,
      String? paymentReference,
      required String idempotencyKey,
      bool isPaymentVerified = false,
    }) async {
      if (_backendCommerce.isConfigured) {
        return _backendCommerce.createOrder(
          items: items,
          paymentMethod: paymentMethod,
          shippingLabel: shippingLabel,
          shippingAddress: shippingAddress,
        );
      }
      if (walletCreditUsed < 0) {
        throw StateError('Wallet credit cannot be negative.');
      }
      if (walletCreditUsed > 75) {
        throw StateError('A maximum of Rs 75 referral credit can be used per order.');
      }
      if (paymentMethod.toUpperCase() != 'COD' && (paymentReference?.trim().isEmpty ?? true)) {
        throw StateError('A valid payment reference is required for online payments.');
      }
    if (paymentMethod.toUpperCase() != 'COD' && !isPaymentVerified) {
      throw StateError('Online payment must be verified before placing the order.');
    }
    final existingForKey = await _findOrderByIdempotencyKey(actor.id, idempotencyKey);
    if (existingForKey != null) {
      return existingForKey;
    }
    final liveProducts = <String, Product>{};
    final liveStores = <String, Store>{};
    final allProducts = await _productService.fetchAll();
    for (final product in allProducts) {
      liveProducts[product.id] = product;
    }

    final grouped = <String, List<OrderItem>>{};
    for (final item in items) {
      final product = liveProducts[item.productId];
      final storeId = product?.storeId;
      if (storeId == null || storeId.isEmpty) {
        throw StateError('Each order item must be linked to a valid store.');
      }
      grouped.putIfAbsent(storeId, () => <OrderItem>[]).add(item);
    }

    if (grouped.length > 1) {
      throw StateError('Checkout currently supports one store per order.');
    }

    final updates = <String, dynamic>{};
    OrderModel? placedOrder;

    for (final entry in grouped.entries) {
      final fetchedStore = await _fetchDocument('stores/${entry.key}', (map, id) => Store.fromMap(map, id));
      if (fetchedStore != null) {
        liveStores[entry.key] = fetchedStore;
      }
      final store = liveStores[entry.key];
      if (store == null) {
        throw StateError('Store ${entry.key} could not be found for this order.');
      }
      final subtotal = entry.value.fold<double>(0, (runningTotal, item) {
        final liveProduct = liveProducts[item.productId];
        if (liveProduct == null) {
          throw StateError('Missing product ${item.productId} in Realtime Database.');
        }
        return runningTotal + (liveProduct.effectivePrice * item.quantity);
      });
      final extraTailoring = entry.value.fold<double>(
        0,
        (runningTotal, item) {
          final product = liveProducts[item.productId];
          if (product == null) {
            throw StateError('Missing product ${item.productId} in Realtime Database.');
          }
          return runningTotal + (product.tailoringExtraCost * item.quantity);
        },
        );
        final discountedSubtotal = (subtotal - discountAmount).clamp(0.0, double.infinity).toDouble();
        final taxAmount = discountedSubtotal * 0.05;
        final preCreditTotal = discountedSubtotal + taxAmount + extraTailoring;
        final appliedWalletCredit =
            (preCreditTotal >= 499 ? walletCreditUsed : 0).clamp(0.0, actor.walletBalance).toDouble();
        final total = (preCreditTotal - appliedWalletCredit).clamp(0.0, double.infinity).toDouble();
        final commission = discountedSubtotal * store.commissionRate;
        final vendorEarnings = preCreditTotal - commission;
        final hasCustom = entry.value.any((item) => item.isCustomTailoring);
      
      final liveItems = entry.value.map((item) {
        final liveProduct = liveProducts[item.productId]!;
        return OrderItem(
          productId: item.productId,
          productName: item.productName,
          quantity: item.quantity,
          price: liveProduct.effectivePrice,
          size: item.size,
          imageUrl: item.imageUrl,
          isCustomTailoring: item.isCustomTailoring,
          neededBy: item.neededBy,
          tailoringDeliveryMode: item.tailoringDeliveryMode,
          measurementProfileLabel: item.measurementProfileLabel,
        );
      }).toList();

        final orderId = _buildDeterministicOrderId(entry.key, idempotencyKey);
        final existingOrder = await _fetchDocument('orders/$orderId', (map, id) => OrderModel.fromMap(map, id));
        if (existingOrder != null) {
          if (existingOrder.userId != actor.id || existingOrder.idempotencyKey != idempotencyKey) {
            throw StateError('A conflicting order already exists for this checkout attempt.');
          }
          return existingOrder;
        }
        final createdAt = DateTime.now();
        await _ensureOrderIdAvailable(orderId);
        await _ensurePaymentReferenceAvailable(actor.id, paymentReference, orderId: orderId);
        final order = OrderModel(
          id: orderId,
          userId: actor.id,
        storeId: entry.key,
        totalAmount: total,
        status: 'Placed',
        paymentMethod: paymentMethod,
        timestamp: createdAt,
        items: liveItems,
        shippingLabel: shippingLabel,
        shippingAddress: shippingAddress,
        extraCharges: extraTailoring,
        subtotal: discountedSubtotal,
        taxAmount: taxAmount,
        platformCommission: commission,
        vendorEarnings: vendorEarnings,
        payoutStatus: 'Pending',
        riderId: null,
        trackingId: _buildTrackingId(entry.key),
        deliveryStatus: 'Placed',
        assignedDeliveryPartner: 'Abzora Dispatch',
        invoiceNumber: _buildInvoiceNumber(entry.key),
        orderType: hasCustom ? 'custom_tailoring' : 'marketplace',
        trackingTimestamps: {
          'Order Placed': createdAt.toIso8601String(),
        },
        riderLatitude: null,
        riderLongitude: null,
        riderLocationUpdatedAt: null,
        createdAt: createdAt.toIso8601String(),
        updatedAt: createdAt.toIso8601String(),
        isConfirmed: false,
        isDelivered: false,
        payoutProcessed: false,
          paymentReference: paymentReference,
          idempotencyKey: idempotencyKey,
          isPaymentVerified: paymentMethod.toUpperCase() == 'COD' ? false : isPaymentVerified,
          walletCreditUsed: appliedWalletCredit,
        );

      final notifId = 'n-${DateTime.now().millisecondsSinceEpoch}-${entry.key}';
      final notification = AppNotification(
        id: notifId,
        title: 'New Order Alert',
        body: 'A new order for ${store.name} is ready to process.',
        type: 'vendor_order',
        isRead: false,
        timestamp: DateTime.now(),
        audienceRole: 'vendor',
        storeId: entry.key,
      );

      updates['orders/$orderId'] = order.toMap();
      updates['notifications/$notifId'] = notification.toMap();
      updates['idempotencyClaims/${actor.id}/${Uri.encodeComponent(idempotencyKey)}'] = {
        'orderId': orderId,
        'idempotencyKey': idempotencyKey,
        'createdAt': createdAt.toIso8601String(),
      };
      if (paymentReference != null && paymentReference.trim().isNotEmpty) {
        updates['paymentClaims/${Uri.encodeComponent(paymentReference)}'] = {
          'userId': actor.id,
          'paymentReference': paymentReference,
          'orderId': orderId,
          'createdAt': createdAt.toIso8601String(),
          'updatedAt': createdAt.toIso8601String(),
        };
        }
        placedOrder = order;
      }

      if (walletCreditUsed > 0) {
        updates['users/${actor.id}/walletBalance'] = (actor.walletBalance - walletCreditUsed)
            .clamp(0.0, double.infinity)
            .toDouble();
      }

      if (updates.isNotEmpty) {
        await _ref('').update(updates);
      }
      if (placedOrder == null) {
        throw StateError('No order could be created for this cart.');
      }
      await trackOrderPlacedForGrowth(user: actor, order: placedOrder);
      await _processReferralRewardIfEligible(actor: actor, order: placedOrder);
      for (final item in placedOrder.items) {
        final product = liveProducts[item.productId];
        if (product == null) {
          continue;
        }
      final updatedProduct = Product(
        id: product.id,
        storeId: product.storeId,
        name: product.name,
        brand: product.brand,
        description: product.description,
        price: product.price,
        basePrice: product.basePrice ?? product.price,
        dynamicPrice: product.dynamicPrice,
        originalPrice: product.originalPrice,
        demandScore: product.demandScore > 0 ? product.demandScore : _normalizedDemandScore(product),
        viewCount: product.viewCount,
        cartCount: product.cartCount,
        purchaseCount: product.purchaseCount + item.quantity,
        images: product.images,
        sizes: product.sizes,
        stock: product.stock,
        category: product.category,
        isActive: product.isActive,
        createdAt: product.createdAt,
        rating: product.rating,
        reviewCount: product.reviewCount,
        lastPriceUpdated: _nowIso(),
        isCustomTailoring: product.isCustomTailoring,
        outfitType: product.outfitType,
        fabric: product.fabric,
        customizations: product.customizations,
        measurements: product.measurements,
        addons: product.addons,
        measurementProfileLabel: product.measurementProfileLabel,
        neededBy: product.neededBy,
        tailoringDeliveryMode: product.tailoringDeliveryMode,
        tailoringExtraCost: product.tailoringExtraCost,
      );
      await _productService.update(updatedProduct);
      unawaited(refreshDynamicPrice(updatedProduct));
    }
    return placedOrder;
  }

  Future<void> createBooking(BookingModel booking) async {
    if (_backendCommerce.isConfigured) {
      await _backendCommerce.createBooking(booking);
      return;
    }
    final resolved = BookingModel(
      id: booking.id.isEmpty ? 'bk-${DateTime.now().millisecondsSinceEpoch}' : booking.id,
      userId: booking.userId,
      tailorId: booking.tailorId,
      tailorName: booking.tailorName,
      outfitType: booking.outfitType,
      appointmentDate: booking.appointmentDate,
      timeSlot: booking.timeSlot,
      status: booking.status,
      notes: booking.notes,
    );
    await _ref('bookings/${resolved.id}').set(resolved.toMap());
  }

  Stream<List<BookingModel>> getUserBookings(String userId) {
    if (_backendCommerce.isConfigured) {
      return (() async* {
        final initial = await _backendCommerce.getMyBookings();
        yield initial.where((booking) => booking.userId == userId).toList();
        while (true) {
          await Future<void>.delayed(const Duration(seconds: 10));
          final bookings = await _backendCommerce.getMyBookings();
          yield bookings.where((booking) => booking.userId == userId).toList();
        }
      })();
    }
    return _watchCollection('bookings', (map, id) => BookingModel.fromMap(map, id))
        .map((bookings) => bookings.where((booking) => booking.userId == userId).toList());
  }

  Stream<List<OrderModel>> getUserOrders(String userId) {
    if (_backendCommerce.isConfigured) {
      return (() async* {
        yield await _backendCommerce.getUserOrders();
        while (true) {
          await Future<void>.delayed(const Duration(seconds: 10));
          final orders = await _backendCommerce.getUserOrders();
          orders.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          yield orders;
        }
      })().asBroadcastStream();
    }
    return _watchQueryCollection(
      _ref('orders').orderByChild('userId').equalTo(userId),
      (map, id) => OrderModel.fromMap(map, id),
    ).map((orders) {
      orders.sort((a, b) => _orderTimestampValue(b).compareTo(_orderTimestampValue(a)));
      return orders;
    });
  }

  bool _isRefundEligible(OrderModel order) {
    final paymentMethod = order.paymentMethod.trim().toUpperCase();
    final hasOnlinePayment =
        paymentMethod != 'COD' && order.isPaymentVerified && (order.paymentReference?.trim().isNotEmpty ?? false);
    if (!hasOnlinePayment) {
      return false;
    }
    final refundState = order.refundStatus.trim().toLowerCase();
    if (refundState == 'requested' || refundState == 'refunded') {
      return false;
    }
    return true;
  }

  bool _isReturnEligible(OrderModel order) {
    final delivered = order.isDelivered || order.status.trim().toLowerCase() == 'delivered';
    if (!delivered) {
      return false;
    }
    final customOrder =
        order.orderType == 'custom_tailoring' || order.items.any((item) => item.isCustomTailoring);
    if (customOrder) {
      return false;
    }
    final returnState = order.returnStatus.trim().toLowerCase();
    if (returnState == 'requested' ||
        returnState == 'approved' ||
        returnState == 'picked' ||
        returnState == 'completed') {
      return false;
    }
    final deliveredAt = DateTime.tryParse(order.deliveredAt ?? '') ??
        DateTime.tryParse(order.trackingTimestamps['Delivered'] ?? '');
    if (deliveredAt == null) {
      return false;
    }
    return DateTime.now().difference(deliveredAt) <= const Duration(days: 3);
  }

  double _distanceKm(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = (endLat - startLat) * (3.141592653589793 / 180);
    final dLng = (endLng - startLng) * (3.141592653589793 / 180);
    final a =
        (sin(dLat / 2) * sin(dLat / 2)) +
        cos(startLat * (3.141592653589793 / 180)) *
            cos(endLat * (3.141592653589793 / 180)) *
            (sin(dLng / 2) * sin(dLng / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  String _taskIdForDelivery(String orderId) => 'task-delivery-$orderId';

  String _taskIdForReturn(String returnId) => 'task-return-$returnId';

  String _returnTaskStatusForRequest(ReturnRequest request) {
    final status = request.status.trim().toLowerCase();
    if (status == 'completed') {
      return 'completed';
    }
    if (status == 'picked') {
      return 'in_progress';
    }
    return 'assigned';
  }

  Map<String, dynamic> _returnTaskPayloadForRequest(
    ReturnRequest request, {
    required String riderId,
    String? createdAt,
  }) {
    final nowIso = _nowIso();
    return UnifiedRiderTask(
      id: _taskIdForReturn(request.id),
      type: 'return',
      returnId: request.id,
      userId: request.userId,
      address: request.address,
      status: _returnTaskStatusForRequest(request),
      riderId: riderId,
      createdAt: createdAt ?? request.createdAt,
      updatedAt: nowIso,
    ).toMap();
  }

  Future<AppUser?> _nearestAvailableRiderForUser(AppUser user) async {
    final riders = await getRiders();
    if (riders.isEmpty) {
      return null;
    }
    final destinationLat = user.latitude;
    final destinationLng = user.longitude;
    if (destinationLat == null || destinationLng == null) {
      return riders.first;
    }
    riders.sort((a, b) {
      final aDistance = (a.latitude == null || a.longitude == null)
          ? double.infinity
          : _distanceKm(a.latitude!, a.longitude!, destinationLat, destinationLng);
      final bDistance = (b.latitude == null || b.longitude == null)
          ? double.infinity
          : _distanceKm(b.latitude!, b.longitude!, destinationLat, destinationLng);
      return aDistance.compareTo(bDistance);
    });
    return riders.first;
  }

  int calculateFraudScore({
    required OrderModel order,
    required AppUser user,
    required int totalRefundRequests,
    required int refundsLast30Days,
    required int ordersLast30Days,
    required int sameDayRefunds,
  }) {
    var score = 0;

    final accountCreated = DateTime.tryParse(user.createdAt ?? '');
    final accountAgeDays = accountCreated == null ? 30 : DateTime.now().difference(accountCreated).inDays;
    if (accountAgeDays < 7) {
      score += 25;
    } else if (accountAgeDays < 30) {
      score += 12;
    }

    if (order.totalAmount >= 5000) {
      score += 18;
    } else if (order.totalAmount >= 2500) {
      score += 10;
    }

    final normalizedStatus = order.status.toLowerCase();
    if (normalizedStatus != 'delivered' && normalizedStatus != 'cancelled') {
      score += 22;
    }

    if (totalRefundRequests >= 5) {
      score += 22;
    } else if (totalRefundRequests >= 3) {
      score += 12;
    }

    if (refundsLast30Days >= 3) {
      score += 18;
    } else if (refundsLast30Days >= 2) {
      score += 10;
    }

    if (sameDayRefunds >= 2) {
      score += 18;
    }

    final orderAgeHours = DateTime.now().difference(order.timestamp).inHours;
    if (orderAgeHours <= 6) {
      score += 12;
    } else if (orderAgeHours <= 24) {
      score += 6;
    }

    if (ordersLast30Days > 0 && totalRefundRequests > 0) {
      final ratio = totalRefundRequests / ordersLast30Days;
      if (ratio >= 0.6) {
        score += 15;
      } else if (ratio >= 0.35) {
        score += 8;
      }
    }

    return score.clamp(0, 100);
  }

  Future<_RefundFraudAssessment> _assessRefundFraud({
    required OrderModel order,
    required AppUser user,
  }) async {
    final refunds = await _fetchQueryCollection(
      _ref('refundRequests').orderByChild('userId').equalTo(user.id),
      (map, id) => RefundRequest.fromMap(map, id),
    );
    final orders = await getUserOrdersOnce(user.id);
    final now = DateTime.now();
    final last30Days = now.subtract(const Duration(days: 30));
    final refundsLast30Days = refunds.where((item) {
      final created = DateTime.tryParse(item.createdAt);
      return created != null && created.isAfter(last30Days);
    }).length;
    final sameDayRefunds = refunds.where((item) {
      final created = DateTime.tryParse(item.createdAt);
      return created != null &&
          created.year == now.year &&
          created.month == now.month &&
          created.day == now.day;
    }).length;
    final ordersLast30Days = orders.where((item) => item.timestamp.isAfter(last30Days)).length;
    final score = calculateFraudScore(
      order: order,
      user: user,
      totalRefundRequests: refunds.length,
      refundsLast30Days: refundsLast30Days,
      ordersLast30Days: ordersLast30Days,
      sameDayRefunds: sameDayRefunds,
    );

    final reasons = <String>[];
    final accountCreated = DateTime.tryParse(user.createdAt ?? '');
    final accountAgeDays = accountCreated == null ? 30 : now.difference(accountCreated).inDays;
    if (accountAgeDays < 7) {
      reasons.add('Very new account requesting a refund.');
    } else if (accountAgeDays < 30) {
      reasons.add('Recent account with limited history.');
    }
    if (order.totalAmount >= 5000) {
      reasons.add('High-value order refund.');
    }
    if (order.status.toLowerCase() != 'delivered' && order.status.toLowerCase() != 'cancelled') {
      reasons.add('Refund requested before final order completion.');
    }
    if (refundsLast30Days >= 2) {
      reasons.add('Multiple refund requests in the last 30 days.');
    }
    if (sameDayRefunds >= 2) {
      reasons.add('Repeated same-day refund behavior detected.');
    }
    if (ordersLast30Days > 0 && refunds.length / ordersLast30Days >= 0.35) {
      reasons.add('High refund-to-order ratio for this account.');
    }
    if (reasons.isEmpty) {
      reasons.add('Low historical refund risk.');
    }

    final decision = score > 60
        ? 'reject'
        : score >= 30
            ? 'review'
            : 'approve';
    return _RefundFraudAssessment(
      score: score,
      decision: decision,
      reasons: reasons,
    );
  }

  Future<RefundRequest?> getRefundRequestForOrder(
    String orderId, {
    AppUser? actor,
  }) async {
    if (_backendCommerce.isConfigured) {
      final refund = await _backendCommerce.getRefundRequestForOrder(orderId);
      if (refund == null) {
        return null;
      }
      if (actor != null && !isSuperAdmin(actor) && refund.userId != actor.id) {
        throw StateError('Refund access denied.');
      }
      return refund;
    }
    final requests = await _fetchQueryCollection(
      _ref('refundRequests').orderByChild('orderId').equalTo(orderId),
      (map, id) => RefundRequest.fromMap(map, id),
    );
    requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final refund = requests.isEmpty ? null : requests.first;
    if (refund == null) {
      return null;
    }
    if (actor != null && !isSuperAdmin(actor) && refund.userId != actor.id) {
      throw StateError('Refund access denied.');
    }
    return refund;
  }

  Future<List<RefundRequest>> getRefundRequests({
    required AppUser actor,
    String status = 'all',
  }) async {
    if (_backendCommerce.isConfigured) {
      return _backendCommerce.getRefundRequests(status: status);
    }
    final requests = isSuperAdmin(actor)
        ? await _fetchCollection('refundRequests', (map, id) => RefundRequest.fromMap(map, id))
        : await _fetchQueryCollection(
            _ref('refundRequests').orderByChild('userId').equalTo(actor.id),
            (map, id) => RefundRequest.fromMap(map, id),
          );
    final filtered = status == 'all'
        ? requests
        : requests.where((request) => request.status.toLowerCase() == status.toLowerCase()).toList();
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  Future<ReturnRequest?> getReturnRequestForOrder(
    String orderId, {
    AppUser? actor,
  }) async {
    if (_backendCommerce.isConfigured) {
      final request = await _backendCommerce.getReturnRequestForOrder(orderId);
      if (request == null) {
        return null;
      }
      if (actor != null && !isSuperAdmin(actor) && request.userId != actor.id) {
        throw StateError('Return access denied.');
      }
      return request;
    }
    final requests = await _fetchQueryCollection(
      _ref('returnRequests').orderByChild('orderId').equalTo(orderId),
      (map, id) => ReturnRequest.fromMap(map, id),
    );
    requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final request = requests.isEmpty ? null : requests.first;
    if (request == null) {
      return null;
    }
    if (actor != null && !isSuperAdmin(actor) && request.userId != actor.id) {
      throw StateError('Return access denied.');
    }
    return request;
  }

  Future<List<ReturnRequest>> getReturnRequests({
    required AppUser actor,
    String status = 'all',
  }) async {
    if (_backendCommerce.isConfigured) {
      return _backendCommerce.getReturnRequests(status: status);
    }
    final requests = isSuperAdmin(actor)
        ? await _fetchCollection('returnRequests', (map, id) => ReturnRequest.fromMap(map, id))
        : await _fetchQueryCollection(
            _ref('returnRequests').orderByChild('userId').equalTo(actor.id),
            (map, id) => ReturnRequest.fromMap(map, id),
          );
    final filtered = status == 'all'
        ? requests
        : requests.where((request) => request.status.toLowerCase() == status.toLowerCase()).toList();
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  Future<ReturnRequest?> assignRiderToReturnRequest(
    String returnId, {
    AppUser? rider,
    AppUser? actor,
  }) async {
    if (actor != null && !isSuperAdmin(actor)) {
      throw StateError('Only admins can assign pickup riders.');
    }
    final request = await _fetchDocument('returnRequests/$returnId', (map, id) => ReturnRequest.fromMap(map, id));
    if (request == null) {
      throw StateError('Return request not found.');
    }
    if (request.status.toLowerCase() == 'completed') {
      throw StateError('This return is already completed.');
    }
    final order = await _fetchDocument('orders/${request.orderId}', (map, id) => OrderModel.fromMap(map, id));
    if (order == null) {
      throw StateError('Order not found.');
    }
    final user = await getUser(request.userId);
    if (user == null) {
      throw StateError('Customer account not found.');
    }
    final assignedRider = rider ?? await _nearestAvailableRiderForUser(user);
    if (assignedRider == null) {
      return null;
    }
    final nowIso = _nowIso();
    final pickupTaskId = request.pickupTaskId?.trim().isNotEmpty == true
        ? request.pickupTaskId!.trim()
        : 'pickup-${DateTime.now().millisecondsSinceEpoch}';
    final resolved = request.copyWith(
      riderId: assignedRider.id,
      pickupTaskId: pickupTaskId,
      status: 'assigned',
      updatedAt: nowIso,
    );
    await _ref('').update({
      'returnRequests/$returnId': resolved.toMap(),
      'pickupTasks/$pickupTaskId': PickupTask(
        id: pickupTaskId,
        returnId: returnId,
        riderId: assignedRider.id,
        status: 'assigned',
        pickupLocation: request.address,
        createdAt: request.createdAt,
        updatedAt: nowIso,
      ).toMap(),
      'tasks/${_taskIdForReturn(returnId)}': _returnTaskPayloadForRequest(
        resolved,
        riderId: assignedRider.id,
        createdAt: request.createdAt,
      ),
      'orders/${order.id}/returnStatus': 'assigned',
      'orders/${order.id}/updatedAt': nowIso,
    });
    return resolved;
  }

  Stream<List<PickupTask>> watchPickupTasksForRider(AppUser actor) {
    if (!isRider(actor) && !isSuperAdmin(actor)) {
      throw StateError('Rider access denied.');
    }
    return _watchQueryCollection(
      _ref('pickupTasks').orderByChild('riderId').equalTo(actor.id),
      (map, id) => PickupTask.fromMap(map, id),
    ).map((tasks) {
      tasks.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return tasks;
    });
  }

  Future<void> updateReturnPickupLocation({
    required String returnId,
    required double latitude,
    required double longitude,
    required AppUser actor,
  }) async {
    final request = await _fetchDocument('returnRequests/$returnId', (map, id) => ReturnRequest.fromMap(map, id));
    if (request == null) {
      throw StateError('Return request not found.');
    }
    if (!isSuperAdmin(actor) && (!isRider(actor) || request.riderId != actor.id)) {
      throw StateError('Pickup tracking access denied.');
    }
    await _ref('returnRequests/$returnId').update({
      'riderLatitude': latitude,
      'riderLongitude': longitude,
      'updatedAt': _nowIso(),
    });
  }

  Future<ReturnRequest> createReturnRequest({
    required String orderId,
    required String reason,
    required AppUser actor,
    String imageUrl = '',
  }) async {
    if (_backendCommerce.isConfigured) {
      return _backendCommerce.createReturnRequest(
        orderId: orderId,
        reason: reason,
        imageUrl: imageUrl,
      );
    }
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      throw StateError('Tell us why you want to return this item.');
    }

    final order = await _fetchDocument('orders/$orderId', (map, id) => OrderModel.fromMap(map, id));
    if (order == null) {
      throw StateError('Order not found.');
    }
    if (!isSuperAdmin(actor) && order.userId != actor.id) {
      throw StateError('You can only request a return for your own order.');
    }
    if (!_isReturnEligible(order)) {
      throw StateError('This order is not eligible for return right now.');
    }
    final user = await getUser(order.userId);
    if (user == null) {
      throw StateError('Customer account not found.');
    }

    final existing = await getReturnRequestForOrder(orderId);
    if (existing != null && existing.status.toLowerCase() != 'rejected') {
      throw StateError('A return request already exists for this order.');
    }

    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final pickupAddress = order.shippingAddress.trim().isNotEmpty
        ? order.shippingAddress.trim()
        : (user.address?.trim().isNotEmpty == true ? user.address!.trim() : 'Pickup address unavailable');
    final rider = await _nearestAvailableRiderForUser(user);
    final pickupTaskId = rider == null ? null : 'pickup-${now.millisecondsSinceEpoch}';
    final request = ReturnRequest(
      id: 'return-${now.millisecondsSinceEpoch}',
      orderId: orderId,
      userId: order.userId,
      address: pickupAddress,
      reason: trimmedReason,
      status: rider == null ? 'requested' : 'assigned',
      createdAt: nowIso,
      updatedAt: nowIso,
      riderId: rider?.id,
      pickupTaskId: pickupTaskId,
      imageUrl: imageUrl.trim().isEmpty ? null : imageUrl.trim(),
    );
    final label = order.invoiceNumber.isEmpty ? order.id : order.invoiceNumber;
    final notification = AppNotification(
      id: 'return-request-${now.millisecondsSinceEpoch}',
      title: 'Return request received',
      body: 'We received your return request for $label and will review it shortly.',
      type: 'return',
      isRead: false,
      timestamp: now,
      audienceRole: 'user',
      userId: order.userId,
      storeId: order.storeId,
    );
    final riderNotification = rider == null
        ? null
        : AppNotification(
            id: 'return-rider-${now.millisecondsSinceEpoch}',
            title: 'Return pickup assigned',
            body: 'A return pickup for $label is ready for collection.',
            type: 'return_pickup',
            isRead: false,
            timestamp: now,
            audienceRole: 'rider',
            userId: rider.id,
            storeId: order.storeId,
          );

    final updates = <String, dynamic>{
      'returnRequests/${request.id}': request.toMap(),
      'orders/${order.id}/returnStatus': request.status,
      'orders/${order.id}/updatedAt': nowIso,
      'notifications/${notification.id}': notification.toMap(),
    };
    if (pickupTaskId != null && rider != null) {
      updates['pickupTasks/$pickupTaskId'] = PickupTask(
        id: pickupTaskId,
        returnId: request.id,
        riderId: rider.id,
        status: 'assigned',
        pickupLocation: pickupAddress,
        createdAt: nowIso,
        updatedAt: nowIso,
      ).toMap();
      updates['tasks/${_taskIdForReturn(request.id)}'] = _returnTaskPayloadForRequest(
        request,
        riderId: rider.id,
      );
      updates['notifications/${riderNotification!.id}'] = riderNotification.toMap();
    }

    await _ref('').update(updates);

    return request;
  }

  Future<RefundRequest> createRefundRequest({
    required String orderId,
    required String reason,
    required AppUser actor,
  }) async {
    if (_backendCommerce.isConfigured) {
      return _backendCommerce.createRefundRequest(
        orderId: orderId,
        reason: reason,
      );
    }
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      throw StateError('Tell us why you want a refund.');
    }

    final order = await _fetchDocument('orders/$orderId', (map, id) => OrderModel.fromMap(map, id));
    if (order == null) {
      throw StateError('Order not found.');
    }
    if (!isSuperAdmin(actor) && order.userId != actor.id) {
      throw StateError('You can only request a refund for your own order.');
    }
    if (!_isRefundEligible(order)) {
      throw StateError('This order is not eligible for a refund right now.');
    }
    final user = await getUser(order.userId);
    if (user == null) {
      throw StateError('Customer account not found.');
    }

    final existing = await getRefundRequestForOrder(orderId);
    if (existing != null && existing.status.toLowerCase() != 'rejected') {
      throw StateError('A refund request already exists for this order.');
    }

    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final fraud = await _assessRefundFraud(order: order, user: user);
    final refundId = 'refund-${now.millisecondsSinceEpoch}';
    final refund = RefundRequest(
      id: refundId,
      orderId: orderId,
      userId: order.userId,
      reason: trimmedReason,
      status: 'pending',
      createdAt: nowIso,
      rejectionReason: null,
      fraudScore: fraud.score,
      fraudDecision: fraud.decision,
      fraudReasons: fraud.reasons,
    );
    final fraudLog = RefundFraudLog(
      id: 'fraud-$refundId',
      refundId: refundId,
      orderId: orderId,
      userId: order.userId,
      riskScore: fraud.score,
      decision: fraud.decision,
      reasons: fraud.reasons,
      createdAt: nowIso,
    );

    if (fraud.decision == 'reject') {
      await _ref('fraudLogs/${fraudLog.id}').set(fraudLog.toMap());
      throw StateError(fraud.reasons.join(' '));
    }

    await _ref('').update({
      'refundRequests/${refund.id}': refund.toMap(),
      'fraudLogs/${fraudLog.id}': fraudLog.toMap(),
    });
    return refund;
  }

  Stream<List<OrderModel>> getVendorOrders(String storeId, {AppUser? actor}) {
    if (_backendCommerce.isConfigured) {
      return (() async* {
        yield await _backendCommerce.getStoreOrders(storeId);
        while (true) {
          await Future<void>.delayed(const Duration(seconds: 15));
          final orders = await _backendCommerce.getStoreOrders(storeId);
          orders.sort((a, b) => _orderTimestampValue(b).compareTo(_orderTimestampValue(a)));
          yield orders;
        }
      })();
    }
    _requireStoreAccess(actor, storeId);
    return _watchQueryCollection(
      _ref('orders').orderByChild('storeId').equalTo(storeId),
      (map, id) => OrderModel.fromMap(map, id),
    ).map((orders) {
      orders.sort((a, b) => _orderTimestampValue(b).compareTo(_orderTimestampValue(a)));
      return orders;
    });
  }

  Future<void> saveUser(AppUser user) async {
    if (_backendCommerce.isConfigured) {
      await _backendCommerce.syncUserProfile(user);
      return;
    }
    await _ref('users/${user.id}').update(user.toMap());
  }

  Future<List<UserAddress>> getUserAddresses(String userId) async {
    if (_backendCommerce.isConfigured) {
      final addresses = await _backendCommerce.getUserAddresses();
      addresses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return addresses;
    }
    final addresses = await _fetchCollection(
      'users/$userId/addresses',
      (map, id) => UserAddress.fromMap(map, id),
    );
    addresses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return addresses;
  }

  Future<void> saveUserAddress(UserAddress address) async {
    final resolved = UserAddress(
      id: address.id.isEmpty ? 'addr-${DateTime.now().millisecondsSinceEpoch}' : address.id,
      userId: address.userId,
      name: address.name,
      phone: address.phone,
      addressLine: address.addressLine,
      city: address.city,
      state: address.state,
      pincode: address.pincode,
      houseDetails: address.houseDetails,
      landmark: address.landmark,
      locality: address.locality,
      latitude: address.latitude,
      longitude: address.longitude,
      type: address.type,
      createdAt: address.createdAt,
    );
    if (_backendCommerce.isConfigured) {
      await _backendCommerce.saveUserAddress(resolved);
      return;
    }
    await _ref('users/${resolved.userId}/addresses/${resolved.id}').set(resolved.toMap());
  }

  Future<void> deleteUserAddress(String userId, String addressId) async {
    if (_backendCommerce.isConfigured) {
      await _backendCommerce.deleteUserAddress(addressId);
      return;
    }
    await _ref('users/$userId/addresses/$addressId').remove();
  }

  Future<List<AppUser>> getUsers({AppUser? actor}) async {
    if (_backendCommerce.isConfigured) {
      if (actor != null) {
        _requireSuperAdmin(actor);
      }
      return _backendCommerce.getAdminUsers();
    }
    if (actor != null) {
      _requireSuperAdmin(actor);
    }
    return _fetchCollection('users', (map, _) => AppUser.fromMap(map));
  }

  Future<List<AppUser>> getRiders() async {
    if (_backendCommerce.isConfigured) {
      final users = await _backendCommerce.getAdminUsers();
      return users
          .where((user) => user.role == riderRole && user.isActive && user.riderApprovalStatus == 'approved')
          .toList();
    }
    final users = await _fetchCollection('users', (map, _) => AppUser.fromMap(map));
    return users
        .where((user) => user.role == riderRole && user.isActive && user.riderApprovalStatus == 'approved')
        .toList();
  }

  Future<int> _activeTaskCountForRider(String riderId) async {
    final tasks = await _fetchQueryCollection(
      _ref('tasks').orderByChild('riderId').equalTo(riderId),
      (map, id) => UnifiedRiderTask.fromMap(map, id),
    );
    return tasks.where((task) => task.status != 'completed').length;
  }

  Future<List<ReturnRequest>> _availableReturnsForAssignment() async {
    final requests = await _fetchCollection(
      'returnRequests',
      (map, id) => ReturnRequest.fromMap(map, id),
    );
    return requests
        .where((request) =>
            request.status == 'requested' &&
            (request.riderId ?? '').trim().isEmpty)
        .toList();
  }

  Future<void> assignTasks({
    required AppUser actor,
    int maxTasksPerRider = 3,
    double bundleDistanceKm = 4,
  }) async {
    _requireSuperAdmin(actor);
    final riders = await getRiders();
    if (riders.isEmpty) {
      return;
    }
    final availableOrders = await getAvailableDeliveryOrders();
    final availableReturns = await _availableReturnsForAssignment();
    final assignedOrderIds = <String>{};
    final assignedReturnIds = <String>{};

    for (final rider in riders) {
      var capacity = maxTasksPerRider - await _activeTaskCountForRider(rider.id);
      if (capacity <= 0) {
        continue;
      }

      OrderModel? anchorOrder;
      if (availableOrders.isNotEmpty) {
        final candidates = availableOrders.where((order) => !assignedOrderIds.contains(order.id)).toList();
        if (candidates.isNotEmpty) {
          anchorOrder = candidates.first;
          await assignRiderToOrder(anchorOrder.id, rider, actor: actor);
          assignedOrderIds.add(anchorOrder.id);
          capacity -= 1;
        }
      }

      if (capacity <= 0) {
        continue;
      }

      final anchorUser = anchorOrder == null ? null : await getUser(anchorOrder.userId);
      final anchorLat = anchorUser?.latitude ?? rider.latitude;
      final anchorLng = anchorUser?.longitude ?? rider.longitude;

      for (final request in availableReturns) {
        if (capacity <= 0 || assignedReturnIds.contains(request.id)) {
          continue;
        }
        if (anchorLat != null && anchorLng != null) {
          final user = await getUser(request.userId);
          if (user?.latitude != null && user?.longitude != null) {
            final distance = _distanceKm(anchorLat, anchorLng, user!.latitude!, user.longitude!);
            if (distance > bundleDistanceKm) {
              continue;
            }
          }
        }
        final assigned = await assignRiderToReturnRequest(
          request.id,
          rider: rider,
          actor: actor,
        );
        if (assigned != null) {
          assignedReturnIds.add(request.id);
          capacity -= 1;
        }
      }
    }
  }

  Future<AppUser?> getUser(String uid) async {
    if (_backendCommerce.isConfigured) {
      try {
        final current = await _backendCommerce.getCurrentUserProfile();
        if (current.id == uid) {
          return current;
        }
      } catch (_) {
        return null;
      }
    }
    return _fetchDocument('users/$uid', (map, _) => AppUser.fromMap(map));
  }

  Stream<AppUser?> watchUser(String uid) {
    if (_backendCommerce.isConfigured) {
      return (() async* {
        try {
          final current = await _backendCommerce.getCurrentUserProfile();
          yield current.id == uid ? current : null;
        } catch (_) {
          yield null;
        }
        while (true) {
          await Future<void>.delayed(const Duration(seconds: 20));
          try {
            final current = await _backendCommerce.getCurrentUserProfile();
            yield current.id == uid ? current : null;
          } catch (_) {
            yield null;
          }
        }
      })();
    }
    return _ref('users/$uid').onValue.map((event) {
      final map = _asMap(event.snapshot.value);
      if (map == null || map.isEmpty) {
        return null;
      }
      return AppUser.fromMap(map);
    });
  }

  Future<OrderModel?> getOrderById(String orderId) async {
    if (_backendCommerce.isConfigured) {
      try {
        final assigned = await _backendCommerce.getAssignedDeliveries();
        final assignedMatch = assigned.where((order) => order.id == orderId);
        if (assignedMatch.isNotEmpty) {
          return assignedMatch.first;
        }
      } catch (_) {}
      try {
        final userOrders = await _backendCommerce.getUserOrders();
        final userMatch = userOrders.where((order) => order.id == orderId);
        if (userMatch.isNotEmpty) {
          return userMatch.first;
        }
      } catch (_) {}
      try {
        final adminOrders = await _backendCommerce.getAdminOrders();
        final adminMatch = adminOrders.where((order) => order.id == orderId);
        if (adminMatch.isNotEmpty) {
          return adminMatch.first;
        }
      } catch (_) {}
      return null;
    }
    return _fetchDocument('orders/$orderId', (map, id) => OrderModel.fromMap(map, id));
  }

  Future<void> updateUser(AppUser user, {AppUser? actor}) async {
    if (actor != null) {
      _requireSuperAdmin(actor);
    }
    await saveUser(user);
    if (actor != null) {
      await logActivity(
        action: 'update_user',
        targetType: 'user',
        targetId: user.id,
        message: 'Updated ${user.name} with role ${user.role} and active=${user.isActive}.',
        actor: actor,
      );
    }
  }

  Future<void> updateUserProfile({
      required String userId,
      String? name,
      String? phone,
    String? profileImageUrl,
    String? address,
    String? area,
    String? city,
    double? latitude,
      double? longitude,
    }) async {
      if (_backendCommerce.isConfigured) {
        final current = await _backendCommerce.getCurrentUserProfile();
        if (current.id != userId) {
          throw StateError('Cross-user profile updates are not allowed.');
        }
        await _backendCommerce.syncUserProfile(
          current.copyWith(
            name: name != null ? (name.trim().isEmpty ? 'ABZORA Member' : name.trim()) : current.name,
            phone: phone != null ? phone.trim() : current.phone,
            profileImageUrl: profileImageUrl != null ? profileImageUrl.trim() : current.profileImageUrl,
            address: address != null ? address.trim() : current.address,
            area: area != null ? area.trim() : current.area,
            city: city != null ? city.trim() : current.city,
            latitude: latitude ?? current.latitude,
            longitude: longitude ?? current.longitude,
            locationUpdatedAt: (latitude != null || longitude != null || address != null || area != null || city != null)
                ? _nowIso()
                : current.locationUpdatedAt,
          ),
        );
        return;
      }
      final nowIso = _nowIso();
      final updates = <String, dynamic>{
        'updatedAt': nowIso,
      };
    if (name != null) {
      updates['name'] = name.trim().isEmpty ? 'ABZORA Member' : name.trim();
    }
    if (phone != null) {
      updates['phone'] = phone.trim();
      updates['phone_number'] = phone.trim();
    }
    if (profileImageUrl != null) {
      updates['profileImageUrl'] = profileImageUrl.trim();
    }
    if (address != null) {
      updates['address'] = address.trim();
    }
    if (area != null) {
      updates['area'] = area.trim();
    }
    if (city != null) {
      updates['city'] = city.trim();
    }
    if (latitude != null) {
      updates['latitude'] = latitude;
    }
    if (longitude != null) {
      updates['longitude'] = longitude;
    }
    if (latitude != null || longitude != null || address != null || area != null || city != null) {
      updates['locationUpdatedAt'] = nowIso;
    }
    await _ref('users/$userId').update(updates);
  }

  Future<void> deleteUser(String userId, {AppUser? actor}) async {
    if (_backendCommerce.isConfigured) {
      throw StateError('Deleting users is not supported in backend mode yet.');
    }
    if (actor != null) {
      _requireSuperAdmin(actor);
    }
    await _ref('users/$userId').remove();
  }

  Future<void> saveStore(Store store, {AppUser? actor}) async {
    if (_backendCommerce.isConfigured) {
      await _backendCommerce.saveStore(store);
      return;
    }
    if (actor != null && !isSuperAdmin(actor) && actor.storeId != store.id && actor.id != store.ownerId) {
      throw StateError('Cross-store access denied.');
    }
    Store resolvedStore;
    if (actor != null && !isSuperAdmin(actor) && actor.role == 'vendor' && store.id.isNotEmpty) {
      final existing = await _fetchDocument('stores/${store.id}', (map, id) => Store.fromMap(map, id));
      if (existing == null) {
        throw StateError('Store does not exist.');
      }
      resolvedStore = existing.copyWith(
        name: store.name,
        description: store.description,
        imageUrl: store.imageUrl,
        logoUrl: store.logoUrl,
        bannerImageUrl: store.bannerImageUrl,
        tagline: store.tagline,
      );
    } else {
      resolvedStore = Store(
        id: store.id.isEmpty ? 's${DateTime.now().millisecondsSinceEpoch}' : store.id,
        storeId: store.storeId,
        ownerId: store.ownerId,
        name: store.name,
        description: store.description,
        imageUrl: store.imageUrl,
        rating: store.rating,
        reviewCount: store.reviewCount,
        address: store.address,
        city: store.city,
        isApproved: store.isApproved,
        isActive: store.isActive,
        isFeatured: store.isFeatured,
        approvalStatus: store.approvalStatus,
        logoUrl: store.logoUrl,
        bannerImageUrl: store.bannerImageUrl,
        tagline: store.tagline,
        commissionRate: store.commissionRate,
        walletBalance: store.walletBalance,
        latitude: store.latitude,
        longitude: store.longitude,
        category: store.category,
        vendorScore: store.vendorScore,
        vendorRank: store.vendorRank,
        vendorVisibility: store.vendorVisibility,
        performanceMetrics: store.performanceMetrics,
      );
    }
    await _ref('stores/${resolvedStore.id}').set(resolvedStore.toMap());
    if (actor != null) {
      await logActivity(
        action: 'save_store',
        targetType: 'store',
        targetId: resolvedStore.id,
        message: 'Saved store ${resolvedStore.name}. Status=${resolvedStore.approvalStatus}, approved=${resolvedStore.isApproved}, active=${resolvedStore.isActive}.',
        actor: actor,
      );
    }
  }

  Future<void> deleteStore(String storeId, {AppUser? actor}) async {
    if (_backendCommerce.isConfigured) {
      throw StateError('Deleting stores is not supported in backend mode yet.');
    }
    if (actor != null) {
      _requireSuperAdmin(actor);
    }
    await _ref('stores/$storeId').remove();
    if (actor != null) {
      await logActivity(
        action: 'delete_store',
        targetType: 'store',
        targetId: storeId,
        message: 'Deleted store $storeId.',
        actor: actor,
      );
    }
  }

  Future<List<Product>> getAllProducts({AppUser? actor}) async {
    if (_backendCommerce.isConfigured) {
      if (actor != null && !isSuperAdmin(actor)) {
        if (actor.role != 'vendor' || actor.storeId == null) {
          throw StateError('Product access denied.');
        }
        return getProductsByStore(actor.storeId!);
      }
      return _backendCommerce.getAdminProducts();
    }
    if (actor != null && !isSuperAdmin(actor)) {
      if (actor.role != 'vendor' || actor.storeId == null) {
        throw StateError('Product access denied.');
      }
      return getProductsByStore(actor.storeId!);
    }
    return (await _productService.fetchAll()).map(_decorateProduct).toList();
  }

  Future<List<OrderModel>> getAllOrders({AppUser? actor}) async {
    if (_backendCommerce.isConfigured) {
      if (actor != null && !isSuperAdmin(actor)) {
        if (actor.role == 'vendor' && actor.storeId != null) {
          return _backendCommerce.getStoreOrders(actor.storeId!);
        }
        if (actor.role == riderRole) {
          return _backendCommerce.getAssignedDeliveries();
        }
        throw StateError('Order access denied.');
      }
      return _backendCommerce.getAdminOrders();
    }
    final orders = await _fetchCollection('orders', (map, id) => OrderModel.fromMap(map, id));
    if (actor != null && !isSuperAdmin(actor)) {
      if (actor.role == 'vendor' && actor.storeId != null) {
        return orders.where((order) => order.storeId == actor.storeId).toList();
      }
      if (actor.role == riderRole) {
        return orders.where((order) => order.riderId == actor.id).toList();
      }
      throw StateError('Order access denied.');
    }
    return orders;
  }

  Future<void> updateOrderStatus(String orderId, String status, {AppUser? actor}) async {
    if (_backendCommerce.isConfigured) {
      await _backendCommerce.updateOrderStatus(orderId, status);
      return;
    }
    final existing = await _fetchDocument('orders/$orderId', (map, id) => OrderModel.fromMap(map, id));
    if (existing == null) {
      throw StateError('Order not found.');
    }
    if (actor != null && !isSuperAdmin(actor)) {
      _requireStoreAccess(actor, existing.storeId);
    }
    final normalizedStatus = actor != null && actor.role == 'vendor' && !isSuperAdmin(actor)
        ? _normalizeVendorStatus(status)
        : status;
    if (existing.status == normalizedStatus) {
      return;
    }

    final updates = <String, dynamic>{};
    final validatedStatus = actor != null && actor.role == 'vendor' && !isSuperAdmin(actor)
        ? _validatedVendorOrderStatus(existing.status, status)
        : status;
    final nowIso = _nowIso();
    updates['orders/$orderId/status'] = validatedStatus;
    updates['orders/$orderId/deliveryStatus'] = validatedStatus;
    updates['orders/$orderId/updatedAt'] = nowIso;
    updates['orders/$orderId/trackingTimestamps'] = _trackingTimestampsForStatus(existing, validatedStatus, nowIso);
    if (validatedStatus == 'Confirmed') {
      updates['orders/$orderId/isConfirmed'] = true;
    }
    if (validatedStatus == 'Delivered') {
      if (existing.isDelivered) {
        throw StateError('This order is already marked as delivered.');
      }
      updates['orders/$orderId/isDelivered'] = true;
      updates['orders/$orderId/deliveredAt'] = nowIso;
      if (existing.payoutStatus != 'Paid') {
        updates['orders/$orderId/payoutStatus'] = 'Ready';
      }
      if (existing.payoutStatus != 'Ready' && existing.payoutStatus != 'Paid') {
        final store = await _fetchDocument('stores/${existing.storeId}', (map, id) => Store.fromMap(map, id));
        if (store != null) {
          updates['stores/${store.id}/walletBalance'] = store.walletBalance + existing.vendorEarnings;
        }
      }
    }
    if ((validatedStatus == 'Packed' || validatedStatus == 'Ready for pickup') && existing.riderId == null) {
      final riderNotifId = 'n-${DateTime.now().millisecondsSinceEpoch}-delivery-ready';
      final store = await _fetchDocument('stores/${existing.storeId}', (map, id) => Store.fromMap(map, id));
      final riderNotification = AppNotification(
        id: riderNotifId,
        title: 'New delivery available',
        body: 'Pickup is ready${store == null ? '' : ' from ${store.name}'}.',
        type: 'delivery',
        isRead: false,
        timestamp: DateTime.now(),
        audienceRole: 'rider',
        storeId: existing.storeId,
      );
      updates['notifications/$riderNotifId'] = riderNotification.toMap();
    }
    if (validatedStatus == 'Delivered') {
      final notifId = 'n-${DateTime.now().millisecondsSinceEpoch}-delivered';
      final notification = AppNotification(
        id: notifId,
        title: 'Order Delivered',
        body: 'Order ${existing.invoiceNumber.isEmpty ? '#$orderId' : existing.invoiceNumber} has been delivered.',
        type: 'order',
        isRead: false,
        timestamp: DateTime.now(),
        audienceRole: 'user',
        userId: existing.userId,
        storeId: existing.storeId,
      );
      updates['notifications/$notifId'] = notification.toMap();
    }

    if (actor != null) {
      await _queueActivityLogWrite(
        updates,
        action: 'update_order_status',
        targetType: 'order',
        targetId: orderId,
        message: 'Updated order $orderId to status $validatedStatus.',
        actor: actor,
        timestamp: nowIso,
      );
    }

    if (updates.isNotEmpty) {
      await _ref('').update(updates);
    }
  }

  Future<void> approveRefundRequest(String refundId, {required AppUser actor}) async {
    if (_backendCommerce.isConfigured) {
      _requireSuperAdmin(actor);
      await _backendCommerce.approveRefundRequest(refundId);
      return;
    }
    _requireSuperAdmin(actor);
    final refund = await _fetchDocument('refundRequests/$refundId', (map, id) => RefundRequest.fromMap(map, id));
    if (refund == null) {
      throw StateError('Refund request not found.');
    }
    if (refund.status.toLowerCase() != 'pending') {
      throw StateError('This refund request has already been processed.');
    }

    final order = await _fetchDocument('orders/${refund.orderId}', (map, id) => OrderModel.fromMap(map, id));
    if (order == null) {
      throw StateError('Order not found.');
    }
    final user = await getUser(order.userId);
    if (user == null) {
      throw StateError('Customer account not found.');
    }
    final fraud = await _assessRefundFraud(order: order, user: user);
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final fraudLog = RefundFraudLog(
      id: 'fraud-recheck-${refund.id}-${now.millisecondsSinceEpoch}',
      refundId: refund.id,
      orderId: order.id,
      userId: order.userId,
      riskScore: fraud.score,
      decision: fraud.decision,
      reasons: fraud.reasons,
      createdAt: nowIso,
    );
    if (fraud.decision == 'reject') {
      await _ref('').update({
        'refundRequests/$refundId/status': 'rejected',
        'refundRequests/$refundId/processedAt': nowIso,
        'refundRequests/$refundId/processedBy': actor.id,
        'refundRequests/$refundId/rejectionReason': fraud.reasons.join(' '),
        'refundRequests/$refundId/fraudScore': fraud.score,
        'refundRequests/$refundId/fraudDecision': fraud.decision,
        'refundRequests/$refundId/fraudReasons': fraud.reasons,
        'orders/${order.id}/refundStatus': 'rejected',
        'orders/${order.id}/updatedAt': nowIso,
        'fraudLogs/${fraudLog.id}': fraudLog.toMap(),
      });
      throw StateError('Refund blocked by fraud protection.');
    }
    if (fraud.decision == 'review') {
      await _ref('').update({
        'refundRequests/$refundId/fraudScore': fraud.score,
        'refundRequests/$refundId/fraudDecision': fraud.decision,
        'refundRequests/$refundId/fraudReasons': fraud.reasons,
        'fraudLogs/${fraudLog.id}': fraudLog.toMap(),
      });
      throw StateError('Refund needs manual review before approval.');
    }
    final paymentId = order.paymentReference?.trim();
    if (paymentId == null || paymentId.isEmpty) {
      throw StateError('A valid online payment reference is required before refunding.');
    }

    final refundResult = await _paymentService.refundPayment(
      paymentId: paymentId,
      refundRequestId: refund.id,
      reason: refund.reason,
    );
    final label = order.invoiceNumber.isEmpty ? order.id : order.invoiceNumber;
    final notification = AppNotification(
      id: 'refund-approved-${now.millisecondsSinceEpoch}',
      title: 'Refund approved',
      body: 'Your refund for $label has been processed successfully.',
      type: 'refund',
      isRead: false,
      timestamp: now,
      audienceRole: 'user',
      userId: order.userId,
      storeId: order.storeId,
    );

    await _ref('').update({
      'refundRequests/$refundId/status': 'approved',
      'refundRequests/$refundId/processedAt': nowIso,
      'refundRequests/$refundId/processedBy': actor.id,
      'refundRequests/$refundId/gatewayRefundId': refundResult.refundId,
      'refundRequests/$refundId/fraudScore': fraud.score,
      'refundRequests/$refundId/fraudDecision': fraud.decision,
      'refundRequests/$refundId/fraudReasons': fraud.reasons,
      'orders/${order.id}/status': 'Cancelled',
      'orders/${order.id}/deliveryStatus': 'Cancelled',
      'orders/${order.id}/refundStatus': 'refunded',
      'orders/${order.id}/updatedAt': nowIso,
      'notifications/${notification.id}': notification.toMap(),
      'fraudLogs/${fraudLog.id}': fraudLog.toMap(),
    });
    unawaited(refreshVendorRankings());

    await logActivity(
      action: 'approve_refund',
      targetType: 'refund_request',
      targetId: refundId,
      message: 'Approved refund for order ${order.id}.',
      actor: actor,
    );
  }

  Future<void> rejectRefundRequest(
    String refundId, {
    required String reason,
    required AppUser actor,
  }) async {
    if (_backendCommerce.isConfigured) {
      _requireSuperAdmin(actor);
      await _backendCommerce.rejectRefundRequest(refundId: refundId, reason: reason);
      return;
    }
    _requireSuperAdmin(actor);
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      throw StateError('Add a reason before rejecting this refund.');
    }
    final refund = await _fetchDocument('refundRequests/$refundId', (map, id) => RefundRequest.fromMap(map, id));
    if (refund == null) {
      throw StateError('Refund request not found.');
    }
    if (refund.status.toLowerCase() != 'pending') {
      throw StateError('This refund request has already been processed.');
    }
    final order = await _fetchDocument('orders/${refund.orderId}', (map, id) => OrderModel.fromMap(map, id));
    if (order == null) {
      throw StateError('Order not found.');
    }

    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final label = order.invoiceNumber.isEmpty ? order.id : order.invoiceNumber;
    final notification = AppNotification(
      id: 'refund-rejected-${now.millisecondsSinceEpoch}',
      title: 'Refund request updated',
      body: 'Your refund request for $label was not approved. Reason: $trimmedReason',
      type: 'refund',
      isRead: false,
      timestamp: now,
      audienceRole: 'user',
      userId: order.userId,
      storeId: order.storeId,
    );

    await _ref('').update({
      'refundRequests/$refundId/status': 'rejected',
      'refundRequests/$refundId/processedAt': nowIso,
      'refundRequests/$refundId/processedBy': actor.id,
      'refundRequests/$refundId/rejectionReason': trimmedReason,
      'orders/${order.id}/refundStatus': 'rejected',
      'orders/${order.id}/updatedAt': nowIso,
      'notifications/${notification.id}': notification.toMap(),
    });

    await logActivity(
      action: 'reject_refund',
      targetType: 'refund_request',
      targetId: refundId,
      message: 'Rejected refund for order ${order.id}. Reason: $trimmedReason',
      actor: actor,
    );
  }

  Future<void> approveReturnRequest(String returnId, {required AppUser actor}) async {
    if (_backendCommerce.isConfigured) {
      _requireSuperAdmin(actor);
      await _backendCommerce.approveReturnRequest(returnId);
      return;
    }
    _requireSuperAdmin(actor);
    final request = await _fetchDocument('returnRequests/$returnId', (map, id) => ReturnRequest.fromMap(map, id));
    if (request == null) {
      throw StateError('Return request not found.');
    }
    if (request.status.toLowerCase() != 'requested') {
      throw StateError('This return request has already been processed.');
    }
    final order = await _fetchDocument('orders/${request.orderId}', (map, id) => OrderModel.fromMap(map, id));
    if (order == null) {
      throw StateError('Order not found.');
    }
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final label = order.invoiceNumber.isEmpty ? order.id : order.invoiceNumber;
    final notification = AppNotification(
      id: 'return-approved-${now.millisecondsSinceEpoch}',
      title: 'Return approved',
      body: 'Your return for $label has been approved and pickup will be arranged.',
      type: 'return',
      isRead: false,
      timestamp: now,
      audienceRole: 'user',
      userId: order.userId,
      storeId: order.storeId,
    );
    await _ref('').update({
      'returnRequests/$returnId/status': request.riderId == null ? 'requested' : 'assigned',
      'returnRequests/$returnId/approvedAt': nowIso,
      'returnRequests/$returnId/updatedAt': nowIso,
      'returnRequests/$returnId/processedBy': actor.id,
      'orders/${order.id}/returnStatus': request.riderId == null ? 'requested' : 'assigned',
      'orders/${order.id}/updatedAt': nowIso,
      'notifications/${notification.id}': notification.toMap(),
    });
  }

  Future<void> markReturnPicked(String returnId, {required AppUser actor}) async {
    if (_backendCommerce.isConfigured) {
      await _backendCommerce.markReturnPicked(returnId);
      return;
    }
    final request = await _fetchDocument('returnRequests/$returnId', (map, id) => ReturnRequest.fromMap(map, id));
    if (request == null) {
      throw StateError('Return request not found.');
    }
    final canManage = isSuperAdmin(actor) || (isRider(actor) && request.riderId == actor.id);
    if (!canManage) {
      throw StateError('Pickup access denied.');
    }
    if (request.status.toLowerCase() != 'assigned') {
      throw StateError('Only assigned returns can be marked as picked.');
    }
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final updates = <String, dynamic>{
      'returnRequests/$returnId/status': 'picked',
      'returnRequests/$returnId/pickedAt': nowIso,
      'returnRequests/$returnId/updatedAt': nowIso,
      'returnRequests/$returnId/processedBy': actor.id,
      'orders/${request.orderId}/returnStatus': 'picked',
      'orders/${request.orderId}/updatedAt': nowIso,
    };
    if ((request.pickupTaskId ?? '').trim().isNotEmpty) {
      updates['pickupTasks/${request.pickupTaskId}/status'] = 'picked';
      updates['pickupTasks/${request.pickupTaskId}/updatedAt'] = nowIso;
    }
    updates['tasks/${_taskIdForReturn(returnId)}/status'] = 'in_progress';
    updates['tasks/${_taskIdForReturn(returnId)}/updatedAt'] = nowIso;
    await _ref('').update(updates);
  }

  Future<void> completeReturnRequest({
    required String returnId,
    required AppUser actor,
    bool qualityApproved = true,
    String rejectionReason = '',
  }) async {
    if (_backendCommerce.isConfigured) {
      await _backendCommerce.completeReturnRequest(
        returnId: returnId,
        qualityApproved: qualityApproved,
        rejectionReason: rejectionReason,
      );
      return;
    }
    final request = await _fetchDocument('returnRequests/$returnId', (map, id) => ReturnRequest.fromMap(map, id));
    if (request == null) {
      throw StateError('Return request not found.');
    }
    final canManage = isSuperAdmin(actor) || (isRider(actor) && request.riderId == actor.id);
    if (!canManage) {
      throw StateError('Return completion access denied.');
    }
    if (request.status.toLowerCase() != 'picked' && request.status.toLowerCase() != 'approved') {
      throw StateError('This return is not ready for completion.');
    }
    final order = await _fetchDocument('orders/${request.orderId}', (map, id) => OrderModel.fromMap(map, id));
    if (order == null) {
      throw StateError('Order not found.');
    }
    final user = await getUser(order.userId);
    if (user == null) {
      throw StateError('Customer account not found.');
    }
    final now = DateTime.now();
    final nowIso = now.toIso8601String();

    if (!qualityApproved) {
      final trimmedReason = rejectionReason.trim().isEmpty
          ? 'The returned item did not pass quality verification.'
          : rejectionReason.trim();
      await _ref('').update({
        'returnRequests/$returnId/status': 'rejected',
        'returnRequests/$returnId/completedAt': nowIso,
        'returnRequests/$returnId/updatedAt': nowIso,
        'returnRequests/$returnId/rejectionReason': trimmedReason,
        'returnRequests/$returnId/processedBy': actor.id,
        'orders/${order.id}/returnStatus': 'rejected',
        'orders/${order.id}/updatedAt': nowIso,
        'tasks/${_taskIdForReturn(returnId)}/status': 'completed',
        'tasks/${_taskIdForReturn(returnId)}/updatedAt': nowIso,
      });
      unawaited(refreshVendorRankings());
      return;
    }

    String? refundRequestId = request.refundRequestId;
    if (_isRefundEligible(order)) {
      final existingRefund = await getRefundRequestForOrder(order.id);
      if (existingRefund != null && existingRefund.status.toLowerCase() != 'rejected') {
        refundRequestId = existingRefund.id;
        if (existingRefund.status.toLowerCase() == 'pending') {
          await approveRefundRequest(existingRefund.id, actor: actor);
        }
      } else {
        final createdRefund = await createRefundRequest(
          orderId: order.id,
          reason: 'Return completed: ${request.reason}',
          actor: actor,
        );
        refundRequestId = createdRefund.id;
        await approveRefundRequest(createdRefund.id, actor: actor);
      }
    }

    final label = order.invoiceNumber.isEmpty ? order.id : order.invoiceNumber;
    final notification = AppNotification(
      id: 'return-complete-${now.millisecondsSinceEpoch}',
      title: 'Return completed',
      body: refundRequestId == null
          ? 'Your return for $label has been completed successfully.'
          : 'Your return for $label has been completed and the refund is being processed.',
      type: 'return',
      isRead: false,
      timestamp: now,
      audienceRole: 'user',
      userId: order.userId,
      storeId: order.storeId,
    );

    await _ref('').update({
      'returnRequests/$returnId/status': 'completed',
      'returnRequests/$returnId/completedAt': nowIso,
      'returnRequests/$returnId/updatedAt': nowIso,
      'returnRequests/$returnId/processedBy': actor.id,
      'returnRequests/$returnId/refundRequestId': refundRequestId,
      'orders/${order.id}/returnStatus': 'completed',
      'orders/${order.id}/updatedAt': nowIso,
      'notifications/${notification.id}': notification.toMap(),
      'tasks/${_taskIdForReturn(returnId)}/status': 'completed',
      'tasks/${_taskIdForReturn(returnId)}/updatedAt': nowIso,
      if ((request.pickupTaskId ?? '').trim().isNotEmpty) 'pickupTasks/${request.pickupTaskId}/status': 'delivered',
      if ((request.pickupTaskId ?? '').trim().isNotEmpty) 'pickupTasks/${request.pickupTaskId}/updatedAt': nowIso,
    });
    unawaited(refreshVendorRankings());
  }

  Future<void> assignRiderToOrder(String orderId, AppUser rider, {required AppUser actor}) async {
    _requireSuperAdmin(actor);
    final existing = await _fetchDocument('orders/$orderId', (map, id) => OrderModel.fromMap(map, id));
    if (existing == null) {
      throw StateError('Order not found.');
    }
    if (existing.riderId != null && existing.riderId != rider.id) {
      throw StateError('This order already has a rider assigned.');
    }
    final nowIso = _nowIso();

    final updates = <String, dynamic>{
      'orders/$orderId/riderId': rider.id,
      'orders/$orderId/assignedDeliveryPartner': rider.name,
      'orders/$orderId/deliveryStatus': 'Assigned',
      'orders/$orderId/updatedAt': nowIso,
      'orders/$orderId/trackingTimestamps': _trackingTimestampsForStatus(existing, 'Assigned', nowIso),
    };
    final user = await getUser(existing.userId);
    updates['tasks/${_taskIdForDelivery(orderId)}'] = UnifiedRiderTask(
      id: _taskIdForDelivery(orderId),
      type: 'delivery',
      orderId: existing.id,
      userId: existing.userId,
      address: existing.shippingAddress.trim().isNotEmpty
          ? existing.shippingAddress.trim()
          : (user?.address?.trim().isNotEmpty == true ? user!.address!.trim() : 'Address unavailable'),
      status: 'assigned',
      riderId: rider.id,
      createdAt: existing.createdAt ?? nowIso,
      updatedAt: nowIso,
    ).toMap();

    final riderNotification = AppNotification(
      id: 'n-${DateTime.now().millisecondsSinceEpoch}-rider',
      title: 'New delivery assigned',
      body: 'Order $orderId has been assigned to you for pickup.',
      type: 'delivery',
      isRead: false,
      timestamp: DateTime.now(),
      audienceRole: 'rider',
      userId: rider.id,
    );
    updates['notifications/${riderNotification.id}'] = riderNotification.toMap();

    await _queueActivityLogWrite(
      updates,
      action: 'assign_rider',
      targetType: 'order',
      targetId: orderId,
      message: 'Assigned rider ${rider.name} to order $orderId.',
      actor: actor,
      timestamp: nowIso,
    );

    await _ref('').update(updates);
    unawaited(refreshVendorRankings());
  }

  Stream<List<UnifiedRiderTask>> watchRiderTasks(AppUser actor) {
    if (_backendCommerce.isConfigured) {
      return (() async* {
        yield await getRiderTasks(actor);
        while (true) {
          await Future<void>.delayed(const Duration(seconds: 15));
          yield await getRiderTasks(actor);
        }
      })();
    }
    if (!isRider(actor) && !isSuperAdmin(actor)) {
      throw StateError('Rider access denied.');
    }
    return _watchQueryCollection(
      _ref('tasks').orderByChild('riderId').equalTo(actor.id),
      (map, id) => UnifiedRiderTask.fromMap(map, id),
    ).map((tasks) {
      tasks.sort((a, b) => a.status == b.status
          ? b.updatedAt.compareTo(a.updatedAt)
          : a.status.compareTo(b.status));
      return tasks;
    });
  }

  Future<List<UnifiedRiderTask>> getRiderTasks(AppUser actor) async {
    if (_backendCommerce.isConfigured) {
      final orders = await _backendCommerce.getAssignedDeliveries();
      final tasks = orders
          .map(
            (order) => UnifiedRiderTask(
              id: 'delivery-${order.id}',
              type: 'delivery',
              orderId: order.id,
              userId: order.userId,
              address: order.shippingAddress,
              status: order.deliveryStatus == 'Delivered'
                  ? 'completed'
                  : (order.deliveryStatus == 'Picked up' || order.deliveryStatus == 'Out for delivery'
                      ? 'in_progress'
                      : 'assigned'),
              riderId: actor.id,
              createdAt: order.createdAt ?? order.timestamp.toIso8601String(),
              updatedAt: order.updatedAt ?? order.timestamp.toIso8601String(),
            ),
          )
          .toList()
        ..sort((a, b) => a.status == b.status ? b.updatedAt.compareTo(a.updatedAt) : a.status.compareTo(b.status));
      return tasks;
    }
    if (!isRider(actor) && !isSuperAdmin(actor)) {
      throw StateError('Rider access denied.');
    }
    final tasks = await _fetchQueryCollection(
      _ref('tasks').orderByChild('riderId').equalTo(actor.id),
      (map, id) => UnifiedRiderTask.fromMap(map, id),
    );
    tasks.sort((a, b) => a.status == b.status
        ? b.updatedAt.compareTo(a.updatedAt)
        : a.status.compareTo(b.status));
    return tasks;
  }

  Stream<List<OrderModel>> getRiderOrders(AppUser actor) {
    if (_backendCommerce.isConfigured) {
      return (() async* {
        yield await _backendCommerce.getAssignedDeliveries();
        while (true) {
          await Future<void>.delayed(const Duration(seconds: 15));
          final orders = await _backendCommerce.getAssignedDeliveries();
          orders.sort((a, b) => _orderTimestampValue(b).compareTo(_orderTimestampValue(a)));
          yield orders;
        }
      })();
    }
    if (!isRider(actor) && !isSuperAdmin(actor)) {
      throw StateError('Rider access denied.');
    }
    return _watchQueryCollection(
      _ref('orders').orderByChild('riderId').equalTo(actor.id),
      (map, id) => OrderModel.fromMap(map, id),
    ).map((orders) {
      orders.sort((a, b) => _orderTimestampValue(b).compareTo(_orderTimestampValue(a)));
      return orders;
    });
  }

  Stream<List<OrderModel>> watchAvailableDeliveryOrders() {
    if (_backendCommerce.isConfigured) {
      return (() async* {
        yield await _backendCommerce.getAvailableDeliveries();
        while (true) {
          await Future<void>.delayed(const Duration(seconds: 15));
          final orders = await _backendCommerce.getAvailableDeliveries();
          orders.sort((a, b) => _orderTimestampValue(b).compareTo(_orderTimestampValue(a)));
          yield orders;
        }
      })();
    }
    return _watchCollection('orders', (map, id) => OrderModel.fromMap(map, id)).map((orders) {
      final filtered = orders.where(_isOrderAvailableForRider).toList()
        ..sort((a, b) => _orderTimestampValue(b).compareTo(_orderTimestampValue(a)));
      return filtered;
    });
  }

  Future<List<OrderModel>> getAvailableDeliveryOrders() async {
    if (_backendCommerce.isConfigured) {
      final orders = await _backendCommerce.getAvailableDeliveries();
      orders.sort((a, b) => _orderTimestampValue(b).compareTo(_orderTimestampValue(a)));
      return orders;
    }
    final orders = await _fetchCollection('orders', (map, id) => OrderModel.fromMap(map, id));
    final filtered = orders.where(_isOrderAvailableForRider).toList();
    filtered.sort((a, b) => _orderTimestampValue(b).compareTo(_orderTimestampValue(a)));
    return filtered;
  }

  bool _isOrderAvailableForRider(OrderModel order) {
    final status = order.status.trim().toLowerCase();
    final delivery = order.deliveryStatus.trim().toLowerCase();
    final readyForPickup = status == 'packed' || status == 'confirmed' || delivery == 'ready for pickup';
    final closed = status == 'delivered' || status == 'cancelled' || delivery == 'delivered';
    return order.riderId == null && readyForPickup && !closed;
  }

  Future<void> acceptDeliveryRequest(String orderId, AppUser actor) async {
    if (_backendCommerce.isConfigured) {
      await _backendCommerce.acceptDelivery(orderId);
      return;
    }
    if (!isRider(actor) && !isSuperAdmin(actor)) {
      throw StateError('Only riders can accept delivery requests.');
    }
    if (!isSuperAdmin(actor) && actor.riderApprovalStatus != 'approved') {
      throw StateError('Rider approval is required before accepting deliveries.');
    }
    final existing = await _fetchDocument('orders/$orderId', (map, id) => OrderModel.fromMap(map, id));
    if (existing == null) {
      throw StateError('Order not found.');
    }
    if (!_isOrderAvailableForRider(existing) && existing.riderId != actor.id && !isSuperAdmin(actor)) {
      throw StateError('This delivery is not available for pickup.');
    }
    if (existing.riderId != null && existing.riderId != actor.id && !isSuperAdmin(actor)) {
      throw StateError('Delivery already accepted by another rider.');
    }
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final riderNotifId = 'n-rider-${now.millisecondsSinceEpoch}';
    final customerNotifId = 'n-customer-${now.millisecondsSinceEpoch}';
    final updates = <String, dynamic>{
      'orders/$orderId/riderId': actor.id,
      'orders/$orderId/assignedDeliveryPartner': actor.name,
      'orders/$orderId/deliveryStatus': 'Assigned',
      'orders/$orderId/updatedAt': nowIso,
      'orders/$orderId/trackingTimestamps': _trackingTimestampsForStatus(existing, 'Assigned', nowIso),
      'tasks/${_taskIdForDelivery(orderId)}': UnifiedRiderTask(
        id: _taskIdForDelivery(orderId),
        type: 'delivery',
        orderId: existing.id,
        userId: existing.userId,
        address: existing.shippingAddress,
        status: 'assigned',
        riderId: actor.id,
        createdAt: existing.createdAt ?? nowIso,
        updatedAt: nowIso,
      ).toMap(),
      'notifications/$riderNotifId': AppNotification(
        id: riderNotifId,
        title: 'Delivery accepted',
        body: 'You accepted delivery for order $orderId.',
        type: 'delivery',
        isRead: false,
        timestamp: now,
        audienceRole: 'rider',
        userId: actor.id,
      ).toMap(),
      'notifications/$customerNotifId': AppNotification(
        id: customerNotifId,
        title: 'Delivery partner assigned',
        body: '${actor.name} is now assigned to deliver your order.',
        type: 'order',
        isRead: false,
        timestamp: now,
        audienceRole: 'user',
          userId: existing.userId,
          storeId: existing.storeId,
        ).toMap(),
      };
    await _queueActivityLogWrite(
      updates,
      action: 'accept_delivery',
      targetType: 'order',
      targetId: orderId,
      message: 'Accepted delivery for order $orderId.',
      actor: actor,
      timestamp: nowIso,
    );
    await _ref('').update(updates);
  }

  Future<void> updateDeliveryStatus(String orderId, String deliveryStatus, {required AppUser actor}) async {
    if (_backendCommerce.isConfigured) {
      await _backendCommerce.updateDeliveryStatus(orderId, deliveryStatus);
      return;
    }
    final existing = await _fetchDocument('orders/$orderId', (map, id) => OrderModel.fromMap(map, id));
    if (existing == null) {
      throw StateError('Order not found.');
    }
    if (!isSuperAdmin(actor)) {
      _requireRiderAccess(actor, existing);
    }
    if (!isSuperAdmin(actor) && actor.riderApprovalStatus != 'approved') {
      throw StateError('Rider approval is required before updating delivery status.');
    }
    final normalizedDeliveryStatus = _normalizeRiderDeliveryStatus(deliveryStatus);
    if (existing.deliveryStatus == normalizedDeliveryStatus) {
      return;
    }
    final validatedDeliveryStatus = _validatedRiderDeliveryStatus(existing, deliveryStatus);
    final nowIso = _nowIso();

    final updates = <String, dynamic>{
      'orders/$orderId/deliveryStatus': validatedDeliveryStatus,
      'orders/$orderId/updatedAt': nowIso,
      'orders/$orderId/trackingTimestamps': _trackingTimestampsForStatus(existing, validatedDeliveryStatus, nowIso),
      'tasks/${_taskIdForDelivery(orderId)}/status': validatedDeliveryStatus == 'Delivered'
          ? 'completed'
          : (validatedDeliveryStatus == 'Picked up' || validatedDeliveryStatus == 'Out for delivery'
              ? 'in_progress'
              : 'assigned'),
      'tasks/${_taskIdForDelivery(orderId)}/updatedAt': nowIso,
    };

    if (validatedDeliveryStatus == 'Picked up') {
      updates['orders/$orderId/status'] = 'Picked up';
    } else if (validatedDeliveryStatus == 'Out for delivery') {
      updates['orders/$orderId/status'] = 'Out for delivery';
    }

    if (validatedDeliveryStatus == 'Delivered') {
      if (existing.isDelivered) {
        throw StateError('This order is already marked as delivered.');
      }
      updates['orders/$orderId/status'] = 'Delivered';
      updates['orders/$orderId/isDelivered'] = true;
      updates['orders/$orderId/deliveredAt'] = nowIso;
      if (existing.payoutStatus != 'Paid') {
        updates['orders/$orderId/payoutStatus'] = 'Ready';
      }

      if (existing.payoutStatus != 'Ready' && existing.payoutStatus != 'Paid') {
        final store = await _fetchDocument('stores/${existing.storeId}', (map, id) => Store.fromMap(map, id));
        if (store != null) {
          updates['stores/${store.id}/walletBalance'] = store.walletBalance + existing.vendorEarnings;
        }
      }

      final notifId = 'n-${DateTime.now().millisecondsSinceEpoch}-delivered';
      final notification = AppNotification(
        id: notifId,
        title: 'Order Delivered',
        body: 'Order ${existing.invoiceNumber.isEmpty ? '#$orderId' : existing.invoiceNumber} has been delivered.',
        type: 'order',
        isRead: false,
        timestamp: DateTime.now(),
        audienceRole: 'user',
        userId: existing.userId,
        storeId: existing.storeId,
      );
      updates['notifications/$notifId'] = notification.toMap();
    }

    await _queueActivityLogWrite(
      updates,
        action: 'update_delivery_status',
        targetType: 'order',
        targetId: orderId,
        message: 'Updated delivery status to $validatedDeliveryStatus.',
        actor: actor,
        timestamp: nowIso,
      );

    await _ref('').update(updates);
  }

  Future<void> updateRiderLocation({
    required String orderId,
    required double latitude,
    required double longitude,
    required AppUser actor,
  }) async {
    if (_backendCommerce.isConfigured) {
      await _backendCommerce.updateRiderLocation(
        orderId: orderId,
        latitude: latitude,
        longitude: longitude,
      );
      return;
    }
    final existing = await _fetchDocument('orders/$orderId', (map, id) => OrderModel.fromMap(map, id));
    if (existing == null) {
      throw StateError('Order not found.');
    }
    if (!isSuperAdmin(actor)) {
      _requireRiderAccess(actor, existing);
    }
    if (!isSuperAdmin(actor) && actor.riderApprovalStatus != 'approved') {
      throw StateError('Rider approval is required before sharing live location.');
    }
    await _ref('orders/$orderId').update({
      'riderLatitude': latitude,
      'riderLongitude': longitude,
      'riderLocationUpdatedAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<int> getUsersCount() async {
    if (_backendCommerce.isConfigured) {
      return (await _backendCommerce.getAdminUsers()).length;
    }
    return (await _fetchCollection('users', (map, _) => AppUser.fromMap(map))).length;
  }

  Future<int> getStoresCount() async {
    if (_backendCommerce.isConfigured) {
      return (await _backendCommerce.getAdminStores()).length;
    }
    return (await _fetchCollection('stores', (map, id) => Store.fromMap(map, id))).length;
  }

  Future<int> getOrdersCount() async {
    if (_backendCommerce.isConfigured) {
      return (await _backendCommerce.getAdminOrders()).length;
    }
    return (await _fetchCollection('orders', (map, id) => OrderModel.fromMap(map, id))).length;
  }

  Future<List<AppNotification>> getNotificationsFor(AppUser? actor) async {
    final user = actor;
    if (user == null) {
      return [];
    }
    if (_backendCommerce.isConfigured) {
      if (isSuperAdmin(user)) {
        return _sortedNotifications(await _backendCommerce.getAdminNotifications());
      }
      return [];
    }
    try {
      if (isSuperAdmin(user)) {
        final adminNotifications = await _fetchQueryCollection(
          _ref('notifications').orderByChild('audienceRole').equalTo('admin'),
          (map, _) => AppNotification.fromMap(map),
        );
        final globalNotifications = await _fetchQueryCollection(
          _ref('notifications').orderByChild('audienceRole').equalTo('all'),
          (map, _) => AppNotification.fromMap(map),
        );
        return _sortedNotifications([...adminNotifications, ...globalNotifications]);
      }

      if (user.role == 'vendor' && user.storeId != null && user.storeId!.isNotEmpty) {
        final vendorNotifications = await _fetchQueryCollection(
          _ref('notifications').orderByChild('storeId').equalTo(user.storeId),
          (map, _) => AppNotification.fromMap(map),
        );
        return _sortedNotifications(
          vendorNotifications.where((notification) => notification.audienceRole == 'vendor'),
        );
      }

      final scopedUserNotifications = await _fetchQueryCollection(
        _ref('notifications').orderByChild('userId').equalTo(user.id),
        (map, _) => AppNotification.fromMap(map),
      );

      if (user.role == riderRole) {
        final riderBroadcastNotifications = await _fetchQueryCollection(
          _ref('notifications').orderByChild('audienceRole').equalTo('rider'),
          (map, _) => AppNotification.fromMap(map),
        );
        return _sortedNotifications(
          [
            ...scopedUserNotifications.where((notification) => notification.audienceRole == 'rider'),
            ...riderBroadcastNotifications.where(
              (notification) => notification.userId == null || notification.userId == user.id,
            ),
          ],
        );
      }

      final globalNotifications = await _fetchQueryCollection(
        _ref('notifications').orderByChild('audienceRole').equalTo('all'),
        (map, _) => AppNotification.fromMap(map),
      );
      return _sortedNotifications([
        ...scopedUserNotifications.where(
          (notification) => notification.audienceRole == 'user' || notification.audienceRole == 'customer',
        ),
        ...globalNotifications,
      ]);
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        debugPrint('Notifications unavailable for ${user.id}: ${error.message}');
        return const <AppNotification>[];
      }
      rethrow;
    }
  }

  Future<void> markAllNotificationsRead(AppUser? actor) async {
    if (_backendCommerce.isConfigured) {
      return;
    }
    final visible = await getNotificationsFor(actor);
    for (final notification in visible) {
      await _ref('notifications/${notification.id}').update({'isRead': true});
    }
  }

  Future<void> createAbandonedCartReminder({
    required AppUser user,
    required List<OrderItem> items,
    String offerCode = 'COMPLETE10',
  }) async {
    if (_backendCommerce.isConfigured) {
      return;
    }
    if (items.isEmpty) {
      return;
    }
    await _ref('notifications/n-abandoned-${DateTime.now().millisecondsSinceEpoch}').set(
      AppNotification(
        id: 'n-abandoned-${DateTime.now().millisecondsSinceEpoch}',
        title: 'Complete your order now',
        body: 'Your ${items.first.productName} is still waiting in the bag. Use $offerCode to finish checkout.',
        type: 'abandoned_cart',
        isRead: false,
        timestamp: DateTime.now(),
        audienceRole: 'user',
        userId: user.id,
      ).toMap(),
    );
  }

  Future<AdminAnalytics> getAdminAnalytics() async {
    if (_backendCommerce.isConfigured) {
      return _backendCommerce.getAdminDashboard();
    }
    final orders = await getAllOrders();
    final stores = await getAdminStores();
    final delivered = orders.where((order) => order.status == 'Delivered' || order.status == 'Shipped').toList();
    final totalRevenue = delivered.fold<double>(0, (sum, order) => sum + order.totalAmount);
    final commissionRevenue = delivered.fold<double>(0, (sum, order) => sum + order.platformCommission);
    final storeTotals = <String, double>{};
    for (final order in delivered) {
      storeTotals.update(order.storeId, (value) => value + order.totalAmount, ifAbsent: () => order.totalAmount);
    }
    final topStores = stores.toList()
      ..sort((a, b) => (storeTotals[b.id] ?? 0).compareTo(storeTotals[a.id] ?? 0));
    final dailySales = List.generate(7, (index) {
      final day = DateTime.now().subtract(Duration(days: 6 - index));
      final value = delivered
          .where((order) =>
              order.timestamp.year == day.year && order.timestamp.month == day.month && order.timestamp.day == day.day)
          .fold<double>(0, (sum, order) => sum + order.totalAmount);
      return AnalyticsPoint(label: DateFormat('dd MMM').format(day), value: value);
    });
    final weeklySales = List.generate(4, (index) {
      final weekStart = DateTime.now().subtract(Duration(days: (3 - index) * 7));
      final weekEnd = weekStart.add(const Duration(days: 6));
      final value = delivered
          .where((order) => !order.timestamp.isBefore(weekStart) && !order.timestamp.isAfter(weekEnd))
          .fold<double>(0, (sum, order) => sum + order.totalAmount);
      return AnalyticsPoint(label: 'W${index + 1}', value: value);
    });
    return AdminAnalytics(
      totalRevenue: totalRevenue,
      platformCommissionRevenue: commissionRevenue,
      totalOrders: orders.length,
      topStores: topStores.take(3).toList(),
      dailySales: dailySales,
      weeklySales: weeklySales,
    );
  }

  Future<VendorAnalytics> getVendorAnalytics(String storeId, {AppUser? actor}) async {
    if (_backendCommerce.isConfigured) {
      final store = await getStoreByOwner(actor?.id ?? '');
      final orders = await _backendCommerce.getStoreOrders(storeId);
      final totalSales = orders.fold<double>(0, (sum, order) => sum + order.totalAmount);
      final totalEarnings = totalSales;
      final products = await getProductsByStore(storeId)
        ..sort((a, b) => b.reviewCount.compareTo(a.reviewCount));
      final salesTrend = List.generate(7, (index) {
        final day = DateTime.now().subtract(Duration(days: 6 - index));
        final value = orders
            .where((order) =>
                order.timestamp.year == day.year &&
                order.timestamp.month == day.month &&
                order.timestamp.day == day.day)
            .fold<double>(0, (sum, order) => sum + order.totalAmount);
        return AnalyticsPoint(label: DateFormat('dd').format(day), value: value);
      });
      return VendorAnalytics(
        totalSales: totalSales,
        availableBalance: store?.walletBalance ?? 0,
        totalEarnings: totalEarnings,
        orders: orders.length,
        bestSellingProducts: products.take(3).toList(),
        salesTrend: salesTrend,
      );
    }
    _requireStoreAccess(actor, storeId);
    final orders = (await getAllOrders()).where((order) => order.storeId == storeId).toList();
    final totalSales = orders.fold<double>(0, (sum, order) => sum + order.totalAmount);
    final totalEarnings = orders.fold<double>(0, (sum, order) => sum + order.vendorEarnings);
    final store = (await getAdminStores()).firstWhere((candidate) => candidate.id == storeId);
    final productUnits = <String, int>{};
    for (final order in orders) {
      for (final item in order.items) {
        productUnits.update(item.productId, (value) => value + item.quantity, ifAbsent: () => item.quantity);
      }
    }
    final bestSellingProducts = await getProductsByStore(storeId)
      ..sort((a, b) => (productUnits[b.id] ?? 0).compareTo(productUnits[a.id] ?? 0));
    final salesTrend = List.generate(7, (index) {
      final day = DateTime.now().subtract(Duration(days: 6 - index));
      final value = orders
          .where((order) =>
              order.timestamp.year == day.year && order.timestamp.month == day.month && order.timestamp.day == day.day)
          .fold<double>(0, (sum, order) => sum + order.vendorEarnings);
      return AnalyticsPoint(label: DateFormat('dd').format(day), value: value);
    });
    return VendorAnalytics(
      totalSales: totalSales,
      availableBalance: store.walletBalance,
      totalEarnings: totalEarnings,
      orders: orders.length,
      bestSellingProducts: bestSellingProducts.take(3).toList(),
      salesTrend: salesTrend,
    );
  }

  Future<List<PayoutModel>> getPayouts({AppUser? actor, String? storeId}) async {
    if (_backendCommerce.isConfigured) {
      if (actor != null && !isSuperAdmin(actor)) {
        _requireStoreAccess(actor, storeId ?? actor.storeId ?? '');
      }
      final payouts = await _backendCommerce.getAdminPayouts();
      final scoped = storeId == null
          ? payouts
          : payouts.where((payout) => payout.storeId == storeId).toList();
      scoped.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return scoped;
    }
    if (actor != null && !isSuperAdmin(actor)) {
      _requireStoreAccess(actor, storeId ?? actor.storeId ?? '');
    }
    final payouts = storeId != null
        ? await _fetchQueryCollection(
            _ref('payouts').orderByChild('storeId').equalTo(storeId),
            (map, id) => PayoutModel.fromMap(map, id),
          )
        : await _fetchCollection('payouts', (map, id) => PayoutModel.fromMap(map, id));
    payouts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return payouts;
  }

  Future<PayoutModel?> processVendorPayout({
    required String storeId,
    required AppUser actor,
    String periodLabel = 'Manual payout',
  }) async {
    if (_backendCommerce.isConfigured) {
      _requireSuperAdmin(actor);
      final payout = await _backendCommerce.processAdminPayout(
        storeId: storeId,
        periodLabel: periodLabel,
      );
      if (payout != null) {
        _addNotification(
          AppNotification(
            id: 'n-payout-${DateTime.now().millisecondsSinceEpoch}',
            title: 'Payout processed',
            body: 'Vendor payout of Rs ${payout.amount.toInt()} has been processed.',
            type: 'payout',
            isRead: false,
            timestamp: DateTime.now(),
            audienceRole: 'vendor',
            storeId: storeId,
          ),
        );
      }
      return payout;
    }
    _requireSuperAdmin(actor);
    final readyOrders = (await getAllOrders()).where((order) {
      return order.storeId == storeId && order.payoutStatus == 'Ready' && !order.payoutProcessed;
    }).toList();
    if (readyOrders.isEmpty) {
      return null;
    }
    final now = DateTime.now();
    final payout = PayoutModel(
      id: 'pay-${now.millisecondsSinceEpoch}',
      storeId: storeId,
      processedBy: actor.id,
      amount: readyOrders.fold<double>(0, (sum, order) => sum + order.vendorEarnings),
      periodLabel: periodLabel,
      createdAt: now,
      orderIds: readyOrders.map((order) => order.id).toList(),
    );
    final updates = <String, dynamic>{
      'payouts/${payout.id}': payout.toMap(),
    };
    final store = await _fetchDocument('stores/$storeId', (map, id) => Store.fromMap(map, id));
    if (store != null) {
      updates['stores/$storeId/walletBalance'] = (store.walletBalance - payout.amount).clamp(0, double.infinity).toDouble();
    }
    for (final order in readyOrders) {
      updates['orders/${order.id}/payoutStatus'] = 'Paid';
      updates['orders/${order.id}/payoutId'] = payout.id;
      updates['orders/${order.id}/payoutProcessed'] = true;
      updates['orders/${order.id}/updatedAt'] = now.toIso8601String();
    }
    await _queueActivityLogWrite(
      updates,
      action: 'process_payout',
      targetType: 'payout',
      targetId: payout.id,
      message: 'Processed payout ${payout.id} for store $storeId covering ${readyOrders.length} orders.',
      actor: actor,
      timestamp: now.toIso8601String(),
    );
    await _ref('').update(updates);
    _addNotification(
      AppNotification(
        id: 'n-payout-${now.millisecondsSinceEpoch}',
        title: 'Payout processed',
        body: 'Vendor payout of Rs ${payout.amount.toInt()} has been processed.',
        type: 'payout',
        isRead: false,
        timestamp: now,
        audienceRole: 'vendor',
        storeId: storeId,
      ),
    );
    return payout;
  }

  Future<VendorKycRequest?> getVendorKycRequestForUser(String userId) {
    if (_backendCommerce.isConfigured) {
      return _backendCommerce.getMyVendorKycRequest();
    }
    return _fetchDocument(
      'vendorRequests/vendor-$userId',
      (map, id) => VendorKycRequest.fromMap(map, id),
    );
  }

  Future<RiderKycRequest?> getRiderKycRequestForUser(String userId) {
    if (_backendCommerce.isConfigured) {
      return _backendCommerce.getMyRiderKycRequest();
    }
    return _fetchDocument(
      'riderRequests/rider-$userId',
      (map, id) => RiderKycRequest.fromMap(map, id),
    );
  }

  Future<List<VendorKycRequest>> getVendorKycRequests({required AppUser actor}) async {
    if (_backendCommerce.isConfigured) {
      _requireSuperAdmin(actor);
      return _backendCommerce.getVendorKycRequests();
    }
    _requireSuperAdmin(actor);
    final requests = await _fetchCollection(
      'vendorRequests',
      (map, id) => VendorKycRequest.fromMap(map, id),
    );
    requests.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return requests;
  }

  Future<List<RiderKycRequest>> getRiderKycRequests({required AppUser actor}) async {
    if (_backendCommerce.isConfigured) {
      _requireSuperAdmin(actor);
      return _backendCommerce.getRiderKycRequests();
    }
    _requireSuperAdmin(actor);
    final requests = await _fetchCollection(
      'riderRequests',
      (map, id) => RiderKycRequest.fromMap(map, id),
    );
    requests.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return requests;
  }

  Future<VendorKycRequest> submitVendorKycRequest(VendorKycRequest request, {required AppUser actor}) async {
    if (_backendCommerce.isConfigured) {
      if (actor.id != request.userId) {
        throw StateError('You can only submit KYC for your own account.');
      }
      return _backendCommerce.submitVendorKycRequest(request);
    }
    if (actor.id != request.userId) {
      throw StateError('You can only submit KYC for your own account.');
    }
    final existing = await getVendorKycRequestForUser(request.userId);
    if (existing != null && existing.status == 'approved') {
      throw StateError('Vendor KYC is already approved for this account.');
    }
    final nowIso = DateTime.now().toIso8601String();
    final analysis = await _kycAi.analyzeVendorDocuments(
      ownerName: request.ownerName,
      aadhaarImageUrl: request.kyc.aadhaarUrl,
      panImageUrl: request.kyc.panUrl,
    );
    final mergedAnalysis = analysis.copyWith(
      livenessPassed: request.verification.livenessPassed,
      faceVerified: request.verification.faceVerified,
      matchScore: request.verification.matchScore,
      livenessMode: request.verification.livenessMode,
      selfieRetryCount: request.verification.selfieRetryCount,
      selfieVerifiedAt: request.verification.selfieVerifiedAt,
      flags: <String>{
        ...analysis.flags,
        ...request.verification.flags,
      }.toList(),
      provider: request.verification.faceVerified
          ? '${analysis.provider}+${request.verification.provider}'
          : analysis.provider,
    );
    final verification = await _finalizeVendorKycVerification(
      verification: mergedAnalysis,
      actor: actor,
      request: request,
    );
    final resolved = request.copyWith(
      id: 'vendor-${request.userId}',
      status: 'pending',
      createdAt: existing?.createdAt.isNotEmpty == true ? existing!.createdAt : nowIso,
      updatedAt: nowIso,
      rejectionReason: '',
      reviewedBy: '',
      reviewedByName: '',
      reviewedAt: '',
      actionHistory: [
        ...(existing?.actionHistory ?? const <KycActionEntry>[]),
        KycActionEntry(
          action: existing == null ? 'submitted' : 'resubmitted',
          actorId: actor.id,
          actorName: actor.name,
          timestamp: nowIso,
          note: existing == null
              ? 'Initial vendor KYC submission. ${verification.reviewSummary}'
              : 'Vendor KYC re-submitted with updated documents. ${verification.reviewSummary}',
        ),
      ],
      verification: verification,
    );
    await _ref('vendorRequests/${resolved.id}').set(resolved.toMap());
    await _ref('vendorRiskAssessments/${request.userId}').set({
      'userId': request.userId,
      'requestId': resolved.id,
      'riskScore': verification.riskScore,
      'status': verification.riskDecision,
      'kycVerified': verification.aadhaarValid && verification.panValid,
      'faceVerified': verification.faceVerified,
      'livenessPassed': verification.livenessPassed,
      'confidenceScore': verification.confidenceScore,
      'matchScore': verification.matchScore,
      'fraudFlags': verification.flags,
      'duplicateDetected': verification.duplicateDetected,
      'gpsValid': verification.gpsValid,
      'nameMatch': verification.nameMatch,
      'addressMatch': verification.addressMatch,
      'createdAt': existing?.createdAt.isNotEmpty == true ? existing!.createdAt : nowIso,
      'updatedAt': nowIso,
    });
    if (verification.duplicateDetected || verification.autoReviewStatus == 'fraud_flagged') {
      await _ref('kycFraudLogs/${resolved.id}-${DateTime.now().millisecondsSinceEpoch}').set({
        'userId': actor.id,
        'requestId': resolved.id,
        'requestType': 'vendor',
        'confidenceScore': verification.confidenceScore,
        'flags': verification.flags,
        'duplicateDetected': verification.duplicateDetected,
        'duplicateMatches': verification.duplicateMatches,
        'timestamp': nowIso,
      });
    }
    _addNotification(
      AppNotification(
        id: 'vendor-kyc-${DateTime.now().millisecondsSinceEpoch}',
        title: 'New vendor KYC request',
        body: verification.autoReviewStatus == 'auto_verified'
            ? '${request.ownerName} submitted vendor verification for ${request.storeName} with strong AI confidence.'
            : verification.autoReviewStatus == 'fraud_flagged'
                ? '${request.ownerName} submitted vendor verification for ${request.storeName}; the request was flagged for review.'
                : '${request.ownerName} submitted vendor verification for ${request.storeName}.',
        type: 'kyc',
        isRead: false,
        timestamp: DateTime.now(),
        audienceRole: 'admin',
        userId: request.userId,
      ),
    );
    await logActivity(
      action: 'submit_vendor_kyc',
      targetType: 'vendor_request',
      targetId: resolved.id,
      message: 'Submitted vendor KYC request for ${request.storeName}.',
      actor: actor,
    );
    return resolved;
  }

  Future<void> submitRiderKycRequest(RiderKycRequest request, {required AppUser actor}) async {
    if (_backendCommerce.isConfigured) {
      if (actor.id != request.userId) {
        throw StateError('You can only submit KYC for your own account.');
      }
      await _backendCommerce.submitRiderKycRequest(request);
      return;
    }
    if (actor.id != request.userId) {
      throw StateError('You can only submit KYC for your own account.');
    }
    final existing = await getRiderKycRequestForUser(request.userId);
    if (existing != null && existing.status == 'approved') {
      throw StateError('Rider KYC is already approved for this account.');
    }
    final nowIso = DateTime.now().toIso8601String();
    final resolved = request.copyWith(
      id: 'rider-${request.userId}',
      status: 'pending',
      createdAt: existing?.createdAt.isNotEmpty == true ? existing!.createdAt : nowIso,
      updatedAt: nowIso,
      rejectionReason: '',
      reviewedBy: '',
      reviewedByName: '',
      reviewedAt: '',
      actionHistory: [
        ...(existing?.actionHistory ?? const <KycActionEntry>[]),
        KycActionEntry(
          action: existing == null ? 'submitted' : 'resubmitted',
          actorId: actor.id,
          actorName: actor.name,
          timestamp: nowIso,
          note: existing == null ? 'Initial rider KYC submission.' : 'Rider KYC re-submitted with updated documents.',
        ),
      ],
    );
    await _ref('riderRequests/${resolved.id}').set(resolved.toMap());
    _addNotification(
      AppNotification(
        id: 'rider-kyc-${DateTime.now().millisecondsSinceEpoch}',
        title: 'New rider KYC request',
        body: '${request.name} submitted rider verification for ${request.city}.',
        type: 'kyc',
        isRead: false,
        timestamp: DateTime.now(),
        audienceRole: 'admin',
        userId: request.userId,
      ),
    );
    await logActivity(
      action: 'submit_rider_kyc',
      targetType: 'rider_request',
      targetId: resolved.id,
      message: 'Submitted rider KYC request for ${request.name}.',
      actor: actor,
    );
  }

  Future<void> approveVendorKycRequest({
    required String requestId,
    required AppUser actor,
  }) async {
    if (_backendCommerce.isConfigured) {
      _requireSuperAdmin(actor);
      await _backendCommerce.reviewVendorKycRequest(
        requestId: requestId,
        status: 'approved',
      );
      return;
    }
    _requireSuperAdmin(actor);
    final request = await _fetchDocument(
      'vendorRequests/$requestId',
      (map, id) => VendorKycRequest.fromMap(map, id),
    );
    if (request == null) {
      throw StateError('Vendor request not found.');
    }
    final user = await getUser(request.userId);
    if (user == null) {
      throw StateError('Applicant account not found.');
    }
    final nowIso = DateTime.now().toIso8601String();
    final existingStore = await getStoreByOwner(request.userId);
    final storeId = existingStore?.id ?? 'store-${DateTime.now().millisecondsSinceEpoch}';
    final roles = Map<String, bool>.from(user.roles)
      ..['customer'] = true
      ..['vendor'] = true;

    await saveStore(
      Store(
        id: storeId,
        ownerId: request.userId,
        name: request.storeName,
        description: existingStore?.description ?? 'Approved vendor storefront on ABZORA.',
        imageUrl: request.kyc.storeImageUrl.isNotEmpty
            ? request.kyc.storeImageUrl
            : (existingStore?.imageUrl ??
                'https://images.unsplash.com/photo-1441986300917-64674bd600d8?auto=format&fit=crop&q=80&w=400'),
        rating: existingStore?.rating ?? 0,
        reviewCount: existingStore?.reviewCount ?? 0,
        address: request.address,
        city: request.city,
        isApproved: true,
        isActive: true,
        isFeatured: existingStore?.isFeatured ?? false,
        approvalStatus: 'approved',
        logoUrl: existingStore?.logoUrl ?? request.kyc.ownerPhotoUrl,
        bannerImageUrl: existingStore?.bannerImageUrl ?? request.kyc.storeImageUrl,
        tagline: existingStore?.tagline ?? '',
        commissionRate: existingStore?.commissionRate ?? 0.12,
        walletBalance: existingStore?.walletBalance ?? 0,
        latitude: request.latitude,
        longitude: request.longitude,
        category: existingStore?.category ?? 'Fashion',
        vendorScore: existingStore?.vendorScore ?? 0,
        vendorRank: existingStore?.vendorRank ?? 0,
        vendorVisibility: existingStore?.vendorVisibility ?? 'normal',
        performanceMetrics:
            existingStore?.performanceMetrics ?? const VendorPerformanceMetrics(),
      ),
      actor: actor,
    );
    await updateUser(
      user.copyWith(
        name: request.ownerName,
        phone: request.phone,
        address: request.address,
        city: request.city,
        latitude: request.latitude,
        longitude: request.longitude,
        role: 'vendor',
        storeId: storeId,
        roles: roles,
        isActive: true,
      ),
      actor: actor,
    );
    await _ref('vendorRequests/$requestId').update({
      'status': 'approved',
      'updatedAt': nowIso,
      'rejectionReason': '',
      'reviewedBy': actor.id,
      'reviewedByName': actor.name,
      'reviewedAt': nowIso,
      'actionHistory': [
        ...request.actionHistory.map((entry) => entry.toMap()),
        KycActionEntry(
          action: 'approved',
          actorId: actor.id,
          actorName: actor.name,
          timestamp: nowIso,
          note: 'Vendor KYC approved and store activated.',
        ).toMap(),
      ],
    });
    _addNotification(
      AppNotification(
        id: 'vendor-kyc-approved-${DateTime.now().millisecondsSinceEpoch}',
        title: 'Vendor KYC approved',
        body: 'Your vendor application for ${request.storeName} is approved. You can now manage your store.',
        type: 'kyc',
        isRead: false,
        timestamp: DateTime.now(),
        audienceRole: 'user',
        userId: request.userId,
        storeId: storeId,
      ),
    );
    await logActivity(
      action: 'approve_vendor_kyc',
      targetType: 'vendor_request',
      targetId: requestId,
      message: 'Approved vendor KYC request for ${request.storeName}.',
      actor: actor,
    );
  }

  Future<void> rejectVendorKycRequest({
    required String requestId,
    required String reason,
    required AppUser actor,
  }) async {
    if (_backendCommerce.isConfigured) {
      _requireSuperAdmin(actor);
      await _backendCommerce.reviewVendorKycRequest(
        requestId: requestId,
        status: 'rejected',
        reason: reason,
      );
      return;
    }
    _requireSuperAdmin(actor);
    final request = await _fetchDocument(
      'vendorRequests/$requestId',
      (map, id) => VendorKycRequest.fromMap(map, id),
    );
    if (request == null) {
      throw StateError('Vendor request not found.');
    }
      await _ref('vendorRequests/$requestId').update({
        'status': 'rejected',
        'updatedAt': DateTime.now().toIso8601String(),
        'rejectionReason': reason.trim(),
        'reviewedBy': actor.id,
        'reviewedByName': actor.name,
        'reviewedAt': DateTime.now().toIso8601String(),
        'actionHistory': [
          ...request.actionHistory.map((entry) => entry.toMap()),
          KycActionEntry(
            action: 'rejected',
            actorId: actor.id,
            actorName: actor.name,
            timestamp: DateTime.now().toIso8601String(),
            note: reason.trim(),
          ).toMap(),
        ],
      });
    _addNotification(
      AppNotification(
        id: 'vendor-kyc-rejected-${DateTime.now().millisecondsSinceEpoch}',
        title: 'Vendor KYC rejected',
        body: 'Your vendor application needs updated documents. Reason: ${reason.trim()}',
        type: 'kyc',
        isRead: false,
        timestamp: DateTime.now(),
        audienceRole: 'user',
        userId: request.userId,
      ),
    );
    await logActivity(
      action: 'reject_vendor_kyc',
      targetType: 'vendor_request',
      targetId: requestId,
      message: 'Rejected vendor KYC request. Reason: ${reason.trim()}',
      actor: actor,
    );
  }

  Future<void> approveRiderKycRequest({
    required String requestId,
    required AppUser actor,
  }) async {
    if (_backendCommerce.isConfigured) {
      _requireSuperAdmin(actor);
      await _backendCommerce.reviewRiderKycRequest(
        requestId: requestId,
        status: 'approved',
      );
      return;
    }
    _requireSuperAdmin(actor);
    final request = await _fetchDocument(
      'riderRequests/$requestId',
      (map, id) => RiderKycRequest.fromMap(map, id),
    );
    if (request == null) {
      throw StateError('Rider request not found.');
    }
    final user = await getUser(request.userId);
    if (user == null) {
      throw StateError('Applicant account not found.');
    }
    final roles = Map<String, bool>.from(user.roles)
      ..['customer'] = true
      ..['rider'] = true;
    await updateUser(
      user.copyWith(
        name: request.name,
        phone: request.phone,
        city: request.city,
        riderCity: request.city,
        riderVehicleType: request.vehicle,
        riderApprovalStatus: 'approved',
        role: 'rider',
        roles: roles,
        isActive: true,
      ),
      actor: actor,
    );
      await _ref('riderRequests/$requestId').update({
        'status': 'approved',
        'updatedAt': DateTime.now().toIso8601String(),
        'rejectionReason': '',
        'reviewedBy': actor.id,
        'reviewedByName': actor.name,
        'reviewedAt': DateTime.now().toIso8601String(),
        'actionHistory': [
          ...request.actionHistory.map((entry) => entry.toMap()),
          KycActionEntry(
            action: 'approved',
            actorId: actor.id,
            actorName: actor.name,
            timestamp: DateTime.now().toIso8601String(),
            note: 'Rider KYC approved and rider role activated.',
          ).toMap(),
        ],
      });
    _addNotification(
      AppNotification(
        id: 'rider-kyc-approved-${DateTime.now().millisecondsSinceEpoch}',
        title: 'Rider KYC approved',
        body: 'Your rider application is approved. Delivery requests are now available in your dashboard.',
        type: 'kyc',
        isRead: false,
        timestamp: DateTime.now(),
        audienceRole: 'user',
        userId: request.userId,
      ),
    );
    await logActivity(
      action: 'approve_rider_kyc',
      targetType: 'rider_request',
      targetId: requestId,
      message: 'Approved rider KYC request for ${request.name}.',
      actor: actor,
    );
  }

  Future<void> rejectRiderKycRequest({
    required String requestId,
    required String reason,
    required AppUser actor,
  }) async {
    if (_backendCommerce.isConfigured) {
      _requireSuperAdmin(actor);
      await _backendCommerce.reviewRiderKycRequest(
        requestId: requestId,
        status: 'rejected',
        reason: reason,
      );
      return;
    }
    _requireSuperAdmin(actor);
    final request = await _fetchDocument(
      'riderRequests/$requestId',
      (map, id) => RiderKycRequest.fromMap(map, id),
    );
    if (request == null) {
      throw StateError('Rider request not found.');
    }
      await _ref('riderRequests/$requestId').update({
        'status': 'rejected',
        'updatedAt': DateTime.now().toIso8601String(),
        'rejectionReason': reason.trim(),
        'reviewedBy': actor.id,
        'reviewedByName': actor.name,
        'reviewedAt': DateTime.now().toIso8601String(),
        'actionHistory': [
          ...request.actionHistory.map((entry) => entry.toMap()),
          KycActionEntry(
            action: 'rejected',
            actorId: actor.id,
            actorName: actor.name,
            timestamp: DateTime.now().toIso8601String(),
            note: reason.trim(),
          ).toMap(),
        ],
      });
    _addNotification(
      AppNotification(
        id: 'rider-kyc-rejected-${DateTime.now().millisecondsSinceEpoch}',
        title: 'Rider KYC rejected',
        body: 'Your rider application needs updated documents. Reason: ${reason.trim()}',
        type: 'kyc',
        isRead: false,
        timestamp: DateTime.now(),
        audienceRole: 'user',
        userId: request.userId,
      ),
    );
    await logActivity(
      action: 'reject_rider_kyc',
      targetType: 'rider_request',
      targetId: requestId,
      message: 'Rejected rider KYC request. Reason: ${reason.trim()}',
      actor: actor,
    );
  }

  Stream<List<SupportChat>> watchSupportChatsForUser({required AppUser actor}) {
    if (_backendCommerce.isConfigured) {
      return (() async* {
        yield await _backendCommerce.getSupportChats();
        while (true) {
          await Future<void>.delayed(const Duration(seconds: 10));
          final chats = await _backendCommerce.getSupportChats();
          chats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          yield chats;
        }
      })().asBroadcastStream();
    }
    if (isSuperAdmin(actor)) {
      return _watchCollection(
        'supportChats',
        (map, id) => SupportChat.fromMap(map, id),
      ).map((items) {
        final chats = items.toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return chats;
      }).asBroadcastStream();
    }

    final query = _ref('supportChats').orderByChild('userId').equalTo(actor.id);
    return _watchQueryCollection(
      query,
      (map, id) => SupportChat.fromMap(map, id),
    ).map((items) {
      final chats = items.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return chats;
    }).asBroadcastStream();
  }

  Future<List<SupportChat>> getSupportChats({
    required AppUser actor,
    String? status,
    String? type,
  }) async {
    if (_backendCommerce.isConfigured) {
      final chats = await _backendCommerce.getSupportChats(status: status, type: type);
      final filtered = chats.where((chat) {
        final matchesStatus = status == null || status == 'all' || chat.status == status;
        final matchesType = type == null || type == 'all' || chat.type == type;
        return matchesStatus && matchesType;
      }).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return filtered;
    }
    final chats = isSuperAdmin(actor)
        ? await _fetchCollection(
            'supportChats',
            (map, id) => SupportChat.fromMap(map, id),
          )
        : await _fetchQueryCollection(
            _ref('supportChats').orderByChild('userId').equalTo(actor.id),
            (map, id) => SupportChat.fromMap(map, id),
          );

    final filtered = chats.where((chat) {
      final matchesStatus = status == null || status == 'all' || chat.status == status;
      final matchesType = type == null || type == 'all' || chat.type == type;
      return matchesStatus && matchesType;
    }).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return filtered;
  }

  Future<SupportChat?> getSupportChatById({
    required String chatId,
    required AppUser actor,
  }) async {
    if (_backendCommerce.isConfigured) {
      return _backendCommerce.getSupportChatById(chatId);
    }
    final chat = await _fetchDocument(
      'supportChats/$chatId',
      (map, id) => SupportChat.fromMap(map, id),
    );
    if (chat == null) {
      return null;
    }
    if (!isSuperAdmin(actor) && chat.userId != actor.id) {
      throw StateError('Support chat access denied.');
    }
    return chat;
  }

  Stream<List<SupportMessage>> watchSupportMessages({
    required String chatId,
    required AppUser actor,
    int limit = 20,
  }) {
    if (_backendCommerce.isConfigured) {
      return (() async* {
        yield await _backendCommerce.getSupportMessages(chatId, limit: limit);
        while (true) {
          await Future<void>.delayed(const Duration(seconds: 4));
          final messages = await _backendCommerce.getSupportMessages(chatId, limit: limit);
          messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          yield messages;
        }
      })().asBroadcastStream();
    }
    return Stream.fromFuture(getSupportChatById(chatId: chatId, actor: actor)).asyncExpand((chat) {
      if (chat == null) {
        return Stream.value(const <SupportMessage>[]);
      }
      final query = _ref('messages/$chatId').orderByChild('timestamp').limitToLast(limit);
      return _watchQueryCollection(
        query,
        (map, id) => SupportMessage.fromMap(map, id),
      ).map((items) {
        final messages = items.toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
        return messages;
      });
    }).asBroadcastStream();
  }

  Future<List<SupportMessage>> getOlderSupportMessages({
    required String chatId,
    required AppUser actor,
    required String beforeTimestamp,
    int limit = 20,
  }) async {
    if (_backendCommerce.isConfigured) {
      final messages = await _backendCommerce.getSupportMessages(
        chatId,
        limit: limit,
        beforeTimestamp: beforeTimestamp,
      );
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return messages;
    }
    await getSupportChatById(chatId: chatId, actor: actor);
    final query = _ref('messages/$chatId')
        .orderByChild('timestamp')
        .endAt(beforeTimestamp)
        .limitToLast(limit + 1);
    final messages = await _fetchQueryCollection(
      query,
      (map, id) => SupportMessage.fromMap(map, id),
    );
    final sorted = messages.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    if (sorted.isNotEmpty && sorted.last.timestamp == beforeTimestamp) {
      sorted.removeLast();
    }
    return sorted;
  }

  Future<List<FaqItem>> getFaqItems() async {
    if (_backendCommerce.isConfigured) {
      return const <FaqItem>[
        FaqItem(
          id: 'faq-delivery',
          question: 'How long does delivery take?',
          answer: 'Most orders are delivered within 2-5 business days based on your city.',
        ),
        FaqItem(
          id: 'faq-payment',
          question: 'Which payment methods are supported?',
          answer: 'UPI, cards, and Cash on Delivery are supported based on checkout eligibility.',
        ),
        FaqItem(
          id: 'faq-returns',
          question: 'How do I request a return or refund?',
          answer: 'Open your order details and choose return/refund if the order is eligible.',
        ),
      ];
    }
    final faqs = await _fetchCollection(
      'faq',
      (map, id) => FaqItem.fromMap(map, id),
    );
    faqs.sort((a, b) => a.question.toLowerCase().compareTo(b.question.toLowerCase()));
    return faqs;
  }

  Future<List<OrderModel>> getUserOrdersOnce(String userId) async {
    if (_backendCommerce.isConfigured) {
      final orders = await _backendCommerce.getUserOrders();
      orders.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return orders;
    }
    try {
      final orders = await _fetchQueryCollection(
        _ref('orders').orderByChild('userId').equalTo(userId),
        (map, id) => OrderModel.fromMap(map, id),
      );
      orders.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return orders;
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        debugPrint('Orders unavailable for $userId: ${error.message}');
        return const <OrderModel>[];
      }
      rethrow;
    }
  }

  Future<OrderModel?> getLatestUserOrder(String userId) async {
    final orders = await getUserOrdersOnce(userId);
    return orders.isEmpty ? null : orders.first;
  }

  bool _messageLooksLikeOrderTracking(String prompt) {
    final text = prompt.toLowerCase();
    return text.contains('where is my order') ||
        text.contains('track') ||
        text.contains('delivery status') ||
        text.contains('order status');
  }

  bool _messageLooksLikeCancellation(String prompt) {
    final text = prompt.toLowerCase();
    return text.contains('cancel') && text.contains('order');
  }

  bool _messageLooksLikePaymentHelp(String prompt) {
    final text = prompt.toLowerCase();
    return text.contains('payment') ||
        text.contains('refund') ||
        text.contains('charged') ||
        text.contains('upi') ||
        text.contains('failed transaction');
  }

  bool _messageLooksLikeAddressHelp(String prompt) {
    final text = prompt.toLowerCase();
    return text.contains('address') ||
        text.contains('delivery location') ||
        text.contains('change location');
  }

  bool _messageLooksLikeCustomHelp(String prompt) {
    final text = prompt.toLowerCase();
    return text.contains('custom') ||
        text.contains('measurement') ||
        text.contains('fit') ||
        text.contains('tailor') ||
        text.contains('style');
  }

  String _etaForOrder(OrderModel order) {
    final status = order.status.toLowerCase();
    final delivery = order.deliveryStatus.toLowerCase();
    if (status == 'delivered' || delivery == 'delivered') {
      return 'Your order has already been delivered.';
    }
    if (status == 'cancelled' || delivery == 'cancelled') {
      return 'This order is cancelled, so there is no active delivery ETA.';
    }
    if (delivery == 'out for delivery') {
      return 'It is currently out for delivery and should reach you soon.';
    }
    if (delivery == 'picked up' || delivery == 'ready for pickup') {
      return 'It is moving through the delivery handoff now.';
    }
    if (status == 'packed' || status == 'confirmed') {
      return 'The store is preparing dispatch for this order.';
    }
    return 'It is in the early processing stage right now.';
  }

  String _orderSummaryLine(OrderModel order) {
    return 'Order #${order.id} is ${order.status.toLowerCase()} with delivery status ${order.deliveryStatus.toLowerCase()}. ${_etaForOrder(order)}';
  }

  Future<OrderModel?> _resolveOrderForPrompt(AppUser actor, String prompt) async {
    final orders = await getUserOrdersOnce(actor.id);
    if (orders.isEmpty) {
      return null;
    }

    final idMatch = RegExp(r'(ord-[a-zA-Z0-9-]+|cbo-\d+)', caseSensitive: false)
        .firstMatch(prompt);
    if (idMatch != null) {
      final matchedId = idMatch.group(0)?.toLowerCase();
      for (final order in orders) {
        if (order.id.toLowerCase() == matchedId) {
          return order;
        }
      }
    }

    final active = orders.where((order) {
      final status = order.status.toLowerCase();
      return status != 'cancelled' && status != 'delivered';
    }).toList();
    if (active.isNotEmpty) {
      return active.first;
    }
    return orders.first;
  }

  Future<bool> _cancelOrderForAssistant(OrderModel order, AppUser actor) async {
    return _supportActions.cancelOrder(
      ref: _ref,
      nowIso: _nowIso(),
      order: order,
      actor: actor,
    );
  }

  Future<bool> _requestRefundForAssistant({
    required OrderModel order,
    required AppUser actor,
    required SupportChat chat,
    String? reason,
  }) async {
    try {
      final refund = await createRefundRequest(
        orderId: order.id,
        reason: reason?.trim().isNotEmpty == true ? reason!.trim() : 'Requested from AI assistant support.',
        actor: actor,
      );
      final nowIso = _nowIso();
      await _ref('').update({
        'supportChats/${chat.id}/status': 'waiting',
        'supportChats/${chat.id}/updatedAt': nowIso,
        'supportTickets/${chat.ticketId}/status': 'waiting',
        'supportTickets/${chat.ticketId}/resolvedAt': null,
        'supportTickets/${chat.ticketId}/requestedAction': 'refund',
        'supportTickets/${chat.ticketId}/refundOrderId': order.id,
        'supportTickets/${chat.ticketId}/refundReason': refund.reason,
        'supportTickets/${chat.ticketId}/refundRequestId': refund.id,
        'supportTickets/${chat.ticketId}/refundRequestedAt': nowIso,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _requestReturnForAssistant({
    required OrderModel order,
    required AppUser actor,
    required SupportChat chat,
    String? reason,
  }) async {
    try {
      final request = await createReturnRequest(
        orderId: order.id,
        reason: reason?.trim().isNotEmpty == true ? reason!.trim() : 'Requested from AI assistant support.',
        actor: actor,
      );
      final nowIso = _nowIso();
      await _ref('').update({
        'supportChats/${chat.id}/status': 'waiting',
        'supportChats/${chat.id}/updatedAt': nowIso,
        'supportTickets/${chat.ticketId}/status': 'waiting',
        'supportTickets/${chat.ticketId}/resolvedAt': null,
        'supportTickets/${chat.ticketId}/requestedAction': 'return',
        'supportTickets/${chat.ticketId}/returnOrderId': order.id,
        'supportTickets/${chat.ticketId}/returnReason': request.reason,
        'supportTickets/${chat.ticketId}/returnRequestId': request.id,
        'supportTickets/${chat.ticketId}/returnRequestedAt': nowIso,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _updateSavedAddressForAssistant({
    required AppUser actor,
    required String address,
  }) async {
    return _supportActions.updateSavedAddress(
      ref: _ref,
      nowIso: _nowIso(),
      actor: actor,
      address: address,
    );
  }

  String? _extractAddressFromPrompt(String prompt) {
    final match = RegExp(
      r'(?:change|update|set)\s+(?:my\s+)?address(?:\s+to)?\s*[:\-]?\s*(.+)$',
      caseSensitive: false,
    ).firstMatch(prompt.trim());
    final value = match?.group(1)?.trim() ?? '';
    if (value.length < 8) {
      return null;
    }
    return value;
  }

  bool _messageLooksLikeRefundHelp(String prompt) {
    final text = prompt.toLowerCase();
    return text.contains('refund') ||
        text.contains('money back');
  }

  bool _messageLooksLikeReturnHelp(String prompt) {
    final text = prompt.toLowerCase();
    return text.contains('return') ||
        text.contains('exchange') ||
        text.contains('send it back');
  }

  _SupportIntent _routeSupportIntent({
    required SupportChat chat,
    required String prompt,
  }) {
    final extractedAddress = _extractAddressFromPrompt(prompt);
    if (_messageLooksLikeCancellation(prompt)) {
      return _SupportIntent.cancelOrder;
    }
    if (_messageLooksLikeReturnHelp(prompt) || chat.type == 'return') {
      return _SupportIntent.returnItem;
    }
    if (_messageLooksLikeRefundHelp(prompt)) {
      return _SupportIntent.refund;
    }
    if (_messageLooksLikeOrderTracking(prompt) || chat.type == 'order') {
      return _SupportIntent.trackOrder;
    }
    if (extractedAddress != null || _messageLooksLikeAddressHelp(prompt)) {
      return _SupportIntent.addressChange;
    }
    if (_messageLooksLikeCustomHelp(prompt) || chat.type == 'custom') {
      return _SupportIntent.sizeHelp;
    }
    if (_messageLooksLikePaymentHelp(prompt) || chat.type == 'payment') {
      return _SupportIntent.aiNeeded;
    }
    return _SupportIntent.aiNeeded;
  }

  bool _isPremiumAiUser(AppUser actor) {
    return actor.roles['premium'] == true ||
        actor.roles['elite'] == true ||
        actor.role == 'admin' ||
        actor.role == 'super_admin';
  }

  int _dailyAiQuotaFor(AppUser actor) {
    return _isPremiumAiUser(actor) ? 9999 : 8;
  }

  Future<String?> _advancedAiBlockReason({
    required AppUser actor,
  }) async {
    final settings = await getPlatformSettings();
    if (!settings.aiAssistantEnabled) {
      return 'ai_disabled';
    }
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final daily = _backendCommerce.isConfigured
        ? (await _backendCommerce.getAiDailyStats())
            .cast<AiDailyStat?>()
            .firstWhere((item) => item?.date == todayKey, orElse: () => null) ??
            AiDailyStat(date: todayKey, totalRequests: 0, totalCost: 0, aiRequests: 0, logicRequests: 0)
        : AiDailyStat.fromMap(_asMap((await _ref('aiDailyStats/$todayKey').get()).value) ?? const {}, todayKey);
    if (daily.totalCost >= settings.aiDailyCostLimit) {
      return 'daily_cost_limit_reached';
    }
    final todayUsage = await _getTodayAiUsageCount(actor.id);
    if (todayUsage >= _dailyAiQuotaFor(actor)) {
      return 'user_daily_limit_reached';
    }
    return null;
  }

  int _estimateTokens(String message, String response) {
    final totalChars = '${message.trim()} ${response.trim()}'.trim().length;
    return (totalChars / 4).ceil();
  }

  double _estimateAiCost(int tokensUsed) {
    const costPerThousandTokens = 0.0025;
    return (tokensUsed / 1000) * costPerThousandTokens;
  }

  Future<bool> _checkAiConnectivity() async {
    if (kIsWeb) {
      return true;
    }
    try {
      final result = await InternetAddress.lookup('example.com').timeout(
        const Duration(seconds: 2),
      );
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _logAiError({
    required AppUser actor,
    required String errorType,
    required String message,
    String prompt = '',
  }) async {
    final now = DateTime.now();
    final logId = 'ai-error-${now.millisecondsSinceEpoch}';
    if (_backendCommerce.isConfigured) {
      await _backendCommerce.logAiEvent(
        type: errorType,
        message: message,
        prompt: prompt.trim(),
        timestamp: now.toIso8601String(),
      );
      return;
    }
    await _ref('aiErrorLogs/$logId').set({
      'id': logId,
      'userId': actor.id,
      'errorType': errorType,
      'message': message,
      'prompt': prompt.trim(),
      'timestamp': now.toIso8601String(),
    });
  }

  String _aiFailureFallbackMessage({
    required bool offline,
  }) {
    return offline
        ? 'You’re offline. Showing basic help.'
        : 'I\'m having trouble right now, but I can still help with basic things 👍';
  }

  String _supportCacheKey(SupportChat chat, String prompt) {
    final normalized = _supportAi.normalizePromptFingerprint(prompt);
    return Uri.encodeComponent('${chat.type}|$normalized');
  }

  Future<Map<String, dynamic>?> _getCachedSupportResponse({
    required AppUser actor,
    required SupportChat chat,
    required String prompt,
  }) async {
    if (_backendCommerce.isConfigured) {
      return _backendCommerce.getSupportResponseCache(_supportCacheKey(chat, prompt));
    }
    final snapshot = await _ref(
      'supportResponseCache/${actor.id}/${_supportCacheKey(chat, prompt)}',
    ).get();
    return _asMap(snapshot.value);
  }

  Future<void> _cacheSupportResponse({
    required AppUser actor,
    required SupportChat chat,
    required String prompt,
    required String response,
    required _SupportIntent intent,
  }) async {
    if (_backendCommerce.isConfigured) {
      await _backendCommerce.setSupportResponseCache(
        cacheKey: _supportCacheKey(chat, prompt),
        response: response,
        intent: intent.name,
        updatedAt: _nowIso(),
      );
      return;
    }
    await _ref(
      'supportResponseCache/${actor.id}/${_supportCacheKey(chat, prompt)}',
    ).set({
      'response': response,
      'intent': intent.name,
      'updatedAt': _nowIso(),
    });
  }

  Future<int> _getTodayAiUsageCount(String userId) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (_backendCommerce.isConfigured) {
      return _backendCommerce.getTodayAiUsageCount(today);
    }
    final usageSnapshot = await _ref('userDailyUsage/$userId').get();
    final usageMap = _asMap(usageSnapshot.value);
    if (usageMap != null && (usageMap['dateKey'] ?? '').toString() == today) {
      return ((usageMap['aiCallsToday'] ?? 0) as num).toInt();
    }
    final legacySnapshot = await _ref('aiUsage/$userId/$today').get();
    return (legacySnapshot.value as num?)?.toInt() ?? 0;
  }

  Future<void> _incrementTodayAiUsage(String userId) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (_backendCommerce.isConfigured) {
      await _backendCommerce.incrementTodayAiUsage(today);
      return;
    }
    final ref = _ref('aiUsage/$userId/$today');
    final snapshot = await ref.get();
    final current = (snapshot.value as num?)?.toInt() ?? 0;
    final next = current + 1;
    await _ref('').update({
      'aiUsage/$userId/$today': next,
      'userDailyUsage/$userId': {
        'dateKey': today,
        'aiCallsToday': next,
        'updatedAt': _nowIso(),
      },
    });
  }

  Future<void> _logBlockedAiRequest({
    required AppUser actor,
    required String prompt,
    required String reason,
    required _SupportIntent intent,
  }) async {
    final now = DateTime.now();
    final logId = 'blocked-${now.millisecondsSinceEpoch}';
    if (_backendCommerce.isConfigured) {
      await _backendCommerce.logAiEvent(
        type: 'blocked',
        message: prompt.trim(),
        reason: reason,
        intentType: intent.name,
        timestamp: now.toIso8601String(),
      );
      return;
    }
    await _ref('aiBlockedLogs/$logId').set({
      'id': logId,
      'userId': actor.id,
      'reason': reason,
      'intentType': intent.name,
      'message': prompt.trim(),
      'timestamp': now.toIso8601String(),
    });
  }

  Future<void> _logAiUsage({
    required AppUser actor,
    required String prompt,
    required String response,
    required _SupportIntent intent,
    required bool usedAi,
  }) async {
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final dateKey = DateFormat('yyyy-MM-dd').format(now);
    final logId = 'ai-${now.millisecondsSinceEpoch}';
    final tokensUsed = usedAi ? _estimateTokens(prompt, response) : 0;
    final cost = usedAi ? _estimateAiCost(tokensUsed) : 0.0;
    final entry = AiUsageLogEntry(
      id: logId,
      userId: actor.id,
      message: prompt.trim(),
      responseLength: response.trim().length,
      tokensUsed: tokensUsed,
      cost: cost,
      costPerRequest: cost,
      timestamp: nowIso,
      intentType: intent.name,
      usedAi: usedAi,
    );

    if (_backendCommerce.isConfigured) {
      await _backendCommerce.logAiUsage(entry: entry, date: dateKey);
      return;
    }

    final dailySnapshot = await _ref('aiDailyStats/$dateKey').get();
    final dailyExisting = _asMap(dailySnapshot.value);
    final daily = AiDailyStat.fromMap(dailyExisting ?? const {}, dateKey);

    final userSnapshot = await _ref('userAIUsage/${actor.id}').get();
    final userExisting = _asMap(userSnapshot.value);
    final userUsage = UserAiUsageStat.fromMap(userExisting ?? const {}, actor.id);

    await _ref('').update({
      'aiUsageLogs/$logId': entry.toMap(),
      'aiDailyStats/$dateKey': AiDailyStat(
        date: dateKey,
        totalRequests: daily.totalRequests + 1,
        totalCost: daily.totalCost + cost,
        aiRequests: daily.aiRequests + (usedAi ? 1 : 0),
        logicRequests: daily.logicRequests + (usedAi ? 0 : 1),
      ).toMap(),
      'userAIUsage/${actor.id}': UserAiUsageStat(
        userId: actor.id,
        totalMessages: userUsage.totalMessages + 1,
        aiMessages: userUsage.aiMessages + (usedAi ? 1 : 0),
        lastUsed: nowIso,
        dailyUsage: dateKey == DateFormat('yyyy-MM-dd').format(
                DateTime.tryParse(userUsage.lastUsed) ?? now)
            ? userUsage.dailyUsage + 1
            : 1,
      ).toMap(),
    });
  }

  Future<_SupportActionPlan?> _planSupportActionWithOpenAi({
    required AppUser actor,
    required SupportChat chat,
    required String prompt,
    OrderModel? order,
    UserMemory? memory,
    List<ConversationMemoryMessage> recentHistory = const [],
  }) async {
    try {
      final plan = await _supportAi.planActionWithOpenAi(
        actor: actor,
        chat: chat,
        prompt: prompt,
        order: order,
        memory: memory,
        recentHistory: recentHistory,
      );
      if (plan == null) {
        return null;
      }
      return _SupportActionPlan(
        action: _toPrivateActionType(plan.action),
        orderId: plan.orderId,
        address: plan.address,
        reason: plan.reason,
      );
    } on TimeoutException {
      await _logAiError(
        actor: actor,
        errorType: 'timeout',
        message: 'Support action planner timed out.',
        prompt: prompt,
      );
      return null;
    } on SocketException {
      await _logAiError(
        actor: actor,
        errorType: 'network',
        message: 'Support action planner failed due to network connectivity.',
        prompt: prompt,
      );
      return null;
    } catch (error) {
      await _logAiError(
        actor: actor,
        errorType: 'api_failure',
        message: error.toString(),
        prompt: prompt,
      );
      return null;
    }
  }

  _SupportActionPlan _planSupportActionFallback({
    required SupportChat chat,
    required String prompt,
  }) {
    final looksLikeReturn = _messageLooksLikeReturnHelp(prompt) || chat.type == 'return';
    final plan = _supportAi.planActionFallback(
      chat: chat,
      looksLikeCancellation: _messageLooksLikeCancellation(prompt),
      looksLikeRefund: _messageLooksLikeRefundHelp(prompt),
      looksLikeOrderTracking: _messageLooksLikeOrderTracking(prompt),
      looksLikePaymentHelp: _messageLooksLikePaymentHelp(prompt),
      looksLikeCustomHelp: _messageLooksLikeCustomHelp(prompt),
      looksLikeAddressHelp: _messageLooksLikeAddressHelp(prompt),
      extractedAddress: _extractAddressFromPrompt(prompt),
    );
    if (looksLikeReturn) {
      return _SupportActionPlan(
        action: _SupportActionType.requestReturn,
        orderId: plan.orderId,
        address: plan.address,
        reason: plan.reason,
      );
    }
    return _SupportActionPlan(
      action: _toPrivateActionType(plan.action),
      orderId: plan.orderId,
      address: plan.address,
      reason: plan.reason,
    );
  }

  Future<OrderModel?> _resolveOrderForSupportPlan({
    required AppUser actor,
    required _SupportActionPlan plan,
    OrderModel? fallbackOrder,
  }) async {
    final requestedOrderId = plan.orderId?.trim() ?? '';
    if (requestedOrderId.isEmpty) {
      return fallbackOrder;
    }
    final requestedOrder = await _fetchDocument(
      'orders/$requestedOrderId',
      (map, id) => OrderModel.fromMap(map, id),
    );
    if (requestedOrder == null || requestedOrder.userId != actor.id) {
      return fallbackOrder;
    }
    return requestedOrder;
  }

  Future<String?> _generateOpenAiSupportReply({
    required AppUser actor,
    required SupportChat chat,
    required String prompt,
    OrderModel? order,
    MeasurementProfile? measurement,
    BodyProfile? bodyProfile,
    UserMemory? memory,
    List<ConversationMemoryMessage> recentHistory = const [],
    String? toolName,
    String? actionSummary,
  }) async {
    try {
      return await _supportAi.generateOpenAiSupportReply(
        actor: actor,
        chat: chat,
        prompt: prompt,
        order: order,
        measurement: measurement,
        bodyProfile: bodyProfile,
        memory: memory,
        recentHistory: recentHistory,
        toolName: toolName,
        actionSummary: actionSummary,
      );
    } on TimeoutException {
      await _logAiError(
        actor: actor,
        errorType: 'timeout',
        message: 'Support reply generation timed out.',
        prompt: prompt,
      );
      return null;
    } on SocketException {
      await _logAiError(
        actor: actor,
        errorType: 'network',
        message: 'Support reply generation failed due to network connectivity.',
        prompt: prompt,
      );
      return null;
    } catch (error) {
      await _logAiError(
        actor: actor,
        errorType: 'api_failure',
        message: error.toString(),
        prompt: prompt,
      );
      return null;
    }
  }

  List<String> _mergePastIssues(List<String> existing, List<String> incoming) {
    final merged = <String>[];
    for (final item in [...existing, ...incoming]) {
      final normalized = item.trim();
      if (normalized.isEmpty) {
        continue;
      }
      if (!merged.any((entry) => entry.toLowerCase() == normalized.toLowerCase())) {
        merged.add(normalized);
      }
    }
    return merged.take(6).toList();
  }

  Map<String, dynamic> _fallbackMemoryExtraction(
    String userMessage,
    String assistantReply,
  ) {
    final lowered = '$userMessage $assistantReply'.toLowerCase();
    final style = lowered.contains('black')
        ? 'black / dark'
        : lowered.contains('casual')
            ? 'casual'
            : lowered.contains('formal')
                ? 'formal'
                : lowered.contains('streetwear')
                    ? 'streetwear'
                    : '';
    final sizeMatch = RegExp(r'\b(xl|xs|s|m|l|xxl)\b', caseSensitive: false)
        .firstMatch(userMessage);
    final issues = <String>[
      if (lowered.contains('refund')) 'refund',
      if (lowered.contains('size')) 'size issue',
      if (lowered.contains('payment')) 'payment issue',
      if (lowered.contains('address')) 'address update',
    ];
    return {
      'preferredStyle': style,
      'size': sizeMatch?.group(0)?.toUpperCase() ?? '',
      'addPastIssues': issues,
      'lastConversationSummary':
          userMessage.trim().isEmpty ? '' : 'Recent request: ${userMessage.trim()}',
    };
  }

  Future<void> _updateUserMemoryAfterConversation({
    required AppUser actor,
    required String chatId,
    required String userMessage,
    required String assistantReply,
    OrderModel? order,
  }) async {
    final existingMemory = await getUserMemory(actor.id);
    final memoryIntent = _routeSupportIntent(
      chat: SupportChat(
        id: chatId,
        userId: actor.id,
        type: 'general',
        createdAt: '',
        updatedAt: '',
      ),
      prompt: userMessage,
    );
    final allowAiMemory =
        memoryIntent == _SupportIntent.aiNeeded &&
        _isPremiumAiUser(actor) &&
        await _advancedAiBlockReason(actor: actor) == null;
    Map<String, dynamic> extracted;
    if (allowAiMemory) {
      try {
        extracted = await _supportAi.extractMemoryWithOpenAi(
              actor: actor,
              userMessage: userMessage,
              assistantReply: assistantReply,
              currentMemory: existingMemory,
              order: order,
            ) ??
            _fallbackMemoryExtraction(userMessage, assistantReply);
      } catch (error) {
        await _logAiError(
          actor: actor,
          errorType: 'memory_extraction_failure',
          message: error.toString(),
          prompt: userMessage,
        );
        extracted = _fallbackMemoryExtraction(userMessage, assistantReply);
      }
    } else {
      extracted = _fallbackMemoryExtraction(userMessage, assistantReply);
    }
    final recentHistory = await getChatHistory(actor.id, chatId, limit: 8);
    String summary;
    if (allowAiMemory) {
      try {
        summary = await _supportAi.summarizeConversationWithOpenAi(
              actor: actor,
              recentHistory: recentHistory,
              currentMemory: existingMemory,
              order: order,
            ) ??
            (extracted['lastConversationSummary'] ?? '').toString();
      } catch (error) {
        await _logAiError(
          actor: actor,
          errorType: 'memory_summary_failure',
          message: error.toString(),
          prompt: userMessage,
        );
        summary = (extracted['lastConversationSummary'] ?? '').toString();
      }
    } else {
      summary = (extracted['lastConversationSummary'] ?? '').toString();
    }
    final updatedMemory = (existingMemory ??
            UserMemory(
              userId: actor.id,
              name: actor.name,
            ))
        .copyWith(
          name: actor.name.isEmpty ? existingMemory?.name ?? '' : actor.name,
          preferredStyle: (extracted['preferredStyle'] ?? '').toString().trim().isEmpty
              ? existingMemory?.preferredStyle ?? ''
              : (extracted['preferredStyle'] ?? '').toString().trim(),
          size: (extracted['size'] ?? '').toString().trim().isEmpty
              ? existingMemory?.size ?? ''
              : (extracted['size'] ?? '').toString().trim().toUpperCase(),
          pastIssues: _mergePastIssues(
            existingMemory?.pastIssues ?? const [],
            ((extracted['addPastIssues'] as List?) ?? const [])
                .map((item) => item.toString())
                .toList(),
          ),
          lastOrderId: order?.id ?? existingMemory?.lastOrderId ?? '',
          lastConversationSummary: summary.trim(),
          updatedAt: _nowIso(),
        );
    await saveUserMemory(actor.id, updatedMemory);
  }

  Future<String> _buildAssistantReply({
    required AppUser actor,
    required SupportChat chat,
    required String prompt,
  }) async {
    final trimmedPrompt = prompt.trim();
    if (trimmedPrompt.isEmpty) {
      return 'Ask me about your orders, payments, delivery updates, or custom fit journey and I will help right away.';
    }

    final order = await _resolveOrderForPrompt(actor, trimmedPrompt);
    final bodyProfile = await getBodyProfile(actor.id);
    final userMemory = await getUserMemory(actor.id);
    final recentHistory = await getChatHistory(actor.id, chat.id, limit: 8);
    final intent = _routeSupportIntent(chat: chat, prompt: trimmedPrompt);
    final onlineForAi = await _checkAiConnectivity();
    final cachedResponse = await _getCachedSupportResponse(
      actor: actor,
      chat: chat,
      prompt: trimmedPrompt,
    );
    if (cachedResponse != null) {
      final cachedText = (cachedResponse['response'] ?? '').toString().trim();
      if (cachedText.isNotEmpty) {
        return cachedText;
      }
    }
    final blockedReason = await _advancedAiBlockReason(actor: actor);
    final shouldUseAi =
        intent == _SupportIntent.aiNeeded &&
        blockedReason == null &&
        onlineForAi;
    final plan = shouldUseAi
        ? (await _planSupportActionWithOpenAi(
              actor: actor,
              chat: chat,
              prompt: trimmedPrompt,
              order: order,
              memory: userMemory,
              recentHistory: recentHistory,
            )) ??
            _planSupportActionFallback(chat: chat, prompt: trimmedPrompt)
        : _planSupportActionFallback(chat: chat, prompt: trimmedPrompt);
    if (intent == _SupportIntent.aiNeeded && blockedReason != null) {
      await _logBlockedAiRequest(
        actor: actor,
        prompt: trimmedPrompt,
        reason: blockedReason,
        intent: intent,
      );
    }
    if (intent == _SupportIntent.aiNeeded && !onlineForAi) {
      await _logAiError(
        actor: actor,
        errorType: 'offline',
        message: 'Skipped AI request because the device appears offline.',
        prompt: trimmedPrompt,
      );
    }
    final resolvedOrder = await _resolveOrderForSupportPlan(
      actor: actor,
      plan: plan,
      fallbackOrder: order,
    );
    final measurementProfiles =
        plan.action == _SupportActionType.customHelp || chat.type == 'custom'
            ? await getMeasurementProfiles(actor.id)
            : const <MeasurementProfile>[];
    final latestProfile =
        measurementProfiles.isEmpty ? null : measurementProfiles.first;
    String? actionSummary;

    Future<String> finalizeResponse(String response, {required bool usedAi}) async {
      await _cacheSupportResponse(
        actor: actor,
        chat: chat,
        prompt: trimmedPrompt,
        response: response,
        intent: intent,
      );
      await _logAiUsage(
        actor: actor,
        prompt: trimmedPrompt,
        response: response,
        intent: intent,
        usedAi: usedAi,
      );
      return response;
    }

    if (plan.action == _SupportActionType.cancelOrder) {
      if (resolvedOrder == null) {
        return 'I could not find an active order to cancel yet. If you have just placed one, try again in a moment or share the order ID.';
      }
      final cancelled = await _cancelOrderForAssistant(resolvedOrder, actor);
      if (cancelled) {
        actionSummary =
            'Order #${resolvedOrder.id} was cancelled successfully and delivery status was also updated to cancelled.';
        return finalizeResponse(
          'Done. I cancelled order #${resolvedOrder.id} and updated the delivery status for you.',
          usedAi: false,
        );
      }
      return 'This order is already too far along to cancel instantly. I can still help you track it or guide you through the return path after delivery.';
    }

    if (plan.action == _SupportActionType.requestRefund) {
      if (resolvedOrder == null) {
        return 'I can help with a refund request. Share the order ID or tell me which recent order had the problem.';
      }
      final requested = await _requestRefundForAssistant(
        order: resolvedOrder,
        actor: actor,
        chat: chat,
        reason: plan.reason,
      );
      if (requested) {
        actionSummary =
            'Refund request was submitted for order #${resolvedOrder.id} and the ticket is now waiting for automated refund processing.';
        return finalizeResponse(
          'I have submitted a refund request for order #${resolvedOrder.id}. I will keep this thread updated as it moves through refund processing.',
          usedAi: false,
        );
      }
      return 'This order is not eligible for an instant refund request yet. If the item is still in transit, I can help you track it or cancel it if it is still allowed.';
    }

    if (plan.action == _SupportActionType.requestReturn) {
      if (resolvedOrder == null) {
        return 'I can help start a return. Share the order ID or tell me which delivered item you want to send back.';
      }
      final requested = await _requestReturnForAssistant(
        order: resolvedOrder,
        actor: actor,
        chat: chat,
        reason: plan.reason,
      );
      if (requested) {
        actionSummary =
            'Return request was submitted for order #${resolvedOrder.id} and pickup approval is now pending.';
        return finalizeResponse(
          'I have started a return request for order #${resolvedOrder.id}. Once the item is picked up and passes checks, I will help move it into refund processing automatically.',
          usedAi: false,
        );
      }
      return 'This order is not eligible for return right now. Returns are only available within 3 days of delivery for non-custom items.';
    }

    if (plan.action == _SupportActionType.trackOrder) {
      if (resolvedOrder == null) {
        return 'You do not have an active order right now. Once you place one, I can track it live for you here.';
      }
      return finalizeResponse(_orderSummaryLine(resolvedOrder), usedAi: false);
    }

    if (plan.action == _SupportActionType.paymentHelp) {
      if (resolvedOrder == null) {
        return 'I can help with payment issues. If this is about a recent order, send the order ID or tell me what happened with the payment.';
      }
      if (resolvedOrder.paymentMethod.toUpperCase() == 'COD') {
        return 'Order #${resolvedOrder.id} is marked as cash on delivery, so there is no online payment to verify. If you need to cancel or change the order, I can help with that.';
      }
      if (resolvedOrder.isPaymentVerified) {
        actionSummary =
            'Payment for order #${resolvedOrder.id} is verified successfully.';
        final aiReply = await _generateOpenAiSupportReply(
          actor: actor,
          chat: chat,
          prompt: trimmedPrompt,
          order: resolvedOrder,
          measurement: latestProfile,
          bodyProfile: bodyProfile,
          memory: userMemory,
          recentHistory: recentHistory,
          toolName: 'paymentHelp',
          actionSummary: actionSummary,
        );
        return aiReply ??
            'Your payment for order #${resolvedOrder.id} is verified successfully. If you are asking about a refund, tell me if the issue is cancellation, damaged item, or delivery problem.';
      }
      return 'I can see order #${resolvedOrder.id} still needs payment confirmation. Please wait a moment and refresh, or share the payment reference if the amount was debited.';
    }

    if (plan.action == _SupportActionType.updateAddress) {
      final requestedAddress = plan.address ?? _extractAddressFromPrompt(trimmedPrompt);
      if (requestedAddress != null) {
        final updated = await _updateSavedAddressForAssistant(
          actor: actor,
          address: requestedAddress,
        );
        if (updated) {
          actionSummary =
              'Saved address was updated to $requestedAddress for future orders.';
          final aiReply = shouldUseAi
              ? await _generateOpenAiSupportReply(
                  actor: actor,
                  chat: chat,
                  prompt: trimmedPrompt,
                  order: resolvedOrder,
                  measurement: latestProfile,
                  bodyProfile: bodyProfile,
                  memory: userMemory,
                  recentHistory: recentHistory,
                  toolName: 'updateAddress',
                  actionSummary: actionSummary,
                )
              : null;
          final response = aiReply ??
              'Done. I updated your saved address for future orders. If you want the current order tracked too, I can help with that here.';
          return finalizeResponse(response, usedAi: shouldUseAi);
        }
      }
      if (resolvedOrder == null) {
        return 'You can update your saved address from Profile > Addresses before placing the next order. If you want, I can help you track your current order too.';
      }
      return 'For security, I cannot rewrite the shipping address after an order is placed from this chat. The safest next step is to update your saved address in Profile > Addresses for future checkouts.';
    }

    if (plan.action == _SupportActionType.customHelp) {
      if (measurementProfiles.isEmpty) {
        return 'I can help you get the right fit. You do not have saved measurements yet, so the best next step is to add one from Your Style > Saved Measurements before placing a custom order.';
      }
      actionSummary =
          'Saved profile ${latestProfile!.label}: chest ${latestProfile.chest.toStringAsFixed(0)} cm, waist ${latestProfile.waist.toStringAsFixed(0)} cm, sleeve ${latestProfile.sleeve.toStringAsFixed(0)} cm.';
      return finalizeResponse(
        'You already have a saved profile called ${latestProfile.label}. If your fit feels off, check chest ${latestProfile.chest.toStringAsFixed(0)} cm, waist ${latestProfile.waist.toStringAsFixed(0)} cm, and sleeve ${latestProfile.sleeve.toStringAsFixed(0)} cm before confirming the next custom design.',
        usedAi: false,
      );
    }

    final faqs = await getFaqItems();
    if (faqs.isNotEmpty) {
      final lowered = trimmedPrompt.toLowerCase();
      for (final faq in faqs) {
        final haystack = '${faq.question} ${faq.answer} ${faq.category}'.toLowerCase();
        if (haystack.contains(lowered) || lowered.split(' ').any((token) => token.length > 4 && haystack.contains(token))) {
          return faq.answer;
        }
      }
    }

    final firstName = actor.name.trim().isEmpty ? 'there' : actor.name.trim().split(' ').first;
    if (resolvedOrder != null && shouldUseAi) {
      final aiReply = await _generateOpenAiSupportReply(
        actor: actor,
        chat: chat,
        prompt: trimmedPrompt,
        order: resolvedOrder,
        measurement: latestProfile,
        bodyProfile: bodyProfile,
        memory: userMemory,
        recentHistory: recentHistory,
        actionSummary:
            'Latest order is #${resolvedOrder.id}, status ${resolvedOrder.status.toLowerCase()}.',
      );
      final response = aiReply ??
          'Hi $firstName, I can help with that. Your latest order is #${resolvedOrder.id}, currently ${resolvedOrder.status.toLowerCase()}. You can ask me to track it, explain the payment, or help with your custom fit preferences.';
      await _incrementTodayAiUsage(actor.id);
      return finalizeResponse(response, usedAi: true);
    }
    if (shouldUseAi) {
      final aiReply = await _generateOpenAiSupportReply(
        actor: actor,
        chat: chat,
        prompt: trimmedPrompt,
        measurement: latestProfile,
        bodyProfile: bodyProfile,
        memory: userMemory,
        recentHistory: recentHistory,
      );
      final response = aiReply ??
          'Hi $firstName, I am your ABZORA Assistant. I can help with orders, payments, returns, address guidance, and custom clothing questions. Try asking "Where is my order?" or "Help with custom fitting".';
      await _incrementTodayAiUsage(actor.id);
      return finalizeResponse(response, usedAi: true);
    }
    if (blockedReason == 'user_daily_limit_reached') {
      return finalizeResponse(
        'You have reached today\'s advanced AI assistance limit. I can still help with order tracking, cancellation, refunds, address updates, and saved size guidance.',
        usedAi: false,
      );
    }
    if (blockedReason == 'daily_cost_limit_reached' || blockedReason == 'ai_disabled') {
      return finalizeResponse(
        'AI is currently busy. Please try again later.',
        usedAi: false,
      );
    }
    if (!onlineForAi) {
      return finalizeResponse(
        _aiFailureFallbackMessage(offline: true),
        usedAi: false,
      );
    }
    return finalizeResponse(
      'Hi $firstName, ${_aiFailureFallbackMessage(offline: false)} Try asking me to track your order, cancel an order, request a refund, or guide your fit.',
      usedAi: false,
    );
  }

  Future<SupportChat> createSupportChat({
    required AppUser actor,
    required String issueType,
  }) async {
    if (_backendCommerce.isConfigured) {
      return _backendCommerce.createSupportChat(issueType.trim().toLowerCase());
    }
    final normalizedType = issueType.trim().toLowerCase();
    final existing = (await getSupportChats(actor: actor, type: normalizedType))
        .where((chat) => chat.status != 'closed')
        .toList();
    if (existing.isNotEmpty) {
      return existing.first;
    }
    final nowIso = _nowIso();
    final timestampSeed = DateTime.now().millisecondsSinceEpoch;
    final chatId = 'support-$timestampSeed';
    final ticketId = 'ticket-$timestampSeed';
    final chat = SupportChat(
      id: chatId,
      userId: actor.id,
      type: normalizedType,
      status: 'open',
      createdAt: nowIso,
      updatedAt: nowIso,
      lastMessage: '',
      lastMessageAt: nowIso,
      userName: actor.name,
      userPhone: actor.phone ?? '',
      ticketId: ticketId,
      participantIds: {
        actor.id: true,
      },
    );
    final ticket = SupportTicket(
      id: ticketId,
      chatId: chatId,
      userId: actor.id,
      issueType: normalizedType,
      status: 'open',
      createdAt: nowIso,
    );
    final welcomeMessage = _assistantWelcomeMessage(actor, normalizedType);
    await _ref('').update({
      'supportChats/$chatId': chat.copyWith(
        lastMessage: welcomeMessage,
        lastMessageAt: nowIso,
        lastSenderId: 'abzora-assistant',
        lastSenderRole: 'assistant',
      ).toMap(),
      'supportTickets/$ticketId': ticket.toMap(),
      'messages/$chatId/msg-$timestampSeed': SupportMessage(
        id: 'msg-$timestampSeed',
        senderId: 'abzora-assistant',
        senderRole: 'assistant',
        text: welcomeMessage,
        timestamp: nowIso,
        read: true,
      ).toMap(),
    });
    return chat;
  }

  String _assistantWelcomeMessage(AppUser actor, String issueType) {
    final firstName = actor.name.trim().isEmpty ? 'there' : actor.name.trim().split(' ').first;
    switch (issueType) {
      case 'order':
        return 'Hi $firstName, I can track your latest order, explain the delivery stage, or help cancel it if it is still eligible.';
      case 'payment':
        return 'Hi $firstName, I can check payment status, explain refunds, and help you understand what happened with your last order payment.';
      case 'custom':
        return 'Hi $firstName, I can guide you with measurements, fit questions, and custom clothing decisions based on your saved profile.';
      default:
        return 'Hi $firstName, I am ABZORA Assistant. Ask me about orders, payments, delivery updates, or custom clothing and I will help instantly.';
    }
  }

  Future<String> _nextSupportStatusForPrompt({
    required String prompt,
    required SupportChat chat,
    required bool isAdminActor,
  }) async {
    final plan = isAdminActor
        ? const _SupportActionPlan(action: _SupportActionType.generalReply)
        : _planSupportActionFallback(chat: chat, prompt: prompt);
    return _supportActions.nextSupportStatus(
      action: _toPublicActionType(plan.action),
      chat: chat,
      isAdminActor: isAdminActor,
    );
  }

  Future<void> sendSupportMessage({
    required String chatId,
    required String text,
    required AppUser actor,
    String imageUrl = '',
  }) async {
    if (_backendCommerce.isConfigured) {
      final chat = await getSupportChatById(chatId: chatId, actor: actor);
      if (chat == null) {
        throw StateError('Support chat not found.');
      }
      final trimmedText = text.trim();
      if (trimmedText.isEmpty && imageUrl.trim().isEmpty) {
        return;
      }
      final isAdminActor = isSuperAdmin(actor);
      final assistantReply = !isAdminActor
          ? await _buildAssistantReply(actor: actor, chat: chat, prompt: trimmedText)
          : null;
      final nextStatus = await _nextSupportStatusForPrompt(
        prompt: trimmedText,
        chat: chat,
        isAdminActor: isAdminActor,
      );
      final now = DateTime.now();
      if (!isAdminActor) {
        await _saveChatHistoryEntry(
          userId: actor.id,
          chatId: chatId,
          entry: ConversationMemoryMessage(
            id: 'msg-${now.millisecondsSinceEpoch}',
            role: 'user',
            text: trimmedText,
            timestamp: now.toIso8601String(),
          ),
        );
      }
      await _backendCommerce.sendSupportMessage(
        chatId: chatId,
        text: trimmedText,
        imageUrl: imageUrl.trim(),
        assistantReplyText: assistantReply?.trim(),
        assistantTimestamp: assistantReply == null || assistantReply.trim().isEmpty
            ? null
            : now.add(const Duration(milliseconds: 450)).toIso8601String(),
        status: nextStatus,
      );
      if (!isAdminActor && assistantReply != null && assistantReply.trim().isNotEmpty) {
        await _saveChatHistoryEntry(
          userId: actor.id,
          chatId: chatId,
          entry: ConversationMemoryMessage(
            id: 'msg-${now.millisecondsSinceEpoch + 1}',
            role: 'assistant',
            text: assistantReply.trim(),
            timestamp: now.add(const Duration(milliseconds: 450)).toIso8601String(),
          ),
        );
        final latestOrder = await _resolveOrderForPrompt(actor, trimmedText);
        await _updateUserMemoryAfterConversation(
          actor: actor,
          chatId: chatId,
          userMessage: trimmedText,
          assistantReply: assistantReply.trim(),
          order: latestOrder,
        );
      }
      return;
    }
    final chat = await getSupportChatById(chatId: chatId, actor: actor);
    if (chat == null) {
      throw StateError('Support chat not found.');
    }
    final trimmedText = text.trim();
    if (trimmedText.isEmpty && imageUrl.trim().isEmpty) {
      return;
    }
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final isAdminActor = isSuperAdmin(actor);
    final messageId = 'msg-${now.millisecondsSinceEpoch}';
    final senderRole = isAdminActor ? 'admin' : 'user';
    final assistantReply = !isAdminActor
        ? await _buildAssistantReply(actor: actor, chat: chat, prompt: trimmedText)
        : null;
    final nextStatus = await _nextSupportStatusForPrompt(
      prompt: trimmedText,
      chat: chat,
      isAdminActor: isAdminActor,
    );
    final ticketStatus = nextStatus == 'closed' ? 'closed' : 'open';
    final updates = <String, dynamic>{
      'messages/$chatId/$messageId': SupportMessage(
        id: messageId,
        senderId: actor.id,
        senderRole: senderRole,
        text: trimmedText,
        imageUrl: imageUrl.trim(),
        timestamp: nowIso,
        read: false,
      ).toMap(),
      'supportChats/$chatId/lastMessage': trimmedText.isNotEmpty ? trimmedText : 'Attachment shared',
      'supportChats/$chatId/lastMessageAt': nowIso,
      'supportChats/$chatId/lastSenderId': actor.id,
      'supportChats/$chatId/lastSenderRole': senderRole,
      'supportChats/$chatId/updatedAt': nowIso,
      'supportChats/$chatId/status': nextStatus,
      'supportChats/$chatId/unreadCountAdmin': isAdminActor ? 0 : chat.unreadCountAdmin + 1,
      'supportChats/$chatId/unreadCountUser': isAdminActor ? chat.unreadCountUser + 1 : 0,
      'supportTickets/${chat.ticketId}/status': ticketStatus,
      'supportTickets/${chat.ticketId}/resolvedAt': nextStatus == 'closed' ? nowIso : null,
    };
    if (!isAdminActor && assistantReply != null && assistantReply.trim().isNotEmpty) {
      final assistantTimestamp = now.add(const Duration(milliseconds: 450)).toIso8601String();
      final assistantId = 'msg-${now.millisecondsSinceEpoch + 1}';
      updates.addAll({
        'messages/$chatId/$assistantId': SupportMessage(
          id: assistantId,
          senderId: 'abzora-assistant',
          senderRole: 'assistant',
          text: assistantReply.trim(),
          timestamp: assistantTimestamp,
          read: true,
        ).toMap(),
        'supportChats/$chatId/lastMessage': assistantReply.trim(),
        'supportChats/$chatId/lastMessageAt': assistantTimestamp,
        'supportChats/$chatId/lastSenderId': 'abzora-assistant',
        'supportChats/$chatId/lastSenderRole': 'assistant',
        'supportChats/$chatId/updatedAt': assistantTimestamp,
        'supportChats/$chatId/unreadCountAdmin': 0,
        'supportChats/$chatId/unreadCountUser': 0,
      });
    }
    await _ref('').update(updates);
    if (!isAdminActor) {
      await _saveChatHistoryEntry(
        userId: actor.id,
        chatId: chatId,
        entry: ConversationMemoryMessage(
          id: messageId,
          role: 'user',
          text: trimmedText,
          timestamp: nowIso,
        ),
      );
      if (assistantReply != null && assistantReply.trim().isNotEmpty) {
        await _saveChatHistoryEntry(
          userId: actor.id,
          chatId: chatId,
          entry: ConversationMemoryMessage(
            id: 'msg-${now.millisecondsSinceEpoch + 1}',
            role: 'assistant',
            text: assistantReply.trim(),
            timestamp: now.add(const Duration(milliseconds: 450)).toIso8601String(),
          ),
        );
        final latestOrder = await _resolveOrderForPrompt(actor, trimmedText);
        await _updateUserMemoryAfterConversation(
          actor: actor,
          chatId: chatId,
          userMessage: trimmedText,
          assistantReply: assistantReply.trim(),
          order: latestOrder,
        );
      }
    }
    if (isAdminActor) {
      _addNotification(
        AppNotification(
          id: 'support-reply-${now.millisecondsSinceEpoch}',
          title: 'Support replied to your query',
          body: trimmedText.isNotEmpty ? trimmedText : 'Support shared an attachment.',
          type: 'support',
          isRead: false,
          timestamp: now,
          audienceRole: 'user',
          userId: chat.userId,
        ),
      );
      await logActivity(
        action: 'support_reply',
        targetType: 'support_chat',
        targetId: chatId,
        message: 'Replied to ${chat.type} support chat $chatId.',
        actor: actor,
      );
    }
  }

  Future<void> markSupportChatRead({
    required String chatId,
    required AppUser actor,
  }) async {
    if (_backendCommerce.isConfigured) {
      await _backendCommerce.markSupportChatRead(chatId);
      return;
    }
    final chat = await getSupportChatById(chatId: chatId, actor: actor);
    if (chat == null) {
      return;
    }
    await _ref('supportChats/$chatId').update({
      isSuperAdmin(actor) ? 'unreadCountAdmin' : 'unreadCountUser': 0,
    });
  }

  Future<void> saveAiStylistConversationTurn({
    required AppUser actor,
    required String userMessage,
    required String assistantReply,
  }) async {
    final now = DateTime.now();
    final userTimestamp = now.toIso8601String();
    final assistantTimestamp =
        now.add(const Duration(milliseconds: 400)).toIso8601String();
    await _saveChatHistoryEntry(
      userId: actor.id,
      chatId: 'stylist',
      entry: ConversationMemoryMessage(
        id: 'stylist-user-${now.millisecondsSinceEpoch}',
        role: 'user',
        text: userMessage.trim(),
        timestamp: userTimestamp,
      ),
    );
    await _saveChatHistoryEntry(
      userId: actor.id,
      chatId: 'stylist',
      entry: ConversationMemoryMessage(
        id: 'stylist-assistant-${now.millisecondsSinceEpoch + 1}',
        role: 'assistant',
        text: assistantReply.trim(),
        timestamp: assistantTimestamp,
      ),
    );
    final currentMemory = await getUserMemory(actor.id);
    final latestOrder = await getLatestUserOrder(actor.id);
    Map<String, dynamic> extracted;
    try {
      extracted = await _supportAi.extractMemoryWithOpenAi(
            actor: actor,
            userMessage: userMessage,
            assistantReply: assistantReply,
            currentMemory: currentMemory,
            order: latestOrder,
          ) ??
          _fallbackMemoryExtraction(userMessage, assistantReply);
    } catch (error) {
      await _logAiError(
        actor: actor,
        errorType: 'stylist_memory_extraction_failure',
        message: error.toString(),
        prompt: userMessage,
      );
      extracted = _fallbackMemoryExtraction(userMessage, assistantReply);
    }
    final recentHistory = await getChatHistory(actor.id, 'stylist', limit: 8);
    String summary;
    try {
      summary = await _supportAi.summarizeConversationWithOpenAi(
            actor: actor,
            recentHistory: recentHistory,
            currentMemory: currentMemory,
            order: latestOrder,
          ) ??
          (extracted['lastConversationSummary'] ?? '').toString();
    } catch (error) {
      await _logAiError(
        actor: actor,
        errorType: 'stylist_memory_summary_failure',
        message: error.toString(),
        prompt: userMessage,
      );
      summary = (extracted['lastConversationSummary'] ?? '').toString();
    }
    final updated = (currentMemory ??
            UserMemory(
              userId: actor.id,
              name: actor.name,
            ))
        .copyWith(
          name: actor.name.isEmpty ? currentMemory?.name ?? '' : actor.name,
          preferredStyle: (extracted['preferredStyle'] ?? '').toString().trim().isEmpty
              ? currentMemory?.preferredStyle ?? ''
              : (extracted['preferredStyle'] ?? '').toString().trim(),
          size: (extracted['size'] ?? '').toString().trim().isEmpty
              ? currentMemory?.size ?? ''
              : (extracted['size'] ?? '').toString().trim().toUpperCase(),
          pastIssues: _mergePastIssues(
            currentMemory?.pastIssues ?? const [],
            ((extracted['addPastIssues'] as List?) ?? const [])
                .map((item) => item.toString())
                .toList(),
          ),
          lastOrderId: latestOrder?.id ?? currentMemory?.lastOrderId ?? '',
          lastConversationSummary: summary.trim(),
          updatedAt: _nowIso(),
        );
    await saveUserMemory(actor.id, updated);
  }

  Future<void> closeSupportTicket({
    required String chatId,
    required AppUser actor,
  }) async {
    if (_backendCommerce.isConfigured) {
      _requireSuperAdmin(actor);
      await _backendCommerce.closeSupportChat(chatId);
      return;
    }
    _requireSuperAdmin(actor);
    final chat = await getSupportChatById(chatId: chatId, actor: actor);
    if (chat == null) {
      throw StateError('Support chat not found.');
    }
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    await _ref('').update({
      'supportChats/$chatId/status': 'closed',
      'supportChats/$chatId/updatedAt': nowIso,
      'supportTickets/${chat.ticketId}/status': 'closed',
      'supportTickets/${chat.ticketId}/resolvedAt': nowIso,
    });
    _addNotification(
      AppNotification(
        id: 'support-closed-${now.millisecondsSinceEpoch}',
        title: 'Support ticket closed',
        body: 'Your ${chat.type.replaceAll('_', ' ')} request has been marked as resolved.',
        type: 'support',
        isRead: false,
        timestamp: now,
        audienceRole: 'user',
        userId: chat.userId,
      ),
    );
    await logActivity(
      action: 'close_support_ticket',
      targetType: 'support_chat',
      targetId: chatId,
      message: 'Closed support chat $chatId.',
      actor: actor,
    );
  }

  Future<void> reopenSupportTicket({
    required String chatId,
    required AppUser actor,
  }) async {
    if (_backendCommerce.isConfigured) {
      _requireSuperAdmin(actor);
      await _backendCommerce.reopenSupportChat(chatId);
      return;
    }
    _requireSuperAdmin(actor);
    final chat = await getSupportChatById(chatId: chatId, actor: actor);
    if (chat == null) {
      throw StateError('Support chat not found.');
    }
    final nowIso = DateTime.now().toIso8601String();
    await _ref('').update({
      'supportChats/$chatId/status': 'open',
      'supportChats/$chatId/updatedAt': nowIso,
      'supportTickets/${chat.ticketId}/status': 'open',
      'supportTickets/${chat.ticketId}/resolvedAt': null,
    });
    await logActivity(
      action: 'reopen_support_ticket',
      targetType: 'support_chat',
      targetId: chatId,
      message: 'Reopened support chat $chatId.',
      actor: actor,
    );
  }

  Future<void> migrateDemoDataToFirestore({required AppUser actor}) async {
    throw StateError('Demo seeding has been removed. Realtime Database is the source of truth.');
  }

  Future<void> updateFcmToken({required String userId, required String token}) async {
    if (_backendCommerce.isConfigured) {
      return;
    }
    await _ref('users/$userId').update({'fcmToken': token});
  }

  Future<PlatformSettings> getPlatformSettings({AppUser? actor}) async {
    if (actor != null) {
      _requireSuperAdmin(actor);
    }
    if (_backendCommerce.isConfigured) {
      return _backendCommerce.getPlatformSettings();
    }
    final settings = await _fetchDocument('platform/settings', (map, _) => PlatformSettings.fromMap(map));
    return settings ?? const PlatformSettings();
  }

  Future<void> savePlatformSettings(PlatformSettings settings, {required AppUser actor}) async {
    _requireSuperAdmin(actor);
    if (_backendCommerce.isConfigured) {
      await _backendCommerce.savePlatformSettings(settings);
      await logActivity(
        action: 'update_platform_settings',
        targetType: 'platform',
        targetId: 'settings',
        message: 'Updated feature toggles, city availability, or admin security settings.',
        actor: actor,
      );
      return;
    }
    await _ref('platform/settings').set(settings.toMap());
    await logActivity(
      action: 'update_platform_settings',
      targetType: 'platform',
      targetId: 'settings',
      message: 'Updated feature toggles, city availability, or admin security settings.',
      actor: actor,
    );
  }

  Future<List<DisputeRecord>> getDisputes({AppUser? actor}) async {
    if (actor != null) {
      _requireSuperAdmin(actor);
    }
    if (_backendCommerce.isConfigured) {
      final disputes = await _backendCommerce.getAdminDisputes();
      disputes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return disputes;
    }
    final disputes = await _fetchCollection('disputes', (map, id) => DisputeRecord.fromMap(map, id));
    disputes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return disputes;
  }

  Future<void> updateDispute(DisputeRecord dispute, {required AppUser actor}) async {
    _requireSuperAdmin(actor);
    if (_backendCommerce.isConfigured) {
      await _backendCommerce.updateAdminDispute(dispute);
      await logActivity(
        action: 'update_dispute',
        targetType: 'dispute',
        targetId: dispute.id,
        message: 'Marked ${dispute.type.toLowerCase()} ${dispute.id} as ${dispute.status}.',
        actor: actor,
      );
      return;
    }
    await _ref('disputes/${dispute.id}').set(dispute.toMap());
    await logActivity(
      action: 'update_dispute',
      targetType: 'dispute',
      targetId: dispute.id,
      message: 'Marked ${dispute.type.toLowerCase()} ${dispute.id} as ${dispute.status}.',
      actor: actor,
    );
  }

  Future<void> adjustStoreCommission({
    required String storeId,
    required double commissionRate,
    required AppUser actor,
  }) async {
    _requireSuperAdmin(actor);
    final store = (await getAdminStores()).firstWhere((item) => item.id == storeId);
    await saveStore(store.copyWith(commissionRate: commissionRate), actor: actor);
    await logActivity(
      action: 'adjust_commission',
      targetType: 'store',
      targetId: storeId,
      message: 'Adjusted commission for $storeId to ${(commissionRate * 100).toStringAsFixed(0)}%.',
      actor: actor,
    );
  }

  Future<void> adjustStoreWallet({
    required String storeId,
    required double delta,
    required AppUser actor,
  }) async {
    _requireSuperAdmin(actor);
    final store = (await getAdminStores()).firstWhere((item) => item.id == storeId);
    await saveStore(store.copyWith(walletBalance: store.walletBalance + delta), actor: actor);
    await logActivity(
      action: 'adjust_wallet',
      targetType: 'store',
      targetId: storeId,
      message: 'Adjusted wallet for $storeId by Rs ${delta.toStringAsFixed(0)}.',
      actor: actor,
    );
  }

  Future<GlobalSearchResults> runGlobalAdminSearch(String query, {required AppUser actor}) async {
    _requireSuperAdmin(actor);
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const GlobalSearchResults();
    }
    final users = (await getUsers(actor: actor))
        .where((user) => '${user.name} ${user.email} ${user.phone ?? ''} ${user.role}'.toLowerCase().contains(normalized))
        .toList();
    final stores = (await getAdminStores())
        .where((store) => '${store.name} ${store.address} ${store.id}'.toLowerCase().contains(normalized))
        .toList();
    final orders = (await getAllOrders(actor: actor))
        .where((order) => '${order.id} ${order.storeId} ${order.userId} ${order.invoiceNumber}'.toLowerCase().contains(normalized))
        .toList();
    return GlobalSearchResults(users: users, stores: stores, orders: orders);
  }

  Future<List<ActivityLogEntry>> getActivityLogs({required AppUser actor}) async {
    _requireSuperAdmin(actor);
    if (_backendCommerce.isConfigured) {
      final logs = await _backendCommerce.getAdminActivityLogs();
      logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return logs;
    }
    final logs = await _fetchCollection('activityLogs', (map, id) => ActivityLogEntry.fromMap(map, id));
    logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return logs;
  }

  Future<List<AiUsageLogEntry>> getAiUsageLogs({
    required AppUser actor,
    int limit = 120,
  }) async {
    _requireSuperAdmin(actor);
    if (_backendCommerce.isConfigured) {
      return _backendCommerce.getAiUsageLogs(limit: limit);
    }
    final logs = await _fetchCollection(
      'aiUsageLogs',
      (map, id) => AiUsageLogEntry.fromMap(map, id),
    );
    logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return logs.take(limit).toList();
  }

  Future<List<AiDailyStat>> getAiDailyStats({required AppUser actor}) async {
    _requireSuperAdmin(actor);
    if (_backendCommerce.isConfigured) {
      return _backendCommerce.getAiDailyStats();
    }
    final stats = await _fetchCollection(
      'aiDailyStats',
      (map, id) => AiDailyStat.fromMap(map, id),
    );
    stats.sort((a, b) => a.date.compareTo(b.date));
    return stats;
  }

  Future<List<UserAiUsageStat>> getUserAiUsageStats({
    required AppUser actor,
  }) async {
    _requireSuperAdmin(actor);
    if (_backendCommerce.isConfigured) {
      return _backendCommerce.getUserAiUsageStats();
    }
    final stats = await _fetchCollection(
      'userAIUsage',
      (map, id) => UserAiUsageStat.fromMap(map, id),
    );
    stats.sort((a, b) => b.aiMessages.compareTo(a.aiMessages));
    return stats;
  }

  String getCurrentDeviceLabel() {
    if (kIsWeb) {
      return 'web-chrome';
    }
    return 'windows-desktop';
  }

  Future<bool> isAdminDeviceAuthorized({required AppUser user, String? deviceLabel}) async {
    if (!isSuperAdmin(user)) {
      return true;
    }
    final settings = await getPlatformSettings();
    final current = deviceLabel ?? getCurrentDeviceLabel();
    return settings.allowedAdminDevices.contains(current);
  }

  Future<void> notifyAdminLogin({required AppUser user}) async {
    if (!isSuperAdmin(user)) {
      return;
    }
    final message = 'Admin login detected from ${getCurrentDeviceLabel()} at ${DateFormat('dd MMM, hh:mm a').format(DateTime.now())}.';
    _addNotification(
      AppNotification(
        id: 'admin-login-${DateTime.now().millisecondsSinceEpoch}',
        title: 'Admin login event',
        body: message,
        type: 'security',
        isRead: false,
        timestamp: DateTime.now(),
        audienceRole: 'admin',
        userId: user.id,
      ),
    );
    await logActivity(
      action: 'admin_login',
      targetType: 'admin',
      targetId: user.id,
      message: message,
      actor: user,
    );
  }
}
