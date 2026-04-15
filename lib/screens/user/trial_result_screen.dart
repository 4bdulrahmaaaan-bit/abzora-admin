import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/trial_session.dart';
import '../../providers/trial_home_provider.dart';
import '../../theme.dart';
import 'trial_tailoring_conversion_screen.dart';

class TrialResultScreen extends StatefulWidget {
  const TrialResultScreen({
    super.key,
    required this.trialId,
  });

  final String trialId;

  @override
  State<TrialResultScreen> createState() => _TrialResultScreenState();
}

class _TrialResultScreenState extends State<TrialResultScreen> {
  final Map<String, bool> _keptSelections = <String, bool>{};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final provider = context.read<TrialHomeProvider>();
    try {
      final session = await provider.fetchTrialById(widget.trialId);
      if (!mounted) {
        return;
      }
      setState(() {
        for (final item in session.items) {
          _keptSelections[item.productId] = true;
        }
      });
    } catch (_) {}
  }

  Future<void> _confirmKeepReturn() async {
    final provider = context.read<TrialHomeProvider>();
    final session = provider.currentTrial;
    if (session == null) {
      return;
    }

    final keptItems = _keptSelections.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
    final returnedItems = _keptSelections.entries
        .where((entry) => !entry.value)
        .map((entry) => entry.key)
        .toList();

    if (keptItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose at least one item to keep or convert to tailoring.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await provider.completeTrial(
        trialId: session.id,
        keptItems: keptItems,
        returnedItems: returnedItems,
        useTailoring: false,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order conversion confirmed.')),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.error ?? 'We could not confirm your trial decision.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _openTailoring() async {
    final provider = context.read<TrialHomeProvider>();
    final session = provider.currentTrial;
    if (session == null) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrialTailoringConversionScreen(trialId: session.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TrialHomeProvider>();
    final session = provider.currentTrial;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EE),
      appBar: AppBar(title: const Text('Decision')),
      body: session == null
          ? Center(
              child: provider.loading
                  ? const CircularProgressIndicator()
                  : Text(provider.error ?? 'No trial session found.'),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 140),
              children: [
                _ResultHero(session: session),
                const SizedBox(height: 20),
                Text(
                  'Keep or return',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Pick what you loved from ready-made pieces. Return the rest with zero pressure.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                ...session.items.map((item) {
                  final keep = _keptSelections[item.productId] ?? true;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Size ${item.recommendedSize.isEmpty ? session.recommendedSize : item.recommendedSize} | ${item.fitConfidence.toStringAsFixed(0)}% fit confidence',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: keep,
                            activeThumbColor: AbzioTheme.accentColor,
                            activeTrackColor:
                                AbzioTheme.accentColor.withValues(alpha: 0.45),
                            onChanged: (value) {
                              setState(
                                () => _keptSelections[item.productId] = value,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                if (provider.error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4F2),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(provider.error!),
                  ),
                ],
              ],
            ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ? null : _openTailoring,
                child: const Text('Optional Tailoring'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _saving ? null : _confirmKeepReturn,
                child: Text(_saving ? 'Saving...' : 'Confirm Keep/Return'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultHero extends StatelessWidget {
  const _ResultHero({required this.session});

  final TrialSession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF1F1B17), Color(0xFF5F4A2A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Fit Profile Is Ready',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Recommended size ${session.recommendedSize.isEmpty ? 'M' : session.recommendedSize} | ${session.fitConfidence.toStringAsFixed(0)}% confidence',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.75),
                ),
          ),
        ],
      ),
    );
  }
}
