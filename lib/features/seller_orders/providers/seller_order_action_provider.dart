import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/session_request.dart';
import '../models/seller_order.dart';
import '../services/seller_order_service.dart';
import 'seller_orders_provider.dart';

class SellerOrderActionState {
  const SellerOrderActionState({this.isBusy = false, this.needsReload = false});

  final bool isBusy;
  // PUT có thể đã thành công nhưng GET lại bị mất mạng: phải tải lại trước.
  final bool needsReload;
}

final sellerOrderActionProvider =
    NotifierProvider.autoDispose<
      SellerOrderActionNotifier,
      SellerOrderActionState
    >(SellerOrderActionNotifier.new);

class SellerOrderActionNotifier extends Notifier<SellerOrderActionState> {
  @override
  SellerOrderActionState build() {
    ref.watch(sellerOrderRepositoryProvider);
    return const SellerOrderActionState();
  }

  Future<bool> readyToShip(SellerOrder order) =>
      _submit(order, cancelReason: null);

  Future<bool> cancelOrder(SellerOrder order, String reason) {
    if (reason.trim().isEmpty) {
      throw const SellerOrderException('Vui lòng nhập lý do hủy đơn.');
    }
    return _submit(order, cancelReason: reason.trim());
  }

  Future<bool> _submit(
    SellerOrder order, {
    required String? cancelReason,
  }) async {
    final currentRef = ref;
    if (state.isBusy || state.needsReload) return false;
    if (order.status != 'PROCESSING') {
      throw const SellerOrderException(
        'Chỉ được thao tác khi đơn đang chuẩn bị hàng (PROCESSING).',
      );
    }

    state = const SellerOrderActionState(isBusy: true);
    var needsReload = false;
    try {
      final repository = ref.read(sellerOrderRepositoryProvider);
      try {
        if (cancelReason == null) {
          await repository.readyToShip(order.id);
        } else {
          await repository.cancelOrder(order.id, cancelReason);
        }
      } catch (_) {
        if (!currentRef.mounted) return false;
        // Tải lại cả khi PUT báo lỗi: đơn có thể đã đổi trạng thái ở nơi khác,
        // hoặc backend đã xử lý xong trước khi kết nối bị ngắt.
        try {
          await _fetchLatest(currentRef, order.id);
        } catch (_) {
          needsReload = true;
        }
        rethrow;
      }

      try {
        if (!currentRef.mounted) return false;
        final latest = await _fetchLatest(currentRef, order.id);
        if (!currentRef.mounted) return false;
        needsReload = latest.status == 'PROCESSING';
      } catch (_) {
        if (!currentRef.mounted) return false;
        needsReload = true;
      }
      if (needsReload) {
        throw const SellerOrderException(
          'Backend đã xác nhận thao tác nhưng chưa tải được trạng thái mới. Vui lòng tải lại chi tiết trước khi thao tác tiếp.',
        );
      }
      return true;
    } finally {
      if (currentRef.mounted) {
        state = SellerOrderActionState(needsReload: needsReload);
      }
    }
  }

  Future<SellerOrder> _fetchLatest(Ref currentRef, int orderId) {
    if (!currentRef.mounted) {
      throw const SellerOrderException('Phiên làm việc đã thay đổi.');
    }
    final provider = sellerOrderDetailProvider(orderId);
    currentRef.invalidate(provider);
    return waitForSession(currentRef, currentRef.read(provider.future));
  }

  Future<void> reloadDetail(int orderId) async {
    final currentRef = ref;
    if (state.isBusy) return;
    final wasNeedsReload = state.needsReload;
    state = SellerOrderActionState(isBusy: true, needsReload: wasNeedsReload);
    var needsReload = wasNeedsReload;
    try {
      await _fetchLatest(currentRef, orderId);
      needsReload = false;
    } finally {
      if (currentRef.mounted) {
        state = SellerOrderActionState(needsReload: needsReload);
      }
    }
  }
}
