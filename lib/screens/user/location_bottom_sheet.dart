import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/product_provider.dart';
import '../../services/database_service.dart';
import '../../services/location_service.dart';
import '../../theme.dart';

Future<void> showLocationBottomSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _LocationBottomSheet(),
  );
}

class _LocationBottomSheet extends StatefulWidget {
  const _LocationBottomSheet();

  @override
  State<_LocationBottomSheet> createState() => _LocationBottomSheetState();
}

class _LocationBottomSheetState extends State<_LocationBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  final DatabaseService _database = DatabaseService();

  List<UserAddress> _savedAddresses = const [];
  bool _isLoadingSavedAddresses = true;
  bool _isApplyingSavedAddress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _loadSavedAddresses();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedAddresses() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _savedAddresses = const [];
        _isLoadingSavedAddresses = false;
      });
      return;
    }

    try {
      final addresses = await _database.getUserAddresses(user.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _savedAddresses = addresses;
        _isLoadingSavedAddresses = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _savedAddresses = const [];
        _isLoadingSavedAddresses = false;
      });
    }
  }

  Future<void> _applySavedAddress(UserAddress address) async {
    final auth = context.read<AuthProvider>();
    final product = context.read<ProductProvider>();
    final location = context.read<LocationProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _isApplyingSavedAddress = true);
    try {
      final combinedAddress = [
        if (address.addressLine.trim().isNotEmpty) address.addressLine.trim(),
        if (address.locality.trim().isNotEmpty) address.locality.trim(),
        if (address.city.trim().isNotEmpty) address.city.trim(),
        if (address.pincode.trim().isNotEmpty) address.pincode.trim(),
      ].join(', ');

      await auth.saveProfile(
        name: address.name,
        address: combinedAddress,
        area: address.locality.isNotEmpty ? address.locality : address.city,
        city: address.city,
        latitude: address.latitude,
        longitude: address.longitude,
      );

      final selectedNeighborhood =
          location.manualCities.contains(address.locality)
          ? address.locality
          : location.manualCities.contains(address.city)
          ? address.city
          : '';
      if (selectedNeighborhood.isNotEmpty) {
        await product.setManualLocation(selectedNeighborhood);
      } else {
        await product.fetchHomeData(
          user: auth.user,
          forceLocationRefresh: true,
        );
      }

      if (!mounted) {
        return;
      }
      await auth.refreshCurrentUser();
      if (!mounted) {
        return;
      }
      navigator.pop();
    } catch (_) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to use that address right now.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isApplyingSavedAddress = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final location = context.watch<LocationProvider>();
    final product = context.read<ProductProvider>();
    final user = auth.user;
    final displayName = user?.name.trim().isNotEmpty == true
        ? user!.name.trim()
        : 'Abianzo Member';
    final headerCopy = location.deliveryHeaderCopy(displayName);
    final searchQuery = _searchController.text.trim().toLowerCase();
    final manualLocalities = location.manualCities.where((locality) {
      if (searchQuery.isEmpty) {
        return true;
      }
      return locality.toLowerCase().contains(searchQuery);
    }).toList();
    final currentPincode = location.displayPincode.trim();
    final deliveryAreaTitle = location.displayArea.trim().isNotEmpty
        ? location.displayArea.trim()
        : headerCopy.title.replaceFirst('Delivering to ', '').trim();
    final deliveryAreaSubtitleParts = <String>[
      if (location.displayCity.trim().isNotEmpty) location.displayCity.trim(),
      if (currentPincode.isNotEmpty) currentPincode,
    ];
    final deliveryAreaSubtitle = deliveryAreaSubtitleParts.join(' • ');
    final hasCurrentDeliverySelection =
        location.hasResolvedLocation || deliveryAreaTitle.isNotEmpty;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFCF7),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border.all(color: const Color(0xFFE9E0D2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 30,
              offset: const Offset(0, -12),
            ),
          ],
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.74,
          minChildSize: 0.56,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD7D0C5),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Choose where you\'d like your orders delivered.\nWe\'ll show stores and products available in your area.',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF151515),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                _SectionLabel(title: 'Search'),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search locality or pincode',
                    prefixIcon: const Icon(Icons.search_rounded),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 13,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: context.abzioBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: context.abzioBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AbzioTheme.accentColor,
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: manualLocalities
                      .map(
                        (locality) => ChoiceChip(
                          label: Text(locality),
                          selected: location.activeLocation == locality,
                          onSelected: (_) async {
                            final product = context.read<ProductProvider>();
                            final navigator = Navigator.of(context);
                            await product.setManualLocation(locality);
                            if (!mounted) {
                              return;
                            }
                            await auth.refreshCurrentUser();
                            if (!mounted) {
                              return;
                            }
                            navigator.pop();
                          },
                          selectedColor: AbzioTheme.accentColor.withValues(
                            alpha: 0.16,
                          ),
                          labelStyle: TextStyle(
                            color: location.activeLocation == locality
                                ? const Color(0xFF151515)
                                : const Color(0xFF4A4A4A),
                            fontWeight: FontWeight.w600,
                          ),
                          side: BorderSide(
                            color: location.activeLocation == locality
                                ? AbzioTheme.accentColor.withValues(alpha: 0.35)
                                : const Color(0xFFE2D9C8),
                          ),
                          backgroundColor: Colors.white,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 14),
                _SectionLabel(title: 'Current Location'),
                const SizedBox(height: 8),
                _ActionCard(
                  icon: Icons.my_location_rounded,
                  title: 'Use Current Location',
                  subtitle: location.isLocationLoading
                      ? 'Detecting your location...'
                      : location.locationPermissionBlocked
                      ? 'Location access needs permission'
                      : 'Refresh your local boutique coverage instantly',
                  compact: true,
                  trailing: location.isLocationLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AbzioTheme.accentColor,
                          ),
                        )
                      : null,
                  onTap: () async {
                    final navigator = Navigator.of(context);
                    await product.requestLocationAccess();
                    if (!mounted) {
                      return;
                    }
                    await auth.refreshCurrentUser();
                    if (!mounted) {
                      return;
                    }
                    navigator.pop();
                  },
                ),
                if (location.locationStatus ==
                        LocationStatus.permissionDeniedForever ||
                    location.locationStatus ==
                        LocationStatus.serviceDisabled) ...[
                  const SizedBox(height: 10),
                  _InlinePrompt(
                    message:
                        location.locationErrorMessage ??
                        'Location access is unavailable.',
                    actionLabel:
                        location.locationStatus ==
                            LocationStatus.serviceDisabled
                        ? 'Open settings'
                        : 'App settings',
                    onTap: () async {
                      if (location.locationStatus ==
                          LocationStatus.serviceDisabled) {
                        await location.openSystemLocationSettings();
                      } else {
                        await location.openSystemAppSettings();
                      }
                    },
                  ),
                ],
                const SizedBox(height: 14),
                _SectionLabel(title: 'Current Delivery Area'),
                const SizedBox(height: 8),
                _DeliveryCard(
                  title: deliveryAreaTitle,
                  subtitle: deliveryAreaSubtitle,
                  icon: Icons.location_on_outlined,
                  isSelected: hasCurrentDeliverySelection,
                ),
                const SizedBox(height: 14),
                _SectionLabel(title: 'Saved Addresses'),
                const SizedBox(height: 8),
                if (_isLoadingSavedAddresses)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AbzioTheme.accentColor,
                        ),
                      ),
                    ),
                  )
                else if (_savedAddresses.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'No saved addresses yet. Add one from your profile for a quicker checkout experience.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.abzioSecondaryText,
                        height: 1.45,
                      ),
                    ),
                  )
                else
                  ..._savedAddresses.map(
                    (address) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SavedAddressCard(
                        address: address,
                        isBusy: _isApplyingSavedAddress,
                        onTap: () => _applySavedAddress(address),
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
              ],
            );
          },
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
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: const Color(0xFF9B7D38),
        fontWeight: FontWeight.w700,
        letterSpacing: 0.25,
      ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.isSelected = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected
            ? AbzioTheme.accentColor.withValues(alpha: 0.06)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? AbzioTheme.accentColor.withValues(alpha: 0.4)
              : context.abzioBorder,
          width: isSelected ? 1.2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AbzioTheme.accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, size: 20, color: AbzioTheme.accentColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF161616),
                              fontSize: 13.5,
                            ),
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: Color(0xFFC6A769),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.abzioSecondaryText,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedAddressCard extends StatelessWidget {
  const _SavedAddressCard({
    required this.address,
    required this.isBusy,
    required this.onTap,
  });

  final UserAddress address;
  final bool isBusy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = _formatTitle(address);
    final subtitle = _formatSubtitle(address);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isBusy ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.abzioBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AbzioTheme.accentColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.home_outlined,
                  color: AbzioTheme.accentColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF161616),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.abzioSecondaryText,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (isBusy) ...[
                const SizedBox(width: 12),
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AbzioTheme.accentColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTitle(UserAddress address) {
    final locality = address.locality.trim().isNotEmpty
        ? address.locality.trim()
        : address.city.trim();
    return locality.isEmpty ? 'Saved address' : locality;
  }

  String _formatSubtitle(UserAddress address) {
    final city = address.city.trim();
    final pincode = address.pincode.trim();
    if (city.isNotEmpty || pincode.isNotEmpty) {
      return [
        if (city.isNotEmpty) city,
        if (pincode.isNotEmpty) pincode,
      ].join(' • ');
    }
    final addressLine = address.addressLine.trim();
    if (addressLine.isNotEmpty) {
      return addressLine;
    }
    return address.landmark.trim().isNotEmpty
        ? address.landmark.trim()
        : 'Saved address';
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: EdgeInsets.all(compact ? 12 : 15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.abzioBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).inputDecorationTheme.fillColor ??
                      const Color(0xFFF6F2EA),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 19, color: AbzioTheme.accentColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF161616),
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.abzioSecondaryText,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
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
        color: const Color(0xFFF8F3E8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9DDBE)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFB28A2E)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF5C5343),
                height: 1.4,
              ),
            ),
          ),
          TextButton(onPressed: onTap, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

