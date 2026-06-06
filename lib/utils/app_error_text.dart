import 'dart:async';
import 'dart:io';

import '../services/backend_api_client.dart';

class AppErrorText {
  static String from(
    Object error, {
    String fallback = 'Something went wrong. Please try again.',
  }) {
    if (error is BackendApiException) {
      if (error.isUnauthorized) {
        return 'Please sign in again.';
      }
      if (error.isForbidden) {
        return 'You do not have permission to do that.';
      }
      if (error.isNoInternetConnection) {
        return 'Connection problem. Please try again.';
      }
      if (error.isDnsLookupFailure) {
        return 'Connection problem. Please try again.';
      }
      if (error.isTimeout) {
        return 'Connection problem. Please try again.';
      }
      if (error.isBackendUnavailable) {
        return 'Something went wrong. Please try again.';
      }
      if (error.isTlsFailure) {
        return 'Connection problem. Please try again.';
      }
      if (error.isServerError) {
        return 'Something went wrong. Please try again.';
      }
      if (error.isClientError) {
        final message = error.message.trim();
        return message.isEmpty
            ? 'Request failed. Please check your input and try again.'
            : message;
      }
      final message = error.message.trim();
      return message.isEmpty ? fallback : message;
    }

    if (error is StateError) {
      final message = error.message.toString().trim();
      return message.isEmpty ? fallback : message;
    }

    if (error is TimeoutException) {
      return 'Request timed out. Please try again.';
    }

    if (error is SocketException) {
      return 'Network issue. Check your connection and try again.';
    }

    final text = error.toString().replaceFirst('Bad state: ', '').trim();
    if (text.isEmpty || text == 'Exception' || text == 'Error') {
      return fallback;
    }
    final normalized = text.toLowerCase();
    if (normalized == 'unauthorized' ||
        normalized.contains('session expired') ||
        normalized.contains('sign in again') ||
        normalized.contains('too many authentication requests')) {
      return 'Please sign in again.';
    }
    if (normalized.contains('socketexception') ||
        normalized.contains('clientexception') ||
        normalized.contains('failed host lookup') ||
        normalized.contains('timeout') ||
        normalized.contains('no internet')) {
      return 'Connection problem. Please try again.';
    }
    return text;
  }
}
