import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/rider_glass_card.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';

class RiderProfileScreen extends StatefulWidget {
  const RiderProfileScreen({super.key});

  @override
  State<RiderProfileScreen> createState() => _RiderProfileScreenState();
}

class _RiderProfileScreenState extends State<RiderProfileScreen> {
  final _db = DatabaseService();
  final _name = TextEditingController();
  final _city = TextEditingController();
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.read<AuthProvider>().user;
    if (user != null && _name.text.isEmpty) {
      _name.text = user.name;
      _city.text = user.riderCity ?? user.city ?? '';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        RiderGlassCard(
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
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving...' : 'Save Profile'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
