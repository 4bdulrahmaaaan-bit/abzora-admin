import '../models/trial_session.dart';
import 'backend_api_client.dart';

class TrialHomeApi {
  TrialHomeApi({BackendApiClient? client})
      : _client = client ?? const BackendApiClient();

  final BackendApiClient _client;

  bool get isConfigured => _client.isConfigured;

  Future<TrialSession> bookTrial({
    required List<Map<String, dynamic>> items,
    List<Map<String, dynamic>> recommendedItems = const <Map<String, dynamic>>[],
    required String addressLabel,
    required String deliverySlot,
    String deliveryWindowLabel = 'Delivered in 24 hours',
    String experienceType = 'premium',
    double trialFee = 99,
  }) async {
    final payload = await _client.post(
      '/trial-home/book',
      authenticated: true,
      body: {
        'items': items,
        'recommendedItems': recommendedItems,
        'addressLabel': addressLabel,
        'deliverySlot': deliverySlot,
        'deliveryWindowLabel': deliveryWindowLabel,
        'experienceType': experienceType,
        'trialFee': trialFee,
      },
    );
    return TrialSession.fromMap(Map<String, dynamic>.from(payload as Map));
  }

  Future<TrialSession> requestTrial({
    required List<Map<String, dynamic>> items,
    List<Map<String, dynamic>> recommendedItems = const <Map<String, dynamic>>[],
    required String addressLabel,
    required String deliverySlot,
    String deliveryWindowLabel = 'Delivered in 24 hours',
    String experienceType = 'premium',
    double trialFee = 99,
  }) async {
    final payload = await _client.post(
      '/trial-home/request',
      authenticated: true,
      body: {
        'items': items,
        'recommendedItems': recommendedItems,
        'addressLabel': addressLabel,
        'deliverySlot': deliverySlot,
        'deliveryWindowLabel': deliveryWindowLabel,
        'experienceType': experienceType,
        'trialFee': trialFee,
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
    String? experienceType,
    String? paymentStatus,
  }) async {
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
    if (experienceType != null) {
      body['experienceType'] = experienceType;
    }
    if (paymentStatus != null) {
      body['paymentStatus'] = paymentStatus;
    }
    final payload = await _client.patch(
      '/trial-home/$id/modify',
      authenticated: true,
      body: body,
    );
    return TrialSession.fromMap(Map<String, dynamic>.from(payload as Map));
  }

  Future<TrialSession> cancelTrial(String id, {String note = ''}) async {
    final payload = await _client.patch(
      '/trial-home/$id/cancel',
      authenticated: true,
      body: {'note': note},
    );
    return TrialSession.fromMap(Map<String, dynamic>.from(payload as Map));
  }

  Future<TrialSession> submitFitFeedback(
    String id, {
    required String fit,
    String note = '',
    String tailoringRecommendation = '',
    List<String> adjustmentOptions = const <String>[],
    String status = 'completed',
  }) async {
    final payload = await _client.post(
      '/trial-home/$id/fit-feedback',
      authenticated: true,
      body: {
        'fit': fit,
        'note': note,
        'tailoringRecommendation': tailoringRecommendation,
        'adjustmentOptions': adjustmentOptions,
        'status': status,
      },
    );
    return TrialSession.fromMap(Map<String, dynamic>.from(payload as Map));
  }

  Future<TrialSession> convertToOrder(
    String id, {
    required List<String> keptItems,
    List<String> returnedItems = const <String>[],
    String orderId = '',
    String paymentStatus = 'held',
  }) async {
    final payload = await _client.post(
      '/trial-home/$id/convert-to-order',
      authenticated: true,
      body: {
        'keptItems': keptItems,
        'returnedItems': returnedItems,
        'orderId': orderId,
        'paymentStatus': paymentStatus,
      },
    );
    return TrialSession.fromMap(Map<String, dynamic>.from(payload as Map));
  }

  Future<TrialSession> convertToTailoring(
    String id, {
    required String tailoringRequest,
    String tailoringRecommendation = 'Adjust with custom tailoring',
    List<String> adjustmentOptions = const <String>[],
  }) async {
    final payload = await _client.post(
      '/trial-home/$id/convert-to-tailoring',
      authenticated: true,
      body: {
        'tailoringRequest': tailoringRequest,
        'tailoringRecommendation': tailoringRecommendation,
        'adjustmentOptions': adjustmentOptions,
      },
    );
    return TrialSession.fromMap(Map<String, dynamic>.from(payload as Map));
  }

  Future<TrialSession> approveTrial(
    String id, {
    String note = '',
  }) async {
    final payload = await _client.post(
      '/trial-home/$id/approve',
      authenticated: true,
      body: {'note': note},
    );
    return TrialSession.fromMap(Map<String, dynamic>.from(payload as Map));
  }

  Future<TrialSession> rejectTrial(
    String id, {
    String note = '',
  }) async {
    final payload = await _client.post(
      '/trial-home/$id/reject',
      authenticated: true,
      body: {'note': note},
    );
    return TrialSession.fromMap(Map<String, dynamic>.from(payload as Map));
  }
}
