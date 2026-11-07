import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/seller_order.dart';
import '../models/seller_order_status.dart';
import '../repositories/seller_order_repository.dart';
import '../services/seller_order_service.dart';

final sellerOrderServiceProvider = Provider<SellerOrderService>((ref) {
  final service = SellerOrderService();
  ref.onDispose(service.close);
  return service;
});

final sellerOrderRepositoryProvider = Provider<SellerOrderRepository>((ref) {
  return SellerOrderRepository(ref.watch(sellerOrderServiceProvider));
});

final sellerOrderDetailProvider = FutureProvider.autoDispose
    .family<SellerOrder, int>(
      (ref, orderId) =>
          ref.watch(sellerOrderRepositoryProvider).getOrderDetail(orderId),
      retry: (retryCount, error) => null,
    );

class SellerOrdersState {
  const SellerOrdersState({
    this.status = SellerOrderStatus.pending,
    this.orders = const [],
    this.page = 0,
    this.hasNext = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error = '',
    this.loadMoreError = '',
  });

  final SellerOrderStatus status;
  final List<SellerOrder> orders;
  final int page;
  final bool hasNext;
  final bool isLoading;
  final bool isLoadingMore;
  final String error;
  final String loadMoreError;

  SellerOrdersState copyWith({
    List<SellerOrder>? orders,
    int? page,
    bool? hasNext,
    bool? isLoadingMore,
    String? loadMoreError,
  }) {
    return SellerOrdersState(
      status: status,
      orders: orders ?? this.orders,
      page: page ?? this.page,
      hasNext: hasNext ?? this.hasNext,
      isLoading: isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      loadMoreError: loadMoreError ?? this.loadMoreError,
    );
  }
}

final sellerOrdersProvider =
    NotifierProvider.autoDispose<SellerOrdersNotifier, SellerOrdersState>(
      SellerOrdersNotifier.new,
    );

class SellerOrdersNotifier extends Notifier<SellerOrdersState> {
  int _requestId = 0;

  @override
  SellerOrdersState build() => const SellerOrdersState();

  Future<void> selectStatus(SellerOrderStatus status) => _loadFirstPage(status);

  Future<void> refresh() async {
    // Tên người nhận/chi tiết cũng cần tải mới sau khi quay về từ chi tiết.
    ref.invalidate(sellerOrderDetailProvider);
    await _loadFirstPage(state.status);
  }

  Future<void> _loadFirstPage(SellerOrderStatus status) async {
    final requestId = ++_requestId;
    // Xóa ngay danh sách tab cũ và luôn bắt đầu lại từ trang 0.
    state = SellerOrdersState(status: status, isLoading: true);
    try {
      final result = await ref
          .read(sellerOrderRepositoryProvider)
          .getOrders(status: status.value, page: 0);
      if (!ref.mounted || requestId != _requestId) return;
      state = SellerOrdersState(
        status: status,
        orders: _mergeOrders([], result.orders, status),
        page: 0,
        hasNext: result.hasNext,
      );
    } catch (error) {
      if (!ref.mounted || requestId != _requestId) return;
      state = SellerOrdersState(status: status, error: error.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading ||
        state.isLoadingMore ||
        !state.hasNext ||
        state.error.isNotEmpty) {
      return;
    }
    final requestId = _requestId;
    final nextPage = state.page + 1;
    state = state.copyWith(isLoadingMore: true, loadMoreError: '');
    try {
      final result = await ref
          .read(sellerOrderRepositoryProvider)
          .getOrders(status: state.status.value, page: nextPage);
      if (!ref.mounted || requestId != _requestId) return;
      state = state.copyWith(
        orders: _mergeOrders(state.orders, result.orders, state.status),
        page: nextPage,
        hasNext: result.hasNext,
        isLoadingMore: false,
      );
    } catch (error) {
      if (!ref.mounted || requestId != _requestId) return;
      state = state.copyWith(
        isLoadingMore: false,
        loadMoreError: error.toString(),
      );
    }
  }

  List<SellerOrder> _mergeOrders(
    List<SellerOrder> oldOrders,
    List<SellerOrder> newOrders,
    SellerOrderStatus status,
  ) {
    // Dùng ID làm khóa: không trùng đơn giữa các trang, bản mới cập nhật bản cũ.
    final ordersById = <int, SellerOrder>{};
    for (final order in [...oldOrders, ...newOrders]) {
      if (order.status == status.value) ordersById[order.id] = order;
    }
    return ordersById.values.toList();
  }
}
