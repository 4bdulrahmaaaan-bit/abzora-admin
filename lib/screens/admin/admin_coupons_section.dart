import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../theme.dart';
import '../../../widgets/state_views.dart';
import 'api/admin_coupons_api.dart';

class AdminCouponsSection extends StatefulWidget {
  const AdminCouponsSection({super.key});

  @override
  State<AdminCouponsSection> createState() => _AdminCouponsSectionState();
}

class _AdminCouponsSectionState extends State<AdminCouponsSection> {
  bool _isLoading = true;
  String _error = '';
  List<Map<String, dynamic>> _coupons = [];
  Map<String, dynamic> _dashboardStats = {};

  int _currentPage = 1;
  int _totalPages = 1;
  int _totalCount = 0;
  final int _limit = 25;

  String? _filterStatus;

  @override
  void initState() {
    super.initState();
    _fetchDashboard();
    _fetchCoupons();
  }

  Future<void> _fetchDashboard() async {
    try {
      final res = await AdminCouponsApi.fetchCouponsDashboard();
      if (mounted) setState(() => _dashboardStats = res);
    } catch (e) {
      debugPrint('Failed to load coupons dashboard: $e');
    }
  }

  Future<void> _fetchCoupons() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final res = await AdminCouponsApi.fetchCoupons(
        page: _currentPage,
        limit: _limit,
        status: _filterStatus,
      );
      if (mounted) {
        setState(() {
          _coupons = res['coupons'] as List<Map<String, dynamic>>;
          final meta = res['meta'] as Map;
          _totalPages = meta['totalPages'] ?? 1;
          _totalCount = meta['totalCount'] ?? 0;
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

  void _openCreateDialog() {
    showDialog(
      context: context,
      builder: (context) => _CouponDialog(
        onSaved: () {
          _fetchDashboard();
          _fetchCoupons();
        },
      ),
    );
  }

  void _openEditDialog(Map<String, dynamic> coupon) {
    showDialog(
      context: context,
      builder: (context) => _CouponDialog(
        coupon: coupon,
        onSaved: () {
          _fetchDashboard();
          _fetchCoupons();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  'Coupons & Promotions Center',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w800,
                    fontSize: 28,
                    color: AbzioTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Manage global platform discounts and promotional codes.',
                  style: GoogleFonts.inter(
                    color: AbzioTheme.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _openCreateDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create Global Coupon'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            _buildStatCard(
              'Active Coupons',
              _dashboardStats['activeCoupons']?.toString() ?? '-',
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              'Total Redemptions',
              _dashboardStats['totalRedemptions']?.toString() ?? '-',
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              'Total Discount Provided',
              '₹${_dashboardStats['totalDiscountProvided']?.toString() ?? '-'}',
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              'Estimated ROI',
              _dashboardStats['roi']?.toString() ?? '-',
            ),
          ],
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _filterStatus,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: null,
                        child: Text('All Statuses'),
                      ),
                      DropdownMenuItem(value: 'draft', child: Text('Draft')),
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(
                        value: 'expired',
                        child: Text('Expired'),
                      ),
                      DropdownMenuItem(
                        value: 'disabled',
                        child: Text('Disabled'),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _filterStatus = v;
                        _currentPage = 1;
                      });
                      _fetchCoupons();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error.isNotEmpty
              ? Center(child: Text('Error: $_error'))
              : _coupons.isEmpty
              ? const AbzioEmptyCard(
                  title: 'No coupons found',
                  subtitle: 'Create a global coupon to start.',
                )
              : Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Showing ${_coupons.length} of $_totalCount coupons',
                          style: context.abzioText.titleMedium,
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: DataTable(
                              showCheckboxColumn: false,
                              columns: const [
                                DataColumn(label: Text('Code')),
                                DataColumn(label: Text('Status')),
                                DataColumn(label: Text('Discount')),
                                DataColumn(label: Text('Usage Limit')),
                                DataColumn(label: Text('Redemptions')),
                                DataColumn(label: Text('Total Given')),
                                DataColumn(label: Text('Valid Until')),
                                DataColumn(label: Text('Actions')),
                              ],
                              rows: _coupons.map((c) {
                                final discountStr =
                                    c['discountType'] == 'percentage'
                                    ? '${c['discountValue']}%'
                                    : '₹${c['discountValue']}';
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        c['couponCode'] ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Chip(label: Text(c['status'] ?? '')),
                                    ),
                                    DataCell(Text(discountStr)),
                                    DataCell(
                                      Text('${c['usageLimit'] ?? 'Unlimited'}'),
                                    ),
                                    DataCell(Text('${c['redemptions'] ?? 0}')),
                                    DataCell(
                                      Text('₹${c['totalDiscount'] ?? 0}'),
                                    ),
                                    DataCell(
                                      Text(
                                        c['endDate']?.toString().split(
                                              'T',
                                            )[0] ??
                                            '',
                                      ),
                                    ),
                                    DataCell(
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 18),
                                        onPressed: () => _openEditDialog(c),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Page $_currentPage of $_totalPages'),
                            Row(
                              children: [
                                OutlinedButton(
                                  onPressed: _currentPage > 1
                                      ? () {
                                          setState(() => _currentPage--);
                                          _fetchCoupons();
                                        }
                                      : null,
                                  child: const Text('Previous'),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: _currentPage < _totalPages
                                      ? () {
                                          setState(() => _currentPage++);
                                          _fetchCoupons();
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
                ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: AbzioTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: GoogleFonts.poppins(
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
}

class _CouponDialog extends StatefulWidget {
  final Map<String, dynamic>? coupon;
  final VoidCallback onSaved;

  const _CouponDialog({this.coupon, required this.onSaved});

  @override
  State<_CouponDialog> createState() => _CouponDialogState();
}

class _CouponDialogState extends State<_CouponDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codeController;
  late TextEditingController _discountValueController;
  late TextEditingController _minOrderController;
  late TextEditingController _maxDiscountController;
  late TextEditingController _usageLimitController;

  String _discountType = 'percentage';
  String _status = 'draft';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.coupon;
    _codeController = TextEditingController(text: c?['couponCode'] ?? '');
    _discountValueController = TextEditingController(
      text: c?['discountValue']?.toString() ?? '',
    );
    _minOrderController = TextEditingController(
      text: c?['minimumOrderValue']?.toString() ?? '',
    );
    _maxDiscountController = TextEditingController(
      text: c?['maximumDiscount']?.toString() ?? '',
    );
    _usageLimitController = TextEditingController(
      text: c?['usageLimit']?.toString() ?? '',
    );

    if (c != null) {
      _discountType = c['discountType'] ?? 'percentage';
      _status = c['status'] ?? 'draft';
      _startDate = DateTime.tryParse(c['startDate'] ?? '') ?? DateTime.now();
      _endDate =
          DateTime.tryParse(c['endDate'] ?? '') ??
          DateTime.now().add(const Duration(days: 30));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final payload = {
        'couponCode': _codeController.text.trim().toUpperCase(),
        'discountType': _discountType,
        'discountValue': double.tryParse(_discountValueController.text) ?? 0,
        'minimumOrderValue': double.tryParse(_minOrderController.text) ?? 0,
        'status': _status,
        'startDate': _startDate.toIso8601String(),
        'endDate': _endDate.toIso8601String(),
      };

      final maxD = double.tryParse(_maxDiscountController.text);
      if (maxD != null) payload['maximumDiscount'] = maxD;

      final uLimit = int.tryParse(_usageLimitController.text);
      if (uLimit != null) payload['usageLimit'] = uLimit;

      if (widget.coupon != null) {
        await AdminCouponsApi.updateCoupon(widget.coupon!['_id'], payload);
      } else {
        await AdminCouponsApi.createCoupon(payload);
      }

      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.coupon == null ? 'Create Global Coupon' : 'Edit Global Coupon',
      ),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'Coupon Code (e.g. WELCOME20)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _discountType,
                        decoration: const InputDecoration(
                          labelText: 'Discount Type',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'percentage',
                            child: Text('Percentage %'),
                          ),
                          DropdownMenuItem(
                            value: 'fixed',
                            child: Text('Fixed Amount ₹'),
                          ),
                        ],
                        onChanged: (v) => setState(() => _discountType = v!),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _discountValueController,
                        decoration: const InputDecoration(
                          labelText: 'Discount Value',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _minOrderController,
                        decoration: const InputDecoration(
                          labelText: 'Min Order Value (Optional)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _maxDiscountController,
                        decoration: const InputDecoration(
                          labelText: 'Max Discount (Optional)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _usageLimitController,
                        decoration: const InputDecoration(
                          labelText: 'Usage Limit (Optional)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _status,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'draft',
                            child: Text('Draft'),
                          ),
                          DropdownMenuItem(
                            value: 'active',
                            child: Text('Active'),
                          ),
                          DropdownMenuItem(
                            value: 'expired',
                            child: Text('Expired'),
                          ),
                          DropdownMenuItem(
                            value: 'disabled',
                            child: Text('Disabled'),
                          ),
                        ],
                        onChanged: (v) => setState(() => _status = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        title: const Text('Start Date'),
                        subtitle: Text(
                          DateFormat('yyyy-MM-dd').format(_startDate),
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _startDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() => _startDate = picked);
                          }
                        },
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        title: const Text('End Date'),
                        subtitle: Text(
                          DateFormat('yyyy-MM-dd').format(_endDate),
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _endDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) setState(() => _endDate = picked);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
