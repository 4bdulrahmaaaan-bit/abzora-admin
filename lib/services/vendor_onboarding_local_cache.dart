import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

enum SyncStatus {
  cloudSynced,
  pendingSync,
  syncFailed,
  localOnly,
  saving,
  syncing,
}

class VendorOnboardingLocalCache {
  static const String _boxName = 'vendor_onboarding_drafts';

  Future<Box> _getBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box(_boxName);
    }
    return await Hive.openBox(_boxName);
  }

  Future<void> saveDraft(String userId, Map<String, dynamic> payload, int currentStep) async {
    try {
      final box = await _getBox();
      final draftData = {
        'draftPayload': payload,
        'currentStep': currentStep,
        'lastUpdatedAt': DateTime.now().toIso8601String(),
        'lastSyncTime': null,
        'lastSyncStatus': SyncStatus.pendingSync.name,
        'isPendingSync': true,
        'version': 2, // V2 architecture
      };
      await box.put(userId, draftData);
      debugPrint('[ONBOARDING_CACHE] Draft saved locally for $userId');
    } catch (e) {
      debugPrint('[ONBOARDING_CACHE_ERROR] Failed to save draft: $e');
    }
  }

  Future<Map<String, dynamic>?> getDraft(String userId) async {
    try {
      final box = await _getBox();
      final draftData = box.get(userId);
      if (draftData != null && draftData is Map) {
        // Convert to properly typed map
        return Map<String, dynamic>.from(draftData);
      }
    } catch (e) {
      debugPrint('[ONBOARDING_CACHE_ERROR] Failed to get draft: $e');
    }
    return null;
  }

  Future<void> markSynced(String userId) async {
    try {
      final box = await _getBox();
      final draftData = box.get(userId);
      if (draftData != null && draftData is Map) {
        final updatedData = Map<String, dynamic>.from(draftData);
        updatedData['lastSyncTime'] = DateTime.now().toIso8601String();
        updatedData['lastSyncStatus'] = SyncStatus.cloudSynced.name;
        updatedData['isPendingSync'] = false;
        await box.put(userId, updatedData);
        debugPrint('[ONBOARDING_CACHE] Draft marked as synced for $userId');
      }
    } catch (e) {
      debugPrint('[ONBOARDING_CACHE_ERROR] Failed to mark synced: $e');
    }
  }

  Future<void> markSyncFailed(String userId) async {
    try {
      final box = await _getBox();
      final draftData = box.get(userId);
      if (draftData != null && draftData is Map) {
        final updatedData = Map<String, dynamic>.from(draftData);
        updatedData['lastSyncStatus'] = SyncStatus.syncFailed.name;
        await box.put(userId, updatedData);
      }
    } catch (e) {
      debugPrint('[ONBOARDING_CACHE_ERROR] Failed to mark sync failed: $e');
    }
  }

  Future<void> deleteDraft(String userId) async {
    try {
      final box = await _getBox();
      await box.delete(userId);
      debugPrint('[ONBOARDING_CACHE] Draft deleted for $userId');
    } catch (e) {
      debugPrint('[ONBOARDING_CACHE_ERROR] Failed to delete draft: $e');
    }
  }

  Future<List<String>> getPendingSyncUserIds() async {
    try {
      final box = await _getBox();
      final keys = box.keys.where((key) {
        final draftData = box.get(key);
        if (draftData != null && draftData is Map) {
          return draftData['isPendingSync'] == true;
        }
        return false;
      }).map((e) => e.toString()).toList();
      return keys;
    } catch (e) {
      debugPrint('[ONBOARDING_CACHE_ERROR] Failed to get pending sync user ids: $e');
      return [];
    }
  }
}
