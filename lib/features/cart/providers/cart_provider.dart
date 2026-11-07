import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catalog/models/product.dart';
import '../../catalog/models/variant.dart';

class CartItem {
  const CartItem({
    required this.product,
    required this.variant,
    required this.quantity,
  });

  final Product product;
  final Variant? variant;
  final int quantity;

  String get key => '${product.id}:${variant?.id ?? 0}';

  double get unitPrice => variant?.price ?? product.minPrice;

  CartItem withQuantity(int value) =>
      CartItem(product: product, variant: variant, quantity: value);
}

/// Giỏ hàng tạm phía client để cập nhật badge header.
/// Phân hệ Cart/Checkout sẽ đồng bộ với API giỏ hàng của backend.
class CartNotifier extends Notifier<List<CartItem>> {
  @override
  List<CartItem> build() => const [];

  /// Trả về số lượng thực tế trong giỏ của dòng này sau khi thêm.
  int add(
    Product product,
    Variant? variant,
    int quantity, {
    required int maxStock,
  }) {
    final item = CartItem(
      product: product,
      variant: variant,
      quantity: quantity,
    );
    final index = state.indexWhere((i) => i.key == item.key);
    if (index == -1) {
      final clamped = quantity.clamp(1, maxStock);
      state = [...state, item.withQuantity(clamped)];
      return clamped;
    }
    final merged = (state[index].quantity + quantity).clamp(1, maxStock);
    state = [
      for (var i = 0; i < state.length; i++)
        i == index ? state[i].withQuantity(merged) : state[i],
    ];
    return merged;
  }

  void remove(String key) => state = state.where((i) => i.key != key).toList();
}

final cartProvider = NotifierProvider<CartNotifier, List<CartItem>>(
  CartNotifier.new,
);

/// Số dòng sản phẩm khác nhau (Shopee hiển thị số này trên icon giỏ).
final cartCountProvider = Provider<int>(
  (ref) => ref.watch(cartProvider).length,
);
