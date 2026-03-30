import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../theme.dart';
import '../../widgets/tap_scale.dart';
import 'chat_screen.dart';
import 'faq_screen.dart';
import 'voice_assistant_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final DatabaseService _database = DatabaseService();
  bool _creatingChat = false;

  Future<void> _openVoiceAssistant(AppUser actor) async {
    if (_creatingChat) {
      return;
    }
    setState(() => _creatingChat = true);
    try {
      final chat = await _database.createSupportChat(
        actor: actor,
        issueType: 'general',
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              VoiceAssistantScreen(chat: chat),
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) {
            final slide = Tween<Offset>(
              begin: const Offset(0, 0.03),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
            );
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: slide, child: child),
            );
          },
          transitionDuration: const Duration(milliseconds: 260),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _creatingChat = false);
      }
    }
  }

  Future<void> _showStartChatSheet(AppUser actor) async {
    final options = <(String type, IconData icon, String title, String subtitle)>[
      (
        'order',
        Icons.receipt_long_rounded,
        'Order Issue',
        'Help with delivery, return, or order updates',
      ),
      (
        'payment',
        Icons.payments_outlined,
        'Payment Issue',
        'Payment failures, refunds, or charged twice',
      ),
      (
        'custom',
        Icons.design_services_rounded,
        'Custom Clothing Help',
        'Measurements, fittings, and tailoring guidance',
      ),
      (
        'general',
        Icons.auto_awesome_rounded,
        'General Help',
        'Instant answers from ABZORA Assistant',
      ),
    ];

    final selectedType = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.abzioBorder,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Talk to ABZORA AI',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose what you need help with and ABZORA Assistant will open the right conversation instantly.',
                  style: TextStyle(
                    color: context.abzioSecondaryText,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                ...options.map((option) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TapScale(
                      onTap: () => Navigator.pop(sheetContext, option.$1),
                      scale: 0.97,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(sheetContext, option.$1),
                          borderRadius: BorderRadius.circular(18),
                          child: Ink(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFCF4),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: AbzioTheme.accentColor.withValues(
                                  alpha: 0.16,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    option.$2,
                                    color: AbzioTheme.accentColor,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        option.$3,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        option.$4,
                                        style: TextStyle(
                                          color: context.abzioSecondaryText,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 15,
                                  color: AbzioTheme.accentColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );

    if (selectedType == null || _creatingChat) {
      return;
    }

    setState(() => _creatingChat = true);
    try {
      final chat = await _database.createSupportChat(
        actor: actor,
        issueType: selectedType,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              ChatScreen(chat: chat),
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) {
            final slide = Tween<Offset>(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
            );
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: slide, child: child),
            );
          },
          transitionDuration: const Duration(milliseconds: 260),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _creatingChat = false);
      }
    }
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
        title: const Text('AI Assistant'),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FaqScreen()),
            ),
            icon: const Icon(Icons.help_outline_rounded),
          ),
        ],
      ),
      body: StreamBuilder<List<SupportChat>>(
        stream: _database.watchSupportChatsForUser(actor: actor),
        builder: (context, snapshot) {
          final chats = snapshot.data ?? const <SupportChat>[];
          final unreadCount = chats.fold<int>(
            0,
            (sum, chat) => sum + chat.unreadCountUser,
          );
          final waitingCount =
              chats.where((chat) => chat.status == 'waiting').length;
          final openCount =
              chats.where((chat) => chat.status != 'closed').length;

          if (snapshot.connectionState == ConnectionState.waiting &&
              chats.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4D4),
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: AbzioTheme.accentColor,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'ABZORA Assistant is still available',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We could not load your previous chats right now, but you can still start a fresh conversation.',
                      style: TextStyle(
                        color: context.abzioSecondaryText,
                        height: 1.45,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: TapScale(
                        onTap: _creatingChat ? null : () => _showStartChatSheet(actor),
                        scale: 0.97,
                        child: ElevatedButton(
                          onPressed: _creatingChat ? null : () => _showStartChatSheet(actor),
                          child: Text(_creatingChat ? 'Starting...' : 'Start New Chat'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FaqScreen()),
                      ),
                      child: const Text('Browse FAQs'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (chats.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4D4),
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: AbzioTheme.accentColor.withValues(
                              alpha: 0.14,
                            ),
                            blurRadius: 22,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: AbzioTheme.accentColor,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Need help? ABZORA Assistant is ready',
                      style:
                          Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Get instant help for orders, payments, and custom styles anytime.',
                      style: TextStyle(
                        color: context.abzioSecondaryText,
                        height: 1.45,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: TapScale(
                        onTap:
                            _creatingChat ? null : () => _showStartChatSheet(actor),
                        scale: 0.97,
                        child: ElevatedButton(
                          onPressed: _creatingChat
                              ? null
                              : () => _showStartChatSheet(actor),
                          child: Text(
                            _creatingChat ? 'Starting...' : 'Start AI Assistant',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: TapScale(
                        onTap:
                            _creatingChat ? null : () => _openVoiceAssistant(actor),
                        scale: 0.97,
                        child: OutlinedButton.icon(
                          onPressed:
                              _creatingChat ? null : () => _openVoiceAssistant(actor),
                          icon: const Icon(Icons.mic_none_rounded),
                          label: const Text('Talk to ABZORA AI'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FaqScreen()),
                      ),
                      child: const Text('Browse FAQs'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              if (unreadCount > 0 || waitingCount > 0 || openCount > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (unreadCount > 0)
                        _SummaryChip(
                          icon: Icons.mark_chat_unread_rounded,
                          label:
                              '$unreadCount unread repl${unreadCount == 1 ? 'y' : 'ies'}',
                          tone: AbzioTheme.accentColor,
                        ),
                      if (waitingCount > 0)
                        _SummaryChip(
                          icon: Icons.hourglass_top_rounded,
                          label: '$waitingCount needs follow-up',
                          tone: const Color(0xFFD97706),
                        ),
                      if (openCount > 0)
                        _SummaryChip(
                          icon: Icons.support_agent_rounded,
                          label:
                              '$openCount active assistant thread${openCount == 1 ? '' : 's'}',
                          tone: const Color(0xFF15803D),
                        ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Open conversations',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _showStartChatSheet(actor),
                      icon: const Icon(Icons.add_comment_outlined),
                      label: const Text('Start AI Assistant'),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Talk to ABZORA AI',
                      onPressed: _creatingChat ? null : () => _openVoiceAssistant(actor),
                      icon: const Icon(Icons.mic_none_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: chats.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final chat = chats[index];
                    final unread = chat.unreadCountUser;
                    final timestamp = DateTime.tryParse(
                      chat.lastMessageAt.isEmpty
                          ? chat.updatedAt
                          : chat.lastMessageAt,
                    );

                    return TapScale(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(chat: chat),
                        ),
                      ),
                      scale: 0.98,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(chat: chat),
                            ),
                          ),
                          borderRadius: BorderRadius.circular(22),
                          child: Ink(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: unread > 0
                                    ? AbzioTheme.accentColor.withValues(
                                        alpha: 0.20,
                                      )
                                    : context.abzioBorder.withValues(
                                        alpha: 0.75,
                                      ),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 16,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF5DA),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Icon(
                                    _iconForType(chat.type),
                                    color: AbzioTheme.accentColor,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'ABZORA Assistant ✨',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          if (unread > 0)
                                            Container(
                                              margin: const EdgeInsets.only(
                                                right: 8,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 5,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                  0xFFFFF3CB,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                '$unread new',
                                                style: const TextStyle(
                                                  color:
                                                      AbzioTheme.accentColor,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          if (timestamp != null)
                                            Text(
                                              DateFormat('dd MMM')
                                                  .format(timestamp),
                                              style: TextStyle(
                                                color:
                                                    context.abzioSecondaryText,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          _statusDot(chat.status),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF7F5EF),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              _titleForType(chat.type),
                                              style: TextStyle(
                                                color:
                                                    context.abzioSecondaryText,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        chat.lastMessage.isEmpty
                                            ? 'Assistant thread created. Send a message to continue.'
                                            : chat.lastMessage,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: unread > 0
                                              ? Colors.black.withValues(
                                                  alpha: 0.82,
                                                )
                                              : context.abzioSecondaryText,
                                          fontWeight: unread > 0
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (unread > 0) ...[
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AbzioTheme.accentColor,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      unread.toString(),
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'order':
        return Icons.receipt_long_rounded;
      case 'payment':
        return Icons.payments_outlined;
      case 'custom':
        return Icons.design_services_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  String _titleForType(String type) {
    switch (type) {
      case 'order':
        return 'Order Issue';
      case 'payment':
        return 'Payment Issue';
      case 'custom':
        return 'Custom Clothing Help';
      default:
        return 'General Help';
    }
  }

  Widget _statusDot(String status) {
    Color color;
    switch (status) {
      case 'waiting':
        color = const Color(0xFFE2A300);
        break;
      case 'closed':
        color = const Color(0xFF8A8A8A);
        break;
      default:
        color = const Color(0xFF1F9D55);
        break;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          status[0].toUpperCase() + status.substring(1),
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.tone,
  });

  final IconData icon;
  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: tone),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: tone,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
