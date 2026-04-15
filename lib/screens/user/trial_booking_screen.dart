import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/trial_home_provider.dart';
import '../../theme.dart';
import 'trial_status_screen.dart';

class TrialBookingScreen extends StatefulWidget {
  const TrialBookingScreen({
    super.key,
    required this.availableItems,
    required this.seedProduct,
    required this.addressLabel,
    this.recommendedItems = const <Product>[],
    this.recommendedSize = 'M',
    this.fitConfidence = 92,
  });

  final List<Product> availableItems;
  final List<Product> recommendedItems;
  final Product seedProduct;
  final String addressLabel;
  final String recommendedSize;
  final double fitConfidence;

  @override
  State<TrialBookingScreen> createState() => _TrialBookingScreenState();
}

class _TrialBookingScreenState extends State<TrialBookingScreen> {
  final Set<String> _selectedIds = <String>{};
  String _selectedSlot = 'Tomorrow | 6 PM to 9 PM';
  String _experienceType = 'premium';

  @override
  void initState() {
    super.initState();
    _selectedIds.add(widget.seedProduct.id);
  }

  List<Product> get _uniqueItems {
    final seen = <String>{};
    return [
      widget.seedProduct,
      ...widget.availableItems,
    ].where((product) => seen.add(product.id)).toList();
  }

  Future<void> _bookTrial() async {
    final provider = context.read<TrialHomeProvider>();
    final items = _uniqueItems
        .where((product) => _selectedIds.contains(product.id))
        .toList();
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one item to continue.')),
      );
      return;
    }

    try {
      final session = await provider.requestTrial(
        items: items,
        recommendedItems: widget.recommendedItems,
        addressLabel: widget.addressLabel,
        deliverySlot: _selectedSlot,
        experienceType: _experienceType,
        recommendedSize: widget.recommendedSize,
        fitConfidence: widget.fitConfidence,
      );
      if (!mounted) {
        return;
      }
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => TrialStatusScreen(trialId: session.id),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.error ?? 'We could not book your home trial right now.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TrialHomeProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EE),
      appBar: AppBar(
        title: const Text('Perfect Fit Experience'),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: FilledButton(
          onPressed: provider.loading ? null : _bookTrial,
          child: Text(provider.loading ? 'Submitting...' : 'Request Trial'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          _HeroIntro(addressLabel: widget.addressLabel),
          const SizedBox(height: 20),
          Text(
            'Choose items to try at home',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Select up to 5 ready-made styles. Tailoring stays optional if any fit needs adjustment.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ..._uniqueItems.map((product) {
            final selected = _selectedIds.contains(product.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SelectableTrialProductCard(
                product: product,
                selected: selected,
                recommendedSize: widget.recommendedSize,
                fitConfidence: widget.fitConfidence,
                onTap: () {
                  setState(() {
                    if (selected) {
                      _selectedIds.remove(product.id);
                    } else if (_selectedIds.length < 5) {
                      _selectedIds.add(product.id);
                    }
                  });
                },
              ),
            );
          }),
          const SizedBox(height: 20),
          Text(
            'Pick your trial time',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final slot in const [
                'Today | 7 PM to 10 PM',
                'Tomorrow | 6 PM to 9 PM',
                'Weekend | 11 AM to 2 PM',
              ])
                ChoiceChip(
                  label: Text(slot),
                  selected: _selectedSlot == slot,
                  onSelected: (_) => setState(() => _selectedSlot = slot),
                  selectedColor: AbzioTheme.accentColor.withValues(alpha: 0.18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                    side: BorderSide(
                      color: _selectedSlot == slot
                          ? AbzioTheme.accentColor
                          : AbzioTheme.grey300,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Experience type',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _ExperienceCard(
            title: 'Standard Trial',
            subtitle: 'Try at home at your convenience',
            selected: _experienceType == 'standard',
            onTap: () => setState(() => _experienceType = 'standard'),
          ),
          const SizedBox(height: 12),
          _ExperienceCard(
            title: 'Premium Stylist',
            subtitle: 'Get a stylist to assist your look',
            badge: 'Recommended',
            selected: _experienceType == 'premium',
            onTap: () => setState(() => _experienceType = 'premium'),
          ),
          if (provider.error != null) ...[
            const SizedBox(height: 16),
            _InlineError(message: provider.error!),
          ],
        ],
      ),
    );
  }
}

class _HeroIntro extends StatelessWidget {
  const _HeroIntro({required this.addressLabel});

  final String addressLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF23201C), Color(0xFF5E4A2B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: AbzioTheme.eliteShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Luxury styling, delivered home',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: const Color(0xFFF2D7A0),
                ),
          ),
          const SizedBox(height: 10),
          Text(
            'Try ready-made first. Pay only for what you keep.',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            addressLabel,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.78),
                ),
          ),
        ],
      ),
    );
  }
}

class _SelectableTrialProductCard extends StatelessWidget {
  const _SelectableTrialProductCard({
    required this.product,
    required this.selected,
    required this.recommendedSize,
    required this.fitConfidence,
    required this.onTap,
  });

  final Product product;
  final bool selected;
  final String recommendedSize;
  final double fitConfidence;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? AbzioTheme.accentColor : AbzioTheme.grey300,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 72,
                height: 88,
                child: product.images.isEmpty
                    ? Container(color: AbzioTheme.grey200)
                    : Image.network(
                        product.images.first,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(color: AbzioTheme.grey200),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                Text(
                    '${fitConfidence.toStringAsFixed(0)}% fit match | Size $recommendedSize',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\u20B9${product.effectivePrice.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ),
            Checkbox.adaptive(
              value: selected,
              onChanged: (_) => onTap(),
              activeColor: AbzioTheme.accentColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExperienceCard extends StatelessWidget {
  const _ExperienceCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AbzioTheme.accentColor : AbzioTheme.grey300,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleMedium),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AbzioTheme.accentColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            badge!,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: const Color(0xFF7D5A19),
                                ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AbzioTheme.accentColor : AbzioTheme.grey500,
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFD65D4B)),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

