import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'vendor_onboarding_api.dart';
import 'vendor_onboarding_local_cache.dart';

class VendorOnboardingSyncService {
  VendorOnboardingSyncService({
    VendorOnboardingApi? api,
    VendorOnboardingLocalCache? cache,
  })  : _api = api ?? const VendorOnboardingApi(),
        _cache = cache ?? VendorOnboardingLocalCache();

  final VendorOnboardingApi _api;
  final VendorOnboardingLocalCache _cache;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isSyncing = false;
  Timer? _syncTimer;

  void start() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.isNotEmpty && results.first != ConnectivityResult.none) {
        debugPrint('[ONBOARDING_SYNC] Connectivity restored. Triggering sync...');
        syncPendingDrafts();
      }
    });

    // Also run a background sync interval every 5 minutes
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      syncPendingDrafts();
    });

    // Run initial sync on startup
    syncPendingDrafts();
  }

  void stop() {
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
  }

  Future<void> syncPendingDrafts() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.isNotEmpty && connectivity.first == ConnectivityResult.none) {
        debugPrint('[ONBOARDING_SYNC] Offline. Skipping sync.');
        return;
      }

      final pendingUserIds = await _cache.getPendingSyncUserIds();
      if (pendingUserIds.isEmpty) {
        return;
      }

      debugPrint('[ONBOARDING_SYNC] Found ${pendingUserIds.length} pending drafts to sync.');

      for (final userId in pendingUserIds) {
        final draftData = await _cache.getDraft(userId);
        if (draftData != null && draftData['draftPayload'] != null) {
          try {
            debugPrint('[ONBOARDING_SYNC] Syncing draft for $userId');
            final payload = Map<String, dynamic>.from(draftData['draftPayload']);
            await _api.saveDraft(payload);
            
            // Mark synced and delete
            await _cache.markSynced(userId);
            await _cache.deleteDraft(userId);
            debugPrint('[ONBOARDING_SYNC] Successfully synced and removed local draft for $userId');
          } catch (e) {
            debugPrint('[ONBOARDING_SYNC_ERROR] Failed to sync draft for $userId: $e');
            await _cache.markSyncFailed(userId);
          }
        }
      }
    } finally {
      _isSyncing = false;
    }
  }
}
