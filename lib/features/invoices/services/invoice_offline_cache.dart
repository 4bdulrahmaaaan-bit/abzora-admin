import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class InvoiceOfflineCache {
  static const _key = 'invoice_offline_cache_v1';
  static const _tsKey = 'invoice_offline_cache_ts_v1';
  static const _retryKey = 'invoice_offline_retry_queue_v1';

  Future<void> saveRawJson(List<Map<String, dynamic>> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(rows));
    await prefs.setInt(_tsKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<List<Map<String, dynamic>>> readRawJson() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<DateTime?> lastUpdatedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(_tsKey);
    if (value == null || value <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  Future<bool> isExpired({Duration ttl = const Duration(hours: 6)}) async {
    final ts = await lastUpdatedAt();
    if (ts == null) return true;
    return DateTime.now().difference(ts) > ttl;
  }

  Future<void> enqueueRetry(Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_retryKey);
    final rows = raw == null || raw.isEmpty
        ? <dynamic>[]
        : (jsonDecode(raw) as List<dynamic>);
    rows.add(payload);
    await prefs.setString(_retryKey, jsonEncode(rows));
  }

  Future<List<Map<String, dynamic>>> readRetryQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_retryKey);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    final rows = jsonDecode(raw) as List<dynamic>;
    return rows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> clearRetryQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_retryKey);
  }
}
