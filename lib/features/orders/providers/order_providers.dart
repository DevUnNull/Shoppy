import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_providers.dart';
import '../../catalog/providers/catalog_providers.dart';
import '../../checkout/models/shipping_company.dart';
import '../../shop/providers/shop_providers.dart';
import '../models/order.dart';
import '../services/order_service.dart';

final orderServiceProvider = Provider<OrderService>(
  (ref) => OrderService(ref.watch(apiClientProvider)),
);

final shippingCompaniesProvider = FutureProvider<List<ShippingCompany>>(
  (ref) => ref.watch(orderServiceProvider).getShippingCompanies(),
);

/// Gắn tên shop vào đơn (backend chỉ trả `shopId`).
Future<List<Order>> _withShopNames(Ref ref, List<Order> orders) async {
  final ids = orders.map((o) => o.shopId).whereType<int>().toSet();
  final names = <int, String>{};
  await Future.wait(
    ids.map((id) async {
      try {
        names[id] = (await ref.read(shopServiceProvider).getShop(id)).name;
      } catch (_) {
        names[id] = 'Shop #$id';
      }
    }),
  );
  return [
    for (final o in orders)
      o.shopName != null || o.shopId == null
          ? o
          : o.copyWith(shopName: names[o.shopId]),
  ];
}

/// Toàn bộ đơn mua của tôi (mới nhất trước).
final myOrdersProvider = FutureProvider.autoDispose<List<Order>>((ref) async {
  // Sao chép trước khi sort: không sửa list gốc của service.
  final orders = [...await ref.watch(orderServiceProvider).getAllMyOrders()];
  orders.sort((a, b) => b.id.compareTo(a.id));
  return _withShopNames(ref, orders);
});

final orderDetailProvider = FutureProvider.autoDispose.family<Order, int>((
  ref,
  id,
) async {
  final order = await ref.watch(orderServiceProvider).getOrder(id);
  return (await _withShopNames(ref, [order])).first;
});

/// Ảnh sản phẩm cho dòng đơn hàng (đơn chỉ lưu snapshot tên/giá).
final productThumbnailProvider = FutureProvider.autoDispose
    .family<String?, int>((ref, productId) async {
      try {
        final detail = await ref.watch(productDetailProvider(productId).future);
        return detail.product.thumbnailUrl ??
            (detail.images.isEmpty ? null : detail.images.first);
      } catch (_) {
        return null;
      }
    });

/// Tab trạng thái của màn "Đơn mua".
enum OrderTab {
  all('Tất cả', {}),
  pending('Chờ xác nhận', {OrderStatus.pending}),
  toShip('Chờ lấy hàng', {OrderStatus.processing, OrderStatus.readyToShip}),
  shipping('Đang giao', {OrderStatus.shipping}),
  delivered('Đã giao', {OrderStatus.delivered}),
  cancelled('Đã hủy', {OrderStatus.cancelled});

  const OrderTab(this.label, this.statuses);

  final String label;
  final Set<OrderStatus> statuses;

  bool matches(Order order) =>
      statuses.isEmpty || statuses.contains(order.status);

  /// Chỉ hiện badge đếm cho các tab còn đang xử lý.
  bool get showsBadge => this == pending || this == toShip || this == shipping;
}

/// Lọc theo tab + tìm theo mã đơn / tên shop / tên sản phẩm.
List<Order> filterOrders(List<Order> orders, OrderTab tab, String query) {
  final q = query.trim().toLowerCase().replaceAll('#', '');
  return orders.where((o) {
    if (!tab.matches(o)) return false;
    if (q.isEmpty) return true;
    return o.id.toString() == q ||
        o.id.toString().contains(q) ||
        (o.shopName ?? '').toLowerCase().contains(q) ||
        o.items.any((i) => i.productName.toLowerCase().contains(q));
  }).toList();
}
