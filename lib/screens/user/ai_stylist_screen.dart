import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/ai_stylist_service.dart';
import '../../services/database_service.dart';
import '../../theme.dart';
import '../../widgets/tap_scale.dart';
import 'ai_stylist_quick_checkout_screen.dart';
import 'product_detail_screen.dart';

class AiStylistScreen extends StatefulWidget {
  const AiStylistScreen({
    super.key,
    this.product,
    this.initialPrompt,
  });

  final Product? product;
  final String? initialPrompt;

  @override
  State<AiStylistScreen> createState() => _AiStylistScreenState();
}

class _AiStylistScreenState extends State<AiStylistScreen> {
  final DatabaseService _database = DatabaseService();
  final AiStylistService _stylist = const AiStylistService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<OrderModel> _orders = const [];
  List<MeasurementProfile> _measurements = const [];
  List<Product> _catalogProducts = const [];
  BodyProfile? _bodyProfile;
  UserMemory? _userMemory;
  List<ConversationMemoryMessage> _recentHistory = const [];
  final List<_StylistMessage> _messages = [];
  bool _isLoadingContext = true;
  bool _isReplying = false;
  bool _contextLoadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadContext() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    var loadFailed = false;
    try {
      if (user != null) {
        final results = await Future.wait<Object?>([
          _database.getUserOrdersOnce(user.id).catchError((error) {
            debugPrint('Stylist orders fallback for ${user.id}: $error');
            return const <OrderModel>[];
          }),
          _database.getMeasurementProfiles(user.id).catchError((error) {
            debugPrint('Stylist measurements fallback for ${user.id}: $error');
            return const <MeasurementProfile>[];
          }),
          _database.getStylistCatalog().catchError((error) {
            debugPrint('Stylist catalog fallback: $error');
            return const <Product>[];
          }),
          _database.getBodyProfile(user.id).catchError((error) {
            debugPrint('Stylist body profile fallback for ${user.id}: $error');
            return null;
          }),
          _database.getUserMemory(user.id).catchError((error) {
            debugPrint('Stylist memory fallback for ${user.id}: $error');
            return null;
          }),
          _database.getChatHistory(user.id, 'stylist').catchError((error) {
            debugPrint('Stylist history fallback for ${user.id}: $error');
            return const <ConversationMemoryMessage>[];
          }),
        ]);
        _orders = results[0] as List<OrderModel>;
        _measurements = results[1] as List<MeasurementProfile>;
        _catalogProducts = results[2] as List<Product>;
        _bodyProfile = results[3] as BodyProfile?;
        _userMemory = results[4] as UserMemory?;
        _recentHistory = results[5] as List<ConversationMemoryMessage>;
      }
    } catch (error) {
      debugPrint('Stylist context failed: $error');
      loadFailed = true;
      _orders = const [];
      _measurements = const [];
      _catalogProducts = const [];
      _bodyProfile = null;
      _userMemory = null;
      _recentHistory = const [];
    }

    final firstName = _firstName(user?.name);
    final opener = widget.product != null
        ? 'Hi $firstName, I am ABZORA Stylist ✨. I can help you style ${widget.product!.name}, suggest colors, and guide the best fit for this piece.'
        : 'Hi $firstName, I am ABZORA Stylist ✨. Ask me what to wear, which colors fit the season, or what size should feel best for you.';

    if (!mounted) {
      return;
    }
    setState(() {
      _messages
        ..clear()
        ..add(
          _StylistMessage.assistant(
            text: opener,
            quickReplies: _initialQuickReplies(),
          ),
        );
      _isLoadingContext = false;
      _contextLoadFailed = loadFailed;
    });

