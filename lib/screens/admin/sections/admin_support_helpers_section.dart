// ignore_for_file: invalid_use_of_protected_member

part of '../admin_web_panel.dart';

extension _AdminSupportHelpersSection on _AdminWebPanelState {
  Widget _buildSupport() {
    if (!_supportLoaded) {
      return const AbzioLoadingView(
        title: 'Loading support desk',
        subtitle: 'Fetching support chats and timeline data.',
      );
    }
    final chats = _filteredSupportChats;
    final selected = _selectedSupportChat;
    final unreadTotal = _supportUnreadCount();
    final activeCount =
        _supportChatCount(status: 'open') +
        _supportChatCount(status: 'waiting');

    return AdminSupportSection(
      loaded: _supportLoaded,
      searchController: _supportSearchController,
      onSearchChanged: (_) => setState(() {}),
      unreadTotal: unreadTotal,
      activeCount: activeCount,
      resolvedCount: _supportChatCount(status: 'closed'),
      chats: chats,
      selectedChat: selected,
      buildSidebar: ({bool compact = false}) =>
          _buildSupportSidebar(compact: compact),
      buildQueue:
          (
            List<SupportChat> visibleChats,
            SupportChat? visibleSelected, {
            bool includeSidebarFilters = false,
          }) => _buildSupportQueue(
            visibleChats,
            visibleSelected,
            includeSidebarFilters: includeSidebarFilters,
          ),
      buildWorkspace: (SupportChat? visibleSelected) =>
          _buildSupportConversationWorkspace(visibleSelected),
    );
  }

