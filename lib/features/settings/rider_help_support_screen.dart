import 'package:flutter/material.dart';

import '../../core/widgets/rider_glass_card.dart';
import '../../services/rider_support_api.dart';

class RiderHelpSupportScreen extends StatefulWidget {
  const RiderHelpSupportScreen({super.key, this.embeddedMode = false});
  final bool embeddedMode;

  @override
  State<RiderHelpSupportScreen> createState() => _RiderHelpSupportScreenState();
}

class _RiderHelpSupportScreenState extends State<RiderHelpSupportScreen> {
  bool _loadingFaqs = true;
  List<Map<String, dynamic>> _faqs = [];

  @override
  void initState() {
    super.initState();
    _loadFaqs();
  }

  Future<void> _loadFaqs() async {
    final faqs = await RiderSupportApi.getFaqs();
    if (mounted) {
      setState(() {
        _faqs = faqs;
        _loadingFaqs = false;
      });
    }
  }

  void _openTicketForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Open Ticket', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const TextField(decoration: InputDecoration(labelText: 'Category')),
            const SizedBox(height: 12),
            const TextField(decoration: InputDecoration(labelText: 'Description'), maxLines: 3),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37)),
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ticket created successfully')),
                  );
                },
                child: const Text('SUBMIT TICKET', style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showTicketHistory() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => FutureBuilder<List<Map<String, dynamic>>>(
        future: RiderSupportApi.getTickets(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final tickets = snapshot.data ?? [];
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text('Ticket History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (tickets.isEmpty) const Text('No past tickets found.'),
              ...tickets.map((t) => ListTile(
                title: Text(t['category'] ?? 'General'),
                subtitle: Text('Status: ${t['status'] ?? 'Open'}'),
                trailing: const Icon(Icons.chevron_right),
              )),
            ],
          );
        },
      ),
    );
  }

  void _contactSupport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Support'),
        content: const Text('Email: rider-support@abianzo.com\nPhone: +91 90000 00000\nAvailable 24/7 for escalation.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CLOSE')),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Color(0xFF8D6A2E),
        ),
      ),
    );
  }

  Widget _buildFaqTile(String title) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: () {},
    );
  }

  Widget _buildSupportTool(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return RiderGlassCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F1E1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF8D6A2E)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle('SUPPORT TOOLS'),
        _buildSupportTool(
          'Open Ticket',
          'Report an issue with a delivery or payout',
          Icons.support_agent,
          _openTicketForm,
        ),
        const SizedBox(height: 12),
        _buildSupportTool(
          'Ticket History',
          'View your previous support requests',
          Icons.history,
          _showTicketHistory,
        ),
        const SizedBox(height: 12),
        _buildSupportTool(
          'Contact Support',
          'Call or chat with live agent',
          Icons.chat,
          _contactSupport,
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('FREQUENTLY ASKED QUESTIONS'),
        if (_loadingFaqs)
          const Center(child: CircularProgressIndicator(color: Color(0xFFC8A86B)))
        else if (_faqs.isEmpty)
          RiderGlassCard(
            child: Column(
              children: [
                _buildFaqTile('Account & Onboarding'),
                const Divider(height: 1),
                _buildFaqTile('Deliveries & Tasks'),
                const Divider(height: 1),
                _buildFaqTile('Payments & Settlements'),
                const Divider(height: 1),
                _buildFaqTile('Try Before You Buy (Trials)'),
              ],
            ),
          )
        else
          RiderGlassCard(
            child: Column(
              children: _faqs.map((faq) => _buildFaqTile(faq['question'] ?? '')).toList(),
            ),
          ),
      ],
    );

    if (widget.embeddedMode) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      backgroundColor: const Color(0xFFF8F5EF),
      body: body,
    );
  }
}
