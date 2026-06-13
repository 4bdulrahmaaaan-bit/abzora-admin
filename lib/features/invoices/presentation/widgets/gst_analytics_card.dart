import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/invoice_providers.dart';

class GstAnalyticsCard extends ConsumerWidget {
  const GstAnalyticsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gst = ref.watch(gstSummaryProvider);
    return gst.when(
      data: (data) {
        final summary = Map<String, dynamic>.from(
          data['summary'] as Map? ?? const {},
        );
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE6DED0)),
            color: Theme.of(context).colorScheme.surface,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GST Analytics',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text('Total GST: INR ${(summary['tax'] ?? 0).toString()}'),
              Text('CGST: INR ${(summary['cgst'] ?? 0).toString()}'),
              Text('SGST: INR ${(summary['sgst'] ?? 0).toString()}'),
              Text('IGST: INR ${(summary['igst'] ?? 0).toString()}'),
            ],
          ),
        );
      },
      error: (_, _) => const SizedBox.shrink(),
      loading: () => const SizedBox.shrink(),
    );
  }
}
