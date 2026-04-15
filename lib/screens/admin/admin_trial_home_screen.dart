import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/trial_session.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../theme.dart';

class AdminTrialHomeScreen extends StatefulWidget {
  const AdminTrialHomeScreen({super.key});

  @override
  State<AdminTrialHomeScreen> createState() => _AdminTrialHomeScreenState();
}

class _AdminTrialHomeScreenState extends State<AdminTrialHomeScreen> {
  final DatabaseService _db = DatabaseService();
  bool _loading = true;
  String _statusFilter = 'all';
  String? _error;
  List<TrialSession> _sessions = const <TrialSession>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final actor = context.read<AuthProvider>().user;
    if (actor == null) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sessions = await _db.getAdminTrialHomeSessions(
        actor: actor,
        status: _statusFilter == 'all' ? null : _statusFilter,
      );
      if (!mounted) {
        return;
      }
      setState(() => _sessions = sessions);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _updateStatus({
    required TrialSession session,
    required String nextStatus,
    String note = '',
  }) async {
    final actor = context.read<AuthProvider>().user;
    if (actor == null) {
      return;
    }
    try {
      await _db.updateAdminTrialHomeSession(
        actor: actor,
        trialId: session.id,
        status: nextStatus,
        note: note,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Session moved to ${_statusLabel(nextStatus)}.'),
        ),
      );
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'booked':
      case 'confirmed':
        return const Color(0xFF7A5A23);
      case 'out_for_trial_delivery':
        return const Color(0xFF8C6B1A);
      case 'trial_in_progress':
        return const Color(0xFF2666A8);
      case 'completed':
        return const Color(0xFF2F7D4B);
      case 'converted_to_order':
        return const Color(0xFF206A3B);
      case 'converted_to_tailoring':
        return const Color(0xFF6A2B82);
      case 'cancelled':
        return const Color(0xFFB0492F);
      default:
        return AbzioTheme.grey600;
    }
  }

  String _statusLabel(String status) {
    return status.replaceAll('_', ' ').toUpperCase();
  }

  Future<void> _openDetail(TrialSession session) async {
    final detail = await _db.getAdminTrialHomeSession(
      actor: context.read<AuthProvider>().user!,
      trialId: session.id,
    );
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final actions = <(String, String)>[
          ('confirmed', 'Confirm'),
          ('out_for_trial_delivery', 'Mark Out for Trial'),
          ('trial_in_progress', 'Mark In Progress'),
          ('completed', 'Mark Completed'),
          ('cancelled', 'Cancel'),
        ];
        return SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.86,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFFF8F4EE),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
            child: ListView(
              children: [
                Container(
                  width: 48,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AbzioTheme.grey300,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Text(
                  'Trial Session Detail',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Text(
                  detail.id,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AbzioTheme.grey600,
                      ),
                ),
                const SizedBox(height: 16),
                _InfoRow(label: 'Status', value: _statusLabel(detail.status)),
                _InfoRow(label: 'User', value: detail.userId),
                _InfoRow(
                  label: 'Items',
                  value: '${detail.items.length} selected / ${detail.recommendedItems.length} styled',
                ),
                _InfoRow(label: 'Slot', value: detail.deliverySlot),
                _InfoRow(label: 'Address', value: detail.addressLabel),
                _InfoRow(
                  label: 'Fee',
                  value: '\u20B9${detail.trialFee.toStringAsFixed(0)} (${detail.paymentStatus})',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: actions
                      .map((entry) => OutlinedButton(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              await _updateStatus(
                                session: detail,
                                nextStatus: entry.$1,
                              );
                            },
                            child: Text(entry.$2),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final chips = const <(String, String)>[
      ('all', 'All'),
      ('booked', 'Booked'),
      ('out_for_trial_delivery', 'Out'),
      ('trial_in_progress', 'In Progress'),
      ('completed', 'Completed'),
      ('converted_to_order', 'Order'),
      ('converted_to_tailoring', 'Tailoring'),
      ('cancelled', 'Cancelled'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trial at Home'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: chips
                        .map((entry) => ChoiceChip(
                              label: Text(entry.$2),
                              selected: _statusFilter == entry.$1,
                              onSelected: (_) async {
                                setState(() => _statusFilter = entry.$1);
                                await _load();
                              },
                              selectedColor:
                                  AbzioTheme.accentColor.withValues(alpha: 0.18),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 14),
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4F2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(_error!),
                    ),
                  if (_sessions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(
                        child: Text(
                          'No trial-home sessions for this filter.',
                        ),
                      ),
                    ),
                  ..._sessions.map((session) => Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => _openDetail(session),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        session.id,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(color: AbzioTheme.grey600),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _statusColor(session.status)
                                            .withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        _statusLabel(session.status),
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: _statusColor(session.status),
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'User: ${session.userId}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${session.items.length} items | ${session.deliverySlot}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AbzioTheme.grey600),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Approval: ${session.approvalStatus.toUpperCase()}${session.approvedBy.isNotEmpty ? ' by ${session.approvedBy}' : ''}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AbzioTheme.grey600),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '\u20B9${session.trialFee.toStringAsFixed(0)} refundable | ${session.paymentStatus}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AbzioTheme.grey600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )),
                ],
              ),
            ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AbzioTheme.grey600),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
