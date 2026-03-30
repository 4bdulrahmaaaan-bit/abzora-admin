import 'package:flutter/material.dart';

class KycRequestListItem {
  const KycRequestListItem({
    required this.id,
    required this.name,
    required this.role,
    required this.city,
    required this.status,
    required this.submittedTime,
    this.phone = '',
    this.thumbnailUrl = '',
    this.documentLabels = const [],
    this.riskFlags = const [],
    this.selected = false,
  });

  final String id;
  final String name;
  final String role;
  final String city;
  final String status;
  final String submittedTime;
  final String phone;
  final String thumbnailUrl;
  final List<String> documentLabels;
  final List<String> riskFlags;
  final bool selected;
}

class KycRequestCard extends StatelessWidget {
  const KycRequestCard({
    super.key,
    required this.item,
    required this.isSelected,
    required this.onTap,
    this.onSelectedChanged,
    this.onApprove,
    this.onReject,
  });

  final KycRequestListItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final ValueChanged<bool>? onSelectedChanged;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  Color get _statusColor {
    switch (item.status) {
      case 'approved':
        return const Color(0xFF067647);
      case 'rejected':
        return const Color(0xFFB42318);
      default:
        return const Color(0xFFB76E00);
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? const Color(0xFFD4AF37) : const Color(0xFFEAEAEA),
          width: isSelected ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: item.selected,
                onChanged: onSelectedChanged == null ? null : (value) => onSelectedChanged!(value ?? false),
                activeColor: const Color(0xFFD4AF37),
              ),
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  item.status.toUpperCase(),
                  style: TextStyle(
                    color: _statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (item.thumbnailUrl.trim().isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    item.thumbnailUrl,
                    width: 54,
                    height: 54,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const SizedBox(
                      width: 54,
                      height: 54,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: Color(0xFFF1F1F1)),
                        child: Icon(Icons.image_not_supported_outlined, color: Color(0xFF9B9B9B)),
                      ),
                    ),
                  ),
                ),
              if (item.thumbnailUrl.trim().isNotEmpty) const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...item.documentLabels.map((label) => _iconDoc(label)),
                    ...item.riskFlags.map((flag) => _risk(flag)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(item.role),
              _pill(item.city),
              if (item.phone.trim().isNotEmpty) _pill(item.phone),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Submitted ${item.submittedTime}',
            style: const TextStyle(
              color: Color(0xFF737373),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: item.status == 'pending' ? onReject : null,
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: item.status == 'pending' ? onApprove : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF067647),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final dismissibleEnabled = item.status == 'pending' && (onApprove != null || onReject != null);
    if (!dismissibleEnabled) {
      return Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(20), onTap: onTap, child: card));
    }

    return Dismissible(
      key: ValueKey(item.id),
      background: _SwipeAction(
        color: const Color(0xFF067647),
        icon: Icons.check_circle_outline_rounded,
        label: 'Approve',
        alignLeft: true,
      ),
      secondaryBackground: _SwipeAction(
        color: const Color(0xFFB42318),
        icon: Icons.close_rounded,
        label: 'Reject',
        alignLeft: false,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onApprove?.call();
        } else {
          onReject?.call();
        }
        return false;
      },
      child: Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(20), onTap: onTap, child: card)),
    );
  }

  Widget _pill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _iconDoc(String label) {
    IconData icon;
    switch (label.toLowerCase()) {
      case 'aadhaar':
        icon = Icons.badge_outlined;
        break;
      case 'pan':
        icon = Icons.description_outlined;
        break;
      case 'license':
        icon = Icons.credit_card_outlined;
        break;
      default:
        icon = Icons.insert_drive_file_outlined;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF7A7A7A)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _risk(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFB76E00)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF9A6700),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeAction extends StatelessWidget {
  const _SwipeAction({
    required this.color,
    required this.icon,
    required this.label,
    required this.alignLeft,
  });

  final Color color;
  final IconData icon;
  final String label;
  final bool alignLeft;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: alignLeft ? Alignment.centerLeft : Alignment.centerRight,
      child: Row(
        mainAxisAlignment: alignLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (!alignLeft) Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          if (!alignLeft) const SizedBox(width: 8),
          Icon(icon, color: Colors.white),
          if (alignLeft) const SizedBox(width: 8),
          if (alignLeft) Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
