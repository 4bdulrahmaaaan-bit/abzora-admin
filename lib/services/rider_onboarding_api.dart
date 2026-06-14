import 'backend_api_client.dart';

class RiderOnboardingApi {
  const RiderOnboardingApi({BackendApiClient? apiClient}) : _apiClient = apiClient ?? const BackendApiClient();

  final BackendApiClient _apiClient;
  static const String _basePath = '/api/rider/onboarding/draft';

  Future<void> saveDraft(Map<String, dynamic> payload) async {
    await _apiClient.post(
      _basePath,
      body: payload,
      authenticated: true,
    );
  }

  Future<Map<String, dynamic>?> getDraft() async {
    try {
      final response = await _apiClient.get(
        _basePath,
        authenticated: true,
      );
      
      if (response != null && response['success'] == true && response['data'] != null) {
        return response['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      if (e.toString().contains('404')) {
        return null;
      }
      rethrow;
    }
  }

  Future<void> deleteDraft() async {
    await _apiClient.delete(
      _basePath,
      authenticated: true,
    );
  }

  Future<void> updateStep(int currentStep) async {
    await _apiClient.patch(
      '$_basePath/step',
      body: {'currentStep': currentStep},
      authenticated: true,
    );
  }
}
