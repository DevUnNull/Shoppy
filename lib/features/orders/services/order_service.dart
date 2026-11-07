import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/json_utils.dart';
import '../../../core/network/page_result.dart';
import '../../catalog/services/product_service.dart';
import '../../checkout/models/checkout_models.dart';
import '../../checkout/models/shipping_company.dart';
import '../models/order.dart';

class OrderService {
  OrderService(this._client);

  final ApiClient _client;

  /// `GET /shipping-companies`
  Future<List<ShippingCompany>> getShippingCompanies() async {
    final data = await _client.get('/shipping-companies');
    return asMapList(data)
        .map(ShippingCompany.fromJson)
        .where((c) => c.isActive)
        .toList();
  }

  /// `POST /orders` — tạo 1 đơn cho 1 shop. Trả về đơn vừa tạo nếu backend
  /// trả kèm dữ liệu (null nếu chỉ trả message).
  Future<Order?> createOrder(CreateOrderRequest request) async {
    final data = await _client.post('/orders', body: request.toJson());
    if (data is Map) return Order.fromJson(asMap(data));
    if (data is List && data.isNotEmpty && data.first is Map) {
      return Order.fromJson(asMap(data.first));
    }
    return null;
  }

  /// `GET /orders/my?page=&size=`
  Future<PageResult<Order>> getMyOrders({int page = 0, int size = 20}) async {
    final data = await _client.get(
      '/orders/my',
      query: {'page': page, 'size': size},
    );
    return PageResult.fromJson(data, Order.fromJson);
  }

  /// Tải toàn bộ đơn mua để lọc theo tab + tìm kiếm phía client.
  Future<List<Order>> getAllMyOrders() =>
      collectPages((page) => getMyOrders(page: page, size: 50));

  /// `GET /orders/{id}` — chi tiết + `trackings`.
  Future<Order> getOrder(int id) async {
    final data = await _client.get('/orders/$id');
    if (data is! Map) throw const ApiException('Không tìm thấy đơn hàng.');
    return Order.fromJson(asMap(data));
  }

  /// `PUT /orders/{id}/cancel` — body `{reason}`.
  Future<void> cancelOrder(int id, String reason) async {
    await _client.put('/orders/$id/cancel', body: {'reason': reason});
  }
}
