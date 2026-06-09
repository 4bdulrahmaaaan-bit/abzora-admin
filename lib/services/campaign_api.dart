import 'backend_api_client.dart';

class CampaignApi {
  CampaignApi({BackendApiClient? backendApiClient})
      : _backendApiClient = backendApiClient ?? const BackendApiClient();

  final BackendApiClient _backendApiClient;

  Future<List<Map<String, dynamic>>> getCampaigns() async {
    final payload = await _backendApiClient.get('/vendor/campaigns', authenticated: true);
    final campaigns = payload['campaigns'];
    if (campaigns is List) {
      return campaigns.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<Map<String, dynamic>> createCampaign(Map<String, dynamic> data) async {
    final payload = await _backendApiClient.post('/vendor/campaigns', authenticated: true, body: data);
    return payload as Map<String, dynamic>;
  }

  Future<void> updateCampaignStatus(String id, String status) async {
    await _backendApiClient.post('/vendor/campaigns/$id/status', authenticated: true, body: {'status': status, '_method': 'PATCH'});
  }
}
