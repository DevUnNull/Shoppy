import 'product.dart';

/// Các tiêu chí của sort bar Shopee.
enum ProductSort {
  popular('Phổ biến'),
  newest('Mới nhất'),
  bestSelling('Bán chạy'),
  priceAsc('Giá: Thấp đến Cao'),
  priceDesc('Giá: Cao đến Thấp');

  const ProductSort(this.label);

  final String label;

  bool get isPrice => this == priceAsc || this == priceDesc;
}

/// Lọc theo tập danh mục (rỗng = tất cả) và sắp xếp phía client.
List<Product> applyCatalogQuery(
  List<Product> products, {
  Set<int> categoryIds = const {},
  ProductSort sort = ProductSort.popular,
}) {
  final result = products
      .where((p) => p.isActive)
      .where((p) => categoryIds.isEmpty || categoryIds.contains(p.categoryId))
      .toList();
  switch (sort) {
    case ProductSort.popular:
      // Giữ thứ tự backend; đẩy sản phẩm hết hàng xuống cuối.
      final inStock = result.where((p) => !p.isOutOfStock).toList();
      final outOfStock = result.where((p) => p.isOutOfStock).toList();
      return [...inStock, ...outOfStock];
    case ProductSort.newest:
      result.sort((a, b) => b.id.compareTo(a.id));
    case ProductSort.bestSelling:
      result.sort((a, b) => (b.soldCount ?? 0).compareTo(a.soldCount ?? 0));
    case ProductSort.priceAsc:
      result.sort((a, b) => a.minPrice.compareTo(b.minPrice));
    case ProductSort.priceDesc:
      result.sort((a, b) => b.minPrice.compareTo(a.minPrice));
  }
  return result;
}
