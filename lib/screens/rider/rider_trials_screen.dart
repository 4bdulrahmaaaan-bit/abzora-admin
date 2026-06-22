import 'package:flutter/material.dart';
import '../../models/trial_session.dart';
import '../../theme.dart';
import '../../services/rider_trials_api.dart';
import '../../widgets/lazy_indexed_tab_view.dart';
import 'rider_trial_flow_screen.dart';

class RiderTrialsScreen extends StatefulWidget {
  const RiderTrialsScreen({super.key});

  @override
  State<RiderTrialsScreen> createState() => _RiderTrialsScreenState();
}

class _RiderTrialsScreenState extends State<RiderTrialsScreen> {
  List<TrialSession> _activeTrials = [];
  List<TrialSession> _assignedTrials = [];
  List<TrialSession> _completedTrials = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTrials();
  }

  Future<void> _fetchTrials() async {
    setState(() => _isLoading = true);
    try {
      final active = await RiderTrialsApi.getActiveTrials();
      final assigned = await RiderTrialsApi.getAssignedTrials();
      final completed = await RiderTrialsApi.getCompletedTrials();

      if (mounted) {
        setState(() {
          _activeTrials = active;
          _assignedTrials = assigned;
          _completedTrials = completed;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load trials: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F4EE),
        appBar: AppBar(
          title: const Text('TBYB Trial Trips'),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          bottom: const TabBar(
            labelColor: AbzioTheme.accentColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AbzioTheme.accentColor,
            tabs: [
              Tab(text: 'Active'),
              Tab(text: 'Upcoming'),
              Tab(text: 'Completed'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : LazyIndexedTabView(
                length: 3,
                itemBuilder: (context, index) {
                  switch (index) {
                    case 0:
                      return _buildTrialList(_activeTrials, 'No active trials.');
                    case 1:
                      return _buildTrialList(
                        _assignedTrials,
                        'No upcoming trials assigned to you.',
                      );
                    case 2:
                      return _buildTrialList(
                        _completedTrials,
                        'No completed trials yet.',
                      );
                    default:
                      return const SizedBox.shrink();
                  }
                },
              ),
      ),
    );
  }

  Widget _buildTrialList(List<TrialSession> trials, String emptyMessage) {
    if (trials.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: const TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchTrials,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: trials.length,
        itemBuilder: (context, index) {
          final trial = trials[index];
          final isActive =
              trial.status != 'assigned' &&
              trial.status != 'completed' &&
              trial.status != 'cancelled' &&
              trial.status != 'no_show';
          final isCompleted =
              trial.status == 'completed' ||
              trial.status == 'cancelled' ||
              trial.status == 'no_show';

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
                      isActive
                          ? 'Active Trial'
                          : (isCompleted ? 'Completed' : 'Upcoming Trial'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isActive
                            ? AbzioTheme.accentColor
                            : (isCompleted ? Colors.green : AbzioTheme.grey600),
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
                    const Icon(
                      Icons.timer_outlined,
                      size: 16,
                      color: AbzioTheme.accentColor,
                    ),
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
                      ).then((_) => _fetchTrials());
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: isActive
                          ? AbzioTheme.accentColor
                          : Colors.grey[800],
                    ),
                    child: Text(
                      isCompleted
                          ? 'View Details'
                          : (isActive ? 'Manage Trial' : 'Start Trip'),
                    ),
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