  Widget _buildSupportSidebar({bool compact = false}) {
    final statusAllSelected = _supportStatusFilter == 'all';
    final waitingSelected = _supportStatusFilter == 'waiting';
    final openSelected = _supportStatusFilter == 'open';
    final closedSelected = _supportStatusFilter == 'closed';
    final allTypeSelected = _supportTypeFilter == 'all';

    return _Panel(
      title: 'Support filters',
      subtitle: 'Jump between queues and keep unread conversations visible.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SupportFilterItem(
            label: 'All chats',
            subtitle: 'Every support conversation',
            icon: Icons.inbox_rounded,
            count: _supportChatCount(),
            unreadCount: _supportUnreadCount(),
            selected: statusAllSelected && allTypeSelected,
            onTap: () => setState(() {
              _supportStatusFilter = 'all';
              _supportTypeFilter = 'all';
            }),
          ),
          const SizedBox(height: 10),
          _SupportFilterItem(
            label: 'Open',
            subtitle: 'Chats actively handled',
            icon: Icons.mark_chat_read_rounded,
            count: _supportChatCount(status: 'open'),
            unreadCount: _supportUnreadCount(status: 'open'),
            selected: openSelected,
            onTap: () => setState(() => _supportStatusFilter = 'open'),
          ),
          const SizedBox(height: 10),
          _SupportFilterItem(
            label: 'Waiting',
            subtitle: 'Customers awaiting a reply',
            icon: Icons.schedule_send_rounded,
            count: _supportChatCount(status: 'waiting'),
            unreadCount: _supportUnreadCount(status: 'waiting'),
            selected: waitingSelected,
            onTap: () => setState(() => _supportStatusFilter = 'waiting'),
          ),
          const SizedBox(height: 10),
          _SupportFilterItem(
            label: 'Resolved',
            subtitle: 'Closed conversations',
            icon: Icons.task_alt_rounded,
            count: _supportChatCount(status: 'closed'),
            unreadCount: _supportUnreadCount(status: 'closed'),
            selected: closedSelected,
            onTap: () => setState(() => _supportStatusFilter = 'closed'),
          ),
          const SizedBox(height: 16),
          Text(
            'Issue categories',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              color: AbzioTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SupportSegmentChip(
                label: 'All',
                selected: allTypeSelected,
                count: _supportChatCount(),
                onTap: () => setState(() => _supportTypeFilter = 'all'),
              ),
              _SupportSegmentChip(
                label: 'Order',
                selected: _supportTypeFilter == 'order',
                count: _supportChatCount(type: 'order'),
                onTap: () => setState(() => _supportTypeFilter = 'order'),
              ),
              _SupportSegmentChip(
                label: 'Payment',
                selected: _supportTypeFilter == 'payment',
                count: _supportChatCount(type: 'payment'),
                onTap: () => setState(() => _supportTypeFilter = 'payment'),
              ),
              _SupportSegmentChip(
                label: 'Custom',
                selected: _supportTypeFilter == 'custom',
                count: _supportChatCount(type: 'custom'),
                onTap: () => setState(() => _supportTypeFilter = 'custom'),
              ),
              _SupportSegmentChip(
                label: 'General',
                selected: _supportTypeFilter == 'general',
                count: _supportChatCount(type: 'general'),
                onTap: () => setState(() => _supportTypeFilter = 'general'),
              ),
            ],
          ),
          if (compact) ...[
            const SizedBox(height: 14),
            Text(
              'Tap a card to open the full conversation and ticket details.',
              style: GoogleFonts.inter(
                color: AbzioTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSupportQueue(
    List<SupportChat> chats,
    SupportChat? selected, {
    bool includeSidebarFilters = false,
  }) {
    return _Panel(
      title: 'Conversation queue',
      subtitle: '${chats.length} matching conversation(s)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (includeSidebarFilters) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SupportCompactFilterChip(
                  label: 'All',
                  selected: _supportStatusFilter == 'all',
                  onTap: () => setState(() => _supportStatusFilter = 'all'),
                ),
                _SupportCompactFilterChip(
                  label: 'Open',
                  selected: _supportStatusFilter == 'open',
                  onTap: () => setState(() => _supportStatusFilter = 'open'),
                ),
                _SupportCompactFilterChip(
                  label: 'Waiting',
                  selected: _supportStatusFilter == 'waiting',
                  onTap: () => setState(() => _supportStatusFilter = 'waiting'),
                ),
                _SupportCompactFilterChip(
                  label: 'Resolved',
                  selected: _supportStatusFilter == 'closed',
                  onTap: () => setState(() => _supportStatusFilter = 'closed'),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (chats.isEmpty)
            const AbzioEmptyCard(
              title: 'No conversations match',
              subtitle:
                  'Try another search or switch filters to view more support activity.',
            )
          else
            Column(
              children: chats
                  .map(
                    (chat) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SupportChatCard(
                        chat: chat,
                        isSelected: selected?.id == chat.id,
                        onTap: () => _selectSupportChat(chat),
                        timestampLabel: _formatIsoMoment(
                          chat.lastMessageAt.isEmpty
                              ? chat.updatedAt
                              : chat.lastMessageAt,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildSupportConversationWorkspace(SupportChat? selected) {
    if (selected == null) {
      return const _Panel(
        title: 'Active conversation',
        subtitle: 'Select a conversation to start responding',
        child: AbzioEmptyCard(
          title: 'No conversation selected',
          subtitle:
              'Choose a ticket from the queue to review messages, timeline, and ticket details.',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSupportHeaderCard(selected),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 7, child: _buildSupportMessagesPanel(selected)),
            const SizedBox(width: 16),
            Expanded(flex: 4, child: _buildSupportTicketDetailsPanel(selected)),
          ],
        ),
        const SizedBox(height: 16),
        _buildSupportComposer(selected),
      ],
    );
  }

  Widget _buildSupportHeaderCard(SupportChat chat) {
    final statusColor = chat.status == 'waiting'
        ? const Color(0xFFD97706)
        : chat.status == 'closed'
        ? const Color(0xFF8A8A8A)
        : const Color(0xFF1F9D55);

    return _Panel(
      title: chat.userName.isEmpty ? chat.userId : chat.userName,
      subtitle:
          '${chat.userPhone.isEmpty ? 'No phone number' : chat.userPhone} • ${_supportTypeLabel(chat.type)}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusPill(
                  label: chat.status.toUpperCase(),
                  color: statusColor,
                ),
                _StatusPill(
                  label: _supportTypeLabel(chat.type),
                  color: AbzioTheme.accentColor,
                ),
                if ((chat.orderId ?? '').isNotEmpty)
                  _StatusPill(
                    label: 'Order ${chat.orderId}',
                    color: const Color(0xFF2563EB),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (chat.status == 'closed')
            OutlinedButton.icon(
              onPressed: () => _reopenSupportConversation(chat),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reopen ticket'),
            )
          else
            ElevatedButton.icon(
              onPressed: () => _closeSupportConversation(chat),
              icon: const Icon(Icons.task_alt_rounded),
              label: const Text('Mark resolved'),
            ),
        ],
      ),
    );
  }

  Widget _buildSupportMessagesPanel(SupportChat chat) {
    return _Panel(
      title: 'Conversation',
      subtitle: 'Realtime customer and admin messages',
      child: Container(
        height: 520,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFBFAF7),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AbzioTheme.grey200),
        ),
        child: StreamBuilder<List<SupportMessage>>(
          stream: _actor == null
              ? const Stream.empty()
              : _db.watchSupportMessages(chatId: chat.id, actor: _actor!),
          builder: (context, snapshot) {
            final messages = snapshot.data ?? const <SupportMessage>[];
            if (snapshot.connectionState == ConnectionState.waiting &&
                messages.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (messages.isEmpty) {
              return const Center(child: Text('No messages yet.'));
            }
            return ListView.separated(
              itemCount: messages.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final message = messages[index];
                final isAdminMessage = message.senderRole == 'admin';
                return Align(
                  alignment: isAdminMessage
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 420),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isAdminMessage
                          ? AbzioTheme.accentColor.withValues(alpha: 0.18)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isAdminMessage
                            ? AbzioTheme.accentColor.withValues(alpha: 0.20)
                            : AbzioTheme.grey200,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.text.isEmpty
                              ? 'Attachment shared'
                              : message.text,
                          style: GoogleFonts.inter(height: 1.45),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatIsoMoment(message.timestamp),
                          style: GoogleFonts.inter(
                            color: AbzioTheme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildSupportTicketDetailsPanel(SupportChat chat) {
    final timeline = _supportTimelineFor(chat.id);
    return _Panel(
      title: 'Ticket details',
      subtitle: 'Context, ownership, and timeline',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SupportDetailRow(label: 'Ticket ID', value: chat.ticketId),
          _SupportDetailRow(label: 'Chat ID', value: chat.id),
          _SupportDetailRow(
            label: 'Issue',
            value: _supportTypeLabel(chat.type),
          ),
          _SupportDetailRow(label: 'Status', value: chat.status.toUpperCase()),
          _SupportDetailRow(
            label: 'Order',
            value: (chat.orderId ?? '').isEmpty ? 'Not linked' : chat.orderId!,
          ),
          _SupportDetailRow(
            label: 'Created',
            value: _formatIsoMoment(chat.createdAt),
          ),
          _SupportDetailRow(
            label: 'Updated',
            value: _formatIsoMoment(chat.updatedAt),
          ),
          _SupportDetailRow(
            label: 'Unread',
            value: '${chat.unreadCountAdmin} pending for admin',
          ),
          const SizedBox(height: 8),
          Text(
            'Action history',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (timeline.isEmpty)
            Text(
              'No activity history yet.',
              style: GoogleFonts.inter(color: AbzioTheme.textSecondary),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: timeline
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(top: 5),
                            decoration: const BoxDecoration(
                              color: AbzioTheme.accentColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.message,
                                  style: GoogleFonts.inter(
                                    color: AbzioTheme.textSecondary,
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDate(entry.timestamp),
                                  style: GoogleFonts.inter(
                                    color: AbzioTheme.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildSupportComposer(SupportChat chat) {
    return _Panel(
      title: 'Reply',
      subtitle: chat.status == 'closed'
          ? 'Reopen the ticket to send another response.'
          : 'Send a realtime reply to the customer.',
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _supportReplyController,
              enabled: chat.status != 'closed',
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'Reply to customer'),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: chat.status == 'closed' ? null : _sendSupportReply,
            icon: const Icon(Icons.send_rounded),
            label: const Text('Send'),
          ),
        ],
      ),
    );
  }

  String _supportTypeLabel(String type) {
    switch (type) {
      case 'order':
        return 'Order issue';
      case 'payment':
        return 'Payment issue';
      case 'custom':
        return 'Custom clothing';
      default:
        return 'General support';
    }
  }

  // ignore: unused_element
}

