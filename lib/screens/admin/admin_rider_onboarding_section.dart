import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/onboarding_service.dart';
import '../../utils/app_error_text.dart';

class AdminRiderOnboardingSection extends StatefulWidget {
  const AdminRiderOnboardingSection({super.key});

  @override
  State<AdminRiderOnboardingSection> createState() =>
      _AdminRiderOnboardingSectionState();
}

class _AdminRiderOnboardingSectionState
    extends State<AdminRiderOnboardingSection> {
  final _onboardingService = OnboardingService();
  bool _loading = true;
  String? _error;
  List<RiderKycRequest> _requests = [];
  String _statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final actor = context.read<AuthProvider>().user;
    if (actor == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final requests = await _onboardingService.getRiderRequests(actor: actor);
      if (mounted) {
        setState(() {
          _requests = requests;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = AppErrorText.from(e);
          _loading = false;
        });
      }
    }
  }

  Future<void> _updateStatus(String requestId, String newStatus) async {
    final actor = context.read<AuthProvider>().user;
    if (actor == null) return;
    try {
      if (newStatus == 'approved') {
        await _onboardingService.approveRiderRequest(
          requestId: requestId,
          actor: actor,
        );
      } else if (newStatus == 'rejected') {
        await _onboardingService.rejectRiderRequest(
          requestId: requestId,
          reason: 'Admin rejected',
          actor: actor,
        );
      }
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Status updated to $newStatus')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppErrorText.from(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Error: $_error'));

    final filtered = _statusFilter == 'All'
        ? _requests
        : _requests
              .where(
                (r) => r.status.toLowerCase() == _statusFilter.toLowerCase(),
              )
              .toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rider Onboarding',
            style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildKpis(),
          const SizedBox(height: 24),
          _buildPipeline(),
          const SizedBox(height: 24),
          _buildFilters(),
          const SizedBox(height: 16),
          Expanded(child: _buildDataTable(filtered)),
        ],
      ),
    );
  }

  Widget _buildKpis() {
    final applicationsToday = _requests
        .where(
          (r) => r.createdAt.startsWith(
            DateTime.now().toIso8601String().substring(0, 10),
          ),
        )
        .length;
    final pendingKyc = _requests.where((r) => r.status == 'pending_kyc').length;
    final pendingVerification = _requests
        .where((r) => r.status == 'pending_verification')
        .length;
    final pendingTraining = _requests
        .where((r) => r.status == 'pending_training')
        .length;
    final activeRiders = _requests.where((r) => r.status == 'approved').length;
    final rejectedRiders = _requests
        .where((r) => r.status == 'rejected')
        .length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _kpiCard('Apps Today', applicationsToday),
        _kpiCard('Pending KYC', pendingKyc),
        _kpiCard('Pending Verification', pendingVerification),
        _kpiCard('Pending Training', pendingTraining),
        _kpiCard('Active', activeRiders),
        _kpiCard('Rejected', rejectedRiders),
      ],
    );
  }

  Widget _kpiCard(String title, int count) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(
                title,
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                '$count',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPipeline() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: const [
          Text('Applied'),
          Icon(Icons.arrow_forward),
          Text('KYC Review'),
          Icon(Icons.arrow_forward),
          Text('Verification Review'),
          Icon(Icons.arrow_forward),
          Text('Training Pending'),
          Icon(Icons.arrow_forward),
          Text('Fleet Approval'),
          Icon(Icons.arrow_forward),
          Text('Active'),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Row(
      children: [
        const Text('Status Filter: '),
        const SizedBox(width: 8),
        DropdownButton<String>(
          value: _statusFilter,
          items: [
            'All',
            'Pending',
            'Pending_KYC',
            'Pending_Verification',
            'Pending_Training',
            'Approved',
            'Rejected',
          ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _statusFilter = val);
          },
        ),
      ],
    );
  }

  Widget _buildDataTable(List<RiderKycRequest> requests) {
    return ListView.builder(
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final req = requests[index];
        return Card(
          child: ListTile(
            title: Text(req.name),
            subtitle: Text('${req.vehicle} - ${req.city} - ${req.status}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (req.status != 'approved')
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () => _updateStatus(req.id, 'approved'),
                  ),
                if (req.status != 'rejected')
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => _updateStatus(req.id, 'rejected'),
                  ),
                IconButton(
                  icon: const Icon(Icons.info),
                  onPressed: () => _showDetailDrawer(req),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDetailDrawer(RiderKycRequest req) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Details for ${req.name}',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _sectionTitle('Profile Info'),
                Text('Phone: ${req.phone}\nCity: ${req.city}'),
                const SizedBox(height: 16),
                _sectionTitle('Vehicle Info'),
                Text('Type: ${req.vehicle}'),
                const SizedBox(height: 16),
                _sectionTitle('KYC'),
                Text('License URL: ${req.kyc.licenseUrl}'),
                const SizedBox(height: 16),
                _sectionTitle('Training Info'),
                Text('Status: ${req.metadata['training_status'] ?? 'N/A'}'),
                const SizedBox(height: 16),
                _sectionTitle('Audit Trail'),
                ...req.actionHistory.map(
                  (h) => Text('${h.timestamp}: ${h.action} by ${h.actorName}'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}
