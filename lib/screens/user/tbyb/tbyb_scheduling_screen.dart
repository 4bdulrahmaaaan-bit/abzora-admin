import 'package:flutter/material.dart';
import '../../../models/models.dart';
import '../../../theme.dart';
import 'tbyb_address_screen.dart';

class TbybSchedulingScreen extends StatefulWidget {
  const TbybSchedulingScreen({
    super.key,
    required this.selectedItems,
  });

  final List<Product> selectedItems;

  @override
  State<TbybSchedulingScreen> createState() => _TbybSchedulingScreenState();
}

class _TbybSchedulingScreenState extends State<TbybSchedulingScreen> {
  String _selectedDate = 'Tomorrow';
  String _selectedTime = '6 PM – 8 PM';
  final int _selectedDuration = 15;

  final List<String> _dates = ['Today', 'Tomorrow', 'Select Custom Date'];
  final List<String> _times = [
    '10 AM – 12 PM',
    '12 PM – 2 PM',
    '2 PM – 4 PM',
    '4 PM – 6 PM',
    '6 PM – 8 PM',
    '8 PM – 10 PM',
  ];

  void _onContinue() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TbybAddressScreen(
          selectedItems: widget.selectedItems,
          deliveryDate: _selectedDate,
          deliveryTime: _selectedTime,
          trialDurationMinutes: _selectedDuration,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EE),
      appBar: AppBar(
        title: const Text('Schedule Delivery'),
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
                _SectionTitle(title: 'Choose Delivery Date', subtitle: 'When should we deliver?'),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _dates.map((date) {
                    final isSelected = _selectedDate == date;
                    return ChoiceChip(
                      label: Text(date),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() => _selectedDate = date);
                      },
                      selectedColor: AbzioTheme.accentColor.withValues(alpha: 0.1),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected ? AbzioTheme.accentColor : AbzioTheme.grey300,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      labelStyle: TextStyle(
                        color: isSelected ? AbzioTheme.accentColor : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),
                _SectionTitle(title: 'Choose Delivery Time', subtitle: 'Select when you\'d like your products delivered.'),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _times.map((time) {
                    final isSelected = _selectedTime == time;
                    return ChoiceChip(
                      label: Text(time),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() => _selectedTime = time);
                      },
                      selectedColor: AbzioTheme.accentColor.withValues(alpha: 0.1),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected ? AbzioTheme.accentColor : AbzioTheme.grey300,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      labelStyle: TextStyle(
                        color: isSelected ? AbzioTheme.accentColor : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),
                _SectionTitle(title: 'Trial Duration', subtitle: 'Standard Trial Duration is 15 Minutes.'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F4FD),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFF2C74B3), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'You will have 15 minutes to try your selected products once the rider arrives.',
                          style: const TextStyle(color: Color(0xFF2C74B3), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
            child: FilledButton(
              onPressed: _onContinue,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                backgroundColor: AbzioTheme.accentColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AbzioTheme.grey500),
        ),
      ],
    );
  }
}
