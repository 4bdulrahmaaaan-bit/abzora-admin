import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';

import '../../../theme.dart';
import 'api/admin_configuration_api.dart';

class AdminConfigurationSection extends StatefulWidget {
  const AdminConfigurationSection({super.key});

  @override
  State<AdminConfigurationSection> createState() =>
      _AdminConfigurationSectionState();
}

class _AdminConfigurationSectionState extends State<AdminConfigurationSection>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String _error = '';
  Map<String, dynamic> _config = {};

  final _formKey = GlobalKey<FormState>();

  // Controllers for config fields
  final _commissionController = TextEditingController();
  final _deliveryFeeController = TextEditingController();
  final _returnFeeController = TextEditingController();
  final _serviceFeeController = TextEditingController();

  final _trialFeeController = TextEditingController();
  final _trialDurationController = TextEditingController();
  final _returnWindowController = TextEditingController();
  final _purchaseWindowController = TextEditingController();
  final _maxActiveTrialsController = TextEditingController();

  final _fraudWarningController = TextEditingController();
  final _fraudCriticalController = TextEditingController();
  final _fraudAlertController = TextEditingController();

  final _couponReferralController = TextEditingController();
  final _couponCampaignController = TextEditingController();
  final _couponGlobalController = TextEditingController();

  List<Map<String, dynamic>> _history = [];
  int _historyPage = 1;
  int _historyTotalPages = 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _fetchConfig();
    _fetchHistory();
  }

  Future<void> _fetchConfig() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final res = await AdminConfigurationApi.fetchConfig();
      if (mounted) {
        setState(() {
          _config = res;
          _populateControllers();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchHistory() async {
    try {
      final res = await AdminConfigurationApi.fetchConfigHistory(
        page: _historyPage,
        limit: 10,
      );
      if (mounted) {
        setState(() {
          _history = res['history'] as List<Map<String, dynamic>>;
          _historyTotalPages = res['meta']['totalPages'] ?? 1;
        });
      }
    } catch (e) {
      debugPrint('Failed to load config history: $e');
    }
  }

  void _populateControllers() {
    _commissionController.text =
        _config['commissionPercent']?.toString() ?? '15';
    _deliveryFeeController.text = _config['deliveryFee']?.toString() ?? '40';
    _returnFeeController.text = _config['returnFee']?.toString() ?? '20';
    _serviceFeeController.text = _config['serviceFee']?.toString() ?? '10';

    _trialFeeController.text = _config['trialFee']?.toString() ?? '50';
    _trialDurationController.text =
        _config['trialDurationHours']?.toString() ?? '24';
    _returnWindowController.text =
        _config['returnWindowHours']?.toString() ?? '48';
    _purchaseWindowController.text =
        _config['purchaseWindowHours']?.toString() ?? '72';
    _maxActiveTrialsController.text =
        _config['maxActiveTrials']?.toString() ?? '3';

    _fraudWarningController.text =
        _config['fraudWarningThreshold']?.toString() ?? '60';
    _fraudCriticalController.text =
        _config['fraudCriticalThreshold']?.toString() ?? '85';
    _fraudAlertController.text =
        _config['fraudAlertThreshold']?.toString() ?? '75';

    _couponReferralController.text =
        _config['couponReferralLimit']?.toString() ?? '5';
    _couponCampaignController.text =
        _config['couponCampaignLimit']?.toString() ?? '1000';
    _couponGlobalController.text =
        _config['couponGlobalLimit']?.toString() ?? '5000';
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    final payload = {
      'commissionPercent': double.tryParse(_commissionController.text) ?? 15.0,
      'deliveryFee': double.tryParse(_deliveryFeeController.text) ?? 40.0,
      'returnFee': double.tryParse(_returnFeeController.text) ?? 20.0,
      'serviceFee': double.tryParse(_serviceFeeController.text) ?? 10.0,

      'trialFee': double.tryParse(_trialFeeController.text) ?? 50.0,
      'trialDurationHours': int.tryParse(_trialDurationController.text) ?? 24,
      'returnWindowHours': int.tryParse(_returnWindowController.text) ?? 48,
      'purchaseWindowHours': int.tryParse(_purchaseWindowController.text) ?? 72,
      'maxActiveTrials': int.tryParse(_maxActiveTrialsController.text) ?? 3,

      'fraudWarningThreshold': int.tryParse(_fraudWarningController.text) ?? 60,
      'fraudCriticalThreshold':
          int.tryParse(_fraudCriticalController.text) ?? 85,
      'fraudAlertThreshold': int.tryParse(_fraudAlertController.text) ?? 75,

      'couponReferralLimit': int.tryParse(_couponReferralController.text) ?? 5,
      'couponCampaignLimit':
          int.tryParse(_couponCampaignController.text) ?? 1000,
      'couponGlobalLimit': int.tryParse(_couponGlobalController.text) ?? 5000,
    };

    try {
      await AdminConfigurationApi.updateConfig(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuration updated successfully')),
        );
        _fetchConfig();
        _fetchHistory();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update config: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error.isNotEmpty) return Center(child: Text('Error: $_error'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Platform Configuration Center',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w800,
                    fontSize: 28,
                    color: AbzioTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Manage global marketplace settings, fees, and operational limits.',
                  style: GoogleFonts.inter(
                    color: AbzioTheme.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _saveConfig,
              icon: const Icon(Icons.save),
              label: const Text('Save Changes'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Marketplace'),
            Tab(text: 'TBYB'),
            Tab(text: 'Fraud Engine'),
            Tab(text: 'Platform Coupons'),
            Tab(text: 'Notifications'),
            Tab(text: 'Audit History'),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Form(
            key: _formKey,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMarketplaceTab(),
                _buildTBYBTab(),
                _buildFraudTab(),
                _buildCouponsTab(),
                _buildNotificationsTab(),
                _buildAuditHistoryTab(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMarketplaceTab() {
    return SingleChildScrollView(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Marketplace Fee Structure',
                style: context.abzioText.titleMedium,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      'Platform Commission (%)',
                      _commissionController,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      'Delivery Fee (₹)',
                      _deliveryFeeController,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      'Return Fee (₹)',
                      _returnFeeController,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      'Service Charge (₹)',
                      _serviceFeeController,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTBYBTab() {
    return SingleChildScrollView(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Try Before You Buy Constraints',
                style: context.abzioText.titleMedium,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      'Trial Fee (₹)',
                      _trialFeeController,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      'Trial Duration (Hours)',
                      _trialDurationController,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      'Return Window (Hours)',
                      _returnWindowController,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      'Purchase Window (Hours)',
                      _purchaseWindowController,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      'Max Active Trials Per User',
                      _maxActiveTrialsController,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFraudTab() {
    return SingleChildScrollView(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fraud Engine Sensitivity Settings',
                style: context.abzioText.titleMedium,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      'Warning Threshold (Score)',
                      _fraudWarningController,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      'Critical Threshold (Score)',
                      _fraudCriticalController,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      'Automated Alert Threshold (Score)',
                      _fraudAlertController,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCouponsTab() {
    return SingleChildScrollView(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Coupon & Promotion Limits',
                style: context.abzioText.titleMedium,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      'Referral Usage Limit',
                      _couponReferralController,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      'Campaign Max Redemptions',
                      _couponCampaignController,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      'Platform Coupon Cap',
                      _couponGlobalController,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationsTab() {
    return SingleChildScrollView(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notification Rules (Read-Only JSON Config)',
                style: context.abzioText.titleMedium,
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  const JsonEncoder.withIndent('  ').convert({
                    'templates': _config['notificationTemplates'],
                    'reminderRules': _config['notificationReminderRules'],
                    'retryRules': _config['notificationRetryRules'],
                  }),
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuditHistoryTab() {
    return Card(
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _history.length,
              itemBuilder: (context, index) {
                final log = _history[index];
                return ListTile(
                  title: Text(
                    'Update by ${log['actorRole']} (${log['actorId']})',
                  ),
                  subtitle: Text(log['timestampIso'] ?? ''),
                  trailing: const Icon(Icons.settings),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Configuration Delta'),
                        content: SizedBox(
                          width: 500,
                          child: SingleChildScrollView(
                            child: Text(
                              const JsonEncoder.withIndent(
                                '  ',
                              ).convert(log['newState']),
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Page $_historyPage of $_historyTotalPages'),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: _historyPage > 1
                          ? () {
                              setState(() => _historyPage--);
                              _fetchHistory();
                            }
                          : null,
                      child: const Text('Previous'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _historyPage < _historyTotalPages
                          ? () {
                              setState(() => _historyPage++);
                              _fetchHistory();
                            }
                          : null,
                      child: const Text('Next'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (v) => v!.isEmpty ? 'Required' : null,
    );
  }
}
