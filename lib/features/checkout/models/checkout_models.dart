import '../../cart/providers/cart_provider.dart';
import '../../orders/models/order.dart';

/// Địa chỉ nhận hàng (backend chưa có API sổ địa chỉ -> lưu trên máy).
class DeliveryAddress {
  const DeliveryAddress({
    required this.name,
    required this.phone,
    required this.address,
  });

  final String name;
  final String phone;
  final String address;

  bool get isComplete =>
      name.trim().isNotEmpty &&
      phone.trim().isNotEmpty &&
      address.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'address': address,
  };

  factory DeliveryAddress.fromJson(Map<String, dynamic> json) =>
      DeliveryAddress(
        name: json['name']?.toString() ?? '',
        phone: json['phone']?.toString() ?? '',
        address: json['address']?.toString() ?? '',
      );
}

/// Nhóm sản phẩm theo shop — mỗi nhóm tạo thành 1 đơn hàng riêng.
class ShopGroup {
  const ShopGroup({
    required this.shopId,
    required this.shopName,
    required this.items,
  });

  final int shopId;
  final String shopName;
  final List<CartItem> items;

  double get merchandiseTotal =>
      items.fold(0, (sum, i) => sum + i.unitPrice * i.quantity);

  int get quantity => items.fold(0, (sum, i) => sum + i.quantity);

  static List<ShopGroup> fromItems(List<CartItem> items) {
    final byShop = <int, List<CartItem>>{};
    for (final item in items) {
      byShop.putIfAbsent(item.product.shopId, () => []).add(item);
    }
    return [
      for (final entry in byShop.entries)
        ShopGroup(
          shopId: entry.key,
          shopName: entry.value.first.product.shopName ?? 'Shop #${entry.key}',
          items: entry.value,
        ),
    ];
  }
}

/// Body `POST /orders` (đã xác minh tên trường với backend).
class CreateOrderRequest {
  const CreateOrderRequest({
    required this.shippingCompanyId,
    required this.address,
    required this.paymentMethod,
    required this.items,
    this.note,
  });

  final int shippingCompanyId;
  final DeliveryAddress address;
  final PaymentMethod paymentMethod;
  final List<({int variantId, int quantity})> items;
  final String? note;

  Map<String, dynamic> toJson() => {
    'shippingCompanyId': shippingCompanyId,
    'recipientName': address.name.trim(),
    'recipientPhone': address.phone.trim(),
    'shippingAddress': address.address.trim(),
    'paymentMethod': paymentMethod.value,
    if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
    'items': [
      for (final i in items)
        {'productVariantId': i.variantId, 'quantity': i.quantity},
    ],
  };
}
