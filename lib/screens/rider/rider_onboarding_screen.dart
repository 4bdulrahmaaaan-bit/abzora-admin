import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/onboarding_service.dart';
import '../../widgets/state_views.dart';
import 'rider_form_screen.dart';

class RiderOnboardingScreen extends StatefulWidget {
  const RiderOnboardingScreen({super.key});

  @override
  State<RiderOnboardingScreen> createState() => _RiderOnboardingScreenState();
}

class _RiderOnboardingScreenState extends State<RiderOnboardingScreen> {
  final OnboardingService _onboarding = OnboardingService();
  Future<RiderKycRequest?>? _requestFuture;
  String? _boundUserId;

  void _ensureFuture(AppUser user) {
    if (_boundUserId == user.id && _requestFuture != null) return;
    _boundUserId = user.id;
    _requestFuture = _onboarding.getRiderRequestForUser(user.id);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) {
      return const Scaffold(
        body: AbzioLoadingView(
          title: 'Opening rider setup',
          subtitle: 'Checking your account status.',
        ),
      );
    }

    _ensureFuture(user);
    return FutureBuilder<RiderKycRequest?>(
      future: _requestFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: AbzioLoadingView(
              title: 'Checking rider account',
              subtitle: 'Looking for existing onboarding status.',
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Rider Setup')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AbzioEmptyCard(
                  title: 'Could not verify rider status',
                  subtitle: '${snapshot.error}',
                  ctaLabel: 'TRY AGAIN',
                  onTap: () {
                    setState(() {
                      _boundUserId = null;
                      _requestFuture = null;
                    });
                  },
                ),
              ),
            ),
          );
        }

        final request = snapshot.data;
        final requestStatus = request?.status.toLowerCase().trim() ?? '';
        final isExistingRider = user.role == 'rider' || request != null;

        if (isExistingRider) {
          final subtitle = requestStatus == 'pending'
              ? 'Your rider KYC is already under review. Please login and track status from your dashboard.'
              : requestStatus == 'approved'
              ? 'This account already has approved rider access. Please login to continue.'
              : requestStatus == 'rejected'
              ? 'This account already has a previous rider submission. Please login and continue from your account workflow.'
              : 'This account already has rider onboarding activity. Please login to continue.';
          return Scaffold(
            appBar: AppBar(title: const Text('Rider Setup')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AbzioEmptyCard(
                  title: 'Rider account already exists',
                  subtitle: subtitle,
                  ctaLabel: 'GO TO LOGIN',
                  onTap: () => Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/login', (route) => false),
                ),
              ),
            ),
          );
        }

        return const RiderFormScreen();
      },
    );
  }
}
