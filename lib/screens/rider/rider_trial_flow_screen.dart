import 'package:flutter/material.dart';
import 'dart:async';
import '../../../models/trial_session.dart';
import '../../../theme.dart';
import '../../../services/rider_trials_api.dart';
import '../../../services/payment_service.dart';

class RiderTrialFlowScreen extends StatefulWidget {
  const RiderTrialFlowScreen({
    super.key,
    required this.session,
  });

  final TrialSession session;

  @override
  State<RiderTrialFlowScreen> createState() => _RiderTrialFlowScreenState();
}

class _RiderTrialFlowScreenState extends State<RiderTrialFlowScreen> {
  late TrialSession _session;
  Timer? _uiUpdateTimer;
  bool _isLoading = false;

  // Checkout State
  final Set<String> _itemsKept = {};
  final Set<String> _itemsReturned = {};
  String _selectedOutcome = '';
  String _paymentMethod = 'Online';
  final String _notes = '';
  final List<String> _proofPhotos = [];
  bool _customerAcknowledged = false;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    // Auto-select returned by default for safety
    for (var item in _session.items) {
      _itemsReturned.add(item.productId);
    }
    _startUiUpdateTimer();
  }

  void _startUiUpdateTimer() {
    _uiUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _uiUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _markArrived() async {
    setState(() => _isLoading = true);
    try {
      final updatedSession = await RiderTrialsApi.arriveTrial(_session.id, _session);
      setState(() => _session = updatedSession);
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startTrial() async {
    setState(() => _isLoading = true);
    try {
      final updatedSession = await RiderTrialsApi.startTrial(_session.id, _session);
      setState(() => _session = updatedSession);
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markNoShow() async {
    setState(() => _isLoading = true);
    try {
      await RiderTrialsApi.noShowTrial(_session.id, 'Customer unresponsive', _proofPhotos);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marked as No Show. Session closed.')),
        );
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _addProofPhoto() {
    setState(() {
      _proofPhotos.add('https://dummyimage.com/600x400/000/fff&text=Proof+Photo+${_proofPhotos.length + 1}');
    });
  }

  Future<void> _processCompletion() async {
    if (_selectedOutcome.isEmpty) {
      _showError('Please select a trial outcome.');
      return;
    }
    if (!_customerAcknowledged) {
      _showError('Customer must acknowledge completion.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. Calculate Checkout
      final checkoutData = await RiderTrialsApi.calculateCheckout(
        _session.id,
        _itemsKept.toList(),
        _itemsReturned.toList(),
      );
      
      final finalAmount = (checkoutData['finalAmount'] as num?)?.toDouble() ?? 0.0;
      bool paymentCollected = false;

      // 2. Collect Payment if finalAmount > 0
      if (!mounted) return; if (finalAmount > 0) {
        if (_paymentMethod == 'Online') {
          final paymentService = PaymentService();
          final result = await paymentService.processCheckout(
            context: context,
            userId: _session.userId,
            name: _session.userName.isEmpty ? 'Customer' : _session.userName,
            amount: finalAmount,
            email: 'customer@abianzo.com',
            contact: _session.userPhone.isEmpty ? '9999999999' : _session.userPhone,
            description: 'TBYB Checkout',
            backendOrderId: _session.id, // Will be mapped to TrialSession in backend
          );
          if (!result.success || !result.isVerified) {
            _showError('Payment failed or unverified. Cannot complete trial.');
            setState(() => _isLoading = false);
            return;
          }
          paymentCollected = true;
        } else if (_paymentMethod == 'Cash') {
          // Assume cash collected physically
          paymentCollected = true;
        }
      }

      // 3. Complete Trial
      await RiderTrialsApi.completeTrial(
        id: _session.id,
        currentSession: _session,
        itemsKept: _itemsKept.toList(),
        itemsReturned: _itemsReturned.toList(),
        trialOutcome: _selectedOutcome,
        notes: _notes,
        paymentMethod: finalAmount > 0 ? _paymentMethod : '',
        paymentCollected: paymentCollected,
        proofPhotos: _proofPhotos,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trial Completed Successfully')),
        );
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCompletionBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Finalize Trial', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView(
                    children: [
                      const Text('Items Audit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      ..._session.items.map((item) {
                        final isKept = _itemsKept.contains(item.productId);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(backgroundImage: item.imageUrl.isNotEmpty ? NetworkImage(item.imageUrl) : null),
                          title: Text(item.name),
                          subtitle: Text('₹${item.price}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ChoiceChip(
                                label: const Text('Return'),
                                selected: !isKept,
                                onSelected: (val) {
                                  if (val) {
                                    setSheetState(() {
                                      _itemsKept.remove(item.productId);
                                      _itemsReturned.add(item.productId);
                                    });
                                  }
                                },
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: const Text('Keep'),
                                selected: isKept,
                                onSelected: (val) {
                                  if (val) {
                                    setSheetState(() {
                                      _itemsReturned.remove(item.productId);
                                      _itemsKept.add(item.productId);
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                      const Divider(),
                      const Text('Trial Outcome', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: ['converted', 'partial_purchase', 'returned', 'damaged'].map((val) {
                          return ChoiceChip(
                            label: Text(val.replaceAll('_', ' ').toUpperCase()),
                            selected: _selectedOutcome == val,
                            onSelected: (selected) {
                              if (selected) setSheetState(() => _selectedOutcome = val);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      if (_itemsKept.isNotEmpty) ...[
                        const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'Online', label: Text('Online / UPI')),
                            ButtonSegment(value: 'Cash', label: Text('Cash')),
                          ],
                          selected: {_paymentMethod},
                          onSelectionChanged: (set) => setSheetState(() => _paymentMethod = set.first),
                        ),
                        const SizedBox(height: 16),
                      ],
                      const Text('Proof Photos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ..._proofPhotos.map((url) => Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
                                ),
                              )),
                          InkWell(
                            onTap: () {
                              _addProofPhoto();
                              setSheetState(() {});
                            },
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey),
                              ),
                              child: const Icon(Icons.camera_alt),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        title: const Text('Customer has reviewed the items and agrees to the outcome.'),
                        value: _customerAcknowledged,
                        onChanged: (val) => setSheetState(() => _customerAcknowledged = val ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: _isLoading ? null : () {
                    Navigator.pop(context); // close bottom sheet
                    _processCompletion(); // run async task
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    backgroundColor: AbzioTheme.accentColor,
                  ),
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Confirm & Collect Payment'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isEnRoute = _session.status == 'assigned' || _session.status == 'en_route' || _session.status == 'out_for_trial_delivery';
    final bool hasArrived = _session.status == 'arrived';
    final bool isTrialActive = _session.status == 'trial_started' || _session.status == 'trial_active' || _session.status == 'trial_in_progress';
    final bool isCompleted = _session.status == 'completed' || _session.status == 'cancelled' || _session.status == 'no_show';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EE),
      appBar: AppBar(
        title: const Text('TBYB Delivery'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildCustomerCard(),
                const SizedBox(height: 24),
                if (isEnRoute) _buildArrivalSection(),
                if (hasArrived) _buildWaitTimerSection(),
                if (isTrialActive) _buildActiveTrialTimerSection(),
                if (isCompleted) _buildCompletedStatus(),
                const SizedBox(height: 24),
                _buildItemsList(),
              ],
            ),
          ),
          if (isTrialActive)
            Container(
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
              color: Colors.white,
              child: FilledButton(
                onPressed: _showCompletionBottomSheet,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: AbzioTheme.accentColor,
                ),
                child: const Text('Collect Payment & Complete', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          if (hasArrived)
            Container(
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
              color: Colors.white,
              child: FilledButton(
                onPressed: _startTrial,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: Colors.blue.shade600,
                ),
                child: const Text('Start Trial', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AbzioTheme.eliteShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Customer Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AbzioTheme.grey200,
                child: const Icon(Icons.person, color: AbzioTheme.grey500),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_session.userName.isEmpty ? 'Customer' : _session.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(_session.userPhone, style: TextStyle(color: AbzioTheme.grey500, fontSize: 12)),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.phone, color: Colors.green), onPressed: () {}),
            ],
          ),
          const Divider(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, color: AbzioTheme.accentColor, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(_session.addressLabel, style: const TextStyle(fontWeight: FontWeight.w500))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildArrivalSection() {
    return FilledButton.icon(
      onPressed: _markArrived,
      icon: const Icon(Icons.location_on),
      label: const Text('Mark Arrived'),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        backgroundColor: Colors.green.shade600,
      ),
    );
  }

  Widget _buildWaitTimerSection() {
    int waitedSeconds = 0;
    if (_session.arrivedAt != null) {
      waitedSeconds = ServerTimeOffset().now.difference(_session.arrivedAt!).inSeconds;
    }
    final minutes = (waitedSeconds / 60).floor();
    final seconds = waitedSeconds % 60;
    final timeString = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    final canMarkNoShow = waitedSeconds > 600; // 10 minutes

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange, width: 2),
      ),
      child: Column(
        children: [
          const Text('Waiting for Customer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange)),
          const SizedBox(height: 8),
          Text(timeString, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.orange)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: canMarkNoShow ? _markNoShow : null,
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Mark No Show'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTrialTimerSection() {
    int elapsedSeconds = 0;
    if (_session.startedAt != null) {
      elapsedSeconds = ServerTimeOffset().now.difference(_session.startedAt!).inSeconds;
    }
    int remainingSeconds = (_session.trialDurationMinutes * 60) - elapsedSeconds;
    if (remainingSeconds < 0) remainingSeconds = 0;

    final minutes = (remainingSeconds / 60).floor();
    final seconds = remainingSeconds % 60;
    final timeString = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    final isTimeLow = remainingSeconds < 300;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isTimeLow ? Colors.red.shade50 : AbzioTheme.accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isTimeLow ? Colors.red : AbzioTheme.accentColor, width: 2),
      ),
      child: Column(
        children: [
          Text('Trial In Progress', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isTimeLow ? Colors.red.shade700 : AbzioTheme.accentColor)),
          const SizedBox(height: 8),
          Text(timeString, style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: isTimeLow ? Colors.red : Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildCompletedStatus() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green, width: 2),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 48),
          const SizedBox(height: 8),
          Text('Trial Completed', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: AbzioTheme.eliteShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Items To Try', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          ..._session.items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 50, height: 60, color: AbzioTheme.grey200,
                      child: item.imageUrl.isNotEmpty ? Image.network(item.imageUrl, fit: BoxFit.cover) : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Size: ${item.recommendedSize}', style: TextStyle(color: AbzioTheme.grey500, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
