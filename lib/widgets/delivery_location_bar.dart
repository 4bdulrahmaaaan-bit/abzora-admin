import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/location_provider.dart';
import 'tap_scale.dart';
import 'location_selection_sheet.dart';

class DeliveryLocationBar extends StatelessWidget {
  const DeliveryLocationBar({
    super.key,
    this.backgroundColor = const Color(0xFFF7F4ED),
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  final Color backgroundColor;
  final EdgeInsetsGeometry padding;

  String _composeDeliveryLine({
    required String? recipientName,
    required String locationLine,
  }) {
    final recipient = recipientName?.trim() ?? '';
    final location = locationLine.trim();
    if (recipient.isNotEmpty && location.isNotEmpty) {
      return '$recipient • $location';
    }
    if (recipient.isNotEmpty) {
      return recipient;
    }
    if (location.isNotEmpty) {
      return location;
    }
    return 'Choose delivery location';
  }

  String _composeSemanticsLabel({
    required String? recipientName,
    required String locationLine,
  }) {
    final recipient = recipientName?.trim() ?? '';
    final location = locationLine.trim().replaceAll('•', ',');
    if (recipient.isNotEmpty && location.isNotEmpty) {
      return 'Delivering to $recipient, $location.';
    }
    if (location.isNotEmpty) {
      return 'Delivering to $location.';
    }
    return 'Choose delivery location.';
  }

  void _openLocationSheet(BuildContext context) {
    LocationSelectionSheet.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recipientName = context.select<AuthProvider, String?>((auth) {
      final name = auth.user?.name.trim() ?? '';
      return name.isNotEmpty ? name : null;
    });
    
    final activeLocation = context.select<LocationProvider, String>((loc) {
      return loc.activeLocation;
    });

    final deliveryLine = _composeDeliveryLine(
      recipientName: recipientName,
      locationLine: activeLocation,
    );
    final semanticsLabel = _composeSemanticsLabel(
      recipientName: recipientName,
      locationLine: activeLocation,
    );

    return Container(
      color: backgroundColor,
      padding: padding,
      child: Semantics(
        button: true,
        label: semanticsLabel,
        child: TapScale(
          scale: 0.985,
          onTap: () => _openLocationSheet(context),
          child: SizedBox(
            width: double.infinity,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: Color(0xFFC2A15E),
                ),
                const SizedBox(width: 6),
                Flexible(
                  fit: FlexFit.loose,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Deliver to ',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF7C7265),
                                height: 1.1,
                              ),
                            ),
                            TextSpan(
                              text: deliveryLine,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF171411),
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                        key: ValueKey(deliveryLine),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.left,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: Color(0xFFC2A15E),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
