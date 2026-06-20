import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_session_service.dart';
import '../../services/database_service.dart';
import '../../utils/app_error_text.dart';
import '../../utils/app_mode_routes.dart';
import '../../widgets/state_views.dart';
import '../../core/vendor/vendor_status_helper.dart';
import 'store_settings_screen.dart';

class VendorProfileScreen extends StatefulWidget {
  const VendorProfileScreen({super.key});

  @override
  State<VendorProfileScreen> createState() => _VendorProfileScreenState();
}

class _VendorProfileScreenState extends State<VendorProfileScreen> {
  final DatabaseService _db = DatabaseService();
  Future<Store?>? _storeFuture;
  String? _boundUserId;
  String? _boundAuthToken;

  Future<Store?> _loadStoreForUser(AppUser user) async {
    try {
      await AuthSessionService.instance.refreshIfNeeded();
      if (user.storeId != null && user.storeId!.isNotEmpty) {
        return await _db.getStore(user.storeId!);
      }
      return await _db.getStoreByOwner(user.id);
    } catch (error) {
      debugPrint(
        'VendorProfileScreen: store load failed for ${user.id}: $error',
      );
      return null;
    }
  }

  void _bindStoreFuture(AppUser? user, String? authToken) {
    if (user == null) {
      return;
    }
    if (_boundUserId == user.id &&
        _boundAuthToken == authToken &&
        _storeFuture != null) {
      return;
    }
    _boundUserId = user.id;
    _boundAuthToken = authToken;
    _storeFuture = _loadStoreForUser(user);
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    _bindStoreFuture(user, auth.token);

    if (user == null) {
      return const Scaffold(
        body: AbzioLoadingView(
          title: 'Opening vendor profile',
          subtitle: 'Checking your account session.',
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Vendor Profile'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111111),
        elevation: 0,
      ),
      body: FutureBuilder<Store?>(
        future: _storeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const AbzioLoadingView(
              title: 'Loading profile',
              subtitle: 'Preparing your store and account details.',
            );
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: AbzioEmptyCard(
                title: 'Could not load profile',
                subtitle: AppErrorText.from(
                  snapshot.error ?? 'Could not load profile',
                ),
                ctaLabel: 'TRY AGAIN',
                onTap: () => setState(() {
                  _boundUserId = null;
                  _boundAuthToken = null;
                  _storeFuture = null;
                }),
              ),
            );
          }

          final store = snapshot.data;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              _VendorProfileHeader(user: user, store: store),
              const SizedBox(height: 14),
              _VendorSummaryGrid(store: store),
              const SizedBox(height: 14),
              _QuickActionRow(store: store, user: user),
              const SizedBox(height: 18),
              _ProfileSection(
                title: 'Store',
                children: [
                  _ProfileTile(
                    icon: Icons.storefront_rounded,
                    title: 'Store settings',
                    subtitle: store == null
                        ? 'Complete vendor setup to manage store details'
                        : 'Branding, address, banner, policies',
                    onTap: store == null
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => StoreSettingsScreen(store: store),
                            ),
                          ),
                  ),
                  _ProfileTile(
                    icon: Icons.verified_rounded,
                    title: 'KYC status',
                    subtitle: VendorStatusHelper.getVendorStatus(
                      user: user,
                      store: store,
                    ).name.toUpperCase(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _ProfileSection(
                title: 'Account',
                children: [
                  _ProfileTile(
                    icon: Icons.account_balance_wallet_rounded,
                    title: 'Payout account',
                    subtitle: 'Manage settlement and withdrawal details',
                    onTap: () => Navigator.of(context).pushNamed(routeForVendorUser(user)),
                  ),
                  _ProfileTile(
                    icon: Icons.description_rounded,
                    title: 'Legal center',
                    subtitle: 'Vendor terms, privacy, and policies',
                    onTap: store == null
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => StoreSettingsScreen(store: store),
                            ),
                          ),
                  ),
                  _ProfileTile(
                    icon: Icons.logout_rounded,
                    title: 'Logout',
                    subtitle: 'Sign out from this vendor device',
                    danger: true,
                    onTap: _logout,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _VendorProfileHeader extends StatelessWidget {
  const _VendorProfileHeader({required this.user, required this.store});

  final AppUser user;
  final Store? store;

  @override
  Widget build(BuildContext context) {
    final displayName = store?.name.isNotEmpty == true
        ? store!.name
        : user.name;
    final status = VendorStatusHelper.getVendorStatus(
      user: user,
      store: store,
    ).name;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFECE4D2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37),
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text(
                  displayName.trim().isEmpty
                      ? 'A'
                      : displayName.trim()[0].toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF171717),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      user.phone ?? user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF7B756E)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _StatusBadge(status: status),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  store?.city.isNotEmpty == true
                      ? '${store!.city} operations'
                      : 'Vendor operations',
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF6F6A63),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VendorSummaryGrid extends StatelessWidget {
  const _VendorSummaryGrid({required this.store});

  final Store? store;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            label: 'Wallet',
            value: 'INR ${(store?.walletBalance ?? 0).toStringAsFixed(0)}',
            icon: Icons.account_balance_wallet_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            label: 'Rating',
            value: store == null ? '-' : store!.rating.toStringAsFixed(1),
            icon: Icons.star_rounded,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFECE4D2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFD4AF37), size: 22),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF171717),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF7B756E),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionRow extends StatelessWidget {
  const _QuickActionRow({required this.store, required this.user});

  final Store? store;
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickAction(
            icon: Icons.storefront_rounded,
            label: 'Store',
            onTap: store == null
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StoreSettingsScreen(store: store!),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickAction(
            icon: Icons.payments_rounded,
            label: 'Payouts',
            onTap: () => Navigator.of(context).pushNamed(routeForVendorUser(user)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickAction(
            icon: Icons.description_rounded,
            label: 'Legal',
            onTap: store == null
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StoreSettingsScreen(store: store!),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFD4AF37)),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF111111),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFD4AF37),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        normalized.isEmpty ? 'PENDING' : normalized,
        style: const TextStyle(
          color: Color(0xFF111111),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF75643D),
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFB42318) : const Color(0xFF111111);
    return ListTile(
      enabled: onTap != null || !danger,
      onTap: onTap,
      leading: Icon(icon, color: danger ? color : const Color(0xFFD4AF37)),
      title: Text(
        title,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
      subtitle: Text(subtitle),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded),
    );
  }
}
