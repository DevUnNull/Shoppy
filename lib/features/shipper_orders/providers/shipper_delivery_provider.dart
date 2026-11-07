import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/shipper_order.dart';
import '../services/shipper_order_service.dart';
import 'shipper_assign_provider.dart';
import 'shipper_cod_provider.dart';
import 'shipper_orders_provider.dart';

class ShipperDeliveryState {
  const ShipperDeliveryState({this.isBusy = false, this.needsCheck = false});
  final bool isBusy, needsCheck;
}

final shipperDeliveryProvider =
    NotifierProvider.family<ShipperDeliveryNotifier, ShipperDeliveryState, int>(
      ShipperDeliveryNotifier.new,
    );

class ShipperDeliveryNotifier extends Notifier<ShipperDeliveryState> {
  ShipperDeliveryNotifier(this.orderId);
  final int orderId;
  @override
  ShipperDeliveryState build() => const ShipperDeliveryState();

  Future<bool> delivered(
    ShipperOrder order, {
    bool cashCollected = false,
  }) async {
    if (state.isBusy ||
        state.needsCheck ||
        ref.read(shipperAssignProvider(orderId)).isBusy) {
      return false;
    }
    if (order.id != orderId ||
        order.status != 'SHIPPING' ||
        order.shipperId == null) {
      throw const ShipperOrderException(
        'Chỉ xác nhận đơn đang giao và đã được gán cho tài xế.',
      );
    }
    if (order.paymentMethod != 'COD' && order.paymentMethod != 'WALLET') {
      throw const ShipperOrderException(
        'Chưa xác định phương thức thanh toán. Vui lòng tải lại đơn.',
      );
    }
    if (order.paymentMethod == 'COD' && !cashCollected) {
      throw const ShipperOrderException(
        'Bạn cần xác nhận đã thu đủ tiền COD trước khi giao thành công.',
      );
    }

    state = const ShipperDeliveryState(isBusy: true);
    var needsCheck = true;
    var sentToBackend = false;
    try {
      final latest = await _fetchLatest();
      final repository = ref.read(shipperOrderRepositoryProvider);
      final mine = await repository.getMyDeliveries();
      needsCheck = false;
      if (latest.status != 'SHIPPING') {
        throw const ShipperOrderException(
          'Đơn không còn đang giao. Chi tiết đã được cập nhật.',
        );
      }
      if (latest.shipperId == null ||
          !mine.any(
            (item) => item.id == orderId && item.shipperId == latest.shipperId,
          )) {
        throw const ShipperOrderException(
          'Đơn không được giao cho tài xế hiện tại.',
          statusCode: 403,
        );
      }
      if (latest.paymentMethod != order.paymentMethod ||
          latest.grandTotal != order.grandTotal) {
        throw const ShipperOrderException(
          'Thông tin thanh toán đã thay đổi. Vui lòng kiểm tra và xác nhận lại.',
        );
      }

      try {
        sentToBackend = true;
        await repository.delivered(orderId);
      } catch (_) {
        // Không tự lặp PUT. Sau timeout, phải đọc trạng thái và kiểm tra lịch sử
        // của chính token này để xác định backend đã giao thành công hay chưa.
        needsCheck = true;
        final updated = await _fetchLatest();
        if (updated.status == 'DELIVERED') {
          final history = await repository.getMyDeliveries(status: 'DELIVERED');
          needsCheck = false;
          if (updated.shipperId != null &&
              history.any(
                (item) =>
                    item.id == orderId && item.shipperId == updated.shipperId,
              )) {
            return true;
          }
          throw const ShipperOrderException(
            'Không xác minh được đơn đã giao thuộc tài xế hiện tại.',
            statusCode: 403,
          );
        }
        needsCheck = false;
        if (updated.status != 'SHIPPING') {
          throw const ShipperOrderException(
            'Đơn đã đổi trạng thái, không thể xác nhận giao.',
          );
        }
        rethrow;
      }
      needsCheck = true;
      final updated = await _fetchLatest();
      needsCheck = updated.status != 'DELIVERED';
      if (needsCheck) {
        throw const ShipperOrderException(
          'Backend đã xác nhận nhưng chưa tải được trạng thái đã giao. Hãy kiểm tra lại trạng thái trước khi thao tác tiếp.',
        );
      }
      return true;
    } finally {
      if (ref.mounted) {
        state = ShipperDeliveryState(needsCheck: needsCheck);
        _refreshLists();
        // Kể cả mất phản hồi, backend có thể đã ghi COD. Chỉ tải lại dữ liệu.
        if (sentToBackend && order.paymentMethod == 'COD') _refreshCod();
      }
    }
  }

  Future<ShipperOrder> _fetchLatest() {
    final provider = shipperOrderDetailProvider(orderId);
    ref.invalidate(provider);
    return ref.read(provider.future);
  }

  Future<void> checkStatus() async {
    if (state.isBusy || ref.read(shipperAssignProvider(orderId)).isBusy) return;
    state = const ShipperDeliveryState(isBusy: true, needsCheck: true);
    var needsCheck = true;
    try {
      final order = await _fetchLatest();
      needsCheck = false;
      if (order.status == 'DELIVERED' && order.paymentMethod == 'COD') {
        _refreshCod();
      }
    } finally {
      if (ref.mounted) {
        state = ShipperDeliveryState(needsCheck: needsCheck);
        _refreshLists();
      }
    }
  }

  void _refreshLists() {
    ref.invalidate(availableShipperOrdersProvider);
    ref.invalidate(myShipperDeliveriesProvider);
    ref.invalidate(shipperDeliveryHistoryProvider);
  }

  void _refreshCod() {
    ref.invalidate(shipperCodBalanceProvider);
    ref.invalidate(shipperCodTransactionsProvider);
    ref.invalidate(codBalanceProvider);
    ref.invalidate(codTransactionsProvider);
  }
}
