import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/invoice_remote_data_source.dart';
import '../../data/repositories/invoice_repository.dart';
import '../../domain/entities/invoice_entity.dart';
import '../../../../services/authenticated_dio_factory.dart';

class InvoiceListQuery {
  const InvoiceListQuery({
    this.search = '',
    this.paymentStatus = '',
    this.status = '',
    this.page = 1,
    this.limit = 30,
  });

  final String search;
  final String paymentStatus;
  final String status;
  final int page;
  final int limit;

  InvoiceListQuery copyWith({
    String? search,
    String? paymentStatus,
    String? status,
    int? page,
    int? limit,
  }) {
    return InvoiceListQuery(
      search: search ?? this.search,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      status: status ?? this.status,
      page: page ?? this.page,
      limit: limit ?? this.limit,
    );
  }
}

class InvoicePagerState {
  const InvoicePagerState({
    this.items = const <InvoiceEntity>[],
    this.loading = false,
    this.hasMore = true,
    this.error = '',
    this.query = const InvoiceListQuery(),
  });

  final List<InvoiceEntity> items;
  final bool loading;
  final bool hasMore;
  final String error;
  final InvoiceListQuery query;

  InvoicePagerState copyWith({
    List<InvoiceEntity>? items,
    bool? loading,
    bool? hasMore,
    String? error,
    InvoiceListQuery? query,
  }) {
    return InvoicePagerState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      hasMore: hasMore ?? this.hasMore,
      error: error ?? this.error,
      query: query ?? this.query,
    );
  }
}

final invoiceDioProvider = Provider<Dio>((ref) {
  return createAuthenticatedDio(
    BaseOptions(
      baseUrl: const String.fromEnvironment(
        'BACKEND_BASE_URL',
        defaultValue: 'https://abzora-backend.onrender.com',
      ),
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );
});

final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  return InvoiceRepository(
    InvoiceRemoteDataSource(ref.watch(invoiceDioProvider)),
  );
});

final myInvoicesProvider = FutureProvider.autoDispose<List<InvoiceEntity>>((
  ref,
) {
  return ref.watch(invoiceRepositoryProvider).getMyInvoices();
});

final invoiceDetailsProvider = FutureProvider.autoDispose
    .family<InvoiceEntity, String>((ref, id) {
      return ref.watch(invoiceRepositoryProvider).getInvoice(id);
    });

final gstSummaryProvider = FutureProvider.autoDispose<Map<String, dynamic>>((
  ref,
) {
  return ref.watch(invoiceRepositoryProvider).getGstSummary();
});

final customerInvoiceQueryProvider =
    StateProvider.autoDispose<InvoiceListQuery>(
      (ref) => const InvoiceListQuery(),
    );

final vendorInvoiceQueryProvider = StateProvider.autoDispose<InvoiceListQuery>(
  (ref) => const InvoiceListQuery(limit: 50),
);

class InvoicePagerNotifier extends StateNotifier<InvoicePagerState> {
  InvoicePagerNotifier(this._loadPage) : super(const InvoicePagerState());

  final Future<List<InvoiceEntity>> Function(InvoiceListQuery query) _loadPage;

  Future<void> refresh({InvoiceListQuery? query}) async {
    final q = (query ?? state.query).copyWith(page: 1);
    state = state.copyWith(loading: true, error: '', query: q);
    try {
      final rows = await _loadPage(q);
      state = state.copyWith(
        loading: false,
        items: rows,
        hasMore: rows.length >= q.limit,
        query: q,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> nextPage() async {
    if (state.loading || !state.hasMore) return;
    final q = state.query.copyWith(page: state.query.page + 1);
    state = state.copyWith(loading: true, error: '');
    try {
      final rows = await _loadPage(q);
      final merged = <String, InvoiceEntity>{
        for (final i in state.items) i.id: i,
      };
      for (final row in rows) {
        merged[row.id] = row;
      }
      state = state.copyWith(
        loading: false,
        items: merged.values.toList(),
        hasMore: rows.length >= q.limit,
        query: q,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }
}

final customerInvoicePagerProvider =
    StateNotifierProvider.autoDispose<InvoicePagerNotifier, InvoicePagerState>((
      ref,
    ) {
      final repo = ref.watch(invoiceRepositoryProvider);
      final notifier = InvoicePagerNotifier((query) => repo.getMyInvoices());
      unawaited(notifier.refresh());
      return notifier;
    });

final vendorInvoicePagerProvider =
    StateNotifierProvider.autoDispose<InvoicePagerNotifier, InvoicePagerState>((
      ref,
    ) {
      final repo = ref.watch(invoiceRepositoryProvider);
      final notifier = InvoicePagerNotifier(
        (query) => repo.getVendorInvoices(limit: query.limit),
      );
      unawaited(notifier.refresh());
      return notifier;
    });

final adminInvoicePagerProvider =
    StateNotifierProvider.autoDispose<InvoicePagerNotifier, InvoicePagerState>((
      ref,
    ) {
      final repo = ref.watch(invoiceRepositoryProvider);
      final notifier = InvoicePagerNotifier(
        (query) => repo.getAdminInvoices(
          limit: query.limit,
          page: query.page,
          paymentStatus: query.paymentStatus,
          status: query.status,
          search: query.search,
        ),
      );
      unawaited(notifier.refresh());
      return notifier;
    });

final invoiceEmailLogsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      return ref.watch(invoiceRepositoryProvider).getEmailLogs(limit: 200);
    });

final invoiceReplayDashboardProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
      return ref.watch(invoiceRepositoryProvider).getReplayDashboard();
    });

final invoiceQueueHealthProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
      return ref.watch(invoiceRepositoryProvider).getQueueHealth();
    });

final invoiceStorageHealthProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
      return ref.watch(invoiceRepositoryProvider).getStorageHealth();
    });

final invoiceEmailHealthProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
      return ref.watch(invoiceRepositoryProvider).getEmailHealth();
    });

final invoiceOpsHealthProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
      return ref.watch(invoiceRepositoryProvider).getInvoiceHealth();
    });

final invoiceReplayAuditProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      return ref.watch(invoiceRepositoryProvider).getReplayAudit(limit: 200);
    });

final invoiceSuppressionsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      return ref.watch(invoiceRepositoryProvider).getSuppressions(limit: 200);
    });
