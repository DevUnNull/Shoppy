import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_providers.dart';
import '../../catalog/models/product.dart';
import '../models/shop.dart';
import '../services/shop_service.dart';

final shopServiceProvider = Provider<ShopService>(
  (ref) => ShopService(ref.watch(apiClientProvider)),
);

final shopProvider = FutureProvider.autoDispose.family<Shop, int>(
  (ref, id) => ref.watch(shopServiceProvider).getShop(id),
);

/// Toàn bộ sản phẩm của shop (sort + phân trang phía client).
final shopProductsProvider = FutureProvider.autoDispose
    .family<List<Product>, int>(
      (ref, id) => ref.watch(shopServiceProvider).getAllShopProducts(id),
    );

/// Trạng thái "Theo dõi" cục bộ (backend chưa có API follow).
class FollowedShopsNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() => const {};

  bool toggle(int shopId) {
    final next = {...state};
    final followed = !next.remove(shopId);
    if (followed) next.add(shopId);
    state = next;
    return followed;
  }
}

final followedShopsProvider = NotifierProvider<FollowedShopsNotifier, Set<int>>(
  FollowedShopsNotifier.new,
);
