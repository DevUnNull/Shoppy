import '../../orders/models/order.dart';
import '../../orders/services/order_service.dart';
import '../models/checkout_models.dart';
import '../models/shipping_company.dart';

class CheckoutValidationError implements Exception {
  const CheckoutValidationError(this.message, {this.field});

  final String message;

  /// 'address' | 'shipping' | 'variant' | 'wallet' — để UI highlight.
  final String? field;

  @override
  String toString() => message;
}

/// Tổng kết tiền của trang thanh toán.
class CheckoutTotals {
  const CheckoutTotals({
    required this.merchandise,
    required this.shipping,
    this.discount = 0,
  });

  final double merchandise;
  final double shipping;
  final double discount;

  double get total => merchandise + shipping - discount;

  static CheckoutTotals of(
    List<ShopGroup> groups,
    Map<int, int> shippingByShop,
    List<ShippingCompany> companies,
  ) {
    double fee(int shopId) =>
        companies
            .where((c) => c.id == shippingByShop[shopId])
            .firstOrNull
            ?.baseFee ??
        0;
    return CheckoutTotals(
      merchandise: groups.fold(0, (s, g) => s + g.merchandiseTotal),
      shipping: groups.fold(0, (s, g) => s + fee(g.shopId)),
    );
  }
}

/// Kiểm tra dữ liệu và dựng 1 request `POST /orders` cho mỗi shop.
List<(ShopGroup, CreateOrderRequest)> buildOrderRequests({
  required List<ShopGroup> groups,
  required DeliveryAddress? address,
  required Map<int, int> shippingByShop,
  required Map<int, String> notes,
  required PaymentMethod payment,
  required double walletBalance,
  required double total,
}) {
  if (groups.isEmpty) {
    throw const CheckoutValidationError('Không có sản phẩm nào để thanh toán');
  }
  if (address == null || !address.isComplete) {
    throw const CheckoutValidationError(
      'Vui lòng thêm địa chỉ nhận hàng',
      field: 'address',
    );
  }
  for (final g in groups) {
    for (final item in g.items) {
      if (item.variant == null) {
        throw CheckoutValidationError(
          'Sản phẩm "${item.product.name}" chưa có phân loại hợp lệ',
          field: 'variant',
        );
      }
    }
    if (shippingByShop[g.shopId] == null) {
      throw CheckoutValidationError(
        'Vui lòng chọn đơn vị vận chuyển cho ${g.shopName}',
        field: 'shipping',
      );
    }
  }
  if (payment == PaymentMethod.wallet && walletBalance < total) {
    throw const CheckoutValidationError(
      'Số dư Ví Shoppy không đủ để thanh toán',
      field: 'wallet',
    );
  }
  return [
    for (final g in groups)
      (
        g,
        CreateOrderRequest(
          shippingCompanyId: shippingByShop[g.shopId]!,
          address: address,
          paymentMethod: payment,
          note: notes[g.shopId],
          items: [
            for (final i in g.items)
              (variantId: i.variant!.id, quantity: i.quantity),
          ],
        ),
      ),
  ];
}

class CheckoutResult {
  const CheckoutResult({
    required this.placedGroups,
    required this.orders,
    this.error,
  });

  /// Các nhóm (shop) đã đặt thành công.
  final List<ShopGroup> placedGroups;
  final List<Order> orders;

  /// Lỗi ở nhóm đầu tiên thất bại (các nhóm sau không được gửi).
  final Object? error;

  bool get isComplete => error == null;
}

/// Gửi lần lượt từng đơn; dừng ở đơn lỗi đầu tiên để không trừ tiền
/// ví hai lần hoặc tạo đơn ngoài ý muốn khi người dùng thử lại.
Future<CheckoutResult> submitOrders(
  OrderService service,
  List<(ShopGroup, CreateOrderRequest)> requests,
) async {
  final placed = <ShopGroup>[];
  final orders = <Order>[];
  for (final (group, request) in requests) {
    try {
      final order = await service.createOrder(request);
      placed.add(group);
      if (order != null) orders.add(order);
    } catch (e) {
      return CheckoutResult(placedGroups: placed, orders: orders, error: e);
    }
  }
  return CheckoutResult(placedGroups: placed, orders: orders);
}
