import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../theme.dart';
import '../../widgets/state_views.dart';

class ChatDetailScreen extends StatefulWidget {
  final String chatId;
  final String otherUserName;

  const ChatDetailScreen({super.key, required this.chatId, required this.otherUserName});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _messageController = TextEditingController();
  final _chatService = ChatService();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();

    return AbzioThemeScope.dark(
      child: Scaffold(
        backgroundColor: AbzioTheme.darkBackground,
        appBar: AppBar(
          title: Column(
            children: [
              Text(
                widget.otherUserName.toUpperCase(),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: AbzioTheme.textPrimary,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'ONLINE',
                    style: GoogleFonts.poppins(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: AbzioTheme.grey500,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.more_vert_rounded),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    behavior: SnackBarBehavior.floating,
                    content: Text('More conversation tools for ${widget.otherUserName} are on the way.'),
                  ),
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<Message>>(
                stream: _chatService.getMessages(widget.chatId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const AbzioLoadingView(
                      title: 'Loading conversation',
                      subtitle: 'Preparing your latest messages.',
                    );
                  }
                  final messages = snapshot.data!;
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg.senderId == auth.user?.id;
                      return _buildMessageBubble(msg, isMe);
                    },
                  );
                },
              ),
            ),
            _buildInputBar(auth),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Message msg, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              color: isMe ? AbzioTheme.accentColor : AbzioTheme.darkMuted,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isMe ? 20 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 20),
              ),
              border: Border.all(
                color: isMe ? AbzioTheme.accentColor : AbzioTheme.grey100,
              ),
            ),
            child: Text(
              msg.text,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: isMe ? Colors.black : AbzioTheme.textPrimary,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
          Text(
            DateFormat('hh:mm a').format(msg.timestamp),
            style: GoogleFonts.inter(
              fontSize: 9,
              color: AbzioTheme.grey500,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildInputBar(AuthProvider auth) {
    final width = MediaQuery.of(context).size.width;
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 16),
        decoration: BoxDecoration(
          color: AbzioTheme.darkCard,
          border: Border(top: BorderSide(color: context.abzioBorder, width: 1)),
        ),
        child: width < 360
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _messageField(),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _sendButton(auth),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(child: _messageField()),
                  const SizedBox(width: 12),
                  _sendButton(auth),
                ],
              ),
      ),
    );
  }

  Widget _messageField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AbzioTheme.darkMuted,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: context.abzioBorder),
      ),
      child: TextField(
        controller: _messageController,
        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AbzioTheme.textPrimary),
        decoration: InputDecoration(
          hintText: 'Message...',
          hintStyle: GoogleFonts.inter(color: AbzioTheme.grey500, fontWeight: FontWeight.w500),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _sendButton(AuthProvider auth) {
    return GestureDetector(
      onTap: () {
        if (_messageController.text.isNotEmpty && auth.user != null) {
          _chatService.sendMessage(
            widget.chatId,
            Message(
              senderId: auth.user!.id,
              text: _messageController.text,
              timestamp: DateTime.now(),
            ),
          );
          _messageController.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text('Message sent.'),
            ),
          );
        }
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: const BoxDecoration(
          color: AbzioTheme.accentColor,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.send_rounded, color: Colors.black, size: 20),
      ),
    );
  }
}
