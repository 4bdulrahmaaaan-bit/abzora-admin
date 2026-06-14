import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../widgets/payout_account_dialog.dart';

class RiderProfileScreen extends StatefulWidget {
  const RiderProfileScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<RiderProfileScreen> createState() => _RiderProfileScreenState();
}

class _RiderProfileScreenState extends State<RiderProfileScreen> {
  final _db = DatabaseService();
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _vehicle = TextEditingController();
  final _license = TextEditingController();
  bool _saving = false;
  bool _payoutLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.read<AuthProvider>().user;
    if (user != null && _name.text.isEmpty) {
      _name.text = user.name;
      _city.text = user.riderCity ?? user.city ?? '';
      _vehicle.text = user.riderVehicleType ?? '';
      _license.text = user.riderLicenseNumber ?? '';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _vehicle.dispose();
    _license.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      await auth.saveProfile(
        name: _name.text.trim(),
        address: user.address ?? '',
        city: _city.text.trim(),
      );
      await _db.saveUser(
        user.copyWith(
          name: _name.text.trim(),
          city: _city.text.trim(),
          riderCity: _city.text.trim(),
          riderVehicleType: _vehicle.text.trim(),
          riderLicenseNumber: _license.text.trim(),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openPayoutDialog(AppUser user) async {
    setState(() => _payoutLoading = true);
    PayoutProfileSummary? profile;
    try {
      profile = await _db.getRiderPayoutProfile(actor: user);
    } catch (e) {
      // Fallback to empty profile if fetch fails (user hasn't configured payout yet)
      profile = const PayoutProfileSummary(
        methodType: '',
        accountHolderName: '',
        upiId: '',
        bankAccountNumber: '',
        bankIfsc: '',
        bankName: '',
        razorpayContactId: '',
        razorpayFundAccountId: '',
        lastSyncedAt: '',
        isConfigured: false,
      );
    } finally {
      if (mounted) setState(() => _payoutLoading = false);
    }

    if (!mounted) return;
    final result = await showPayoutAccountDialog(
      context: context,
      title: 'Payout Account',
      initialValue: profile,
    );

    if (result != null && mounted) {
      try {
        await _db.saveRiderPayoutProfile(
          actor: user,
          methodType: result.methodType,
          accountHolderName: result.accountHolderName,
          upiId: result.upiId,
          bankAccountNumber: result.bankAccountNumber,
          bankIfsc: result.bankIfsc,
          bankName: result.bankName,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payout account saved')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving payout: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final riderStatus = (user?.riderApprovalStatus ?? 'pending').toUpperCase();
    final cityLabel = _city.text.trim().isEmpty ? 'Not set' : _city.text.trim();
    final vehicleLabel = _vehicle.text.trim().isEmpty
        ? 'Not set'
        : _vehicle.text.trim();

    // Aadhaar/PAN presence derived from riderOnboarding map
    final onboarding = user?.riderOnboarding ?? {};
    final hasAadhaar =
        (onboarding['aadhaarNumber'] ?? '').toString().isNotEmpty;
    final hasPan = (onboarding['panNumber'] ?? '').toString().isNotEmpty;
    final shiftPrefs = (onboarding['shiftPreference'] ?? '').toString().trim();
    final shiftLabel = shiftPrefs.isNotEmpty ? shiftPrefs : 'Not set';

    final listView = ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        // ── Avatar / Name / Status card ────────────────────────────────────
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFC8A86B),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      (user != null && user.name.isNotEmpty
                              ? user.name.trim()[0]
                              : 'R')
                          .toUpperCase(),
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
                          user?.name.isNotEmpty == true
                              ? user!.name
                              : 'Rider Profile',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF111111),
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          (user?.phone ?? '').isNotEmpty
                              ? user!.phone!
                              : 'Mobile not available',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFF666666)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _statusBadge(riderStatus),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$cityLabel operations',
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF666666),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // ── Stat cards ─────────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _statCard(
                title: 'City',
                value: cityLabel,
                icon: Icons.location_on_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                title: 'Vehicle',
                value: vehicleLabel,
                icon: Icons.two_wheeler_outlined,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // ── PERSONAL ───────────────────────────────────────────────────────
        _sectionTitle('Personal Details'),
        const SizedBox(height: 10),
        _sectionCard(
          child: Column(
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              const SizedBox(height: 10),
              _readonlyTile(
                label: 'Email',
                value: user?.email.isNotEmpty == true
                    ? user!.email
                    : 'Not available',
                icon: Icons.email_outlined,
              ),
              const SizedBox(height: 10),
              _readonlyTile(
                label: 'Phone',
                value: (user?.phone ?? '').isNotEmpty
                    ? user!.phone!
                    : 'Not available',
                icon: Icons.phone_outlined,
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: const Color(0xFFC8A86B),
                    foregroundColor: const Color(0xFF111111),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(_saving ? 'Saving...' : 'Save Profile'),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── VEHICLE ────────────────────────────────────────────────────────
        _sectionTitle('Vehicle'),
        const SizedBox(height: 10),
        _sectionCard(
          child: Column(
            children: [
              TextField(
                controller: _vehicle,
                decoration: const InputDecoration(
                  labelText: 'Vehicle Type',
                  hintText: 'e.g. Activa, Splendor',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _license,
                decoration: const InputDecoration(
                  labelText: 'License Number',
                  hintText: 'e.g. KA01 20241234567',
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: const Color(0xFFC8A86B),
                    foregroundColor: const Color(0xFF111111),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(_saving ? 'Saving...' : 'Save Vehicle Info'),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── DOCUMENTS ──────────────────────────────────────────────────────
        _sectionTitle('Documents & KYC'),
        const SizedBox(height: 10),
        _sectionCard(
          child: Column(
            children: [
              _readonlyTile(
                label: 'Aadhaar Number',
                value: hasAadhaar ? '••••••••' : 'Not submitted',
                icon: Icons.badge_outlined,
              ),
              const SizedBox(height: 10),
              _readonlyTile(
                label: 'PAN Number',
                value: hasPan ? '••••••••' : 'Not submitted',
                icon: Icons.credit_card_outlined,
              ),
              const SizedBox(height: 10),
              _readonlyTile(
                label: 'KYC Status',
                value: riderStatus,
                icon: Icons.verified_outlined,
                valueColor: riderStatus == 'APPROVED'
                    ? const Color(0xFF39D98A)
                    : const Color(0xFF8D6A2E),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── BANKING ────────────────────────────────────────────────────────
        _sectionTitle('Banking & Payout'),
        const SizedBox(height: 10),
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Link your bank account or UPI ID to receive earnings settlements.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF666666),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: (user == null || _payoutLoading)
                      ? null
                      : () => _openPayoutDialog(user),
                  icon: _payoutLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.account_balance_outlined),
                  label: Text(
                    _payoutLoading ? 'Loading...' : 'Manage Payout Account',
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: const BorderSide(color: Color(0xFFC8A86B)),
                    foregroundColor: const Color(0xFF8D6A2E),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── WORK ───────────────────────────────────────────────────────────
        _sectionTitle('Work Preferences'),
        const SizedBox(height: 10),
        _sectionCard(
          child: Column(
            children: [
              TextField(
                controller: _city,
                decoration: const InputDecoration(
                  labelText: 'Service Zone (City)',
                  hintText: 'e.g. Bangalore',
                ),
              ),
              const SizedBox(height: 10),
              _readonlyTile(
                label: 'Shift Preferences',
                value: shiftLabel,
                icon: Icons.schedule_outlined,
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: const Color(0xFFC8A86B),
                    foregroundColor: const Color(0xFF111111),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(_saving ? 'Saving...' : 'Save Zone'),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (widget.embedded) {
      return Container(
        color: const Color(0xFFF8F5EF),
        child: listView,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5EF),
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: const Color(0xFFF8F5EF),
        elevation: 0,
        foregroundColor: const Color(0xFF111111),
      ),
      body: listView,
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w900,
        color: Color(0xFF111111),
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFECE4D2)),
      ),
      child: child,
    );
  }

  Widget _readonlyTile({
    required String label,
    required String value,
    required IconData icon,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF8D6A2E)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF999999),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: valueColor ?? const Color(0xFF111111),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusBadge(String status) {
    final approved = status == 'APPROVED';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: approved ? const Color(0x2239D98A) : const Color(0x22C8A86B),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: approved ? const Color(0xFF39D98A) : const Color(0xFF8D6A2E),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECE4D2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF8D6A2E)),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF666666),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF111111),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
