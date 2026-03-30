import 'dart:async';

import 'package:flutter/foundation.dart';

import 'backend_api_client.dart';

class Message {
  final String senderId;
  final String text;
  final DateTime timestamp;

  Message({
    required this.senderId,
    required this.text,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'text': text,
        'timestamp': timestamp.toIso8601String(),
      };

  factory Message.fromMap(Map<String, dynamic> map) => Message(
        senderId: map['senderId'],
        text: map['text'],
        timestamp: DateTime.tryParse(map['timestamp']?.toString() ?? '') ?? DateTime.now(),
      );
}

class ChatService {
  ChatService({BackendApiClient? backendApiClient})
      : _backendApiClient = backendApiClient ?? const BackendApiClient();

  final BackendApiClient _backendApiClient;

  Stream<List<Message>> getMessages(String chatId) {
    return (() async* {
      yield await _fetchBackendMessages(chatId);
      while (true) {
        await Future<void>.delayed(const Duration(seconds: 3));
        yield await _fetchBackendMessages(chatId);
      }
    })();
  }

  Future<void> sendMessage(String chatId, Message message) async {
    try {
      await _backendApiClient.post(
        '/chats/$chatId/messages',
        authenticated: true,
        body: {
          'text': message.text,
          'timestamp': message.timestamp.toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('Chat send failed: $e');
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> getChats() {
    return (() async* {
      yield await _fetchBackendChats();
      while (true) {
        await Future<void>.delayed(const Duration(seconds: 5));
        yield await _fetchBackendChats();
      }
    })();
  }

  Future<List<Message>> _fetchBackendMessages(String chatId) async {
    final payload = await _backendApiClient.get('/chats/$chatId/messages', authenticated: true);
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map(
          (item) => Message(
            senderId: item['senderId']?.toString() ?? '',
            text: item['text']?.toString() ?? '',
            timestamp: DateTime.tryParse(item['timestamp']?.toString() ?? '') ?? DateTime.now(),
          ),
        )
        .toList();
  }

  Future<List<Map<String, dynamic>>> _fetchBackendChats() async {
    final payload = await _backendApiClient.get('/chats', authenticated: true);
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}
