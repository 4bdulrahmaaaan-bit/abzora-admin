part of '../admin_web_panel.dart';

class AdminInvoicesSection extends StatefulWidget {
  const AdminInvoicesSection({super.key});

  @override
  State<AdminInvoicesSection> createState() => _AdminInvoicesSectionState();
}

class _AdminInvoicesSectionState extends State<AdminInvoicesSection> {
  final BackendApiClient _client = const BackendApiClient();
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  List<dynamic> _invoices = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchInvoices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchInvoices() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final query = _searchController.text.trim();
      final path = '/api/invoices/admin/list?search=${Uri.encodeQueryComponent(query)}&limit=50';
      final payload = await _client.get(path, authenticated: true);
      
      if (!mounted) return;
      if (payload is Map<String, dynamic> && payload['success'] == true) {
        setState(() {
          _invoices = payload['data'] ?? [];
          _isLoading = false;
        });
        return;
      }
      
      setState(() {
        _error = 'Failed to load invoices';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error loading invoices';
        _isLoading = false;
      });
    }
  }

  Future<void> _regenerateInvoice(String invoiceId) async {
    try {
      final path = '/api/invoices/admin/$invoiceId/regenerate';
      final payload = await _client.post(path, body: {}, authenticated: true);
      
      if (!mounted) return;
      if (payload is Map<String, dynamic> && payload['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice regenerated successfully')),
        );
        _fetchInvoices();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to regenerate invoice')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error regenerating invoice')),
      );
    }
  }

  Future<void> _launchPdf(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: const Color(0xFFF8F9FA),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Invoices',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by Invoice Number, Order ID, Customer, Vendor...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onSubmitted: (_) => _fetchInvoices(),
                ),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: _fetchInvoices,
                icon: const Icon(Icons.search),
                label: const Text('Search'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(child: Center(child: Text(_error!, style: const TextStyle(color: Colors.red))))
          else if (_invoices.isEmpty)
            const Expanded(child: Center(child: Text('No invoices found')))
          else
            Expanded(
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                child: ListView.separated(
                  itemCount: _invoices.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final inv = _invoices[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text(
                        inv['invoiceNumber'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('Order ID: ${inv['orderId'] ?? 'N/A'}'),
                          Text('Customer: ${inv['customerName'] ?? 'N/A'}'),
                          Text('Status: ${inv['status'] ?? 'N/A'}'),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (inv['invoicePdfUrl'] != null &&
                              inv['invoicePdfUrl'].toString().isNotEmpty)
                            TextButton.icon(
                              onPressed: () => _launchPdf(inv['invoicePdfUrl']),
                              icon: const Icon(Icons.picture_as_pdf),
                              label: const Text('View PDF'),
                            ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () => _regenerateInvoice(inv['_id'] ?? inv['id']),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Regenerate'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