    final initialPrompt = widget.initialPrompt?.trim();
    if (initialPrompt != null && initialPrompt.isNotEmpty) {
      _sendPrompt(initialPrompt);
    }
  }

  List<String> _initialQuickReplies() {
    return widget.product == null
        ? const [
            'What should I wear for a wedding?',
            'Suggest casual outfits',
            'Best colors for summer',
            'Find my size',
          ]
        : const [
            'Find my size',
            'How should I style this?',
            'Will this work for a wedding?',
            'Suggest matching colors',
          ];
  }

  Future<void> _sendPrompt(String prompt) async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (_isReplying || prompt.trim().isEmpty) {
      return;
    }

    setState(() {
      _messages.add(_StylistMessage.user(text: prompt.trim()));
      _isReplying = true;
    });
    _messageController.clear();
    _scrollToBottom();

    try {
      final reply = await _stylist.respond(
        userName: user?.name ?? 'ABZORA Member',
        prompt: prompt,
        orders: _orders,
        measurements: _measurements,
        catalogProducts: _catalogProducts,
        bodyProfile: _bodyProfile,
        memory: _userMemory,
        recentHistory: _recentHistory,
        location: user?.city ?? user?.address,
        focusedProduct: widget.product,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(
          _StylistMessage.assistant(
            text: reply.text,
            quickReplies: reply.quickReplies,
            notes: reply.lookNotes,
            highlightedSize: reply.highlightedSize,
            products: reply.products,
          ),
        );
        _isReplying = false;
      });
      if (user != null) {
        await _database.saveAiStylistConversationTurn(
          actor: user,
          userMessage: prompt.trim(),
          assistantReply: reply.text,
        );
        _userMemory = await _database.getUserMemory(user.id).catchError((_) => null);
        _recentHistory = await _database
            .getChatHistory(user.id, 'stylist')
            .catchError((_) => const <ConversationMemoryMessage>[]);
      }
    } catch (error) {
      debugPrint('Stylist reply failed: $error');
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(
          _StylistMessage.assistant(
            text: 'I am having trouble right now, but I can still help with basic styling, size guidance, and product suggestions.',
            quickReplies: _initialQuickReplies(),
          ),
        );
        _isReplying = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 180,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  String _firstName(String? name) {
    final trimmed = (name ?? '').trim();
    if (trimmed.isEmpty) {
      return 'there';
    }
    return trimmed.split(' ').first;
  }

  @override
  Widget build(BuildContext context) {
    return AbzioThemeScope.light(
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFDFC),
        appBar: AppBar(
          title: const Text('ABZORA Stylist ✨'),
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (widget.product != null) _productContextStrip(widget.product!),
              if (_contextLoadFailed)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: context.abzioBorder.withValues(alpha: 0.7)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: AbzioTheme.accentColor,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Some profile context could not be loaded, so the stylist is using a lighter fallback mode right now.',
                          style: TextStyle(
                            color: context.abzioSecondaryText,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: _isLoadingContext
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                        itemCount: _messages.length + (_isReplying ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (_isReplying && index == _messages.length) {
                            return _typingBubble();
                          }
                          final message = _messages[index];
                          return _messageBubble(message);
                        },
                      ),
              ),
              _composer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _productContextStrip(Product product) {
    final measurement = _measurements.isEmpty ? null : _measurements.first;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.abzioBorder.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            product.name,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            _stylist.styleSummaryForProduct(product, measurement),
            style: TextStyle(color: context.abzioSecondaryText, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _messageBubble(_StylistMessage message) {
    final isUser = message.role == _StylistRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isUser ? const Color(0xFFFFF1C9) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isUser
                    ? AbzioTheme.accentColor.withValues(alpha: 0.25)
                    : context.abzioBorder.withValues(alpha: 0.7),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isUser)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'ABZORA Stylist ✨',
                      style: TextStyle(
                        color: AbzioTheme.accentColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                Text(
                  message.text,
                  style: const TextStyle(height: 1.5),
                ),
                if (message.highlightedSize != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7DE),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Suggested size: ${message.highlightedSize}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
                if (message.notes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ...message.notes.map(
                    (note) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 3),
                            child: Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: AbzioTheme.accentColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(child: Text(note)),
                        ],
                      ),
                    ),
                  ),
                ],
                if (message.quickReplies.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: message.quickReplies
                        .map(
                          (reply) => ActionChip(
                            label: Text(reply),
                            onPressed: () => _sendPrompt(reply),
                          ),
                        )
                        .toList(),
                  ),
                ],
                if (message.products.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 214,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: message.products.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 10),
                      itemBuilder: (context, index) => _productCard(message.products[index]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _productCard(StylistProductCard card) {
    final product = card.product;
    final imageUrl = product.images.isNotEmpty ? product.images.first : '';
    return TapScale(
      onTap: () => _openProductDetails(card),
      child: Container(
        width: 168,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.abzioBorder.withValues(alpha: 0.7)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: const Color(0xFFF6F6F6),
                child: imageUrl.isEmpty
                    ? const Icon(Icons.checkroom_rounded, color: AbzioTheme.accentColor, size: 34)
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.checkroom_rounded,
                          color: AbzioTheme.accentColor,
                          size: 34,
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rs ${product.effectivePrice.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AbzioTheme.accentColor,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    card.reason,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.abzioSecondaryText),
                  ),
                  if ((card.recommendedSize ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7DE),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Best size: ${card.recommendedSize}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _openProductDetails(card),
                          child: const Text('View Details'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _buyFromStylist(card),
                          child: const Text('Buy Now'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openProductDetails(StylistProductCard card) async {
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      await _database.recordProductView(card.product, user: user);
      await _database.trackAiStylistConversion(
        user: user,
        product: card.product,
        eventType: 'product_viewed',
        recommendedSize: card.recommendedSize,
      );
    }
    if (!mounted) {
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductDetailScreen(product: card.product)),
    );
  }

  Future<void> _buyFromStylist(StylistProductCard card) async {
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to buy from the stylist.')),
      );
      return;
    }
    final size = (card.recommendedSize ?? '').trim().isEmpty
        ? (card.product.sizes.isNotEmpty ? card.product.sizes.first : 'M')
        : card.recommendedSize!.trim();
    await _database.trackAiStylistConversion(
      user: user,
      product: card.product,
      eventType: 'buy_started',
      recommendedSize: size,
    );
    if (!mounted) {
      return;
    }
    final placedOrder = await Navigator.push<OrderModel>(
      context,
      MaterialPageRoute(
        builder: (_) => AiStylistQuickCheckoutScreen(
          product: card.product,
          recommendedSize: size,
        ),
      ),
    );
    if (placedOrder == null || !mounted) {
      return;
    }
    setState(() {
      _messages.add(
        _StylistMessage.assistant(
          text: 'Your order has been placed successfully. Order #${placedOrder.id} is now confirmed for ${card.product.name}.',
          quickReplies: const [
            'Track my order',
            'Suggest another outfit',
            'Find matching products',
          ],
        ),
      );
    });
    _scrollToBottom();
    await _database.saveAiStylistConversationTurn(
      actor: user,
      userMessage: 'Buy ${card.product.name}',
      assistantReply: 'Your order has been placed successfully for ${card.product.name}.',
    );
  }

  Widget _typingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.abzioBorder.withValues(alpha: 0.7)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Thinking through your look...'),
          ],
        ),
      ),
    );
  }

  Widget _composer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: context.abzioBorder.withValues(alpha: 0.65)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                textInputAction: TextInputAction.send,
                minLines: 1,
                maxLines: 4,
                onSubmitted: _sendPrompt,
                decoration: const InputDecoration(
                  hintText: 'Ask about outfits, colors, fit, or custom clothing',
                ),
              ),
            ),
            const SizedBox(width: 10),
            TapScale(
              onTap: _isReplying
                  ? null
                  : () => _sendPrompt(_messageController.text),
              child: ElevatedButton(
                onPressed: _isReplying
                    ? null
                    : () => _sendPrompt(_messageController.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AbzioTheme.accentColor,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(56, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Icon(Icons.arrow_upward_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _StylistRole { user, assistant }

class _StylistMessage {
  const _StylistMessage({
    required this.role,
    required this.text,
    this.quickReplies = const [],
    this.notes = const [],
    this.highlightedSize,
    this.products = const [],
  });

  final _StylistRole role;
  final String text;
  final List<String> quickReplies;
  final List<String> notes;
  final String? highlightedSize;
  final List<StylistProductCard> products;

  factory _StylistMessage.user({required String text}) {
    return _StylistMessage(role: _StylistRole.user, text: text);
  }

  factory _StylistMessage.assistant({
    required String text,
    List<String> quickReplies = const [],
    List<String> notes = const [],
    String? highlightedSize,
    List<StylistProductCard> products = const [],
  }) {
    return _StylistMessage(
      role: _StylistRole.assistant,
      text: text,
      quickReplies: quickReplies,
      notes: notes,
      highlightedSize: highlightedSize,
      products: products,
    );
  }
}
