import 'backend_api_client.dart';

class SavedCardSummary {
  const SavedCardSummary({
    required this.id,
    required this.userId,
    required this.gatewayToken,
    required this.last4,
    required this.cardType,
    required this.createdAt,
    this.gatewayCustomerId,
  });

  final String id;
  final String userId;
  final String gatewayToken;
  final String last4;
  final String cardType;
  final DateTime? createdAt;
  final String? gatewayCustomerId;

  String get maskedLabel => '$cardType ending in $last4';
}

class CardVaultService {
  CardVaultService({BackendApiClient? backendApiClient})
      : _backendApiClient = backendApiClient ?? const BackendApiClient();

  final BackendApiClient _backendApiClient;

  Stream<List<SavedCardSummary>> watchSavedCards(String userId) {
    return (() async* {
      yield await _fetchBackendCards();
      while (true) {
        await Future<void>.delayed(const Duration(seconds: 20));
        yield await _fetchBackendCards();
      }
    })();
  }

  Future<void> saveCardSummary(SavedCardSummary card) async {
    await _backendApiClient.post(
      '/cards',
      authenticated: true,
      body: {
        'token': card.gatewayToken,
        'last4': card.last4,
        'cardType': card.cardType,
        'gatewayCustomerId': card.gatewayCustomerId ?? '',
      },
    );
  }

  Future<List<SavedCardSummary>> _fetchBackendCards() async {
    final payload = await _backendApiClient.get('/cards', authenticated: true);
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map((item) => SavedCardSummary(
              id: item['id']?.toString() ?? '',
              userId: item['userId']?.toString() ?? '',
              gatewayToken: item['token']?.toString() ?? '',
              last4: item['last4']?.toString() ?? '0000',
              cardType: item['cardType']?.toString() ?? 'Card',
              gatewayCustomerId: item['gatewayCustomerId']?.toString(),
              createdAt: DateTime.tryParse(item['createdAt']?.toString() ?? ''),
            ))
        .toList();
  }
}
