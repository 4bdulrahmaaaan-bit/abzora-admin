import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import 'body_scan_screen.dart';
import 'profile_completion_flow_screen.dart';
import 'size_recommendation_screen.dart';
import '../../widgets/premium_button.dart';

class SavedFitProfileScreen extends StatefulWidget {
  const SavedFitProfileScreen({super.key});

  @override
  State<SavedFitProfileScreen> createState() => _SavedFitProfileScreenState();
}

class _SavedFitProfileScreenState extends State<SavedFitProfileScreen> {
  final DatabaseService _database = DatabaseService();
  Future<_SavedFitData>? _future;
  String? _userId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthProvider>();
    if (!auth.isInitialized) return;

    final user = auth.user;
    if (user == null) {
      _future = null;
      _userId = null;
      return;
    }
    if (_future == null || _userId != user.id) {
      _userId = user.id;
      _future = _load(user.id);
    }
  }

  Future<_SavedFitData> _load(String userId) async {
    final results = await Future.wait([
      _database.getBodyProfile(userId),
      _database.getMeasurementProfiles(userId),
    ]);
    return _SavedFitData(
      bodyProfile: results[0] as BodyProfile?,
      measurementProfiles: results[1] as List<MeasurementProfile>,
    );
  }

  int _confidencePercentFor(BodyProfile? profile) {
    final confidence = profile?.confidence ?? 0.0;
    if (confidence <= 0) {
      return 88;
    }
    return (confidence <= 1 ? confidence * 100 : confidence).round().clamp(
      0,
      100,
    );
  }

  String _relativeTime(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return 'Today';
    }
    final diff = DateTime.now().difference(parsed);
    if (diff.inDays <= 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4EE),
      appBar: AppBar(
        title: const Text('Saved Fit Profile'),
        backgroundColor: const Color(0xFFF7F4EE),
        elevation: 0,
      ),
      body: SafeArea(
        child: FutureBuilder<_SavedFitData>(
          future: _future,
          builder: (context, snapshot) {
            final auth = context.read<AuthProvider>();
            if (!auth.isInitialized ||
                snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFFC9A55A)),
              );
            }
            if (snapshot.hasError) {
              return const Center(
                child: Text('Saved fit profile unavailable right now.'),
              );
            }
            final data = snapshot.data;
            final bodyProfile = data?.bodyProfile;
            final measurementProfiles =
                data?.measurementProfiles ?? const <MeasurementProfile>[];
            final hasSavedProfile =
                bodyProfile != null || measurementProfiles.isNotEmpty;
            final displaySize = (bodyProfile?.recommendedSize ?? '').trim();
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xFFF3F1EB)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: hasSavedProfile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displaySize.isNotEmpty
                                    ? displaySize.toUpperCase()
                                    : 'M',
                                style: Theme.of(context).textTheme.displayMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF111111),
                                      height: 1,
                                    ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '${_confidencePercentFor(bodyProfile)}% Confidence',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF111111),
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                bodyProfile == null
                                    ? 'Saved fit details are ready'
                                    : '${bodyProfile.fitPreference.isNotEmpty ? bodyProfile.fitPreference : 'Regular'} Fit Recommended',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: const Color(0xFF666666),
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 18),
                              _row(
                                'Height',
                                bodyProfile == null
                                    ? '—'
                                    : '${bodyProfile.heightCm.toStringAsFixed(0)} cm',
                              ),
                              const SizedBox(height: 10),
                              _row(
                                'Weight',
                                bodyProfile == null
                                    ? '—'
                                    : '${bodyProfile.weightKg.toStringAsFixed(0)} kg',
                              ),
                              const SizedBox(height: 10),
                              _row(
                                'Body Type',
                                bodyProfile == null
                                    ? '—'
                                    : _beautify(bodyProfile.bodyType),
                              ),
                              const SizedBox(height: 10),
                              _row(
                                'Fit Preference',
                                bodyProfile == null
                                    ? '—'
                                    : _beautify(bodyProfile.fitPreference),
                              ),
                              const SizedBox(height: 10),
                              _row(
                                'Last Updated',
                                bodyProfile == null
                                    ? 'Today'
                                    : _relativeTime(bodyProfile.updatedAt),
                              ),
                              if (measurementProfiles.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                _row('Scan Status', 'Smart Scan Completed'),
                              ],
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Find My Perfect Fit',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF111111),
                                    ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Get personalized sizing recommendations using your body profile and optional AI scan.',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: const Color(0xFF666666),
                                      height: 1.45,
                                    ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 16),
                  if (hasSavedProfile) ...[
                    PremiumButton(
                      label: 'Edit Profile',
                      filled: false,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const ProfileCompletionFlowScreen(initialStep: 1),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    PremiumButton(
                      label: 'Recalculate Recommendation',
                      filled: true,
                      onTap: () {
                        if (context.read<AuthProvider>().requiresProfileSetup) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please complete your profile first.',
                              ),
                            ),
                          );
                          Navigator.pushNamed(context, '/profile-completion');
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SizeRecommendationScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    PremiumButton(
                      label: 'Run Smart Scan Again',
                      filled: false,
                      onTap: () {
                        if (context.read<AuthProvider>().requiresProfileSetup) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please complete your profile first.',
                              ),
                            ),
                          );
                          Navigator.pushNamed(context, '/profile-completion');
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BodyScanScreen(),
                          ),
                        );
                      },
                    ),
                  ] else
                    PremiumButton(
                      label: 'Start Fit Profile',
                      filled: true,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const ProfileCompletionFlowScreen(initialStep: 1),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF666666),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF111111),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  String _beautify(String value) {
    final text = value.trim();
    if (text.isEmpty) {
      return '—';
    }
    return text
        .replaceAll('_', ' ')
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
        .join(' ');
  }
}

class _SavedFitData {
  const _SavedFitData({
    required this.bodyProfile,
    required this.measurementProfiles,
  });

  final BodyProfile? bodyProfile;
  final List<MeasurementProfile> measurementProfiles;
}
