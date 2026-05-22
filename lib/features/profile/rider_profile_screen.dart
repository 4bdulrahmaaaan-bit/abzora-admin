import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../settings/rider_settings_screen.dart';

class RiderProfileScreen extends StatefulWidget {
  const RiderProfileScreen({super.key});

  @override
  State<RiderProfileScreen> createState() => _RiderProfileScreenState();
}

class _RiderProfileScreenState extends State<RiderProfileScreen> {
  final _db = DatabaseService();
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _vehicle = TextEditingController();
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.read<AuthProvider>().user;
    if (user != null && _name.text.isEmpty) {
      _name.text = user.name;
      _city.text = user.riderCity ?? user.city ?? '';
      _vehicle.text = user.riderVehicleType ?? '';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _vehicle.dispose();
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

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final riderStatus = (user?.riderApprovalStatus ?? 'pending').toUpperCase();
    final cityLabel = _city.text.trim().isEmpty ? 'Not set' : _city.text.trim();
    final vehicleLabel = _vehicle.text.trim().isEmpty
        ? 'Not set'
        : _vehicle.text.trim();

    return Container(
      color: const Color(0xFFFAFAFA),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
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
                        color: const Color(0xFFD4AF37),
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
                              color: Color(0xFF171717),
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
                    _statusBadge(riderStatus),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$cityLabel operations',
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
          ),
          const SizedBox(height: 14),
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
          const SizedBox(height: 18),
          _sectionTitle('Profile Details'),
          const SizedBox(height: 10),
          _sectionCard(
            child: Column(
              children: [
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _city,
                  decoration: const InputDecoration(labelText: 'City'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _vehicle,
                  decoration: const InputDecoration(labelText: 'Vehicle Type'),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: const Color(0xFFD4AF37),
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
          const SizedBox(height: 18),
          _sectionTitle('Settings & Account'),
          const SizedBox(height: 10),
          const RiderSettingsScreen(embedded: true),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w900,
        color: Color(0xFF171717),
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFECE4D2)),
      ),
      child: child,
    );
  }

  Widget _statusBadge(String status) {
    final approved = status == 'APPROVED';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: approved ? const Color(0x2239D98A) : const Color(0x22D4AF37),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: approved ? const Color(0xFF39D98A) : const Color(0xFFD4AF37),
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
          Icon(icon, size: 18, color: const Color(0xFFD4AF37)),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF7B756E),
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
              color: Color(0xFF171717),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
