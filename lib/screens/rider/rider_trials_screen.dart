import 'package:flutter/material.dart';
import '../../models/trial_session.dart';
import '../../theme.dart';
import 'rider_trial_flow_screen.dart';

class RiderTrialsScreen extends StatefulWidget {
  const RiderTrialsScreen({super.key});

  @override
  State<RiderTrialsScreen> createState() => _RiderTrialsScreenState();
}

class _RiderTrialsScreenState extends State<RiderTrialsScreen> {
  // In a real implementation, fetch this from an API endpoint for Rider Assigned Trials
  final List<TrialSession> _mockTrials = [
    TrialSession(
      id: 'tbyb-active-001',
      userId: 'user_mock',
      items: const [], // Mock items
      status: 'in_transit',
      addressLabel: '123 Fashion Street, Mumbai',
      deliverySlot: 'Today | 4 PM - 6 PM',
      deliveryWindowLabel: '15 Minutes',
      trialFee: 99,
      subtotal: 0,
      bookingFeePaid: true,
      trialDurationMinutes: 15,
    ),
    TrialSession(
      id: 'tbyb-upcoming-002',
      userId: 'user_mock2',
      items: const [],
      status: 'assigned',
      addressLabel: '456 Trend Ave, Delhi',
      deliverySlot: 'Tomorrow | 10 AM - 12 PM',
      deliveryWindowLabel: '15 Minutes',
      trialFee: 99,
      subtotal: 0,
      bookingFeePaid: true,
      trialDurationMinutes: 15,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EE),
      appBar: AppBar(
        title: const Text('TBYB Trial Trips'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _mockTrials.length,
        itemBuilder: (context, index) {
          final trial = _mockTrials[index];
          final isActive = trial.status == 'in_transit' || trial.status == 'in_progress';
          
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AbzioTheme.eliteShadow,
              border: Border.all(
                color: isActive ? AbzioTheme.accentColor : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isActive ? 'Active Trial' : 'Upcoming Trial',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isActive ? AbzioTheme.accentColor : AbzioTheme.grey600,
                      ),
                    ),
                    Text(
                      trial.deliverySlot,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  trial.addressLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 16, color: AbzioTheme.accentColor),
                    const SizedBox(width: 4),
                    Text('Duration: ${trial.trialDurationMinutes} Minutes'),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RiderTrialFlowScreen(session: trial),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: isActive ? AbzioTheme.accentColor : Colors.grey[800],
                    ),
                    child: Text(isActive ? 'Manage Trial' : 'View Details'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
