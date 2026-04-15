import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/trial_session.dart';
import '../../providers/trial_home_provider.dart';
import '../../theme.dart';
import 'trial_in_progress_screen.dart';
import 'trial_result_screen.dart';
import 'trial_tailoring_conversion_screen.dart';

class TrialStatusScreen extends StatefulWidget {
  const TrialStatusScreen({
    super.key,
    required this.trialId,
  });

  final String trialId;

  @override
  State<TrialStatusScreen> createState() => _TrialStatusScreenState();
}

class _TrialStatusScreenState extends State<TrialStatusScreen> {
  Timer? _poller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    _poller = Timer.periodic(
      const Duration(seconds: 6),
      (_) => _refresh(silent: true),
    );
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    final provider = context.read<TrialHomeProvider>();
    try {
      await provider.fetchTrialById(widget.trialId);
    } catch (_) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              provider.error ?? 'We could not refresh your trial status.',
            ),
          ),
        );
      }
    }
  }

  String _primaryActionLabel(TrialSession session) {
    if (session.isApprovalPending) {
      return 'Awaiting Approval';
    }
    if (session.isApprovalRejected) {
      return 'Request Rejected';
    }
    if (session.status == 'trial_in_progress') {
      return 'Share Live Fit Feedback';
    }
    if (session.status == 'completed') {
      return 'Choose Keep or Return';
    }
    if (session.status == 'converted_to_tailoring') {
      return 'View Tailoring Request';
    }
    if (session.status == 'converted_to_order') {
      return 'View Trial Outcome';
    }
    if (session.status == 'cancelled') {
      return 'Retry Status Check';
    }
    return 'Refresh Status';
  }

  Future<void> _openStatusAction(TrialSession session) async {
    if (session.isApprovalPending || session.isApprovalRejected) {
      await _refresh();
      return;
    }
    if (session.status == 'trial_in_progress') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TrialInProgressScreen(trialId: session.id),
        ),
      );
      return;
    }
    if (session.status == 'completed' || session.status == 'converted_to_order') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TrialResultScreen(trialId: session.id),
        ),
      );
      return;
    }
    if (session.status == 'converted_to_tailoring') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TrialTailoringConversionScreen(trialId: session.id),
        ),
      );
      return;
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TrialHomeProvider>();
    final session = provider.currentTrial;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EE),
      appBar: AppBar(
        title: const Text('Trial Status'),
        actions: [
          IconButton(
            onPressed: provider.loading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: session == null
          ? _StatusEmptyState(
              loading: provider.loading,
              error: provider.error,
              onRetry: _refresh,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                _StatusHero(session: session),
                const SizedBox(height: 20),
                _StatusProgress(session: session),
                const SizedBox(height: 20),
                _DetailStrip(session: session),
                const SizedBox(height: 20),
                _SmartSuggestionStrip(session: session),
                if (provider.error != null) ...[
                  const SizedBox(height: 20),
                  _InlineStatusError(
                    message: provider.error!,
                    onRetry: _refresh,
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: provider.loading
                      ? null
                      : () => _openStatusAction(session),
                  child: Text(_primaryActionLabel(session)),
                ),
              ],
            ),
    );
  }
}

class _StatusHero extends StatelessWidget {
  const _StatusHero({required this.session});

  final TrialSession session;

  @override
  Widget build(BuildContext context) {
    final title = switch (session.status) {
      'draft' when session.approvalStatus == 'pending' =>
        'Your trial request is waiting for approval',
      'cancelled' when session.approvalStatus == 'rejected' =>
        'Your trial request was not approved',
      'booked' || 'confirmed' => 'Your trial is booked',
      'out_for_trial_delivery' => 'Your stylist is on the way',
      'trial_in_progress' => 'Your Perfect Fit Experience is live',
      'completed' => 'Your trial is complete',
      'converted_to_order' => 'Your kept pieces are confirmed',
      'converted_to_tailoring' => 'Your tailoring request is underway',
      'cancelled' => 'Your trial was cancelled',
      _ => 'Your trial is in motion',
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [Color(0xFF1F1B17), Color(0xFF6B542D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: AbzioTheme.eliteShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Approval: ${session.approvalStatus.replaceAll('_', ' ').toUpperCase()}',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: const Color(0xFFF2D7A0),
                ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            'Recommended size ${session.recommendedSize.isEmpty ? 'M' : session.recommendedSize} | ${session.fitConfidence.toStringAsFixed(0)}% confidence',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.76),
                ),
          ),
          if (session.approvalReason.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              session.approvalReason,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusProgress extends StatelessWidget {
  const _StatusProgress({required this.session});

  final TrialSession session;

  @override
  Widget build(BuildContext context) {
    const steps = <String>[
      'BOOKED',
      'OUT FOR TRIAL',
      'COMPLETED',
    ];
    final statusIndex = switch (session.status) {
      'draft' when session.approvalStatus == 'pending' => 0,
      'booked' || 'confirmed' => 0,
      'out_for_trial_delivery' || 'trial_in_progress' => 1,
      _ => 2,
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Row(
            children: List.generate(steps.length, (index) {
              final active = index <= statusIndex;
              return Expanded(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      height: 8,
                      margin: EdgeInsets.only(
                        right: index == steps.length - 1 ? 0 : 8,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? AbzioTheme.accentColor
                            : AbzioTheme.grey300,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      steps[index],
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: active
                                ? const Color(0xFF7D5A19)
                                : AbzioTheme.grey500,
                          ),
                    ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            child: Text(
              switch (statusIndex) {
                0 when session.approvalStatus == 'pending' =>
                  'Request submitted. Vendor/admin approval is in progress.',
                0 => 'We are preparing your curated delivery.',
                1 => 'Your outfit is on its way for trial.',
                _ => 'You can now choose what to keep or tailor.',
              },
              key: ValueKey(statusIndex),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailStrip extends StatelessWidget {
  const _DetailStrip({required this.session});

  final TrialSession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          _DetailRow(label: 'Delivery slot', value: session.deliverySlot),
          const Divider(height: 20),
          _DetailRow(label: 'Address', value: session.addressLabel),
          const Divider(height: 20),
          _DetailRow(
            label: 'Trial fee',
            value: '\u20B9${session.trialFee.toStringAsFixed(0)} refundable',
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
      ],
    );
  }
}

class _SmartSuggestionStrip extends StatelessWidget {
  const _SmartSuggestionStrip({required this.session});

  final TrialSession session;

  @override
  Widget build(BuildContext context) {
    final copy = switch (session.status) {
      'booked' || 'confirmed' =>
        'Your stylist is preparing a body-aware rack for this visit.',
      'out_for_trial_delivery' =>
        'Styling tip: keep your preferred shoes nearby for better look matching.',
      'trial_in_progress' =>
        'Share fit feedback now to unlock smarter recommendations instantly.',
      'completed' =>
        'Decide what to keep and convert the rest into tailoring if needed.',
      'converted_to_order' =>
        'Great choice. We will use this fit profile for faster next checkout.',
      'converted_to_tailoring' =>
        'Your atelier conversion is active. We will fine-tune this garment for you.',
      _ => 'We are tailoring this journey around your fit profile.',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome_rounded, color: Color(0xFF9E7426)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              copy,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusEmptyState extends StatelessWidget {
  const _StatusEmptyState({
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              error ?? 'No active trial found yet.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineStatusError extends StatelessWidget {
  const _InlineStatusError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_tethering_error_rounded, color: Color(0xFFD65D4B)),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
