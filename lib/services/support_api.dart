import 'backend_api_client.dart';

class SupportApi {
  SupportApi({BackendApiClient? backendApiClient})
      : _backendApiClient = backendApiClient ?? const BackendApiClient();

  final BackendApiClient _backendApiClient;

  Future<Map<String, dynamic>> getTickets({int page = 1, int limit = 20, String? status}) async {
    String url = '/vendor/support/tickets?page=$page&limit=$limit';
    if (status != null && status != 'all') {
      url += '&status=$status';
    }
    final payload = await _backendApiClient.get(url, authenticated: true);
    return payload as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getTicket(String id) async {
    final payload = await _backendApiClient.get('/vendor/support/tickets/$id', authenticated: true);
    return payload as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createTicket(Map<String, dynamic> data) async {
    final payload = await _backendApiClient.post('/vendor/support/tickets', authenticated: true, body: data);
    return payload as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> addMessage(String ticketId, Map<String, dynamic> data) async {
    final payload = await _backendApiClient.post('/vendor/support/tickets/$ticketId/messages', authenticated: true, body: data);
    return payload as Map<String, dynamic>;
  }

  Future<void> updateTicketStatus(String ticketId, String status) async {
    await _backendApiClient.post('/vendor/support/tickets/$ticketId/status', authenticated: true, body: {
      'status': status,
      '_method': 'PATCH',
    });
  }

  Future<Map<String, dynamic>> getAnalytics() async {
    final payload = await _backendApiClient.get('/vendor/support/analytics', authenticated: true);
    return payload as Map<String, dynamic>;
  }
}
