import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../theme.dart';
import '../../widgets/tap_scale.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.chat,
  });

  final SupportChat chat;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final DatabaseService _database = DatabaseService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  List<SupportMessage> _olderMessages = const [];
  bool _loadingOlder = false;
  bool _sending = false;
  bool _markedRead = false;
  bool _speechEnabled = false;
  bool _isListening = false;
  bool _isVoiceProcessing = false;
  String _recognizedSpeech = '';
  String? _lastSpokenAssistantMessageId;
  String? _lastFailedMessage;
  String? _lastSendError;

  @override
  void initState() {
    super.initState();
    unawaited(_initVoice());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markReadOnce();
    });
  }

  @override
  void dispose() {
    unawaited(_speech.cancel());
    unawaited(_tts.stop());
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initVoice() async {
    try {
      final available = await _speech.initialize(
        onStatus: _handleSpeechStatus,
        onError: _handleSpeechError,
      );
      await _tts.setLanguage('en-IN');
      await _tts.setSpeechRate(0.46);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      if (!mounted) {
        return;
      }
      setState(() {
        _speechEnabled = available;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _speechEnabled = false;
      });
    }
  }

  void _handleSpeechStatus(String status) {
    if (!mounted) {
      return;
    }
    if (status == 'done' || status == 'notListening') {
      setState(() {
        _isListening = false;
      });
      final recognized = _recognizedSpeech.trim();
      if (recognized.isNotEmpty && !_sending && !_isVoiceProcessing) {
        setState(() {
          _isVoiceProcessing = true;
        });
        unawaited(_sendMessage());
      }
    }
  }

  void _handleSpeechError(dynamic error) {
    if (!mounted) {
      return;
    }
    setState(() {
      _isListening = false;
      _isVoiceProcessing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Couldn’t understand, please try again'),
      ),
    );
  }

  Future<void> _markReadOnce() async {
    if (_markedRead) {
      return;
    }
    final actor = context.read<AuthProvider>().user;
    if (actor == null) {
      return;
    }
    _markedRead = true;
    await _database.markSupportChatRead(
      chatId: widget.chat.id,
      actor: actor,
    );
  }

  Future<void> _sendMessage() async {
    final actor = context.read<AuthProvider>().user;
    final text = _messageController.text.trim();
    if (actor == null || text.isEmpty || _sending) {
      return;
    }

    setState(() => _sending = true);
    try {
      await _database.sendSupportMessage(
        chatId: widget.chat.id,
        text: text,
        actor: actor,
      );
      _messageController.clear();
      _recognizedSpeech = '';
      _lastFailedMessage = null;
      _lastSendError = null;
      if (!mounted) {
        return;
      }
      _scrollToBottom(animated: true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _lastFailedMessage = text;
        _lastSendError = error.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(error.toString()),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _isVoiceProcessing = false;
        });
      }
    }
  }

  Future<void> _retryLastFailedMessage() async {
    final failed = _lastFailedMessage?.trim() ?? '';
    if (failed.isEmpty || _sending) {
      return;
    }
    _messageController.value = TextEditingValue(
      text: failed,
      selection: TextSelection.collapsed(offset: failed.length),
    );
    await _sendMessage();
  }

  Future<void> _toggleVoiceInput() async {
    final isClosed = widget.chat.status == 'closed';
    if (isClosed || _sending || _isVoiceProcessing) {
      return;
    }
    if (_isListening) {
      await _speech.stop();
      if (!mounted) {
        return;
      }
      setState(() {
        _isListening = false;
        _isVoiceProcessing = false;
      });
      return;
    }
    if (!_speechEnabled) {
      await _initVoice();
      if (!_speechEnabled || !mounted) {
        return;
      }
    }
    await _tts.stop();
    setState(() {
      _recognizedSpeech = '';
      _isListening = true;
      _isVoiceProcessing = false;
    });
    await _speech.listen(
      localeId: 'en_IN',
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.confirmation,
        partialResults: true,
      ),
      onResult: (result) {
        if (!mounted) {
          return;
        }
        final words = result.recognizedWords.trim();
        setState(() {
          _recognizedSpeech = words;
          _messageController.value = TextEditingValue(
            text: words,
            selection: TextSelection.collapsed(offset: words.length),
          );
        });
      },
    );
  }

  Future<void> _speakAssistantReply(SupportMessage message) async {
    if (message.id == _lastSpokenAssistantMessageId ||
        message.senderRole != 'assistant' ||
        message.text.trim().isEmpty) {
      return;
    }
    _lastSpokenAssistantMessageId = message.id;
    try {
      await _tts.stop();
      await _tts.speak(message.text.trim());
    } catch (_) {
      // Keep voice as a non-blocking enhancement.
    }
  }

  Future<void> _loadOlderMessages(List<SupportMessage> currentMessages) async {
    final actor = context.read<AuthProvider>().user;
    if (actor == null || _loadingOlder) {
      return;
    }
    final timeline = [..._olderMessages, ...currentMessages];
    if (timeline.isEmpty) {
      return;
    }

    setState(() => _loadingOlder = true);
    try {
      final older = await _database.getOlderSupportMessages(
        chatId: widget.chat.id,
        actor: actor,
        beforeTimestamp: timeline.first.timestamp,
      );
      if (!mounted || older.isEmpty) {
        return;
      }
      setState(() {
        _olderMessages = [...older, ..._olderMessages];
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
    } finally {
      if (mounted) {
        setState(() => _loadingOlder = false);
      }
    }
  }

  void _scrollToBottom({bool animated = false}) {
    if (!_scrollController.hasClients) {
      return;
    }
    final target = _scrollController.position.maxScrollExtent;
    if (animated) {
      unawaited(
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        ),
      );
      return;
    }
    _scrollController.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    final actor = context.watch<AuthProvider>().user;
    if (actor == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFFDFC),
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ABZORA Assistant ✨'),
            Text(
              _subtitleForChat(widget.chat),
              style: TextStyle(
                fontSize: 12,
                color: context.abzioSecondaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildStatusBanner(context),
            if (_lastFailedMessage != null && _lastFailedMessage!.trim().isNotEmpty)
              _buildRetryBanner(context),
            _buildQuickPrompts(),
            Expanded(
              child: StreamBuilder<List<SupportMessage>>(
                stream: _database.watchSupportMessages(
                  chatId: widget.chat.id,
                  actor: actor,
                ),
                builder: (context, snapshot) {
                  final liveMessages = snapshot.data ?? const <SupportMessage>[];
                  final messages = [..._olderMessages, ...liveMessages]
                    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
                  final latestAssistantMessage = messages.isEmpty
                      ? null
                      : messages.lastWhere(
                          (message) => message.senderRole == 'assistant',
                          orElse: () => const SupportMessage(
                            id: '',
                            senderId: '',
                            senderRole: '',
                            timestamp: '',
                          ),
                        );

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToBottom();
                    _markReadOnce();
                    if (latestAssistantMessage != null &&
                        latestAssistantMessage.id.isNotEmpty) {
                      unawaited(_speakAssistantReply(latestAssistantMessage));
                    }
                  });

                  if (snapshot.connectionState == ConnectionState.waiting &&
                      messages.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (messages.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  return CustomScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: Center(
                            child: TapScale(
                              onTap: _loadingOlder
                                  ? null
                                  : () => _loadOlderMessages(liveMessages),
                              scale: 0.98,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: context.abzioBorder.withValues(alpha: 0.65),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_loadingOlder)
                                      const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    else
                                      const Icon(
                                        Icons.keyboard_arrow_up_rounded,
                                        size: 18,
                                        color: AbzioTheme.accentColor,
                                      ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _loadingOlder ? 'Loading earlier messages' : 'Load older messages',
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final message = messages[index];
                              final isMine = message.senderId == actor.id;
                              final showDate = index == 0 ||
                                  !_isSameDay(
                                    messages[index - 1].timestamp,
                                    message.timestamp,
                                  );

                              return Column(
                                children: [
                                  if (showDate) _buildDateChip(message.timestamp),
                                  _MessageBubble(
                                    message: message,
                                    isMine: isMine,
                                  ),
                                ],
                              );
                            },
                            childCount: messages.length,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            _buildComposer(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner(BuildContext context) {
    final color = switch (widget.chat.status) {
      'closed' => const Color(0xFF6B7280),
      'waiting' => const Color(0xFFD97706),
      _ => const Color(0xFF15803D),
    };

    final text = switch (widget.chat.status) {
      'closed' => 'This ticket has been marked as resolved.',
      'waiting' => 'ABZORA Assistant is preparing the next best answer for you.',
      _ => 'ABZORA Assistant is active on this thread.',
    };

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetryBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0D48A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.refresh_rounded, color: Color(0xFFD97706)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _lastSendError?.trim().isNotEmpty == true
                  ? _lastSendError!.trim()
                  : 'Message failed to send. You can retry safely.',
              style: const TextStyle(
                color: Color(0xFF8A5A00),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: _retryLastFailedMessage,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5DA),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AbzioTheme.accentColor,
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Ask anything about your order or fit',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'ABZORA Assistant can track orders, explain payments, and guide your custom clothing journey in real time.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.abzioSecondaryText,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateChip(String timestamp) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFECE7DB)),
          ),
          child: Text(
            _formatDayLabel(timestamp),
            style: TextStyle(
              fontSize: 12,
              color: context.abzioSecondaryText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickPrompts() {
    final prompts = const [
      'Track my order',
      'Cancel my order',
      'Payment issue',
      'Custom clothing help',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: prompts.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final prompt = prompts[index];
            return TapScale(
              onTap: () {
                _messageController.text = prompt;
                _sendMessage();
              },
              scale: 0.97,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AbzioTheme.accentColor.withValues(alpha: 0.18),
                  ),
                ),
                child: Text(
                  prompt,
                  style: TextStyle(
                    color: context.abzioSecondaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildComposer(BuildContext context) {
    final isClosed = widget.chat.status == 'closed';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).viewInsets.bottom + 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: context.abzioBorder.withValues(alpha: 0.72)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 18,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFFCF7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isClosed
                      ? context.abzioBorder
                      : AbzioTheme.accentColor.withValues(alpha: 0.18),
                ),
              ),
              child: TextField(
                controller: _messageController,
                enabled: !isClosed && !_sending,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 4,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: isClosed ? 'This assistant thread is closed' : 'Ask ABZORA Assistant anything',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          TapScale(
            onTap: isClosed ? null : _toggleVoiceInput,
            scale: 0.96,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _isListening
                    ? const Color(0xFFFFF2C4)
                    : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _isListening
                      ? AbzioTheme.accentColor
                      : context.abzioBorder.withValues(alpha: 0.8),
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_isListening
                            ? AbzioTheme.accentColor
                            : Colors.black)
                        .withValues(alpha: _isListening ? 0.18 : 0.04),
                    blurRadius: _isListening ? 18 : 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: _isVoiceProcessing
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AbzioTheme.accentColor,
                        ),
                      ),
                    )
                  : Icon(
                      _isListening ? Icons.graphic_eq_rounded : Icons.mic_none_rounded,
                      color: _isListening
                          ? AbzioTheme.accentColor
                          : context.abzioSecondaryText,
                    ),
            ),
          ),
          const SizedBox(width: 10),
          TapScale(
            onTap: isClosed || _sending ? null : _sendMessage,
            scale: 0.96,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 140),
              opacity: isClosed ? 0.55 : 1,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFE0BE54),
                      AbzioTheme.accentColor,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AbzioTheme.accentColor.withValues(alpha: 0.24),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: _sending
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _subtitleForChat(SupportChat chat) {
    final typeLabel = chat.type.replaceAll('_', ' ');
    return '${toBeginningOfSentenceCase(typeLabel)} · ${toBeginningOfSentenceCase(chat.status)}';
  }

  String _formatDayLabel(String timestamp) {
    final parsed = DateTime.tryParse(timestamp);
    if (parsed == null) {
      return 'Today';
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(parsed.year, parsed.month, parsed.day);
    final difference = today.difference(date).inDays;
    if (difference == 0) {
      return 'Today';
    }
    if (difference == 1) {
      return 'Yesterday';
    }
    return DateFormat('dd MMM yyyy').format(parsed);
  }

  bool _isSameDay(String first, String second) {
    final a = DateTime.tryParse(first);
    final b = DateTime.tryParse(second);
    if (a == null || b == null) {
      return false;
    }
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
  });

  final SupportMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final alignment = isMine ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor = isMine ? const Color(0xFFFFF1C2) : Colors.white;
    final borderColor = isMine
        ? AbzioTheme.accentColor.withValues(alpha: 0.22)
        : context.abzioBorder.withValues(alpha: 0.76);

    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMine ? 18 : 6),
                bottomRight: Radius.circular(isMine ? 6 : 18),
              ),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (message.text.trim().isNotEmpty)
                  Text(
                    message.text,
                    style: const TextStyle(
                      fontSize: 14.5,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (message.imageUrl.trim().isNotEmpty) ...[
                  if (message.text.trim().isNotEmpty) const SizedBox(height: 10),
                  Container(
                    width: 180,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.image_outlined,
                          size: 18,
                          color: AbzioTheme.accentColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Attachment shared',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.abzioSecondaryText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: context.abzioSecondaryText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return '';
    }
    return DateFormat('hh:mm a').format(parsed);
  }
}
