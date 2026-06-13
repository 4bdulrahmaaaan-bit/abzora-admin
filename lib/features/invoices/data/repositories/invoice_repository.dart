import '../../domain/entities/invoice_entity.dart';
import '../datasources/invoice_remote_data_source.dart';

class InvoiceRepository {
  InvoiceRepository(this._remote);

  final InvoiceRemoteDataSource _remote;

  Future<List<InvoiceEntity>> getMyInvoices() => _remote.fetchMyInvoices();

  Future<List<InvoiceEntity>> getVendorInvoices({int limit = 100}) =>
      _remote.fetchVendorInvoices(limit: limit);

  Future<List<InvoiceEntity>> getAdminInvoices({
    int limit = 50,
    int page = 1,
    String search = '',
    String paymentStatus = '',
    String status = '',
  }) => _remote.fetchAdminInvoices(
    limit: limit,
    page: page,
    search: search,
    paymentStatus: paymentStatus,
    status: status,
  );

  Future<InvoiceEntity> getInvoice(String id) => _remote.fetchInvoiceById(id);

  Future<String> getDownloadUrl(String id) => _remote.getSignedDownloadUrl(id);

  Future<void> emailInvoice(String id, {String email = ''}) =>
      _remote.queueEmail(id, email: email);

  Future<Map<String, dynamic>> getGstSummary({
    String? dateFrom,
    String? dateTo,
  }) => _remote.fetchGstSummary(dateFrom: dateFrom, dateTo: dateTo);

  Future<List<Map<String, dynamic>>> getEmailLogs({int limit = 100}) =>
      _remote.fetchEmailLogs(limit: limit);

  Future<Map<String, dynamic>> getReplayDashboard() =>
      _remote.fetchReplayDashboard();

  Future<void> replayDlq({int limit = 25, required String confirmation}) =>
      _remote.replayDlq(limit: limit, confirmation: confirmation);

  Future<void> resendEmailLog(String emailLogId) =>
      _remote.resendEmailLog(emailLogId);

  Future<Map<String, dynamic>> getQueueHealth() => _remote.fetchQueueHealth();

  Future<Map<String, dynamic>> getStorageHealth() =>
      _remote.fetchStorageHealth();

  Future<Map<String, dynamic>> getEmailHealth() => _remote.fetchEmailHealth();

  Future<Map<String, dynamic>> getInvoiceHealth() =>
      _remote.fetchInvoiceHealth();

  Future<List<Map<String, dynamic>>> getReplayAudit({int limit = 200}) =>
      _remote.fetchReplayAudit(limit: limit);

  Future<List<Map<String, dynamic>>> getSuppressions({int limit = 200}) =>
      _remote.fetchSuppressions(limit: limit);

  Future<Map<String, dynamic>> verifyInvoice(
    String invoiceId, {
    String hash = '',
  }) => _remote.verifyInvoice(invoiceId, hash: hash);

  Future<void> pauseQueue({
    required String queueName,
    required String confirmation,
  }) => _remote.pauseQueue(queueName: queueName, confirmation: confirmation);

  Future<void> resumeQueue({
    required String queueName,
    required String confirmation,
  }) => _remote.resumeQueue(queueName: queueName, confirmation: confirmation);

  Future<void> freezeInvoice(
    String invoiceId, {
    required String freezeState,
    bool legalHold = false,
  }) => _remote.freezeInvoice(
    invoiceId,
    freezeState: freezeState,
    legalHold: legalHold,
  );

  String exportCsvUrl() => _remote.exportCsvUrl();

  String exportXlsxUrl() => _remote.exportXlsxUrl();
}
