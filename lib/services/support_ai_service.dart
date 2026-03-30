import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';
import 'app_config.dart';

enum SupportActionType {
  trackOrder,
  cancelOrder,
  requestReturn,
  requestRefund,
  updateAddress,
  customHelp,
  paymentHelp,
  generalReply,
}

class SupportActionPlan {
  const SupportActionPlan({
    required this.action,
    this.orderId,
    this.address,
    this.reason,
  });

  final SupportActionType action;
  final String? orderId;
  final String? address;
  final String? reason;
}

class SupportAiService {
  const SupportAiService();

  static const String _supportSystemPrompt =
      'ABZORA support assistant. Short answers. Helpful. Max 2 sentences.';
  static const int _maxReplyTokens = 110;
  static const int _maxDetailedReplyTokens = 150;
  static const int _maxPlanningTokens = 70;
  static const int _maxMemoryTokens = 90;
  static const int _maxSummaryTokens = 70;
  static const int _historyMessageLimit = 3;
  static const double _duplicateSimilarityThreshold = 0.74;

  String _cleanPrompt(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^(please|hi|hello|hey)\s+', caseSensitive: false), '')
        .trim();
  }

  String _truncate(String value, {int maxChars = 220}) {
    final cleaned = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.length <= maxChars) {
      return cleaned;
    }
    return '${cleaned.substring(0, maxChars - 3)}...';
  }

  String normalizePromptFingerprint(String value) {
    final normalized = _cleanPrompt(value)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return _truncate(normalized, maxChars: 120);
  }

  Set<String> _wordSet(String value) {
    return normalizePromptFingerprint(value)
        .split(' ')
        .where((item) => item.trim().length > 2)
        .toSet();
  }

  bool _isNearDuplicatePrompt(String current, String previous) {
    final currentSet = _wordSet(current);
    final previousSet = _wordSet(previous);
    if (currentSet.isEmpty || previousSet.isEmpty) {
      return false;
    }
    final overlap = currentSet.intersection(previousSet).length;
    final total = currentSet.union(previousSet).length;
    if (total == 0) {
      return false;
    }
    return (overlap / total) >= _duplicateSimilarityThreshold;
  }

  List<ConversationMemoryMessage> _recentMessages(
    List<ConversationMemoryMessage> messages, {
    int limit = _historyMessageLimit,
  }) {
    if (messages.length <= limit) {
      return messages;
    }
    return messages.sublist(messages.length - limit);
  }

  String _memorySummary(UserMemory? memory) {
    if (memory == null) {
      return '';
    }
    final bits = <String>[
      if (memory.preferredStyle.trim().isNotEmpty)
        'style ${_truncate(memory.preferredStyle, maxChars: 40)}',
      if (memory.size.trim().isNotEmpty) 'size ${memory.size.trim()}',
      if (memory.lastConversationSummary.trim().isNotEmpty)
        _truncate(memory.lastConversationSummary, maxChars: 80),
    ];
    return bits.join(' | ');
  }

  String _orderSummary(OrderModel? order) {
    if (order == null) {
      return '';
    }
    return '#${order.id} ${order.status}/${order.deliveryStatus} ${order.paymentMethod}${order.isPaymentVerified ? " paid" : ""}';
  }

  String _historySummary(List<ConversationMemoryMessage> history) {
    final recent = _recentMessages(history);
    final compact = <ConversationMemoryMessage>[];
    for (final entry in recent) {
      if (compact.isNotEmpty &&
          entry.role == 'user' &&
          compact.last.role == 'user' &&
          _isNearDuplicatePrompt(entry.text, compact.last.text)) {
        compact.removeLast();
      }
      compact.add(entry);
    }
    return compact
        .map(
          (entry) =>
              '${entry.role}: ${_truncate(entry.text, maxChars: entry.role == 'assistant' ? 64 : 82)}',
        )
        .join('\n');
  }

  String buildContext({
    required String prompt,
    OrderModel? order,
    UserMemory? memory,
    List<ConversationMemoryMessage> recentHistory = const [],
    String? extra,
  }) {
    return [
      if (_memorySummary(memory).isNotEmpty) 'memory: ${_memorySummary(memory)}',
      if (_orderSummary(order).isNotEmpty) 'order: ${_orderSummary(order)}',
      if (_historySummary(recentHistory).isNotEmpty) 'recent:\n${_historySummary(recentHistory)}',
      if ((extra ?? '').trim().isNotEmpty) extra!.trim(),
      'message: ${_truncate(_cleanPrompt(prompt), maxChars: 180)}',
    ].join('\n');
  }

  String _replyModelFor({
    required SupportChat chat,
    MeasurementProfile? measurement,
    BodyProfile? bodyProfile,
    String? toolName,
  }) {
    final needsRicherReasoning =
        chat.type == 'custom' ||
        (toolName ?? '').trim().isNotEmpty ||
        measurement != null ||
        bodyProfile != null;
    return needsRicherReasoning ? AppConfig.openAiModel : AppConfig.openAiCheapModel;
  }

  int _replyTokenBudgetFor({
    required SupportChat chat,
    String? toolName,
  }) {
    return chat.type == 'custom' || (toolName ?? '').trim().isNotEmpty
        ? _maxDetailedReplyTokens
        : _maxReplyTokens;
  }

  Future<SupportActionPlan?> planActionWithOpenAi({
    required AppUser actor,
    required SupportChat chat,
    required String prompt,
    OrderModel? order,
    UserMemory? memory,
    List<ConversationMemoryMessage> recentHistory = const [],
  }) async {
    if (!AppConfig.hasOpenAiConfig) {
      return null;
    }

    final response = await http
        .post(
          Uri.parse(AppConfig.openAiResponsesEndpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${AppConfig.openAiApiKey}',
          },
          body: jsonEncode({
            'model': AppConfig.openAiCheapModel,
            'max_output_tokens': _maxPlanningTokens,
            'tools': [
              {
                'type': 'function',
                'name': 'cancelOrder',
                'description': 'Cancel a user order.',
                'parameters': {
                  'type': 'object',
                  'properties': {
                    'orderId': {
                      'type': 'string',
                      'description': 'Order ID to cancel',
                    },
                  },
                  'required': ['orderId'],
                },
              },
              {
                'type': 'function',
                'name': 'trackOrder',
                'description': 'Get the latest order status for a user.',
                'parameters': {
                  'type': 'object',
                  'properties': {
                    'orderId': {'type': 'string'},
                  },
                  'required': ['orderId'],
                },
              },
              {
                'type': 'function',
                'name': 'requestRefund',
                'description': 'Create a refund request for a user order.',
                'parameters': {
                  'type': 'object',
                  'properties': {
                    'orderId': {'type': 'string'},
                    'reason': {'type': 'string'},
                  },
                  'required': ['orderId'],
                },
              },
              {
                'type': 'function',
                'name': 'requestReturn',
                'description': 'Create a return request for a delivered non-custom order.',
                'parameters': {
                  'type': 'object',
                  'properties': {
                    'orderId': {'type': 'string'},
                    'reason': {'type': 'string'},
                  },
                  'required': ['orderId'],
                },
              },
              {
                'type': 'function',
                'name': 'updateAddress',
                'description': 'Update the user delivery address.',
                'parameters': {
                  'type': 'object',
                  'properties': {
                    'newAddress': {'type': 'string'},
                  },
                  'required': ['newAddress'],
                },
              },
            ],
            'tool_choice': 'auto',
            'input': [
              {
                'role': 'system',
                'content': [
                  {
                    'type': 'input_text',
                    'text':
                        'ABZORA support router. Use a function for actions. Keep reasoning minimal. Prefer no free-text when a tool fits.',
                  },
                ],
              },
              {
                'role': 'user',
                'content': [
                  {
                    'type': 'input_text',
                    'text': buildContext(
                      prompt: prompt,
                      order: order,
                      memory: memory,
                      recentHistory: recentHistory,
                      extra:
                          'user: ${actor.name.isEmpty ? 'ABZORA Member' : _truncate(actor.name, maxChars: 24)}\nchat: ${chat.type}',
                    ),
                  },
                ],
              },
            ],
          }),
        )
        .timeout(const Duration(seconds: 2));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      final functionCall = _extractFunctionCall(decoded);
      if (functionCall != null) {
        return _planFromFunctionCall(functionCall);
      }
    }
    return const SupportActionPlan(action: SupportActionType.generalReply);
  }

  SupportActionPlan planActionFallback({
    required SupportChat chat,
    required bool looksLikeCancellation,
    required bool looksLikeRefund,
    required bool looksLikeOrderTracking,
    required bool looksLikePaymentHelp,
    required bool looksLikeCustomHelp,
    required bool looksLikeAddressHelp,
    String? extractedAddress,
  }) {
    if (looksLikeCancellation) {
      return const SupportActionPlan(action: SupportActionType.cancelOrder);
    }
    if (looksLikeRefund) {
      return const SupportActionPlan(action: SupportActionType.requestRefund);
    }
    if (chat.type == 'return') {
      return const SupportActionPlan(action: SupportActionType.requestReturn);
    }
    if (extractedAddress != null) {
      return SupportActionPlan(
        action: SupportActionType.updateAddress,
        address: extractedAddress,
      );
    }
    if (looksLikeOrderTracking || chat.type == 'order') {
      return const SupportActionPlan(action: SupportActionType.trackOrder);
    }
    if (looksLikePaymentHelp || chat.type == 'payment') {
      return const SupportActionPlan(action: SupportActionType.paymentHelp);
    }
    if (looksLikeCustomHelp || chat.type == 'custom') {
      return const SupportActionPlan(action: SupportActionType.customHelp);
    }
    if (looksLikeAddressHelp) {
      return const SupportActionPlan(action: SupportActionType.updateAddress);
    }
    return const SupportActionPlan(action: SupportActionType.generalReply);
  }

  Map<String, dynamic>? _extractFunctionCall(Map<String, dynamic> payload) {
    final output = payload['output'];
    if (output is! List) {
      return null;
    }
    for (final item in output) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      if ((item['type'] ?? '').toString() == 'function_call') {
        return item;
      }
      final content = item['content'];
      if (content is! List) {
        continue;
      }
      for (final block in content) {
        if (block is Map<String, dynamic> &&
            (block['type'] ?? '').toString() == 'function_call') {
          return block;
        }
      }
    }
    return null;
  }

  SupportActionPlan _planFromFunctionCall(Map<String, dynamic> call) {
    final name = (call['name'] ?? '').toString().trim();
    final rawArguments = call['arguments'];
    Map<String, dynamic> arguments = const {};
    if (rawArguments is String && rawArguments.trim().startsWith('{')) {
      arguments = jsonDecode(rawArguments) as Map<String, dynamic>;
    } else if (rawArguments is Map) {
      arguments = Map<String, dynamic>.from(
        rawArguments.map((key, value) => MapEntry(key.toString(), value)),
      );
    }

    final orderId = (arguments['orderId'] ?? '').toString().trim();
    final reason = (arguments['reason'] ?? '').toString().trim();
    final newAddress = (arguments['newAddress'] ?? '').toString().trim();

    return switch (name) {
      'cancelOrder' => SupportActionPlan(
          action: SupportActionType.cancelOrder,
          orderId: orderId.isEmpty ? null : orderId,
          reason: reason.isEmpty ? null : reason,
        ),
      'trackOrder' => SupportActionPlan(
          action: SupportActionType.trackOrder,
          orderId: orderId.isEmpty ? null : orderId,
        ),
      'requestRefund' => SupportActionPlan(
          action: SupportActionType.requestRefund,
          orderId: orderId.isEmpty ? null : orderId,
          reason: reason.isEmpty ? null : reason,
        ),
      'requestReturn' => SupportActionPlan(
          action: SupportActionType.requestReturn,
          orderId: orderId.isEmpty ? null : orderId,
          reason: reason.isEmpty ? null : reason,
        ),
      'updateAddress' => SupportActionPlan(
          action: SupportActionType.updateAddress,
          address: newAddress.isEmpty ? null : newAddress,
          reason: reason.isEmpty ? null : reason,
        ),
      _ => const SupportActionPlan(action: SupportActionType.generalReply),
    };
  }

  Future<String?> generateOpenAiSupportReply({
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
    if (!AppConfig.hasOpenAiConfig) {
      return null;
    }

    final response = await http
        .post(
          Uri.parse(AppConfig.openAiResponsesEndpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${AppConfig.openAiApiKey}',
          },
          body: jsonEncode({
            'model': _replyModelFor(
              chat: chat,
              measurement: measurement,
              bodyProfile: bodyProfile,
              toolName: toolName,
            ),
            'max_output_tokens': _replyTokenBudgetFor(
              chat: chat,
              toolName: toolName,
            ),
            'input': [
              {
                'role': 'system',
                'content': [
                  {
                    'type': 'input_text',
                    'text':
                        '$_supportSystemPrompt Prefer direct answers under 40 words unless fitting or troubleshooting detail is essential.',
                  },
                ],
              },
              {
                'role': 'user',
                'content': [
                  {
                    'type': 'input_text',
                    'text': buildContext(
                      prompt: prompt,
                      order: order,
                      memory: memory,
                      recentHistory: recentHistory,
                      extra: [
                        'user: ${actor.name.isEmpty ? 'ABZORA Member' : _truncate(actor.name, maxChars: 24)}',
                        'chat: ${chat.type}',
                        if (measurement != null)
                          'fit: ${measurement.label}, chest ${measurement.chest.toStringAsFixed(0)}, waist ${measurement.waist.toStringAsFixed(0)}',
                        if (bodyProfile != null)
                          'body: ${bodyProfile.bodyType}, top ${bodyProfile.recommendedSize}, pant ${bodyProfile.pantSize}',
                        if ((toolName ?? '').trim().isNotEmpty) 'tool: ${toolName!.trim()}',
                        if ((actionSummary ?? '').trim().isNotEmpty)
                          'result: ${_truncate(actionSummary!, maxChars: 120)}',
                      ].join('\n'),
                    ),
                  },
                ],
              },
            ],
          }),
        )
        .timeout(const Duration(seconds: 2));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final direct = (decoded['output_text'] ?? '').toString().trim();
    if (direct.isNotEmpty) {
      return direct;
    }
    final output = decoded['output'];
    if (output is List) {
      for (final item in output) {
        if (item is Map<String, dynamic>) {
          final content = item['content'];
          if (content is List) {
            for (final block in content) {
              if (block is Map<String, dynamic>) {
                final text = (block['text'] ?? block['output_text'] ?? '')
                    .toString()
                    .trim();
                if (text.isNotEmpty) {
                  return text;
                }
              }
            }
          }
        }
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> extractMemoryWithOpenAi({
    required AppUser actor,
    required String userMessage,
    required String assistantReply,
    UserMemory? currentMemory,
    OrderModel? order,
  }) async {
    if (!AppConfig.hasOpenAiConfig) {
      return null;
    }

    final response = await http
        .post(
          Uri.parse(AppConfig.openAiResponsesEndpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${AppConfig.openAiApiKey}',
          },
          body: jsonEncode({
            'model': AppConfig.openAiCheapModel,
            'max_output_tokens': _maxMemoryTokens,
            'input': [
              {
                'role': 'system',
                'content': [
                  {
                    'type': 'input_text',
                    'text':
                        'Extract durable memory only. Return strict JSON: preferredStyle, size, addPastIssues, lastConversationSummary.',
                  },
                ],
              },
              {
                'role': 'user',
                'content': [
                  {
                    'type': 'input_text',
                    'text': [
                      'user: ${_truncate(actor.name, maxChars: 24)}',
                      if (currentMemory != null) 'memory: ${_memorySummary(currentMemory)}',
                      if (order != null) 'order: ${_orderSummary(order)}',
                      'u: ${_truncate(_cleanPrompt(userMessage), maxChars: 120)}',
                      'a: ${_truncate(assistantReply, maxChars: 120)}',
                    ].join('\n'),
                  },
                ],
              },
            ],
          }),
        )
        .timeout(const Duration(seconds: 2));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }
    final decoded = jsonDecode(response.body);
    final text = _extractTextResponse(decoded);
    if (!text.trim().startsWith('{')) {
      return null;
    }
    return jsonDecode(text) as Map<String, dynamic>;
  }

  Future<String?> summarizeConversationWithOpenAi({
    required AppUser actor,
    required List<ConversationMemoryMessage> recentHistory,
    UserMemory? currentMemory,
    OrderModel? order,
  }) async {
    if (!AppConfig.hasOpenAiConfig || recentHistory.isEmpty) {
      return null;
    }

    final response = await http
        .post(
          Uri.parse(AppConfig.openAiResponsesEndpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${AppConfig.openAiApiKey}',
          },
          body: jsonEncode({
            'model': AppConfig.openAiCheapModel,
            'max_output_tokens': _maxSummaryTokens,
            'input': [
              {
                'role': 'system',
                'content': [
                  {
                    'type': 'input_text',
                    'text':
                        'Summarize for memory in one short sentence: preferences, fit clues, unresolved issue.',
                  },
                ],
              },
              {
                'role': 'user',
                'content': [
                  {
                    'type': 'input_text',
                    'text': [
                      'user: ${_truncate(actor.name, maxChars: 24)}',
                      if (currentMemory != null &&
                          currentMemory.lastConversationSummary.trim().isNotEmpty)
                        'current: ${_truncate(currentMemory.lastConversationSummary, maxChars: 90)}',
                      if (order != null) 'order: ${_orderSummary(order)}',
                      ..._recentMessages(recentHistory).map(
                        (entry) => '${entry.role}: ${_truncate(entry.text, maxChars: 80)}',
                      ),
                    ].join('\n'),
                  },
                ],
              },
            ],
          }),
        )
        .timeout(const Duration(seconds: 2));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }
    final decoded = jsonDecode(response.body);
    final text = _extractTextResponse(decoded).trim();
    return text.isEmpty ? null : text;
  }

  String _extractTextResponse(Object? decoded) {
    if (decoded is! Map<String, dynamic>) {
      return '';
    }
    final direct = (decoded['output_text'] ?? '').toString().trim();
    if (direct.isNotEmpty) {
      return direct;
    }
    final output = decoded['output'];
    if (output is List) {
      for (final item in output) {
        if (item is Map<String, dynamic>) {
          final content = item['content'];
          if (content is List) {
            for (final block in content) {
              if (block is Map<String, dynamic>) {
                final text = (block['text'] ?? block['output_text'] ?? '')
                    .toString()
                    .trim();
                if (text.isNotEmpty) {
                  return text;
                }
              }
            }
          }
        }
      }
    }
    return '';
  }
}
