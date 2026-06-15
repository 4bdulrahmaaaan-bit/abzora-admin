import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/vendor/theme/vendor_theme.dart';

class ExpertiseStep extends StatelessWidget {
  final TextEditingController experienceYearsController;
  final Set<String> specializations;
  final Set<String> serviceTypes;
  final List<String> storeTags;
  final ValueChanged<String> onToggleSpecialization;
  final ValueChanged<String> onToggleServiceType;
  final ValueChanged<String> onToggleStoreTag;
  final VoidCallback onChanged;

  const ExpertiseStep({
    super.key,
    required this.experienceYearsController,
    required this.specializations,
    required this.serviceTypes,
    required this.storeTags,
    required this.onToggleSpecialization,
    required this.onToggleServiceType,
    required this.onToggleStoreTag,
    required this.onChanged,
  });

  static const List<Map<String, dynamic>> _serviceTypeOptions = [
    {'name': 'Ready-made', 'icon': Icons.checkroom_outlined},
    {'name': 'Custom Tailoring', 'icon': Icons.content_cut_outlined},
    {'name': 'Alterations', 'icon': Icons.straighten_outlined},
    {'name': 'Premium Collections', 'icon': Icons.diamond_outlined},
    {'name': 'Bridal Wear', 'icon': Icons.favorite_border},
  ];

  static const List<Map<String, dynamic>> _specializationOptions = [
    {'name': 'Men\'s Wear', 'icon': Icons.man_outlined},
    {'name': 'Women\'s Wear', 'icon': Icons.woman_outlined},
    {'name': 'Kids Wear', 'icon': Icons.child_care_outlined},
    {'name': 'Ethnic', 'icon': Icons.festival_outlined},
    {'name': 'Formal', 'icon': Icons.business_center_outlined},
    {'name': 'Streetwear', 'icon': Icons.skateboarding_outlined},
    {'name': 'Uniforms', 'icon': Icons.badge_outlined},
  ];

  static const List<Map<String, dynamic>> _storeTagOptions = [
    {'name': 'Premium', 'icon': Icons.star_border},
    {'name': 'Affordable', 'icon': Icons.sell_outlined},
    {'name': 'Express Delivery', 'icon': Icons.local_shipping_outlined},
    {'name': 'Eco-Friendly', 'icon': Icons.eco_outlined},
    {'name': 'Handmade', 'icon': Icons.back_hand_outlined},
    {'name': 'Trending', 'icon': Icons.trending_up_outlined},
    {'name': 'Vintage', 'icon': Icons.history_outlined},
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      children: [
        _buildCard(
          context: context,
          title: 'Experience & Craft',
          children: [
            _buildExperienceMeter(),
            const SizedBox(height: 24),
            _buildSectionTitle(context, 'Fashion Categories'),
            const SizedBox(height: 12),
            _buildChips(
              options: _specializationOptions,
              selected: specializations,
              onSelected: onToggleSpecialization,
            ),
            const SizedBox(height: 24),
            _buildSectionTitle(context, 'Service Types'),
            const SizedBox(height: 12),
            _buildChips(
              options: _serviceTypeOptions,
              selected: serviceTypes,
              onSelected: onToggleServiceType,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionTitle(context, 'Store Tags'),
                Text(
                  '${storeTags.length}/5',
                  style: const TextStyle(color: VendorTheme.onboardingSecondaryText, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildChips(
              options: _storeTagOptions,
              selected: storeTags.toSet(),
              onSelected: onToggleStoreTag,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCard({required BuildContext context, required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: VendorTheme.onboardingSurface,
        borderRadius: BorderRadius.circular(VendorTheme.radiusMedium),
        border: Border.all(color: VendorTheme.onboardingElevatedSurface),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: VendorTheme.onboardingPrimaryText,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: VendorTheme.onboardingPrimaryText,
            fontWeight: FontWeight.w600,
          ),
    );
  }

  Widget _buildChips({
    required List<Map<String, dynamic>> options,
    required Set<String> selected,
    required ValueChanged<String> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((item) {
        final name = item['name'] as String;
        final icon = item['icon'] as IconData;
        final isSelected = selected.contains(name);
        return ChoiceChip(
          avatar: Icon(
            icon, 
            size: 16, 
            color: isSelected ? VendorTheme.onboardingBackground : VendorTheme.onboardingGold
          ),
          label: Text(name),
          selected: isSelected,
          selectedColor: VendorTheme.onboardingGold,
          backgroundColor: Colors.transparent,
          showCheckmark: false,
          labelStyle: TextStyle(
            color: isSelected ? VendorTheme.onboardingBackground : VendorTheme.onboardingGold,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: VendorTheme.onboardingGold.withValues(alpha: isSelected ? 1.0 : 0.5),
            ),
          ),
          onSelected: (_) => onSelected(name),
        );
      }).toList(),
    );
  }

  Widget _buildExperienceMeter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: experienceYearsController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(color: VendorTheme.onboardingPrimaryText, fontSize: 15),
            decoration: InputDecoration(
              labelText: 'Years of Experience',
              labelStyle: const TextStyle(color: VendorTheme.onboardingSecondaryText),
              filled: true,
              fillColor: VendorTheme.onboardingElevatedSurface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              prefixIcon: const Icon(Icons.history, color: VendorTheme.onboardingSecondaryText, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(VendorTheme.radiusSmall),
                borderSide: const BorderSide(color: Colors.transparent),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(VendorTheme.radiusSmall),
                borderSide: const BorderSide(color: Colors.transparent),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(VendorTheme.radiusSmall),
                borderSide: const BorderSide(color: VendorTheme.onboardingGold, width: 1.5),
              ),
            ),
            onChanged: (_) => onChanged(),
          ),
        ),
        AnimatedBuilder(
          animation: experienceYearsController,
          builder: (context, _) {
            final years = int.tryParse(experienceYearsController.text) ?? 0;
            String level = 'Beginner';
            Color levelColor = VendorTheme.onboardingSecondaryText;
            double progress = 0.25;

            if (years >= 2) {
              level = 'Intermediate';
              levelColor = VendorTheme.onboardingSuccess;
              progress = 0.5;
            }
            if (years >= 5) {
              level = 'Advanced';
              levelColor = VendorTheme.onboardingWarning;
              progress = 0.75;
            }
            if (years >= 10) {
              level = 'Expert';
              levelColor = VendorTheme.onboardingGold;
              progress = 1.0;
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Experience Level', style: TextStyle(color: VendorTheme.onboardingSecondaryText, fontSize: 13)),
                    Text(level, style: TextStyle(color: levelColor, fontWeight: FontWeight.w700, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: VendorTheme.onboardingElevatedSurface,
                    valueColor: AlwaysStoppedAnimation<Color>(levelColor),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
