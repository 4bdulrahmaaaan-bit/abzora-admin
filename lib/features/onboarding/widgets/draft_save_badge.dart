import 'package:flutter/material.dart';

import '../../../services/vendor_onboarding_local_cache.dart';

class DraftSaveBadge extends StatelessWidget {
  final DateTime? lastSaved;
  final SyncStatus status;

  const DraftSaveBadge({
    super.key,
    this.lastSaved,
    this.status = SyncStatus.cloudSynced,
  });

  @override
  Widget build(BuildContext context) {
    if (lastSaved == null && status != SyncStatus.pendingSync) return const SizedBox.shrink();

    Color bgColor;
    Color fgColor;
    IconData icon;
    String text;

    switch (status) {
      case SyncStatus.saving:
        bgColor = Colors.grey.withValues(alpha: 0.1);
        fgColor = Colors.grey;
        icon = Icons.sync_rounded;
        text = 'Saving...';
        break;
      case SyncStatus.syncing:
        bgColor = Colors.blue.withValues(alpha: 0.1);
        fgColor = Colors.blue;
        icon = Icons.cloud_sync_rounded;
        text = 'Syncing...';
        break;
      case SyncStatus.pendingSync:
        bgColor = Colors.orange.withValues(alpha: 0.1);
        fgColor = Colors.orange;
        icon = Icons.warning_amber_rounded;
        text = 'Pending Sync';
        break;
      case SyncStatus.syncFailed:
        bgColor = Colors.red.withValues(alpha: 0.1);
        fgColor = Colors.red;
        icon = Icons.error_outline_rounded;
        text = 'Sync Failed';
        break;
      case SyncStatus.localOnly:
        bgColor = Colors.blue.withValues(alpha: 0.1);
        fgColor = Colors.blue;
        icon = Icons.save_alt_rounded;
        text = 'Saved Locally';
        break;
      case SyncStatus.cloudSynced:
        bgColor = Colors.green.withValues(alpha: 0.1);
        fgColor = Colors.green;
        icon = Icons.cloud_done_outlined;
        final diff = lastSaved != null ? DateTime.now().difference(lastSaved!) : const Duration(minutes: 5);
        text = diff.inSeconds < 60 ? 'Saved' : 'Saved';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fgColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: fgColor, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: fgColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
