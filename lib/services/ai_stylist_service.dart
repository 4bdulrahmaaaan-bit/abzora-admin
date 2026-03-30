import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../models/models.dart';
import 'app_config.dart';

enum StylistIntent {
  outfitSuggestion,
  sizeHelp,
  productSearch,
  generalChat,
}

class StylistProductCard {
  const StylistProductCard({
    required this.product,
    required this.reason,
    this.recommendedSize,
  });

  final Product product;
  final String reason;
  final String? recommendedSize;
}

class StylistReply {
  const StylistReply({
    required this.text,
    this.quickReplies = const [],
    this.lookNotes = const [],
    this.highlightedSize,
    this.intent = StylistIntent.generalChat,
    this.products = const [],
  });

  final String text;
  final List<String> quickReplies;
  final List<String> lookNotes;
  final String? highlightedSize;
  final StylistIntent intent;
  final List<StylistProductCard> products;
}

class AiStylistService {
  const AiStylistService();

  static const String _systemPrompt = 'Fashion assistant. Short answers. Helpful.';
  static const int _maxReplyTokens = 140;
  static const int _historyMessageLimit = 4;

  String _cleanPrompt(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^(please|hi|hello|hey)\s+', caseSensitive: false), '')
        .trim()
        .toLowerCase();
  }

  String _truncate(String value, {int maxChars = 140}) {
    final cleaned = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.length <= maxChars) {
      return cleaned;
    }
    return '${cleaned.substring(0, maxChars - 3)}...';
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

  int estimateTokens(String text) => (text.length / 4).ceil();

  StylistIntent detectIntent(String prompt, {Product? focusedProduct}) {
    final cleaned = _cleanPrompt(prompt);
    if (cleaned.contains('size') ||
        cleaned.contains('fit') ||
        cleaned.contains('measurement')) {
      return StylistIntent.sizeHelp;
    }
    if (cleaned.contains('show') ||
        cleaned.contains('find') ||
        cleaned.contains('product') ||
        cleaned.contains('shirt') ||
        cleaned.contains('kurta') ||
        cleaned.contains('dress') ||
        cleaned.contains('blazer') ||
        cleaned.contains('hoodie') ||
        cleaned.contains('jeans') ||
        cleaned.contains('pants') ||
        cleaned.contains('trouser')) {
      return StylistIntent.productSearch;
    }
    if (focusedProduct != null ||
        cleaned.contains('wedding') ||
        cleaned.contains('casual') ||
        cleaned.contains('formal') ||
        cleaned.contains('outfit') ||
        cleaned.contains('wear') ||
        cleaned.contains('style') ||
        cleaned.contains('color')) {
      return StylistIntent.outfitSuggestion;
    }
    return StylistIntent.generalChat;
  }

  List<StylistProductCard> recommendProducts({
    required String prompt,
    required List<Product> catalogProducts,
    UserMemory? memory,
    BodyProfile? bodyProfile,
    List<OrderModel> orders = const [],
    Product? focusedProduct,
    int limit = 4,
  }) {
    if (catalogProducts.isEmpty) {
      return const [];
    }
    final cleaned = _cleanPrompt(prompt);
    final requestedTokens = cleaned
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.trim().isNotEmpty && token.length > 2)
        .toSet();
    final preferredStyle = (memory?.preferredStyle ?? '').toLowerCase();
    final orderedProductNames = orders
        .expand((order) => order.items)
        .map((item) => item.productName.toLowerCase())
        .toList();

    int score(Product product) {
      var total = 0;
      final haystack = [
        product.name,
        product.brand,
        product.description,
        product.category,
        product.outfitType ?? '',
        product.fabric ?? '',
        ...product.addons,
        ...product.customizations.values,
      ].join(' ').toLowerCase();

      for (final token in requestedTokens) {
        if (haystack.contains(token)) {
          total += 14;
        }
      }
      if (preferredStyle.isNotEmpty && haystack.contains(preferredStyle)) {
        total += 20;
      }
      if (focusedProduct != null && product.category == focusedProduct.category) {
        total += 18;
      }
      if (bodyProfile != null &&
          bodyProfile.recommendedSize.isNotEmpty &&
          product.sizes.map((size) => size.toUpperCase()).contains(bodyProfile.recommendedSize.toUpperCase())) {
        total += 10;
      }
      if (orderedProductNames.any((name) => haystack.contains(name.split(' ').first))) {
        total += 8;
      }
      total += product.purchaseCount * 2;
      total += product.viewCount;
      total += (product.rating * 6).round();
      if (product.hasDynamicDiscount) {
        total += 6;
      }
      if (product.isLimitedStock) {
        total += 4;
      }
      return total;
    }

