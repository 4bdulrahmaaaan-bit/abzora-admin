part of '../admin_web_panel.dart';

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.inter(color: AbzioTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: AbzioTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
    this.foreground = Colors.white,
    this.borderColor,
  });

  final String label;
  final Color color;
  final Color foreground;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: foreground,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.inter(color: AbzioTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            Wrap(spacing: 12, runSpacing: 12, children: children),
          ],
        ),
      ),
    );
  }
}

class _SupportFilterItem extends StatelessWidget {
  const _SupportFilterItem({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.count,
    required this.unreadCount,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final int count;
  final int unreadCount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AbzioTheme.accentColor.withValues(alpha: 0.10)
              : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? AbzioTheme.accentColor.withValues(alpha: 0.24)
                : AbzioTheme.grey200,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AbzioTheme.accentColor.withValues(alpha: 0.10),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AbzioTheme.accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AbzioTheme.accentColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        '$count',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          color: AbzioTheme.accentColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: AbzioTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: AbzioTheme.accentColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$unreadCount',
                  style: GoogleFonts.inter(
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
    );
  }
}

class _SupportSegmentChip extends StatelessWidget {
  const _SupportSegmentChip({
    required this.label,
    required this.selected,
    required this.count,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AbzioTheme.accentColor.withValues(alpha: 0.16),
      labelStyle: GoogleFonts.inter(
        fontWeight: FontWeight.w700,
        color: selected ? Colors.black : AbzioTheme.textSecondary,
      ),
      side: BorderSide(
        color: selected
            ? AbzioTheme.accentColor.withValues(alpha: 0.32)
            : AbzioTheme.grey200,
      ),
      backgroundColor: Colors.white,
    );
  }
}

class _SupportCompactFilterChip extends StatelessWidget {
  const _SupportCompactFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AbzioTheme.accentColor.withValues(alpha: 0.16),
      labelStyle: GoogleFonts.inter(
        fontWeight: FontWeight.w700,
        color: selected ? Colors.black : AbzioTheme.textSecondary,
      ),
      side: BorderSide(
        color: selected
            ? AbzioTheme.accentColor.withValues(alpha: 0.32)
            : AbzioTheme.grey200,
      ),
      backgroundColor: Colors.white,
    );
  }
}

class _FeatureSwitchCard extends StatelessWidget {
  const _FeatureSwitchCard({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AbzioTheme.grey200),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
            Switch(
              value: value,
              activeThumbColor: AbzioTheme.accentColor,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.currentPage,
    required this.pageCount,
    this.onPrevious,
    this.onNext,
  });

  final int currentPage;
  final int pageCount;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          'Page ${currentPage + 1} of $pageCount',
          style: GoogleFonts.inter(color: AbzioTheme.textSecondary),
        ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SupportChatCard extends StatelessWidget {
  const _SupportChatCard({
    required this.chat,
    required this.isSelected,
    required this.onTap,
    required this.timestampLabel,
  });

  final SupportChat chat;
  final bool isSelected;
  final VoidCallback onTap;
  final String timestampLabel;

  @override
  Widget build(BuildContext context) {
    final statusColor = chat.status == 'waiting'
        ? const Color(0xFFD97706)
        : chat.status == 'closed'
        ? const Color(0xFF8A8A8A)
        : const Color(0xFF1F9D55);
    final icon = switch (chat.type) {
      'order' => Icons.receipt_long_rounded,
      'payment' => Icons.payments_outlined,
      'custom' => Icons.design_services_rounded,
      _ => Icons.support_agent_rounded,
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AbzioTheme.accentColor.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? AbzioTheme.accentColor.withValues(alpha: 0.22)
                : AbzioTheme.grey200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isSelected ? 0.06 : 0.03),
              blurRadius: isSelected ? 18 : 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4D8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AbzioTheme.accentColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.userName.isEmpty ? chat.userId : chat.userName,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (chat.unreadCountAdmin > 0)
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
                            '${chat.unreadCountAdmin}',
                            style: GoogleFonts.inter(
                              color: Colors.black,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    chat.userPhone.isEmpty ? 'No phone number' : chat.userPhone,
                    style: GoogleFonts.inter(
                      color: AbzioTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _StatusPill(
                        label: chat.status.toUpperCase(),
                        color: statusColor,
                      ),
                      _StatusPill(
                        label: chat.type.toUpperCase(),
                        color: AbzioTheme.accentColor,
                      ),
                      if ((chat.orderId ?? '').isNotEmpty)
                        _StatusPill(
                          label: chat.orderId!,
                          color: const Color(0xFF2563EB),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    chat.lastMessage.isEmpty
                        ? 'Support ticket created'
                        : chat.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AbzioTheme.textSecondary,
                      fontWeight: chat.unreadCountAdmin > 0
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    timestampLabel,
                    style: GoogleFonts.inter(
                      color: AbzioTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportDetailRow extends StatelessWidget {
  const _SupportDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 98,
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: AbzioTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchMetric extends StatelessWidget {
  const _SearchMetric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '$value',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _MiniBarChart extends StatelessWidget {
  const _MiniBarChart({
    required this.points,
    this.barColor = AbzioTheme.accentColor,
    this.valueFormatter,
  });

  final List<AnalyticsPoint> points;
  final Color barColor;
  final String Function(double value)? valueFormatter;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const AbzioEmptyCard(
        title: 'No chart data',
        subtitle:
            'Sales analytics will appear here when transactions are available.',
      );
    }
    final maxValue = points.fold<double>(
      0,
      (max, point) => point.value > max ? point.value : max,
    );
    return SizedBox(
      height: 220,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: points.map((point) {
          final ratio = maxValue == 0
              ? 0.1
              : (point.value / maxValue).clamp(0.1, 1.0);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    valueFormatter?.call(point.value) ??
                        point.value.toStringAsFixed(0),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AbzioTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 140 * ratio,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    point.label,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AbzioTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
