import '../models/trial_session.dart';
import 'backend_api_client.dart';
import 'inventory_service.dart';
import 'trial_status_guard.dart';

class TrialHomeApi {
  TrialHomeApi({BackendApiClient? client})
    : _client = client ?? const BackendApiClient();

  final BackendApiClient _client;

  bool get isConfigured => _client.isConfigured;

  Future<TrialSession> bookTrial({
    required List<Map<String, dynamic>> items,
    required String addressLabel,
    required String deliverySlot,
    String deliveryWindowLabel = 'Delivered in 24 hours',
    double trialFee = 99,
    int trialDurationMinutes = 30,
    bool bookingFeePaid = true,
    String? bookingPaymentId,
    String? bookingOrderId,
  }) async {
    final payload = await _client.post(
      '/trial-home/book',
      authenticated: true,
      body: {
        'items': items,
        'addressLabel': addressLabel,
        'deliverySlot': deliverySlot,
        'deliveryWindowLabel': deliveryWindowLabel,
        'trialFee': trialFee,
        'trialDurationMinutes': trialDurationMinutes,
        'bookingFeePaid': bookingFeePaid,
        'bookingPaymentId': ?bookingPaymentId,
        'bookingOrderId': ?bookingOrderId,
      },
    );
    final session = TrialSession.fromMap(
      Map<String, dynamic>.from(payload as Map),
    );
    final productIds = items
        .map((item) => item['productId']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
    await InventoryService().reserveTrialInventory(productIds);
    return session;
  }

  Future<TrialSession> requestTrial({
    required List<Map<String, dynamic>> items,
    required String addressLabel,
    required String deliverySlot,
    String deliveryWindowLabel = 'Delivered in 24 hours',
    double trialFee = 99,
    int trialDurationMinutes = 30,
    bool bookingFeePaid = true,
  }) async {
    final payload = await _client.post(
      '/trial-home/request',
      authenticated: true,
      body: {
        'items': items,
        'addressLabel': addressLabel,
        'deliverySlot': deliverySlot,
        'deliveryWindowLabel': deliveryWindowLabel,
        'trialFee': trialFee,
        'trialDurationMinutes': trialDurationMinutes,
        'bookingFeePaid': bookingFeePaid,
      },
    );
    return TrialSession.fromMap(Map<String, dynamic>.from(payload as Map));
  }

  Future<TrialSession?> getMyTrial() async {
    final payload = await _client.get('/trial-home/me', authenticated: true);
    final items = payload is List ? payload : const <dynamic>[];
    final sessions = items
        .whereType<Map>()
        .map((item) => TrialSession.fromMap(Map<String, dynamic>.from(item)))
        .toList();
    if (sessions.isEmpty) {
      return null;
    }
    for (final session in sessions) {
      if (!session.isResolved) {
        return session;
      }
    }
    return sessions.first;
  }

  Future<TrialSession> getTrialById(String id) async {
    final payload = await _client.get('/trial-home/$id', authenticated: true);
    return TrialSession.fromMap(Map<String, dynamic>.from(payload as Map));
  }

  Future<TrialSession> modifyTrial(
    String id, {
    List<Map<String, dynamic>>? items,
    String? addressLabel,
    String? deliverySlot,
    String? paymentStatus,
    String? note,
    String? fit,
    String? tailoringRecommendation,
    String? status,
  }) async {
    final currentSession = await getTrialById(id);
    TrialStatusGuard.validateModifiable(currentSession.status);

    final body = <String, dynamic>{};
    if (items != null) {
      body['items'] = items;
    }
    if (addressLabel != null) {
      body['addressLabel'] = addressLabel;
    }
    if (deliverySlot != null) {
      body['deliverySlot'] = deliverySlot;
    }
    if (paymentStatus != null) {
      body['paymentStatus'] = paymentStatus;
    }
    if (note != null) body['note'] = note;
    if (fit != null) body['fit'] = fit;
    if (tailoringRecommendation != null) {
      body['tailoringRecommendation'] = tailoringRecommendation;
    }
    if (status != null) body['status'] = status;
    final payload = await _client.patch(
      '/trial-home/$id/modify',
      authenticated: true,
      body: body,
    );
    return TrialSession.fromMap(Map<String, dynamic>.from(payload as Map));
  }

  Future<TrialSession> cancelTrial(String id, {String note = ''}) async {
    final currentSession = await getTrialById(id);
    TrialStatusGuard.validateTransition(currentSession.status, 'cancelled');

    final payload = await _client.patch(
      '/trial-home/$id/cancel',
      authenticated: true,
      body: {'note': note},
    );
    final session = TrialSession.fromMap(
      Map<String, dynamic>.from(payload as Map),
    );
    final productIds = session.items.map((i) => i.productId).toList();
    await InventoryService().releaseTrialInventory(productIds);
    return session;
  }

  Future<TrialSession> awaitFinalPayment(
    String id, {
    required List<String> keptItems,
    List<String> returnedItems = const <String>[],
  }) async {
    final currentSession = await getTrialById(id);
    TrialStatusGuard.validateTransition(
      currentSession.status,
      'awaiting_final_payment',
    );

    final payload = await _client.post(
      '/trial-home/$id/await-payment',
      authenticated: true,
      body: {'keptItems': keptItems, 'returnedItems': returnedItems},
    );
    return TrialSession.fromMap(Map<String, dynamic>.from(payload as Map));
  }

  Future<TrialSession> convertToOrder(
    String id, {
    required List<String> keptItems,
    List<String> returnedItems = const <String>[],
    String orderId = '',
    String paymentStatus = 'held',
    String paymentMethod = 'online',
    String? finalPaymentId,
    String? finalOrderId,
    double? finalAmount,
  }) async {
    final currentSession = await getTrialById(id);
    TrialStatusGuard.validateTransition(
      currentSession.status,
      'converted_to_order',
    );

    final payload = await _client.post(
      '/trial-home/$id/convert-to-order',
      authenticated: true,
      body: {
        'keptItems': keptItems,
        'returnedItems': returnedItems,
        'orderId': orderId,
        'paymentStatus': paymentStatus,
        'paymentMethod': paymentMethod,
        'finalPaymentId': ?finalPaymentId,
        'finalOrderId': ?finalOrderId,
        'finalAmount': ?finalAmount,
      },
    );
    final session = TrialSession.fromMap(
      Map<String, dynamic>.from(payload as Map),
    );
    final productIds = session.items.map((i) => i.productId).toList();
    await InventoryService().releaseTrialInventory(productIds);
    return session;
  }

  Future<TrialSession> markNoShow(String id) async {
    final currentSession = await getTrialById(id);
    TrialStatusGuard.validateTransition(currentSession.status, 'no_show');

    final payload = await _client.post(
      '/trial-home/$id/no-show',
      authenticated: true,
    );
    final session = TrialSession.fromMap(
      Map<String, dynamic>.from(payload as Map),
    );
    final productIds = session.items.map((i) => i.productId).toList();
    await InventoryService().releaseTrialInventory(productIds);
    return session;
  }
}
