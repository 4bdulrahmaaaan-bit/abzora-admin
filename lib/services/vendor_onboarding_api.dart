import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'app_config.dart';
import 'backend_api_client.dart';

class VendorOnboardingApi {
  const VendorOnboardingApi({BackendApiClient? apiClient}) : _apiClient = apiClient ?? const BackendApiClient();

  final BackendApiClient _apiClient;
  static const String _basePath = '/api/vendor/onboarding/draft';

  Future<void> saveDraft(Map<String, dynamic> payload) async {
    await _withRetries(
      operation: () => _apiClient.post(
        _basePath,
        body: payload,
        authenticated: true,
      ),
      actionName: 'saveDraft',
      payload: payload,
    );
  }

  Future<Map<String, dynamic>?> getDraft() async {
    try {
      final response = await _withRetries(
        operation: () => _apiClient.get(
          _basePath,
          authenticated: true,
        ),
        actionName: 'getDraft',
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
    await _withRetries(
      operation: () => _apiClient.delete(
        _basePath,
        authenticated: true,
      ),
      actionName: 'deleteDraft',
    );
  }

  Future<void> updateStep(int currentStep) async {
    await _withRetries(
      operation: () => _apiClient.patch(
        '$_basePath/step',
        body: {'currentStep': currentStep},
        authenticated: true,
      ),
      actionName: 'updateStep',
    );
  }

  Future<T> _withRetries<T>({
    required Future<T> Function() operation,
    required String actionName,
    Map<String, dynamic>? payload,
  }) async {
    final baseUrl = AppConfig.backendBaseUrl;
    debugPrint('[ONBOARDING_API] Action: $actionName');
    debugPrint('[BASE_URL] $baseUrl');
    debugPrint('[REQUEST_ENDPOINT] $_basePath');

    int attempt = 1;
    final delays = [const Duration(seconds: 2), const Duration(seconds: 4), const Duration(seconds: 8)];

    while (true) {
      final startTime = DateTime.now();
      try {
        debugPrint('[ONBOARDING_DRAFT_SAVE] Attempt $attempt');
        return await operation();
      } catch (e) {
        final duration = DateTime.now().difference(startTime);
        debugPrint('[ONBOARDING_DRAFT_SAVE_FAILED] Attempt: $attempt, Duration: ${duration.inMilliseconds}ms, Error: $e');

        if (e is BackendApiException && (e.isDnsLookupFailure || e.isNoInternetConnection || e.isBackendUnavailable || e.isTimeout)) {
          if (attempt <= delays.length) {
            await Future.delayed(delays[attempt - 1]);
            attempt++;
            continue;
          }
        }
        
        // Retries exhausted or non-retryable error
        Connectivity().checkConnectivity().then((connectivityResult) {
          final networkType = connectivityResult.isNotEmpty ? connectivityResult.first.name : 'unknown';
          Sentry.captureException(
            e,
            withScope: (scope) {
              scope.setTag('userId', payload?['userId']?.toString() ?? 'unknown');
              scope.setTag('endpoint', '$_basePath ($actionName)');
              scope.setTag('baseUrl', baseUrl);
              scope.setTag('retryCount', attempt.toString());
              scope.setTag('networkType', networkType);
              scope.setTag('syncStatus', 'sync_failed');
              scope.setTag('draftVersion', payload?['version']?.toString() ?? 'unknown');
              scope.setContexts('ONBOARDING_DRAFT_SAVE_FAILED', {
                'userId': payload?['userId'],
                'endpoint': '$_basePath ($actionName)',
                'baseUrl': baseUrl,
                'retryCount': attempt,
                'networkType': networkType,
                'syncStatus': 'sync_failed',
                'draftVersion': payload?['version'],
              });
            },
          );
        });

        // Fallback to Hive handled by caller or rethrow
        rethrow;
      }
    }
  }
}
