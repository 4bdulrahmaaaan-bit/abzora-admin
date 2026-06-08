import 'package:flutter/material.dart';
import 'dart:async';
import '../../../models/trial_session.dart';
import '../../../theme.dart';

class RiderTrialFlowScreen extends StatefulWidget {
  const RiderTrialFlowScreen({
    super.key,
    required this.session,
  });

  final TrialSession session;

  @override
  State<RiderTrialFlowScreen> createState() => _RiderTrialFlowScreenState();
}

class _RiderTrialFlowScreenState extends State<RiderTrialFlowScreen> {
  bool _hasArrived = false;
  bool _trialInProgress = false;
  Timer? _waitTimer;
  Timer? _trialTimer;
  int _waitSecondsRemaining = 600; // 10 minutes wait
  int _trialSecondsRemaining = 0;

  @override
  void initState() {
    super.initState();
    if (widget.session.trialStartedAt != null) {
      _hasArrived = true;
      _trialInProgress = true;
      _startTrialTimer();
    }
  }

  void _startWaitTimer() {
    _waitTimer?.cancel();
    _waitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_waitSecondsRemaining > 0) _waitSecondsRemaining--;
        });
      }
    });
  }

  void _startTrialTimer() {
    _trialSecondsRemaining = widget.session.trialDurationMinutes * 60;
    _trialTimer?.cancel();
    _trialTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_trialSecondsRemaining > 0) _trialSecondsRemaining--;
        });
      }
    });
  }

  @override
  void dispose() {
    _waitTimer?.cancel();
    _trialTimer?.cancel();
    super.dispose();
  }

  void _markArrived() {
    setState(() {
      _hasArrived = true;
    });
    _startWaitTimer();
  }

  void _startTrial() {
    setState(() {
      _trialInProgress = true;
    });
    _waitTimer?.cancel();
    _startTrialTimer();
  }

  void _markNoShow() {
    _waitTimer?.cancel();
    // In a real app, call TrialHomeApi.markNoShow
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Marked as No Show'),
        content: const Text('The customer did not respond. Inventory has been released and the session is closed.'),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Return to Dashboard'),
          ),
        ],
      ),
    );
  }

  void _completeTrial() {
    // Show a dialog or navigate to payment collection
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Trial'),
        content: const Text('Confirm that you have collected the returned items and payment (if any).'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to dashboard
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Trial Completed Successfully')),
              );
            },
            child: const Text('Confirm & Complete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EE),
      appBar: AppBar(
        title: const Text('Active Trial Delivery'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AbzioTheme.eliteShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Customer Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AbzioTheme.grey200,
                            child: const Icon(Icons.person, color: AbzioTheme.grey500),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('John Doe', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text('+91 9876543210', style: TextStyle(color: AbzioTheme.grey500, fontSize: 12)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.phone, color: Colors.green),
                            onPressed: () {},
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on, color: AbzioTheme.accentColor, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.session.addressLabel,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (_hasArrived) _buildTimerSection() else _buildArrivalSection(),
                const SizedBox(height: 24),
                const Text('Items To Try', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AbzioTheme.eliteShadow,
                  ),
                  child: Column(
                    children: widget.session.items.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 50,
                                height: 60,
                                color: AbzioTheme.grey200,
                                child: item.imageUrl.isNotEmpty
                                    ? Image.network(item.imageUrl, fit: BoxFit.cover)
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text('Size: ${item.recommendedSize}', style: TextStyle(color: AbzioTheme.grey500, fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          if (_hasArrived)
            Container(
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: _trialInProgress
                  ? FilledButton(
                      onPressed: _completeTrial,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        backgroundColor: AbzioTheme.accentColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text(
                        'Collect Payment & Complete',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    )
                  : FilledButton(
                      onPressed: _startTrial,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        backgroundColor: Colors.blue.shade600,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text(
                        'Customer Started Trial',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildArrivalSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Waiting for arrival...', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _markArrived,
          icon: const Icon(Icons.location_on),
          label: const Text('Mark Arrived'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            backgroundColor: Colors.green.shade600,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ],
    );
  }

  Widget _buildTimerSection() {
    if (!_trialInProgress) {
      final minutes = (_waitSecondsRemaining / 60).floor();
      final seconds = _waitSecondsRemaining % 60;
      final timeString = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      final canMarkNoShow = _waitSecondsRemaining == 0;

      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange, width: 2),
        ),
        child: Column(
          children: [
            const Text(
              'Waiting for Customer',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange),
            ),
            const SizedBox(height: 8),
            Text(
              timeString,
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.orange),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.phone),
                    label: const Text('Call'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.green),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: canMarkNoShow ? _markNoShow : null,
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('Mark No Show'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final minutes = (_trialSecondsRemaining / 60).floor();
    final seconds = _trialSecondsRemaining % 60;
    final timeString = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    final isTimeLow = _trialSecondsRemaining < 300;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isTimeLow ? Colors.red.shade50 : AbzioTheme.accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTimeLow ? Colors.red : AbzioTheme.accentColor,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Text(
            'Trial In Progress',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isTimeLow ? Colors.red.shade700 : AbzioTheme.accentColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            timeString,
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: isTimeLow ? Colors.red : Colors.black87,
            ),
          ),
          if (isTimeLow)
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Text(
                'Please prompt customer to finalize selection.',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
              ),
            ),
        ],
      ),
    );
  }
}
