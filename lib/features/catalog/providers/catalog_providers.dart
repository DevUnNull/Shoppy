import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_providers.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../models/variant.dart';
import '../services/category_service.dart';
import '../services/product_service.dart';

final productServiceProvider = Provider<ProductService>(
  (ref) => ProductService(ref.watch(apiClientProvider)),
);

final categoryServiceProvider = Provider<CategoryService>(
  (ref) => CategoryService(ref.watch(apiClientProvider)),
);

/// Cây danh mục (cache suốt phiên, `ref.invalidate` để tải lại).
final categoryTreeProvider = FutureProvider<List<Category>>(
  (ref) => ref.watch(categoryServiceProvider).getCategoryTree(),
);

final categoryDetailProvider = FutureProvider.autoDispose.family<Category, int>(
  (ref, id) => ref.watch(categoryServiceProvider).getCategory(id),
);

/// Toàn bộ sản phẩm — dùng cho màn Danh mục (lọc/sort phía client).
final allProductsProvider = FutureProvider<List<Product>>(
  (ref) => ref.watch(productServiceProvider).getAllProducts(),
);

/// Chi tiết sản phẩm + biến thể (gọi song song 2 API).
final productDetailProvider = FutureProvider.autoDispose
    .family<ProductDetail, int>((ref, id) async {
      final service = ref.watch(productServiceProvider);
      final detailFuture = service.getProductDetail(id);
      final variantsFuture = service
          .getVariants(id)
          .then<List<Variant>?>((v) => v)
          .catchError((_) => null);
      final detail = await detailFuture;
      final variants = await variantsFuture;
      return variants == null || variants.isEmpty
          ? detail
          : detail.copyWith(variants: variants);
    });
