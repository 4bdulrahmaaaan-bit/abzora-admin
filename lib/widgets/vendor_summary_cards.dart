import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme.dart';

class VendorSummaryMetric {
  const VendorSummaryMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
    this.subtext,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color tint;
  final String? subtext;
}

class VendorSummaryCards extends StatelessWidget {
  const VendorSummaryCards({
    super.key,
    required this.metrics,
  });

  final List<VendorSummaryMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 172,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: metrics.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final metric = metrics[index];
          return _VendorSummaryCard(metric: metric);
        },
      ),
    );
  }
}

class _VendorSummaryCard extends StatelessWidget {
  const _VendorSummaryCard({required this.metric});

  final VendorSummaryMetric metric;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 188,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: AbzioTheme.grey100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: metric.tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(metric.icon, color: metric.tint),
          ),
          const Spacer(),
          Text(
            metric.value,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111111),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            metric.label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF4C4C4C),
            ),
          ),
          if ((metric.subtext ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              metric.subtext!,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF7B7B7B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
