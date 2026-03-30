import 'package:flutter/material.dart';
import 'dart:async';
import '../services/chat_service.dart';

class ChatProvider with ChangeNotifier {
  final ChatService _chatService = ChatService();
  bool _isLoading = false;
  StreamSubscription<List<Map<String, dynamic>>>? _chatSubscription;
  List<Map<String, dynamic>> _chats = [];

  bool get isLoading => _isLoading;
  List<Map<String, dynamic>> get chats => _chats;

  ChatProvider() {
    _isLoading = true;
    _chatSubscription = _chatService.getChats().listen((items) {
      _chats = items;
      _isLoading = false;
      notifyListeners();
    });
  }

  void sendMessage(String chatId, Message message) async {
    await _chatService.sendMessage(chatId, message);
    notifyListeners();
  }

  @override
  void dispose() {
    _chatSubscription?.cancel();
    super.dispose();
  }
}
