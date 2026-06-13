import 'package:dio/dio.dart';

import '../models/invoice_model.dart';

class InvoiceRemoteDataSource {
  InvoiceRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<InvoiceModel>> fetchMyInvoices({int limit = 30}) async {
    final response = await _dio.get(
      '/api/invoices/my',
      queryParameters: {'limit': limit},
    );
    final data = (response.data['data'] as List? ?? const []);
    return data
        .map((e) => InvoiceModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<InvoiceModel>> fetchAdminInvoices({
    int limit = 50,
    int page = 1,
    String search = '',
    String paymentStatus = '',
    String status = '',
  }) async {
    final response = await _dio.get(
      '/api/invoices/admin/list',
      queryParameters: {
        'limit': limit,
        'page': page,
        if (paymentStatus.isNotEmpty) 'paymentStatus': paymentStatus,
        if (status.isNotEmpty) 'status': status,
        if (search.isNotEmpty) 'customerId': search,
      },
    );
    final data = (response.data['data'] as List? ?? const []);
    return data
        .map((e) => InvoiceModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<InvoiceModel>> fetchVendorInvoices({int limit = 100}) async {
    final response = await _dio.get(
      '/api/invoices/vendor',
      queryParameters: {'limit': limit},
    );
    final data = (response.data['data'] as List? ?? const []);
    return data
        .map((e) => InvoiceModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<InvoiceModel> fetchInvoiceById(String invoiceId) async {
    final response = await _dio.get('/api/invoices/$invoiceId');
    return InvoiceModel.fromJson(
      Map<String, dynamic>.from(response.data['data'] as Map),
    );
  }

  Future<String> getSignedDownloadUrl(String invoiceId) async {
    final response = await _dio.get('/api/invoices/download-link/$invoiceId');
    return (response.data['data']['absoluteSignedUrl'] ??
            response.data['data']['signedUrl'])
        .toString();
  }

  Future<void> queueEmail(String invoiceId, {String email = ''}) async {
    await _dio.post('/api/invoices/$invoiceId/email', data: {'email': email});
  }

  Future<Map<String, dynamic>> fetchGstSummary({
    String? dateFrom,
    String? dateTo,
  }) async {
    final response = await _dio.get(
      '/api/invoices/admin/reports/gst',
      queryParameters: {'dateFrom': dateFrom, 'dateTo': dateTo},
    );
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<List<Map<String, dynamic>>> fetchEmailLogs({int limit = 100}) async {
    final response = await _dio.get(
      '/api/invoices/admin/email-logs',
      queryParameters: {'limit': limit},
    );
    final data = (response.data['data'] as List? ?? const []);
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> fetchReplayDashboard() async {
    final response = await _dio.get('/api/invoices/admin/replay-dashboard');
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<Map<String, dynamic>> fetchQueueHealth() async {
    final response = await _dio.get('/health/queue');
    return Map<String, dynamic>.from(response.data['data'] as Map? ?? const {});
  }

  Future<Map<String, dynamic>> fetchStorageHealth() async {
    final response = await _dio.get('/health/storage');
    return Map<String, dynamic>.from(response.data['data'] as Map? ?? const {});
  }

  Future<Map<String, dynamic>> fetchEmailHealth() async {
    final response = await _dio.get('/health/email');
    return Map<String, dynamic>.from(response.data['data'] as Map? ?? const {});
  }

  Future<Map<String, dynamic>> fetchInvoiceHealth() async {
    final response = await _dio.get('/health/invoices');
    return Map<String, dynamic>.from(response.data['data'] as Map? ?? const {});
  }

  Future<List<Map<String, dynamic>>> fetchReplayAudit({int limit = 200}) async {
    final response = await _dio.get(
      '/api/invoices/admin/replay-audit',
      queryParameters: {'limit': limit},
    );
    final data = (response.data['data'] as List? ?? const []);
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchSuppressions({
    int limit = 200,
  }) async {
    final response = await _dio.get(
      '/api/invoices/admin/suppressions',
      queryParameters: {'limit': limit},
    );
    final data = (response.data['data'] as List? ?? const []);
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> verifyInvoice(
    String invoiceId, {
    String hash = '',
  }) async {
    final response = await _dio.get(
      '/api/invoices/verify/invoice/$invoiceId',
      queryParameters: {if (hash.isNotEmpty) 'hash': hash},
    );
    return Map<String, dynamic>.from(response.data);
  }

  Future<void> pauseQueue({
    required String queueName,
    required String confirmation,
  }) async {
    await _dio.post(
      '/api/invoices/admin/queue/pause',
      data: {'queueName': queueName, 'confirmation': confirmation},
    );
  }

  Future<void> resumeQueue({
    required String queueName,
    required String confirmation,
  }) async {
    await _dio.post(
      '/api/invoices/admin/queue/resume',
      data: {'queueName': queueName, 'confirmation': confirmation},
    );
  }

  Future<void> freezeInvoice(
    String invoiceId, {
    required String freezeState,
    bool legalHold = false,
  }) async {
    await _dio.patch(
      '/api/invoices/admin/$invoiceId/freeze',
      data: {'freezeState': freezeState, 'legalHold': legalHold},
    );
  }

  Future<void> replayDlq({int limit = 25, required String confirmation}) async {
    await _dio.post(
      '/api/invoices/admin/queue/replay-dlq',
      data: {'limit': limit, 'confirmation': confirmation},
    );
  }

  Future<void> resendEmailLog(String emailLogId) async {
    await _dio.post('/api/invoices/admin/email-logs/$emailLogId/resend');
  }

  String exportCsvUrl() => '/api/invoices/admin/export/csv';

  String exportXlsxUrl() => '/api/invoices/admin/export/xlsx';
}
