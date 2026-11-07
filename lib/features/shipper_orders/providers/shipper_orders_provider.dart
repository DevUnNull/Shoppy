import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/shipper_order.dart';
import '../repositories/shipper_order_repository.dart';
import '../services/shipper_order_service.dart';

final shipperOrderServiceProvider = Provider<ShipperOrderService>((ref) {
  final service = ShipperOrderService();
  ref.onDispose(service.close);
  return service;
});
final shipperOrderRepositoryProvider = Provider<ShipperOrderRepository>(
  (ref) => ShipperOrderRepository(ref.watch(shipperOrderServiceProvider)),
);
final availableShipperOrdersProvider =
    FutureProvider.autoDispose<List<ShipperOrder>>(
      (ref) => ref.watch(shipperOrderRepositoryProvider).getAvailableOrders(),
      retry: (count, error) => null,
    );
final myShipperDeliveriesProvider =
    FutureProvider.autoDispose<List<ShipperOrder>>(
      (ref) => ref.watch(shipperOrderRepositoryProvider).getMyDeliveries(),
      retry: (count, error) => null,
    );
final shipperDeliveryHistoryProvider =
    FutureProvider.autoDispose<List<ShipperOrder>>(
      (ref) => ref
          .watch(shipperOrderRepositoryProvider)
          .getMyDeliveries(status: 'DELIVERED'),
      retry: (count, error) => null,
    );
// Giữ chi tiết trong phiên để nút ở danh sách cũng có thể kiểm tra trạng thái.
final shipperOrderDetailProvider = FutureProvider.family<ShipperOrder, int>(
  (ref, id) => ref.watch(shipperOrderRepositoryProvider).getOrderDetail(id),
  retry: (count, error) => null,
);
