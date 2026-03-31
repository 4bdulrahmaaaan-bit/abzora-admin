import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../services/onboarding_service.dart';
import '../../widgets/state_views.dart';
import 'vendor_onboarding_screen.dart';

class VendorRegistrationScreen extends StatefulWidget {
  const VendorRegistrationScreen({super.key});

  @override
  State<VendorRegistrationScreen> createState() => _VendorRegistrationScreenState();
}

class _VendorRegistrationScreenState extends State<VendorRegistrationScreen> {
  final DatabaseService _db = DatabaseService();
  final OnboardingService _onboardingService = OnboardingService();

  Future<_VendorRegistrationState>? _stateFuture;
  String? _boundUserId;

  void _ensureFuture(AppUser user) {
    if (_boundUserId == user.id && _stateFuture != null) {
      return;
    }
    _boundUserId = user.id;
    _stateFuture = _loadState(user);
  }

  Future<_VendorRegistrationState> _loadState(AppUser user) async {
    final results = await Future.wait<dynamic>([
      _db.getStoreByOwner(user.id),
      _onboardingService.getVendorRequestForUser(user.id),
    ]);

    return _VendorRegistrationState(
      user: user,
      store: results[0] as Store?,
      request: results[1] as VendorKycRequest?,
    );
  }

  void _openOpsWorkspace() {
    Navigator.of(context).pushNamedAndRemoveUntil('/ops', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) {
      return const Scaffold(
        body: AbzioLoadingView(
          title: 'Opening vendor setup',
          subtitle: 'Checking your partner account status.',
        ),
      );
    }

    _ensureFuture(user);

    return FutureBuilder<_VendorRegistrationState>(
      future: _stateFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: AbzioLoadingView(
              title: 'Checking vendor account',
              subtitle: 'Looking for an existing store and onboarding status.',
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Vendor Setup')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AbzioEmptyCard(
                  title: 'Could not verify account status',
                  subtitle: snapshot.error.toString().replaceFirst('Exception: ', ''),
                  ctaLabel: 'TRY AGAIN',
                  onTap: () {
                    setState(() {
                      _boundUserId = null;
                      _stateFuture = null;
                    });
                  },
                ),
              ),
            ),
          );
        }

        final state = snapshot.data!;
        final requestStatus = state.request?.status.toLowerCase().trim();
        final hasStore = state.store != null;
        final isApprovedVendor =
            state.user.role == 'vendor' || requestStatus == 'approved' || hasStore;

        if (hasStore || isApprovedVendor) {
          return Scaffold(
            appBar: AppBar(title: const Text('Vendor Setup')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AbzioEmptyCard(
                  title: 'Store already active',
                  subtitle:
                      'This account already has approved vendor access${hasStore ? ' and an active store' : ''}. Open your operations workspace instead of registering again.',
                  ctaLabel: 'OPEN VENDOR DASHBOARD',
                  onTap: _openOpsWorkspace,
                ),
              ),
            ),
          );
        }

        if (requestStatus == 'pending') {
          return Scaffold(
            appBar: AppBar(title: const Text('Vendor Setup')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AbzioEmptyCard(
                  title: 'Application under review',
                  subtitle:
                      'Your vendor KYC has already been submitted and is waiting for approval. You do not need to register again.',
                  ctaLabel: 'BACK',
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
          );
        }

        return const VendorOnboardingScreen();
      },
    );
  }
}

class _VendorRegistrationState {
  const _VendorRegistrationState({
    required this.user,
    required this.store,
    required this.request,
  });

  final AppUser user;
  final Store? store;
  final VendorKycRequest? request;
}
