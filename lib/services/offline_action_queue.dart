import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

class OfflineActionQueue {
  static const String _boxName = 'offline_actions_v1';
  static Box? _box;

  static Future<void> init() async {
    try {
      debugPrint('[BOOT] 2 Hive initialize start');
      await Hive.initFlutter().timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('[BOOT ERROR] Hive.initFlutter timeout'),
      );
      debugPrint('[BOOT] 2 Hive initialize done');

      debugPrint('[BOOT] 3 Open offline queue start');
      _box = await Hive.openBox(_boxName).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('[BOOT ERROR] Hive.openBox timeout'),
      );
      debugPrint('[BOOT] 3 Open offline queue done');
    } catch (e, st) {
      debugPrint('[BOOT ERROR] $e');
      debugPrint('$st');
      rethrow;
    }
  }

  static Future<String> enqueue({
    required String endpoint,
    required String method,
    required Map<String, dynamic> payload,
  }) async {
    if (_box == null) await init();
    
    final id = const Uuid().v4();
    final action = {
      'idempotencyKey': id,
      'endpoint': endpoint,
      'method': method,
      'payload': jsonEncode(payload),
      'createdAt': DateTime.now().toIso8601String(),
      'retryCount': 0,
      'synced': false,
    };
    
    await _box!.put(id, action);
    return id;
  }

  static Future<List<Map<String, dynamic>>> getPendingActions() async {
    if (_box == null) await init();
    
    final actions = <Map<String, dynamic>>[];
    for (final key in _box!.keys) {
      final action = _box!.get(key);
      if (action != null && action['synced'] == false) {
        actions.add(Map<String, dynamic>.from(action));
      }
    }
    
    // Sort by createdAt ascending
    actions.sort((a, b) => a['createdAt'].compareTo(b['createdAt']));
    return actions;
  }

  static Future<void> markSynced(String idempotencyKey) async {
    if (_box == null) await init();
    
    final action = _box!.get(idempotencyKey);
    if (action != null) {
      // Requirements: Delete queue item only after 2xx response
      await _box!.delete(idempotencyKey);
    }
  }

  static Future<void> incrementRetry(String idempotencyKey) async {
    if (_box == null) await init();
    
    final action = _box!.get(idempotencyKey);
    if (action != null) {
      final map = Map<String, dynamic>.from(action);
      map['retryCount'] = (map['retryCount'] ?? 0) + 1;
      await _box!.put(idempotencyKey, map);
    }
  }
}
