import 'package:flutter/material.dart';
import 'dart:async';
import '../../../models/trial_session.dart';
import '../../../theme.dart';
import 'package:provider/provider.dart';
import '../../../providers/trial_home_provider.dart';
import 'tbyb_final_bill_screen.dart';

class TbybActiveTrialScreen extends StatefulWidget {
  const TbybActiveTrialScreen({super.key, required this.session});

  final TrialSession session;

  @override
  State<TbybActiveTrialScreen> createState() => _TbybActiveTrialScreenState();
}

class _TbybActiveTrialScreenState extends State<TbybActiveTrialScreen> {
  // Simulating the state transition from tracking -> trial in progress
  bool _isTrialInProgress = false;

  final Map<String, bool> _keepDecisions = {};
  Timer? _timer;
  int _secondsRemaining = 0;

  @override
  void initState() {
    super.initState();
    for (final item in widget.session.items) {
      _keepDecisions[item.productId] = true; // Default to keep
    }
    if (widget.session.trialStartedAt != null) {
      _isTrialInProgress = true;
      _startTimer();
    }
  }

  void _startTimer() {
    _secondsRemaining = widget.session.trialDurationMinutes * 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_secondsRemaining > 0) _secondsRemaining--;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _onContinueToBill() async {
    _timer?.cancel(); // Stop the timer early
    final keptItems = _keepDecisions.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    final returnedItems = _keepDecisions.entries
        .where((e) => !e.value)
        .map((e) => e.key)
        .toList();

    try {
      final provider = context.read<TrialHomeProvider>();
      final updatedSession = await provider.awaitFinalPayment(
        trialId: widget.session.id,
        keptItems: keptItems,
        returnedItems: returnedItems,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TbybFinalBillScreen(
            session: updatedSession,
            keptItems: keptItems,
            returnedItems: returnedItems,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EE),
      appBar: AppBar(
        title: Text(_isTrialInProgress ? 'Choose What To Keep' : 'Track Trial'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (!_isTrialInProgress)
            TextButton(
              onPressed: () {
                setState(() => _isTrialInProgress = true);
                _startTimer();
              },
              child: const Text('Simulate Arrival'),
            ),
        ],
      ),
      body: _isTrialInProgress ? _buildTrialInProgress() : _buildTracking(),
    );
  }

  Widget _buildTracking() {
    return Column(
      children: [
        // Mock Map Area
        Expanded(
          flex: 2,
          child: Container(
            width: double.infinity,
            color: const Color(0xFFE5E9EA), // Map background mock
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.map,
                  size: 100,
                  color: Colors.black.withValues(alpha: 0.1),
                ),
                const Text(
                  'Live Rider Tracking Map',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                Positioned(
                  bottom: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: AbzioTheme.eliteShadow,
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.timer,
                          color: AbzioTheme.accentColor,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Estimated Arrival: 25 Minutes',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Details Area
        Expanded(
          flex: 3,
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
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AbzioTheme.grey200,
                      child: const Icon(
                        Icons.person,
                        color: AbzioTheme.grey500,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Rider Name',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '+91 9876543210 • MH 01 AB 1234',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AbzioTheme.grey500),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.phone, color: Colors.green),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Status Timeline',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              _StatusNode(title: 'Booking Confirmed', isCompleted: true),
              _StatusNode(title: 'Rider Assigned', isCompleted: true),
              _StatusNode(title: 'Items Picked Up', isCompleted: true),
              _StatusNode(
                title: 'Out For Delivery',
                isCompleted: true,
                isCurrent: true,
              ),
              _StatusNode(title: 'Arrived', isCompleted: false, isLast: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrialInProgress() {
    int keptCount = _keepDecisions.values.where((v) => v).length;
    int returnedCount = _keepDecisions.values.where((v) => !v).length;

    double keptTotal = 0;
    for (final item in widget.session.items) {
      if (_keepDecisions[item.productId] == true) {
        keptTotal += item.price;
      }
    }

    final minutes = (_secondsRemaining / 60).floor();
    final seconds = _secondsRemaining % 60;
    final timeString =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    final isTimeLow = _secondsRemaining < 300; // less than 5 minutes

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: isTimeLow
              ? Colors.red.shade50
              : AbzioTheme.accentColor.withValues(alpha: 0.1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.timer,
                color: isTimeLow ? Colors.red : AbzioTheme.accentColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Time Remaining: $timeString',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isTimeLow ? Colors.red : AbzioTheme.accentColor,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          color: Colors.white,
          width: double.infinity,
          child: const Text(
            'Select the products you\'d like to keep.',
            style: TextStyle(fontSize: 16),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: widget.session.items.length,
            itemBuilder: (context, index) {
              final item = widget.session.items[index];
              final isKeeping = _keepDecisions[item.productId] ?? true;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isKeeping
                          ? AbzioTheme.accentColor
                          : AbzioTheme.grey300,
                      width: isKeeping ? 1.5 : 1,
                    ),
                    boxShadow: AbzioTheme.eliteShadow,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 60,
                              height: 80,
                              color: AbzioTheme.grey200,
                              child: item.imageUrl.isNotEmpty
                                  ? Image.network(
                                      item.imageUrl,
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '₹${item.price.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(height: 1),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(
                                  () => _keepDecisions[item.productId] = false,
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: !isKeeping
                                    ? Colors.red
                                    : AbzioTheme.grey600,
                                side: BorderSide(
                                  color: !isKeeping
                                      ? Colors.red
                                      : AbzioTheme.grey300,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Return Item'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                setState(
                                  () => _keepDecisions[item.productId] = true,
                                );
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: isKeeping
                                    ? AbzioTheme.accentColor
                                    : AbzioTheme.grey200,
                                foregroundColor: isKeeping
                                    ? Colors.white
                                    : Colors.black87,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Keep Item'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(context).padding.bottom + 16,
          ),
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
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$keptCount Items Kept',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  Text(
                    '$returnedCount Items Returned',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Estimated Total',
                    style: TextStyle(color: AbzioTheme.grey600),
                  ),
                  Text(
                    '₹${keptTotal.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _onContinueToBill,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: AbzioTheme.accentColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Done Trying',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusNode extends StatelessWidget {
  const _StatusNode({
    required this.title,
    required this.isCompleted,
    this.isCurrent = false,
    this.isLast = false,
  });

  final String title;
  final bool isCompleted;
  final bool isCurrent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted ? Colors.green : Colors.transparent,
                  border: Border.all(
                    color: isCompleted ? Colors.green : AbzioTheme.grey300,
                    width: 2,
                  ),
                ),
                child: isCompleted
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : (isCurrent
                          ? Container(
                              margin: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AbzioTheme.accentColor,
                                shape: BoxShape.circle,
                              ),
                            )
                          : null),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isCompleted ? Colors.green : AbzioTheme.grey200,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
              child: Text(
                title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: isCurrent
                      ? FontWeight.bold
                      : (isCompleted ? FontWeight.w500 : FontWeight.normal),
                  color: isCompleted ? Colors.black87 : AbzioTheme.grey500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
