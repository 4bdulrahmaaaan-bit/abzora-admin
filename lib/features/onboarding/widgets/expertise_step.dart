import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  static const List<String> _serviceTypeOptions = [
    'Ready-made',
    'Custom Tailoring',
    'Alterations',
    'Premium Collections',
    'Bridal Wear',
  ];

  static const List<String> _specializationOptions = [
    'Men\'s Wear',
    'Women\'s Wear',
    'Kids Wear',
    'Ethnic',
    'Formal',
    'Streetwear',
    'Uniforms',
  ];

  static const List<String> _storeTagOptions = [
    'Premium',
    'Affordable',
    'Express Delivery',
    'Eco-Friendly',
    'Handmade',
    'Trending',
    'Vintage',
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      children: [
        _buildCard(
          title: 'Experience & Craft',
          children: [
            _buildExperienceMeter(),
            const SizedBox(height: 24),
            _buildSectionTitle('Fashion Categories'),
            const SizedBox(height: 12),
            _buildChips(
              options: _specializationOptions,
              selected: specializations,
              onSelected: onToggleSpecialization,
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Service Types'),
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
                _buildSectionTitle('Store Tags'),
                Text(
                  '${storeTags.length}/5',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
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

  Widget _buildCard({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildChips({
    required List<String> options,
    required Set<String> selected,
    required ValueChanged<String> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((item) {
        final isSelected = selected.contains(item);
        return ChoiceChip(
          label: Text(item),
          selected: isSelected,
          selectedColor: Colors.white,
          backgroundColor: Colors.transparent,
          labelStyle: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isSelected ? Colors.white : Colors.white24,
            ),
          ),
          onSelected: (_) => onSelected(item),
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
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              labelText: 'Years of Experience',
              labelStyle: const TextStyle(color: Colors.white60),
              filled: true,
              fillColor: Colors.black26,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.white, width: 1.5),
              ),
            ),
            onChanged: (_) => onChanged(),
          ),
        ),
        AnimatedBuilder(
          animation: experienceYearsController,
          builder: (context, _) {
            final years = int.tryParse(experienceYearsController.text) ?? 0;
            int stars = 1;
            if (years >= 2) stars = 2;
            if (years >= 5) stars = 3;
            if (years >= 10) stars = 4;
            if (years >= 15) stars = 5;

            return Row(
              children: [
                const Text('Experience Rating:', style: TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(width: 8),
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      index < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: index < stars ? Colors.amber : Colors.white24,
                      size: 18,
                    );
                  }),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
