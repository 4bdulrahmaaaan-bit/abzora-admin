import 'backend_api_client.dart';

class InventoryService {
  InventoryService({BackendApiClient? client})
      : _client = client ?? const BackendApiClient();

  final BackendApiClient _client;

  /// Reserves the specified products for a Try Before You Buy session.
  /// This ensures they cannot be purchased by others or added to another trial.
  Future<void> reserveTrialInventory(List<String> productIds) async {
    if (productIds.isEmpty) return;

    try {
      await _client.post(
        '/inventory/reserve',
        authenticated: true,
        body: {
          'productIds': productIds,
          'purpose': 'trial',
        },
      );
    } catch (e) {
      // Log or handle reservation failure
      rethrow;
    }
  }

  /// Releases the specified products from the reserved state.
  /// Called upon trial completion, cancellation, or no-show.
  Future<void> releaseTrialInventory(List<String> productIds) async {
    if (productIds.isEmpty) return;

    try {
      await _client.post(
        '/inventory/release',
        authenticated: true,
        body: {
          'productIds': productIds,
          'purpose': 'trial',
        },
      );
    } catch (e) {
      // Log or handle release failure
      rethrow;
    }
  }
}
