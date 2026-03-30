import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';

class AddressCard extends StatelessWidget {
  const AddressCard({
    super.key,
    required this.address,
    required this.onChange,
  });

  final UserAddress? address;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final addressValue = address;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.abzioBorder),
        boxShadow: context.abzioShadow,
      ),
      child: addressValue == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add a delivery address',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose where you want your order delivered before you continue.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: onChange,
                  child: const Text('Add address'),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            addressValue.name,
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatPhone(addressValue.phone),
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _compactAddress(addressValue),
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AbzioTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: onChange,
                      child: const Text('Change'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: context.abzioMuted,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 18, color: context.abzioSecondaryText),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _fullAddress(addressValue),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: context.abzioSecondaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  static String _formatPhone(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Phone not added';
    }
    return trimmed.startsWith('+') ? trimmed : '+91 $trimmed';
  }

  static String _compactAddress(UserAddress address) {
    final parts = <String>[
      if (address.locality.trim().isNotEmpty) address.locality.trim(),
      if (address.city.trim().isNotEmpty) address.city.trim(),
    ];
    final line = parts.join(', ');
    if (address.pincode.trim().isEmpty) {
      return line;
    }
    return line.isEmpty ? address.pincode.trim() : '$line - ${address.pincode.trim()}';
  }

  static String _fullAddress(UserAddress address) {
    return [
      if (address.houseDetails.trim().isNotEmpty) address.houseDetails.trim(),
      if (address.addressLine.trim().isNotEmpty) address.addressLine.trim(),
      if (address.landmark.trim().isNotEmpty) address.landmark.trim(),
      if (address.locality.trim().isNotEmpty) address.locality.trim(),
      if (address.city.trim().isNotEmpty) address.city.trim(),
      if (address.state.trim().isNotEmpty) address.state.trim(),
      if (address.pincode.trim().isNotEmpty) address.pincode.trim(),
    ].join(', ');
  }
}
