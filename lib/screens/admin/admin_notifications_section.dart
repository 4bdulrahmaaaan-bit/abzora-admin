import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/models.dart';
import '../../../theme.dart';
import '../../../widgets/state_views.dart';
import 'api/admin_notifications_api.dart';

class AdminNotificationsSection extends StatefulWidget {
  const AdminNotificationsSection({super.key});

  @override
  State<AdminNotificationsSection> createState() =>
      _AdminNotificationsSectionState();
}

class _AdminNotificationsSectionState extends State<AdminNotificationsSection>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoading = true;
  String _error = '';
  List<AdminNotification> _history = [];
  List<Map<String, dynamic>> _templates = [];

  int _currentPage = 1;
  int _totalPages = 1;
  int _totalCount = 0;
  final int _limit = 25;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  String _audienceRole = 'user';
  String _campaignType = 'Instant';
  List<String> _channels = ['Push'];
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1) {
        _fetchHistory();
      }
    });
    _fetchTemplates();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _fetchTemplates() async {
    try {
      final res = await AdminNotificationsApi.fetchTemplates();
      if (mounted) {
        setState(() {
          _templates = res;
        });
      }
    } catch (e) {
      debugPrint('Failed to load templates: $e');
    }
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final res = await AdminNotificationsApi.fetchHistory(
        page: _currentPage,
        limit: _limit,
      );
      if (mounted) {
        setState(() {
          _history = res['history'] as List<AdminNotification>;
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

  Future<void> _dispatchCampaign() async {
    if (_titleController.text.trim().isEmpty ||
        _bodyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and body are required.')),
      );
      return;
    }
    if (_channels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one channel must be selected.')),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      if (_campaignType == 'Scheduled') {
        final schDate = DateTime.now()
            .add(const Duration(hours: 1))
            .toIso8601String();
        await AdminNotificationsApi.scheduleCampaign(
          title: _titleController.text.trim(),
          body: _bodyController.text.trim(),
          audienceRole: _audienceRole,
          channels: _channels,
          scheduledAt: schDate,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Campaign scheduled successfully!')),
          );
        }
      } else {
        await AdminNotificationsApi.sendCampaign(
          title: _titleController.text.trim(),
          body: _bodyController.text.trim(),
          audienceRole: _audienceRole,
          channels: _channels,
          campaignType: _campaignType,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Campaign dispatched successfully!')),
          );
        }
      }

      _titleController.clear();
      _bodyController.clear();
      setState(() {
        _channels = ['Push'];
        _audienceRole = 'user';
        _campaignType = 'Instant';
      });
      _tabController.animateTo(1);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _useTemplate(Map<String, dynamic> t) {
    setState(() {
      _titleController.text = t['title'] ?? '';
      _bodyController.text = t['body'] ?? '';
      _channels = List<String>.from(t['channels'] ?? ['Push']);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notification Center',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w800,
            fontSize: 28,
            color: AbzioTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Broadcast operational and marketing communications via Push, Email, and SMS.',
          style: GoogleFonts.inter(
            color: AbzioTheme.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        TabBar(
          controller: _tabController,
          labelColor: AbzioTheme.accentColor,
          unselectedLabelColor: AbzioTheme.textSecondary,
          indicatorColor: AbzioTheme.accentColor,
          tabs: const [
            Tab(text: 'Compose Campaign'),
            Tab(text: 'Campaign History & Analytics'),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildComposeTab(), _buildHistoryTab()],
          ),
        ),
      ],
    );
  }

  Widget _buildComposeTab() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Campaign Details',
                    style: context.abzioText.titleMedium,
                  ),
                  const Divider(),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Campaign Title / Subject',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _bodyController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Message Body (Supports HTML for email)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _audienceRole,
                          decoration: const InputDecoration(
                            labelText: 'Target Audience',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'user',
                              child: Text('All Customers'),
                            ),
                            DropdownMenuItem(
                              value: 'vendor',
                              child: Text('All Vendors'),
                            ),
                            DropdownMenuItem(
                              value: 'rider',
                              child: Text('All Riders'),
                            ),
                          ],
                          onChanged: (v) => setState(() => _audienceRole = v!),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _campaignType,
                          decoration: const InputDecoration(
                            labelText: 'Campaign Type',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Instant',
                              child: Text('Instant Broadcast'),
                            ),
                            DropdownMenuItem(
                              value: 'Scheduled',
                              child: Text('Scheduled'),
                            ),
                            DropdownMenuItem(
                              value: 'Segmented',
                              child: Text('Segmented'),
                            ),
                          ],
                          onChanged: (v) => setState(() => _campaignType = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Channels', style: context.abzioText.titleSmall),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildChannelCheckbox('Push', Icons.notifications),
                      _buildChannelCheckbox('Email', Icons.email),
                      _buildChannelCheckbox('SMS', Icons.sms),
                    ],
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSending ? null : _dispatchCampaign,
                      child: _isSending
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Dispatch Campaign'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Quick Templates', style: context.abzioText.titleMedium),
              const SizedBox(height: 16),
              if (_templates.isEmpty) const Text('Loading templates...'),
              ..._templates.map(
                (t) => Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ListTile(
                    title: Text(t['name'] ?? ''),
                    subtitle: Text('${t['channels']?.join(', ')}'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _useTemplate(t),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChannelCheckbox(String channel, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: _channels.contains(channel),
          onChanged: (val) {
            setState(() {
              if (val == true) {
                _channels.add(channel);
              } else {
                _channels.remove(channel);
              }
            });
          },
        ),
        Icon(icon, size: 18, color: AbzioTheme.textSecondary),
        const SizedBox(width: 4),
        Text(channel),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildHistoryTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error.isNotEmpty) return Center(child: Text('Error: $_error'));
    if (_history.isEmpty) {
      return const AbzioEmptyCard(
        title: 'No campaigns found',
        subtitle: 'Your dispatch history is empty.',
      );
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Showing ${_history.length} of $_totalCount campaigns',
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
                    DataColumn(label: Text('Date')),
                    DataColumn(label: Text('Type')),
                    DataColumn(label: Text('Title')),
                    DataColumn(label: Text('Audience')),
                    DataColumn(label: Text('Channels')),
                    DataColumn(label: Text('Sent')),
                    DataColumn(label: Text('Delivered')),
                    DataColumn(label: Text('Open Rate')),
                  ],
                  rows: _history.map((h) {
                    return DataRow(
                      cells: [
                        DataCell(Text(h.timestamp.toString().split('.')[0])),
                        DataCell(Chip(label: Text(h.campaignType))),
                        DataCell(
                          SizedBox(
                            width: 200,
                            child: Text(
                              h.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(Text(h.audienceRole)),
                        DataCell(Text(h.channels.join(', '))),
                        DataCell(Text('${h.analytics['sent'] ?? 0}')),
                        DataCell(Text('${h.analytics['delivered'] ?? 0}')),
                        DataCell(Text('${h.analytics['openRate'] ?? 0}%')),
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
                              _fetchHistory();
                            }
                          : null,
                      child: const Text('Previous'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _currentPage < _totalPages
                          ? () {
                              setState(() => _currentPage++);
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
}
