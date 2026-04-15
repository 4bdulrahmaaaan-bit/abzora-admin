import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/trial_session.dart';
import '../../providers/trial_home_provider.dart';
import '../../theme.dart';
import 'trial_result_screen.dart';

class TrialInProgressScreen extends StatefulWidget {
  const TrialInProgressScreen({
    super.key,
    required this.trialId,
  });

  final String trialId;

  @override
  State<TrialInProgressScreen> createState() => _TrialInProgressScreenState();
}

class _TrialInProgressScreenState extends State<TrialInProgressScreen> {
  String _fit = 'perfect';
  bool _saving = false;

  Future<void> _submitLiveFeedback() async {
    final provider = context.read<TrialHomeProvider>();
    final session = provider.currentTrial;
    if (session == null) {
      return;
    }

    setState(() => _saving = true);
    try {
      final updated = await provider.submitFeedback(
        trialId: widget.trialId,
        fit: _fit,
        note: _fit == 'perfect'
            ? 'Fit looked great during home trial.'
            : 'Customer asked for adjustment support.',
        tailoringRecommendation:
            _fit == 'perfect' ? '' : 'Adjust with custom tailoring',
        status: 'completed',
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => TrialResultScreen(trialId: updated.id),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.error ?? 'Unable to save your fit feedback right now.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TrialHomeProvider>();
    final session = provider.currentTrial;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EE),
      appBar: AppBar(title: const Text('Trial In Progress')),
      body: session == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
              children: [
                _LiveHero(session: session),
                const SizedBox(height: 20),
                Text(
                  'How does it feel right now?',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your feedback helps us confirm ready-made fit first, then suggest tailoring only if needed.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: const [
                    ('perfect', 'Perfect'),
                    ('too_tight', 'Too tight'),
                    ('too_loose', 'Too loose'),
                  ].map((entry) {
                    final selected = _fit == entry.$1;
                    return ChoiceChip(
                      label: Text(entry.$2),
                      selected: selected,
                      selectedColor:
                          AbzioTheme.accentColor.withValues(alpha: 0.2),
                      onSelected: (_) => setState(() => _fit = entry.$1),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFF8C651D),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _fit == 'perfect'
                              ? 'Great. We will lock this ready-to-wear fit profile for faster checkouts.'
                              : 'We can recommend optional tailoring after this trial if you want a refined fit.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                if (provider.error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    provider.error!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFFB94A2D),
                        ),
                  ),
                ],
              ],
            ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: FilledButton(
          onPressed: _saving ? null : _submitLiveFeedback,
          child: Text(_saving ? 'Saving...' : 'Continue to Decision'),
        ),
      ),
    );
  }
}

class _LiveHero extends StatelessWidget {
  const _LiveHero({required this.session});

  final TrialSession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1A16), Color(0xFF5C4828)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A personal fitting room came home',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Size ${session.recommendedSize.isEmpty ? 'M' : session.recommendedSize} with ${session.fitConfidence.toStringAsFixed(0)}% confidence',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.78),
                ),
          ),
        ],
      ),
    );
  }
}
