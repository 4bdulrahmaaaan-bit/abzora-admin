import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/product_provider.dart';
import '../../services/location_service.dart';
import '../../theme.dart';

Future<void> showLocationBottomSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const _LocationBottomSheet(),
  );
}

class _LocationBottomSheet extends StatefulWidget {
  const _LocationBottomSheet();

  @override
  State<_LocationBottomSheet> createState() => _LocationBottomSheetState();
}

class _LocationBottomSheetState extends State<_LocationBottomSheet> {
  final TextEditingController _cityController = TextEditingController();

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final location = context.watch<LocationProvider>();
    final product = context.read<ProductProvider>();
    final user = auth.user;
    final filteredCities = location.manualCities
        .where((city) => city.toLowerCase().contains(_cityController.text.trim().toLowerCase()))
        .toList();
    final displayName = user?.name.trim().isNotEmpty == true ? user!.name.trim() : 'ABZORA Member';

    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: context.abzioBorder,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Choose delivery location',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Update your area and store radius without cluttering the home screen.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.abzioSecondaryText),
            ),
            const SizedBox(height: 18),
            _SectionLabel(title: 'Current Location'),
            const SizedBox(height: 10),
            _ActionCard(
              icon: Icons.my_location_rounded,
              title: 'Use Current Location (GPS)',
              subtitle: location.isLocationLoading
                  ? 'Detecting your current address...'
                  : location.locationPermissionBlocked
                      ? 'Location access needs permission'
                      : 'Refresh your exact delivery location',
              trailing: location.isLocationLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AbzioTheme.accentColor),
                    )
                  : null,
              onTap: () async {
                await product.requestLocationAccess();
                if (!mounted) {
                  return;
                }
                await auth.refreshCurrentUser();
              },
            ),
            if (location.locationStatus == LocationStatus.permissionDeniedForever ||
                location.locationStatus == LocationStatus.serviceDisabled) ...[
              const SizedBox(height: 10),
              _InlinePrompt(
                message: location.locationErrorMessage ?? 'Location access is unavailable.',
                actionLabel: location.locationStatus == LocationStatus.serviceDisabled ? 'Open settings' : 'App settings',
                onTap: () async {
                  if (location.locationStatus == LocationStatus.serviceDisabled) {
                    await location.openSystemLocationSettings();
                  } else {
                    await location.openSystemAppSettings();
                  }
                },
              ),
            ],
            const SizedBox(height: 20),
            _SectionLabel(title: 'Saved / Detected Address'),
            const SizedBox(height: 10),
            _ActionCard(
              icon: Icons.location_on_outlined,
              title: '$displayName, ${location.displayArea.isEmpty ? location.displayCity : location.displayArea}',
              subtitle: location.displayCity.isEmpty ? location.displayAddress : '${location.displayAddress}, ${location.displayCity}',
            ),
            const SizedBox(height: 20),
            _SectionLabel(title: 'Manual Location'),
            const SizedBox(height: 10),
            TextField(
              controller: _cityController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search city',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: filteredCities
                  .map(
                    (city) => ChoiceChip(
                      label: Text(city),
                      selected: location.activeLocation == city,
                      onSelected: (_) async {
                        await product.setManualLocation(city);
                        if (!mounted) {
                          return;
                        }
                        await auth.refreshCurrentUser();
                      },
                      selectedColor: AbzioTheme.accentColor.withValues(alpha: 0.18),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            _SectionLabel(title: 'Search Radius'),
            const SizedBox(height: 10),
            SegmentedButton<double>(
              showSelectedIcon: false,
              segments: LocationProvider.radiusOptionsKm
                  .map((radius) => ButtonSegment<double>(value: radius, label: Text('${radius.toInt()} km')))
                  .toList(),
              selected: {location.radiusKm},
              onSelectionChanged: (selected) async {
                final nextRadius = selected.first;
                await product.setRadiusKm(nextRadius);
                if (!mounted) {
                  return;
                }
                await auth.refreshCurrentUser();
              },
            ),
            const SizedBox(height: 12),
            Text(
              location.nearbyStores.isEmpty
                  ? 'No stores within ${location.radiusKm.toInt()} km yet.'
                  : '${location.nearbyStores.length} nearby store${location.nearbyStores.length == 1 ? '' : 's'} within ${location.radiusKm.toInt()} km.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.abzioSecondaryText),
            ),
            if (location.nearbyStores.isEmpty && location.radiusKm < LocationProvider.radiusOptionsKm.last) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    final currentIndex = LocationProvider.radiusOptionsKm.indexOf(location.radiusKm);
                    final nextRadius = LocationProvider.radiusOptionsKm[(currentIndex + 1).clamp(0, LocationProvider.radiusOptionsKm.length - 1)];
                    await product.setRadiusKm(nextRadius);
                    if (!mounted) {
                      return;
                    }
                    await auth.refreshCurrentUser();
                  },
                  child: Text('Expand to ${LocationProvider.radiusOptionsKm[LocationProvider.radiusOptionsKm.indexOf(location.radiusKm) + 1].toInt()} km'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AbzioTheme.accentColor),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.abzioBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Theme.of(context).inputDecorationTheme.fillColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AbzioTheme.accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.abzioSecondaryText)),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InlinePrompt extends StatelessWidget {
  const _InlinePrompt({
    required this.message,
    required this.actionLabel,
    required this.onTap,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).inputDecorationTheme.fillColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.abzioBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AbzioTheme.accentColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.abzioSecondaryText)),
          ),
          TextButton(onPressed: onTap, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
