import 'package:flutter/material.dart';

import '../rider/rider_onboarding_screen.dart';
import '../vendor/vendor_registration_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Become a Partner')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Choose how you want to grow with ABZORA.',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Apply once, upload your KYC, and track approval status from your account.',
            style: TextStyle(color: Color(0xFF666666), height: 1.45),
          ),
          const SizedBox(height: 24),
          _PartnerOptionCard(
            title: 'Become Vendor',
            subtitle: 'Launch your store, manage catalog, and grow revenue from nearby shoppers.',
            icon: Icons.storefront_outlined,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const VendorRegistrationScreen()),
              );
            },
          ),
          const SizedBox(height: 16),
          _PartnerOptionCard(
            title: 'Become Rider',
            subtitle: 'Accept deliveries, complete pickups, and manage live drop-offs efficiently.',
            icon: Icons.delivery_dining_outlined,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RiderOnboardingScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PartnerOptionCard extends StatelessWidget {
  const _PartnerOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE9E1C7)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
            gradient: const LinearGradient(
              colors: [Color(0xFFFFFBF1), Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: const Color(0xFFD4AF37)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Color(0xFF666666), height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
