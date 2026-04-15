import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/trial_home_provider.dart';

class TrialTailoringConversionScreen extends StatefulWidget {
  const TrialTailoringConversionScreen({
    super.key,
    required this.trialId,
  });

  final String trialId;

  @override
  State<TrialTailoringConversionScreen> createState() =>
      _TrialTailoringConversionScreenState();
}

class _TrialTailoringConversionScreenState
    extends State<TrialTailoringConversionScreen> {
  final Set<String> _adjustments = <String>{'Tighten fit'};
  final TextEditingController _notesController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final provider = context.read<TrialHomeProvider>();
    setState(() => _saving = true);
    try {
      await provider.completeTrial(
        trialId: widget.trialId,
        keptItems: const <String>[],
        returnedItems: const <String>[],
        useTailoring: true,
        tailoringRequest: _notesController.text.trim().isEmpty
            ? 'Please refine this fit for my body profile.'
            : _notesController.text.trim(),
        adjustmentOptions: _adjustments.toList(),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tailoring conversion is confirmed.')),
      );
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.error ?? 'Unable to create tailoring request right now.',
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
    const options = <String>[
      'Tighten fit',
      'Loosen fit',
      'Adjust length',
      'Custom stitch upgrade',
    ];
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EE),
      appBar: AppBar(title: const Text('Tailoring Conversion')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFF1D1915), Color(0xFF5A4526)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Make this perfect for you',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'ABZORA will convert your trial into a custom tailoring request.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Select adjustments',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: options.map((option) {
              final selected = _adjustments.contains(option);
              return FilterChip(
                label: Text(option),
                selected: selected,
                onSelected: (value) {
                  setState(() {
                    if (value) {
                      _adjustments.add(option);
                    } else {
                      _adjustments.remove(option);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _notesController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Any stylist notes for our atelier team?',
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(_saving ? 'Submitting...' : 'Confirm Tailoring Request'),
        ),
      ),
    );
  }
}
