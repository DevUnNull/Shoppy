import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/session_request.dart';
import '../models/shipper_order.dart';
import '../services/shipper_order_service.dart';
import 'shipper_orders_provider.dart';

class ShipperAssignState {
  const ShipperAssignState({this.isBusy = false, this.needsCheck = false});
  final bool isBusy, needsCheck;
}

// Cùng một khóa cho mỗi đơn dù bấm từ danh sách hay màn chi tiết.
final shipperAssignProvider =
    NotifierProvider.family<ShipperAssignNotifier, ShipperAssignState, int>(
      ShipperAssignNotifier.new,
    );

class ShipperAssignNotifier extends Notifier<ShipperAssignState> {
  ShipperAssignNotifier(this.orderId);
  final int orderId;
  @override
  ShipperAssignState build() {
    ref.watch(shipperOrderRepositoryProvider);
    return const ShipperAssignState();
  }

  Future<bool> assign(ShipperOrder order) async {
    final currentRef = ref;
    if (state.isBusy || state.needsCheck) return false;
    if (order.id != orderId || !order.canAssign) {
      throw const ShipperOrderException(
        'Chỉ được nhận đơn sẵn sàng lấy hàng và chưa có tài xế.',
      );
    }
    state = const ShipperAssignState(isBusy: true);
    var needsCheck = true;
    try {
      final current = await _fetchLatest(currentRef);
      if (!currentRef.mounted) return false;
      needsCheck = false;
      if (!current.canAssign) {
        throw const ShipperOrderException(
          'Đơn đã có tài xế nhận hoặc đã đổi trạng thái. Danh sách đã được cập nhật.',
        );
      }
      final repository = ref.read(shipperOrderRepositoryProvider);
      try {
        await repository.assign(orderId);
      } catch (_) {
        if (!currentRef.mounted) return false;
        // PUT timeout có thể đã được BE xử lý. Không tự gửi lại PUT.
        needsCheck = true;
        final latest = await _fetchLatest(currentRef);
        if (!currentRef.mounted) return false;
        needsCheck = false;
        if (latest.status == 'SHIPPING') {
          needsCheck = true;
          final mine = await repository.getMyDeliveries();
          if (!currentRef.mounted) return false;
          needsCheck = false;
          if (mine.any((order) => order.id == orderId)) return true;
          throw const ShipperOrderException('Đơn đã được tài xế khác nhận.');
        }
        if (!latest.canAssign) {
          throw const ShipperOrderException(
            'Đơn đã bị hủy hoặc đã đổi trạng thái, không thể nhận.',
          );
        }
        rethrow;
      }
      if (!currentRef.mounted) return false;
      needsCheck = true;
      final latest = await _fetchLatest(currentRef);
      if (!currentRef.mounted) return false;
      needsCheck = latest.status != 'SHIPPING';
      if (needsCheck) {
        throw const ShipperOrderException(
          'Backend đã xác nhận nhưng chưa lấy được trạng thái đang giao. Hãy kiểm tra lại trạng thái trước khi thao tác tiếp.',
        );
      }
      return true;
    } catch (_) {
      if (!currentRef.mounted) return false;
      rethrow;
    } finally {
      if (currentRef.mounted) {
        state = ShipperAssignState(needsCheck: needsCheck);
        ref.invalidate(availableShipperOrdersProvider);
        ref.invalidate(myShipperDeliveriesProvider);
      }
    }
  }

  Future<ShipperOrder> _fetchLatest(Ref currentRef) {
    if (!currentRef.mounted) {
      throw const ShipperOrderException('Phiên làm việc đã thay đổi.');
    }
    final provider = shipperOrderDetailProvider(orderId);
    currentRef.invalidate(provider);
    return waitForSession(currentRef, currentRef.read(provider.future));
  }

  Future<void> checkStatus() async {
    final currentRef = ref;
    if (state.isBusy) return;
    state = const ShipperAssignState(isBusy: true, needsCheck: true);
    var needsCheck = true;
    try {
      await _fetchLatest(currentRef);
      needsCheck = false;
    } finally {
      if (currentRef.mounted) {
        state = ShipperAssignState(needsCheck: needsCheck);
        ref.invalidate(availableShipperOrdersProvider);
        ref.invalidate(myShipperDeliveriesProvider);
      }
    }
  }
}
