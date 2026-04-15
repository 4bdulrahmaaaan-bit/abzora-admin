import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../models/trial_session.dart';
import '../services/backend_api_client.dart';
import '../services/trial_home_api.dart';

class TrialHomeProvider with ChangeNotifier {
  TrialHomeProvider({TrialHomeApi? api}) : _api = api ?? TrialHomeApi();

  final TrialHomeApi _api;

  TrialSession? _currentTrial;
  bool _loading = false;
  String? _error;
  String? _lastActionKey;

  TrialSession? get currentTrial => _currentTrial;
  bool get loading => _loading;
  String? get error => _error;
  bool get isConfigured => _api.isConfigured;

  Future<TrialSession?> fetchMyTrial() async {
    return _runGuarded(() async {
      _currentTrial = await _api.getMyTrial();
      return _currentTrial;
    });
  }

  Future<TrialSession> fetchTrialById(String trialId) async {
    return _runGuarded(() async {
      final session = await _api.getTrialById(trialId);
      _currentTrial = session;
      return session;
    });
  }

  Future<TrialSession> requestTrial({
    required List<Product> items,
    List<Product> recommendedItems = const <Product>[],
    required String addressLabel,
    required String deliverySlot,
    String deliveryWindowLabel = 'Delivered in 24 hours',
    String experienceType = 'premium',
    String recommendedSize = 'M',
    double fitConfidence = 92,
  }) async {
    final actionKey = 'request:${items.map((item) => item.id).join(',')}';
    return _runGuarded(
      () async {
        final session = await _api.requestTrial(
          items: items
              .map((product) => TrialSessionItem.fromProduct(
                    product,
                    recommendedSize: recommendedSize,
                    fitConfidence: fitConfidence,
                  ).toMap())
              .toList(),
          recommendedItems: recommendedItems
              .map((product) => TrialSessionItem.fromProduct(
                    product,
                    recommendedSize: recommendedSize,
                    fitConfidence: fitConfidence - 6,
                    styledForYou: true,
                    source: 'styled',
                  ).toMap())
              .toList(),
          addressLabel: addressLabel,
          deliverySlot: deliverySlot,
          deliveryWindowLabel: deliveryWindowLabel,
          experienceType: experienceType,
        );
        _currentTrial = session;
        return session;
      },
      actionKey: actionKey,
    );
  }

  Future<TrialSession> bookTrial({
    required List<Product> items,
    List<Product> recommendedItems = const <Product>[],
    required String addressLabel,
    required String deliverySlot,
    String deliveryWindowLabel = 'Delivered in 24 hours',
    String experienceType = 'premium',
    String recommendedSize = 'M',
    double fitConfidence = 92,
  }) {
    return requestTrial(
      items: items,
      recommendedItems: recommendedItems,
      addressLabel: addressLabel,
      deliverySlot: deliverySlot,
      deliveryWindowLabel: deliveryWindowLabel,
      experienceType: experienceType,
      recommendedSize: recommendedSize,
      fitConfidence: fitConfidence,
    );
  }

  Future<TrialSession> modifyTrial({
    required String trialId,
    List<Product>? items,
    String? addressLabel,
    String? deliverySlot,
    String? experienceType,
    String recommendedSize = 'M',
    double fitConfidence = 92,
  }) async {
    return _runGuarded(() async {
      final session = await _api.modifyTrial(
        trialId,
        items: items
            ?.map((product) => TrialSessionItem.fromProduct(
                  product,
                  recommendedSize: recommendedSize,
                  fitConfidence: fitConfidence,
                ).toMap())
            .toList(),
        addressLabel: addressLabel,
        deliverySlot: deliverySlot,
        experienceType: experienceType,
      );
      _currentTrial = session;
      return session;
    }, actionKey: 'modify:$trialId');
  }

  Future<TrialSession> cancelTrial(String trialId, {String note = ''}) async {
    return _runGuarded(() async {
      final session = await _api.cancelTrial(trialId, note: note);
      _currentTrial = session;
      return session;
    }, actionKey: 'cancel:$trialId');
  }

  Future<TrialSession> submitFeedback({
    required String trialId,
    required String fit,
    String note = '',
    String tailoringRecommendation = '',
    List<String> adjustmentOptions = const <String>[],
    String status = 'completed',
  }) async {
    return _runGuarded(() async {
      final session = await _api.submitFitFeedback(
        trialId,
        fit: fit,
        note: note,
        tailoringRecommendation: tailoringRecommendation,
        adjustmentOptions: adjustmentOptions,
        status: status,
      );
      _currentTrial = session;
      return session;
    }, actionKey: 'feedback:$trialId');
  }

  Future<TrialSession> completeTrial({
    required String trialId,
    required List<String> keptItems,
    required List<String> returnedItems,
    bool useTailoring = false,
    String tailoringRequest = '',
    List<String> adjustmentOptions = const <String>[],
  }) async {
    return _runGuarded(() async {
      final session = useTailoring
          ? await _api.convertToTailoring(
              trialId,
              tailoringRequest: tailoringRequest,
              adjustmentOptions: adjustmentOptions,
            )
          : await _api.convertToOrder(
              trialId,
              keptItems: keptItems,
              returnedItems: returnedItems,
            );
      _currentTrial = session;
      return session;
    }, actionKey: 'complete:$trialId:${useTailoring ? 'tailor' : 'order'}');
  }

  Future<T> _runGuarded<T>(
    Future<T> Function() action, {
    String? actionKey,
  }) async {
    if (_loading && actionKey != null && actionKey == _lastActionKey) {
      throw StateError('Please wait while we finish your last action.');
    }

    _loading = true;
    _error = null;
    _lastActionKey = actionKey;
    notifyListeners();

    try {
      return await action();
    } on BackendApiException catch (error) {
      _error = error.message;
      rethrow;
    } catch (error) {
      _error = error.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      _loading = false;
      _lastActionKey = null;
      notifyListeners();
    }
  }
}
