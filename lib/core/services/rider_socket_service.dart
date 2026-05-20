import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class RiderSocketService {
  RiderSocketService({String? baseUrl})
    : _baseUrl = baseUrl ?? 'https://api.abzora.com';

  final String _baseUrl;
  WebSocketChannel? _channel;

  void Function()? _onConnect;
  void Function()? _onDisconnect;
  void Function(Map<String, dynamic>)? _onIncomingOrder;
  void Function(Map<String, dynamic>)? _onOrderStatusUpdate;
  void Function(Map<String, dynamic>)? _onDeliveryCompleted;

  bool _connected = false;
  bool get isConnected => _connected;

  void connect({
    required String riderId,
    required String authToken,
    String? orderId,
  }) {
    disconnect();

    final uri = _buildSocketUri(
      riderId: riderId,
      authToken: authToken,
      orderId: orderId,
    );
    if (kIsWeb) {
      _channel = WebSocketChannel.connect(uri);
    } else {
      _channel = IOWebSocketChannel.connect(
        uri,
        headers: <String, dynamic>{'Authorization': 'Bearer $authToken'},
      );
    }
    _connected = true;
    _onConnect?.call();

    _channel?.stream.listen(
      (data) {
        final payload = _normalizePayload(data);
        final eventType = payload['eventType']?.toString() ?? '';
        if (eventType == 'connected') {
          _connected = true;
          _onConnect?.call();
        } else if (eventType == 'receive_order') {
          _onIncomingOrder?.call(payload);
        } else if (eventType == 'order_status_update') {
          _onOrderStatusUpdate?.call(payload);
        } else if (eventType == 'delivery_completed') {
          _onDeliveryCompleted?.call(payload);
        }
      },
      onDone: () {
        _connected = false;
        _onDisconnect?.call();
      },
      onError: (_) {
        _connected = false;
        _onDisconnect?.call();
      },
    );
  }

  Uri _buildSocketUri({
    required String riderId,
    required String authToken,
    String? orderId,
  }) {
    final base = Uri.parse(_baseUrl);
    final secureScheme = base.scheme == 'https' ? 'wss' : 'ws';
    final query = <String, String>{
      'riderId': riderId,
      if (orderId != null && orderId.trim().isNotEmpty) 'orderId': orderId,
      if (kIsWeb) 'token': authToken,
    };
    return base.replace(
      scheme: secureScheme,
      path: '/tracking/ws',
      queryParameters: query,
    );
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    if (_connected) {
      _connected = false;
      _onDisconnect?.call();
    }
  }

  void onConnect(void Function() handler) => _onConnect = handler;

  void onDisconnect(void Function() handler) => _onDisconnect = handler;

  void onIncomingOrder(void Function(Map<String, dynamic>) handler) =>
      _onIncomingOrder = handler;

  void onOrderStatusUpdate(void Function(Map<String, dynamic>) handler) =>
      _onOrderStatusUpdate = handler;

  void onDeliveryCompleted(void Function(Map<String, dynamic>) handler) =>
      _onDeliveryCompleted = handler;

  void emitOrderAssigned({required String orderId, required String riderId}) {
    _send(<String, dynamic>{
      'eventType': 'order_assigned',
      'orderId': orderId,
      'riderId': riderId,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void emitLocationUpdate({
    required String orderId,
    required String riderId,
    required double latitude,
    required double longitude,
  }) {
    _send(<String, dynamic>{
      'eventType': 'rider_location_update',
      'orderId': orderId,
      'riderId': riderId,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void emitStatusUpdate({required String orderId, required String status}) {
    _send(<String, dynamic>{
      'eventType': 'order_status_update',
      'orderId': orderId,
      'status': status,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void emitDeliveryCompleted({
    required String orderId,
    required String riderId,
  }) {
    _send(<String, dynamic>{
      'eventType': 'delivery_completed',
      'orderId': orderId,
      'riderId': riderId,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void _send(Map<String, dynamic> payload) {
    final text = jsonEncode(payload);
    _channel?.sink.add(text);
  }

  Map<String, dynamic> _normalizePayload(Object? data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    }
    return <String, dynamic>{};
  }
}
