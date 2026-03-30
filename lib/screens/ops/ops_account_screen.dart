import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme.dart';
import '../../widgets/brand_logo.dart';
import '../rider/rider_onboarding_screen.dart';

class OpsAccountScreen extends StatelessWidget {
  const OpsAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final roleLabel = auth.isVendor ? 'VENDOR' : auth.isRider ? 'RIDER' : 'OPS';

    return Scaffold(
      backgroundColor: AbzioTheme.grey50,
      appBar: AppBar(
        backgroundColor: AbzioTheme.grey50,
        elevation: 0,
        title: Text(
          'ACCOUNT',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.black, size: 20),
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (!context.mounted) {
                return;
              }
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                const BrandLogo(
                  size: 88,
                  radius: 24,
                  backgroundColor: Colors.white,
                  assetPath: 'assets/branding/abzora_partner_icon.png',
                ),
                const SizedBox(height: 18),
                Text(
                  user?.name ?? 'Operations User',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  user?.email ?? '',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AbzioTheme.accentColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    roleLabel,
                    style: GoogleFonts.poppins(
                      color: Colors.black,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _OpsTile(
            icon: auth.isVendor ? Icons.storefront_outlined : Icons.delivery_dining_outlined,
            title: auth.isVendor ? 'Operations access' : 'Delivery access',
            subtitle: auth.isVendor
                ? 'You are signed into the merchant operations app.'
                : 'You are signed into the rider operations app.',
          ),
          _OpsTile(
            icon: Icons.verified_user_outlined,
            title: 'Access model',
            subtitle: auth.isVendor
                ? 'Your account can only manage your own store and store orders.'
                : 'Your account can only view and update orders assigned to you.',
          ),
          _OpsTile(
            icon: Icons.support_agent_outlined,
            title: 'Support',
            subtitle: 'Reach platform support from the operations channel when needed.',
          ),
          if (auth.isRider) ...[
            _OpsTile(
              icon: Icons.verified_user_outlined,
              title: 'Rider approval',
              subtitle: user?.riderApprovalStatus == 'approved'
                  ? 'Your rider profile is approved and ready for live deliveries.'
                  : 'Your rider profile is pending approval or needs completion.',
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RiderOnboardingScreen()),
                  );
                },
                child: Text(
                  user?.riderApprovalStatus == 'approved' ? 'EDIT RIDER PROFILE' : 'COMPLETE RIDER PROFILE',
                ),
              ),
            ),
          ],
          const SizedBox(height: 28),
          TextButton(
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (!context.mounted) {
                return;
              }
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
            child: Text(
              'LOG OUT',
              style: GoogleFonts.poppins(
                color: Colors.redAccent,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpsTile extends StatelessWidget {
  const _OpsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AbzioTheme.grey100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.black, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.45,
                    color: AbzioTheme.grey600,
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
