import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../routes/rider_routes.dart';
import '../../services/onboarding_service.dart';
import '../../utils/app_mode_routes.dart';
import '../../widgets/state_views.dart';
import '../../features/onboarding/rider_onboarding_screens.dart';

class RiderOnboardingScreen extends StatefulWidget {
  const RiderOnboardingScreen({super.key});

  @override
  State<RiderOnboardingScreen> createState() => _RiderOnboardingScreenState();
}

class _RiderOnboardingScreenState extends State<RiderOnboardingScreen> {
  final OnboardingService _onboarding = OnboardingService();
  Future<RiderKycRequest?>? _requestFuture;
  String? _boundUserId;
  bool _redirectedToDashboard = false;
  bool _openedNewFlow = false;

  void _ensureFuture(AppUser user) {
    if (_boundUserId == user.id && _requestFuture != null) {
      return;
    }
    _boundUserId = user.id;
    _requestFuture = _onboarding.getRiderRequestForUser(user.id);
  }

  void _openApplicationFlow() {
    if (_openedNewFlow) {
      return;
    }
    _openedNewFlow = true;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RiderOnboardingFlowScreen()),
    );
  }

  void _openDashboard() {
    if (_redirectedToDashboard) {
      return;
    }
    _redirectedToDashboard = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.go(RiderRoutes.dashboard);
    });
  }

  Color _statusColor(String status) {
    return switch (status) {
      'approved' => const Color(0xFF1F7A4D),
      'rejected' => const Color(0xFFB42318),
      'pending' => const Color(0xFF8D6A2E),
      _ => const Color(0xFF666666),
    };
  }

  String _statusLabel(String status) {
    return switch (status) {
      'approved' => 'Approved',
      'rejected' => 'Needs Review',
      'pending' => 'Under Review',
      _ => 'In Progress',
    };
  }

  String _statusMessage(String status) {
    return switch (status) {
      'approved' =>
        'Your rider access is active. You can open the dashboard and start accepting live deliveries.',
      'rejected' =>
        'Your previous application needs updates. You can reopen the onboarding flow, refresh the documents, and submit again.',
      'pending' =>
        'Your rider application is currently under review. We will notify you when it moves forward.',
      _ => 'Your rider onboarding is ready to continue.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select<AuthProvider, AppUser?>((auth) => auth.user);
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
              subtitle: 'Looking for your latest onboarding status.',
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
        final isApproved = hasRiderOperationsAccess(user);
        final hasExistingRequest = request != null;
        final showDashboard = isApproved || requestStatus == 'approved';
        final isNewUser = !hasExistingRequest && !isApproved;

        if (showDashboard && !_redirectedToDashboard) {
          _openDashboard();
        }

        if (showDashboard) {
          return const Scaffold(
            body: AbzioLoadingView(
              title: 'Opening rider dashboard',
              subtitle: 'Preparing your delivery workspace.',
            ),
          );
        }

        if (isNewUser && !_openedNewFlow) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _openedNewFlow) {
              return;
            }
            _openApplicationFlow();
          });
          return const Scaffold(
            body: AbzioLoadingView(
              title: 'Starting rider onboarding',
              subtitle: 'Preparing your application flow.',
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Rider Setup')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              _RiderOnboardingHeader(
                title: hasExistingRequest
                    ? 'Continue your rider application'
                    : 'Start your rider application',
                subtitle: _statusMessage(requestStatus),
                statusLabel: _statusLabel(requestStatus),
                statusColor: _statusColor(requestStatus),
              ),
              const SizedBox(height: 16),
              _RiderOnboardingSummaryCard(
                actor: user,
                request: request,
              ),
              const SizedBox(height: 16),
              _RiderOnboardingActionCard(
                hasExistingRequest: hasExistingRequest,
                status: requestStatus,
                onPrimaryAction: _openApplicationFlow,
              ),
              const SizedBox(height: 16),
              const _RiderOnboardingNotesCard(),
            ],
          ),
        );
      },
    );
  }
}

class _RiderOnboardingHeader extends StatelessWidget {
  const _RiderOnboardingHeader({
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.statusColor,
  });

  final String title;
  final String subtitle;
  final String statusLabel;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEAE3D5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFC8A86B).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.delivery_dining_rounded,
              color: Color(0xFF8D6A2E),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
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

class _RiderOnboardingSummaryCard extends StatelessWidget {
  const _RiderOnboardingSummaryCard({
    required this.actor,
    required this.request,
  });

  final AppUser actor;
  final RiderKycRequest? request;

  @override
  Widget build(BuildContext context) {
    final hasRequest = request != null;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEAE3D5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryRow(label: 'Name', value: actor.name),
          const SizedBox(height: 12),
          _SummaryRow(label: 'Phone', value: actor.phone ?? 'Not provided'),
          const SizedBox(height: 12),
          _SummaryRow(label: 'City', value: request?.city ?? actor.city ?? 'Not provided'),
          const SizedBox(height: 12),
          _SummaryRow(
            label: 'Vehicle',
            value: request?.vehicle.isNotEmpty == true
                ? request!.vehicle
                : (actor.riderVehicleType ?? 'Not selected'),
          ),
          const SizedBox(height: 12),
          _SummaryRow(
            label: 'Application',
            value: hasRequest ? 'Existing submission detected' : 'No submission yet',
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF8D6A2E),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFF111111),
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _RiderOnboardingActionCard extends StatelessWidget {
  const _RiderOnboardingActionCard({
    required this.hasExistingRequest,
    required this.status,
    required this.onPrimaryAction,
  });

  final bool hasExistingRequest;
  final String status;
  final VoidCallback onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    final actionLabel = hasExistingRequest
        ? status == 'rejected'
            ? 'RESUBMIT APPLICATION'
            : 'REVIEW APPLICATION'
        : 'START APPLICATION';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ready to continue?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasExistingRequest
                ? 'Your application state is preserved. You can reopen the workflow to update your details and submit again.'
                : 'Complete the rider onboarding flow to unlock delivery partner access.',
            style: const TextStyle(
              color: Color.fromRGBO(255, 255, 255, 0.76),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56, child: ElevatedButton(
              onPressed: onPrimaryAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC8A86B),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RiderOnboardingNotesCard extends StatelessWidget {
  const _RiderOnboardingNotesCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEAE3D5)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What happens next',
            style: TextStyle(
              color: Color(0xFF111111),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 12),
          Text(
            '• Your documents are reviewed by the operations team.\n• Approved riders move into the live dashboard automatically.\n• Rejected applications can be resubmitted after updates.',
            style: TextStyle(
              color: Color(0xFF666666),
              height: 1.55,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }
}
