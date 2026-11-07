import '../models/seller_order.dart';
import '../models/seller_orders_page.dart';
import '../services/seller_order_service.dart';

class SellerOrderRepository {
  SellerOrderRepository(this.service);

  final SellerOrderService service;

  Future<void> readyToShip(int orderId) => service.readyToShip(orderId);

  Future<void> cancelOrder(int orderId, String reason) =>
      service.cancelOrder(orderId, reason);

  Future<SellerOrdersPage> getOrders({
    required String status,
    required int page,
  }) async {
    final data = await service.getOrders(status: status, page: page);
    try {
      return SellerOrdersPage.fromJson(data);
    } catch (_) {
      throw const SellerOrderException(
        'Không đọc được danh sách đơn hàng từ backend.',
      );
    }
  }

  Future<SellerOrder> getOrderDetail(int orderId) async {
    final data = await service.getOrderDetail(orderId);
    try {
      final order = SellerOrder.fromJson(data);
      if (order.id != orderId) {
        throw const SellerOrderException(
          'Backend trả về sai đơn hàng được yêu cầu.',
        );
      }
      return order;
    } on SellerOrderException {
      rethrow;
    } catch (_) {
      throw const SellerOrderException(
        'Không đọc được chi tiết đơn hàng từ backend.',
      );
    }
  }
}