    final ranked = catalogProducts
        .where((product) => product.isActive && product.stock > 0)
        .toList()
      ..sort((a, b) => score(b).compareTo(score(a)));

    return ranked.take(limit).map((product) {
      final recommendedSize = recommendSize(
        product: product,
        bodyProfile: bodyProfile,
        memory: memory,
      );
      return StylistProductCard(
        product: product,
        reason: _reasonForRecommendation(
          product,
          prompt: prompt,
          preferredStyle: preferredStyle,
        ),
        recommendedSize: recommendedSize,
      );
    }).toList();
  }

  String recommendSize({
    required Product product,
    BodyProfile? bodyProfile,
    MeasurementProfile? measurement,
    UserMemory? memory,
  }) {
    final base = (bodyProfile?.recommendedSize ??
            measurement?.recommendedSize ??
            memory?.size ??
            'M')
        .trim()
        .toUpperCase();
    final sizes = product.sizes.map((size) => size.trim().toUpperCase()).toList();
    if (sizes.isEmpty) {
      return base;
    }

    final fitText = [
      product.outfitType ?? '',
      product.description,
      product.fabric ?? '',
      ...product.customizations.values,
    ].join(' ').toLowerCase();
    const order = ['XS', 'S', 'M', 'L', 'XL', 'XXL'];
    var target = base;
    final index = order.indexOf(base);
    if (index != -1) {
      if (fitText.contains('slim') || fitText.contains('tailored')) {
        target = order[(index + 1).clamp(0, order.length - 1)];
      } else if (fitText.contains('oversized') || fitText.contains('relaxed')) {
        target = order[index];
      }
    }

    if (sizes.contains(target)) {
      return target;
    }
    if (sizes.contains(base)) {
      return base;
    }
    return sizes.first;
  }

  Future<StylistReply> respond({
    required String userName,
    required String prompt,
    required List<OrderModel> orders,
    required List<MeasurementProfile> measurements,
    List<Product> catalogProducts = const [],
    BodyProfile? bodyProfile,
    UserMemory? memory,
    List<ConversationMemoryMessage> recentHistory = const [],
    String? location,
    Product? focusedProduct,
  }) async {
    final intent = detectIntent(prompt, focusedProduct: focusedProduct);
    final recommendations = recommendProducts(
      prompt: prompt,
      catalogProducts: catalogProducts,
      memory: memory,
      bodyProfile: bodyProfile,
      orders: orders,
      focusedProduct: focusedProduct,
    );

    if (AppConfig.hasOpenAiConfig) {
      try {
        final openAiReply = await _respondWithOpenAi(
          userName: userName,
          prompt: prompt,
          orders: orders,
          measurements: measurements,
          catalogProducts: catalogProducts,
          bodyProfile: bodyProfile,
          memory: memory,
          recentHistory: recentHistory,
          location: location,
          focusedProduct: focusedProduct,
          intent: intent,
          recommendations: recommendations,
        );
        if (openAiReply != null) {
          return openAiReply;
        }
      } catch (_) {
        // Fall through to the heuristic response so the stylist stays usable.
      }
    }

    return _fallbackReply(
      userName: userName,
      prompt: prompt,
      orders: orders,
      measurements: measurements,
      catalogProducts: catalogProducts,
      bodyProfile: bodyProfile,
      memory: memory,
      recentHistory: recentHistory,
      location: location,
      focusedProduct: focusedProduct,
      intent: intent,
      recommendations: recommendations,
    );
  }

  Future<StylistReply?> _respondWithOpenAi({
    required String userName,
    required String prompt,
    required List<OrderModel> orders,
    required List<MeasurementProfile> measurements,
    List<Product> catalogProducts = const [],
    BodyProfile? bodyProfile,
    UserMemory? memory,
    List<ConversationMemoryMessage> recentHistory = const [],
    String? location,
    Product? focusedProduct,
    required StylistIntent intent,
    required List<StylistProductCard> recommendations,
  }) async {
    final response = await http
        .post(
          Uri.parse(AppConfig.openAiResponsesEndpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${AppConfig.openAiApiKey}',
          },
          body: jsonEncode({
            'model': AppConfig.openAiModel,
            'max_output_tokens': _maxReplyTokens,
            'input': [
              {
                'role': 'system',
                'content': [
                  {
                    'type': 'input_text',
                    'text': _systemPrompt,
                  },
                ],
              },
              {
                'role': 'user',
                'content': [
                  {
                    'type': 'input_text',
                    'text': _buildOpenAiPrompt(
                      userName: userName,
                      prompt: prompt,
                      orders: orders,
                      measurements: measurements,
                      catalogProducts: catalogProducts,
                      bodyProfile: bodyProfile,
                      memory: memory,
                      recentHistory: recentHistory,
                      location: location,
                      focusedProduct: focusedProduct,
                      intent: intent,
                      recommendations: recommendations,
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
    String text = '';
    if (decoded is Map<String, dynamic>) {
      text = (decoded['output_text'] ?? '').toString().trim();
      if (text.isEmpty) {
        final output = decoded['output'];
        if (output is List) {
          for (final item in output) {
            if (item is Map<String, dynamic>) {
              final content = item['content'];
              if (content is List) {
                for (final block in content) {
                  if (block is Map<String, dynamic>) {
                    final candidate = (block['text'] ?? block['output_text'] ?? '')
                        .toString()
                        .trim();
                    if (candidate.isNotEmpty) {
                      text = candidate;
                      break;
                    }
                  }
                }
              }
            }
            if (text.isNotEmpty) {
              break;
            }
          }
        }
      }
    }
    if (text.isEmpty) {
      return null;
    }

    final size = bodyProfile?.recommendedSize ??
        (measurements.isEmpty ? null : measurements.first.recommendedSize);
    return StylistReply(
      text: text,
      quickReplies: _quickRepliesForPrompt(prompt),
      highlightedSize: size,
      intent: intent,
      products: recommendations,
    );
  }

  String _buildOpenAiPrompt({
    required String userName,
    required String prompt,
    required List<OrderModel> orders,
    required List<MeasurementProfile> measurements,
    List<Product> catalogProducts = const [],
    BodyProfile? bodyProfile,
    UserMemory? memory,
    List<ConversationMemoryMessage> recentHistory = const [],
    String? location,
    Product? focusedProduct,
    required StylistIntent intent,
    required List<StylistProductCard> recommendations,
  }) {
    final latestOrder = orders.isEmpty ? null : orders.first;
    final primaryMeasurement = measurements.isEmpty ? null : measurements.first;
    final cleanedPrompt = _cleanPrompt(prompt);
    final history = _recentMessages(recentHistory)
        .map((entry) => '${entry.role}: ${_truncate(entry.text, maxChars: 80)}')
        .join('\n');
    final parts = [
      'user: ${userName.trim().isEmpty ? 'ABZORA Member' : _truncate(userName.trim(), maxChars: 24)}',
      if ((location ?? '').trim().isNotEmpty) 'loc: ${_truncate(location!.trim(), maxChars: 32)}',
      if (memory != null && memory.preferredStyle.trim().isNotEmpty)
        'style: ${_truncate(memory.preferredStyle, maxChars: 40)}',
      if (memory != null && memory.size.trim().isNotEmpty) 'size: ${memory.size.trim()}',
      if (memory != null && memory.lastConversationSummary.trim().isNotEmpty)
        'summary: ${_truncate(memory.lastConversationSummary, maxChars: 90)}',
      if (bodyProfile != null)
        'body: ${bodyProfile.bodyType}, top ${bodyProfile.recommendedSize}, pant ${bodyProfile.pantSize}, ${bodyProfile.heightCm.toStringAsFixed(0)}cm',
      if (primaryMeasurement != null)
        'measure: chest ${primaryMeasurement.chest.toStringAsFixed(0)}, waist ${primaryMeasurement.waist.toStringAsFixed(0)}, shoulder ${primaryMeasurement.shoulder.toStringAsFixed(0)}',
      if (latestOrder != null)
        'order: #${latestOrder.id} ${latestOrder.status} INR ${latestOrder.totalAmount.toStringAsFixed(0)}',
      if (focusedProduct != null)
        'product: ${_truncate(focusedProduct.name, maxChars: 40)}, ${focusedProduct.category}, sizes ${focusedProduct.sizes.take(5).join('/')}',
      'intent: ${intent.name}',
      if (recommendations.isNotEmpty)
        'reco: ${recommendations.take(3).map((item) => '${_truncate(item.product.name, maxChars: 24)} (${item.recommendedSize ?? '-'})').join(', ')}',
      if (history.isNotEmpty) 'recent:\n$history',
      'ask: ${_truncate(cleanedPrompt, maxChars: 160)}',
      'reply in max 2 sentences and mention the best matching pieces briefly.',
    ];
    final promptText = parts.join('\n');
    if (estimateTokens(promptText) <= 220) {
      return promptText;
    }
    return [
      'user: ${userName.trim().isEmpty ? 'ABZORA Member' : _truncate(userName.trim(), maxChars: 24)}',
      if (memory != null && memory.size.trim().isNotEmpty) 'size: ${memory.size.trim()}',
      if (bodyProfile != null) 'body: ${bodyProfile.bodyType}, top ${bodyProfile.recommendedSize}',
      if (focusedProduct != null)
        'product: ${_truncate(focusedProduct.name, maxChars: 36)}, sizes ${focusedProduct.sizes.take(4).join('/')}',
      if (recommendations.isNotEmpty)
        'reco: ${_truncate(recommendations.first.product.name, maxChars: 24)} ${recommendations.first.recommendedSize ?? ''}',
      'ask: ${_truncate(cleanedPrompt, maxChars: 120)}',
      'reply in max 2 sentences.',
    ].join('\n');
  }

  StylistReply _fallbackReply({
    required String userName,
    required String prompt,
    required List<OrderModel> orders,
    required List<MeasurementProfile> measurements,
    List<Product> catalogProducts = const [],
    BodyProfile? bodyProfile,
    UserMemory? memory,
    List<ConversationMemoryMessage> recentHistory = const [],
    String? location,
    Product? focusedProduct,
    required StylistIntent intent,
    required List<StylistProductCard> recommendations,
  }) {
    final text = prompt.trim().toLowerCase();
    final firstName = userName.trim().isEmpty ? 'there' : userName.trim().split(' ').first;
    final month = DateTime.now().month;
    final season = switch (month) {
      3 || 4 || 5 || 6 => 'summer',
      7 || 8 || 9 => 'monsoon',
      10 || 11 => 'festive',
      _ => 'winter',
    };
    final latestOrder = orders.isEmpty ? null : orders.first;
    final primaryMeasurement = measurements.isEmpty ? null : measurements.first;
    final size = bodyProfile?.recommendedSize ?? primaryMeasurement?.recommendedSize ?? 'M';

    if (text.contains('wedding')) {
      return StylistReply(
        text:
            'Here is a sharp wedding direction for you, $firstName: go with a structured silhouette, one rich tone like emerald, wine, or ivory, and a polished fabric finish.',
        quickReplies: const [
          'Show festive colors',
          'Suggest custom outfit',
          'What size should I choose?',
        ],
        lookNotes: const [
          'Structured fits work beautifully for occasion dressing',
          'Jewel tones and warm neutrals feel premium',
          'One standout texture is enough',
        ],
        intent: intent,
        products: recommendations,
      );
    }

    if (text.contains('casual')) {
      return StylistReply(
        text:
            'For a clean casual edit, keep it polished and effortless: breathable fabrics, one strong top layer, and relaxed pieces that still look intentional.',
        quickReplies: const [
          'Suggest summer colors',
          'Build a budget look',
          'Find my size',
        ],
        lookNotes: const [
          'Soft neutrals and washed tones feel easy and premium',
          'Regular fits work best for all-day wear',
          'Keep one focal piece and simplify the rest',
        ],
        intent: intent,
        products: recommendations,
      );
    }

    if (text.contains('summer') || text.contains('color')) {
      return StylistReply(
        text:
            'For $season dressing, I would lean into sand, off-white, sage, dusty blue, and warm gold accents. Those tones feel lighter and more expensive than harsh contrast.',
        quickReplies: const [
          'Suggest wedding look',
          'Custom clothing help',
          'Find my size',
        ],
        lookNotes: const [
          'Warm neutrals are easy to repeat across outfits',
          'Muted color blocking feels premium',
          'Keep dark tones for evening balance',
        ],
        intent: intent,
        products: recommendations,
      );
    }

    if (text.contains('size') || text.contains('fit')) {
      final sizeLine = bodyProfile != null
          ? 'Your saved body profile points to a confident $size top fit and ${bodyProfile.pantSize.isEmpty ? 'a regular trouser fit' : '${bodyProfile.pantSize} trousers'}.'
          : primaryMeasurement != null
              ? 'Your saved measurement profile ${primaryMeasurement.label} points to a confident $size fit.'
              : 'I do not have a saved body profile for you yet, so this is a guided estimate.';
      return StylistReply(
        text:
            '$sizeLine ${focusedProduct != null ? 'For ${focusedProduct.name}, I would start with ${recommendSize(product: focusedProduct, bodyProfile: bodyProfile, measurement: primaryMeasurement, memory: memory)} if that size is available.' : 'Start with $size for tops and adjust only if you prefer a roomier look.'}',
        quickReplies: const [
          'Scan your body',
          'Find my perfect size',
          'Custom clothing help',
        ],
        highlightedSize: size,
        lookNotes: [
          if (bodyProfile != null)
            'Height ${bodyProfile.heightCm.toStringAsFixed(0)} cm | Weight ${bodyProfile.weightKg.toStringAsFixed(0)} kg | ${bodyProfile.bodyType}',
          if (primaryMeasurement != null)
            'Chest ${primaryMeasurement.chest.toStringAsFixed(0)} cm | Waist ${primaryMeasurement.waist.toStringAsFixed(0)} cm',
        ],
        intent: intent,
        products: recommendations,
      );
    }

    if (text.contains('custom') || text.contains('measurement')) {
      return StylistReply(
        text: bodyProfile == null && primaryMeasurement == null
            ? 'Custom clothing will feel much smoother once you save a scan or a body profile. The smartest next step is to scan your body or save a measurement profile first.'
            : 'You already have a saved fit baseline, so custom clothing can start from a much stronger foundation. I would use that profile and adjust only if you want a slimmer or roomier silhouette.',
        quickReplies: const [
          'Scan your body',
          'Suggest custom outfit',
          'What should I wear for a wedding?',
        ],
        lookNotes: const [
          'Regular fits are easiest for first custom orders',
          'Shoulder and chest accuracy matter most for tailored tops',
        ],
        intent: intent,
        products: recommendations,
      );
    }

    if (text.contains('order') && latestOrder != null) {
      return StylistReply(
        text:
            'Your latest order is #${latestOrder.id}, currently ${latestOrder.status.toLowerCase()}. While that is on the way, I can still help you style your next look or choose a safer size.',
        quickReplies: const [
          'Track my order',
          'Find my size',
          'Suggest another outfit',
        ],
        intent: intent,
        products: recommendations,
      );
    }

    final locationLine =
        (location ?? '').trim().isEmpty ? '' : ' Since you are in ${location!.trim()}, I can also tune looks to the weather and local dressing vibe.';
    final productLine =
        recommendations.isNotEmpty ? ' I also pulled a few matching pieces you can browse right away.' : '';
    return StylistReply(
      text:
          'Hi $firstName, I am ABZORA Stylist. I can suggest outfits for occasions, help you choose colors, and guide your size or custom-fit decisions with your saved profile.$locationLine$productLine',
      quickReplies: const [
        'What should I wear for a wedding?',
        'Suggest casual outfits',
        'Best colors for summer',
        'Find my size',
      ],
      lookNotes: const [
        'Ask for occasion-based looks',
        'Ask for fit or size guidance',
        'Ask for custom clothing help',
      ],
      intent: intent,
      products: recommendations,
    );
  }

  String _reasonForRecommendation(
    Product product, {
    required String prompt,
    required String preferredStyle,
  }) {
    final text = _cleanPrompt(prompt);
    if (text.contains('wedding')) {
      return 'Strong pick for occasion styling';
    }
    if (text.contains('casual')) {
      return 'Easy everyday styling option';
    }
    if (preferredStyle.isNotEmpty) {
      return 'Matches your saved style preference';
    }
    if (product.hasDynamicDiscount) {
      return 'Great value right now';
    }
    return 'Popular match for your request';
  }

  List<String> _quickRepliesForPrompt(String prompt) {
    final lowered = prompt.toLowerCase();
    if (lowered.contains('size') || lowered.contains('fit')) {
      return const [
        'Scan your body',
        'Find my perfect size',
        'Custom clothing help',
      ];
    }
    if (lowered.contains('wedding')) {
      return const [
        'Show festive colors',
        'Suggest custom outfit',
        'Find my size',
      ];
    }
    return const [
      'Suggest casual outfits',
      'Best colors for summer',
      'Find my size',
    ];
  }

  String styleSummaryForProduct(Product product, MeasurementProfile? measurement) {
    final category = product.category.isEmpty ? 'piece' : product.category;
    final sizeNote = measurement?.recommendedSize != null
        ? 'Your saved profile leans toward ${measurement!.recommendedSize} for similar silhouettes.'
        : 'Scan or save a measurement profile to get a tighter recommendation.';
    return '${product.name} feels strongest as a $category-led statement piece. $sizeNote';
  }

  String formatRecentOrderLabel(OrderModel order) {
    return '#${order.id} | ${DateFormat('dd MMM').format(order.timestamp)} | INR ${order.totalAmount.toStringAsFixed(0)}';
  }
}
