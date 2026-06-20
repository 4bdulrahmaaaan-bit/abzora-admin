part of '../admin_web_panel.dart';

class AdminSupportSection extends StatelessWidget {
  const AdminSupportSection({
    super.key,
    required this.loaded,
    required this.searchController,
    required this.onSearchChanged,
    required this.unreadTotal,
    required this.activeCount,
    required this.resolvedCount,
    required this.chats,
    required this.selectedChat,
    required this.buildSidebar,
    required this.buildQueue,
    required this.buildWorkspace,
  });

  final bool loaded;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final int unreadTotal;
  final int activeCount;
  final int resolvedCount;
  final List<SupportChat> chats;
  final SupportChat? selectedChat;
  final Widget Function({bool compact}) buildSidebar;
  final Widget Function(
    List<SupportChat> chats,
    SupportChat? selected, {
    bool includeSidebarFilters,
  })
  buildQueue;
  final Widget Function(SupportChat? selected) buildWorkspace;

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return const AbzioLoadingView(
        title: 'Loading support desk',
        subtitle: 'Fetching support chats and timeline data.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FilterPanel(
          title: 'Support desk',
          subtitle:
              'Monitor support chats, reply quickly, and resolve tickets without leaving the workspace.',
          children: [
            SizedBox(
              width: 280,
              child: TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                decoration: const InputDecoration(
                  hintText: 'Search by name, phone, issue, order, or message',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            _SupportSegmentChip(
              label: 'Unread replies',
              selected: false,
              count: unreadTotal,
              onTap: () {},
            ),
            _SupportSegmentChip(
              label: 'Active',
              selected: false,
              count: activeCount,
              onTap: () {},
            ),
            _SupportSegmentChip(
              label: 'Resolved',
              selected: false,
              count: resolvedCount,
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 1380) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 300, child: buildSidebar()),
                  const SizedBox(width: 16),
                  SizedBox(width: 360, child: buildQueue(chats, selectedChat)),
                  const SizedBox(width: 16),
                  Expanded(child: buildWorkspace(selectedChat)),
                ],
              );
            }
            if (constraints.maxWidth >= 980) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 360,
                    child: buildQueue(
                      chats,
                      selectedChat,
                      includeSidebarFilters: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: buildWorkspace(selectedChat)),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildSidebar(compact: true),
                const SizedBox(height: 16),
                buildQueue(chats, selectedChat, includeSidebarFilters: true),
                const SizedBox(height: 16),
                buildWorkspace(selectedChat),
              ],
            );
          },
        ),
      ],
    );
  }
}
