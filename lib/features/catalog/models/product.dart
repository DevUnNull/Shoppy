import '../../../core/network/json_utils.dart';
import 'variant.dart';

/// Sản phẩm dạng rút gọn trong danh sách (`/products/getAll`, `/shops/{id}/products`).
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.minPrice,
    required this.maxPrice,
    required this.totalStock,
    required this.shopId,
    this.description,
    this.thumbnailUrl,
    this.shopName,
    this.categoryId,
    this.categoryName,
    this.hasVariants = false,
    this.isActive = true,
    this.soldCount,
    this.rating,
    this.reviewCount,
  });

  final int id;
  final String name;
  final String? description;
  final String? thumbnailUrl;
  final int shopId;
  final String? shopName;
  final int? categoryId;
  final String? categoryName;
  final int totalStock;
  final bool hasVariants;
  final bool isActive;
  final double minPrice;
  final double maxPrice;

  /// Backend hiện chưa trả các trường dưới; FE hiển thị nếu có.
  final int? soldCount;
  final double? rating;
  final int? reviewCount;

  bool get isOutOfStock => totalStock <= 0;

  bool get isMall => (shopName ?? '').toLowerCase().contains('official');

  factory Product.fromJson(Map<String, dynamic> json) {
    final min = asDouble(json['minPrice'] ?? json['price']);
    return Product(
      id: asInt(json['id']),
      name: asString(json['name']),
      description: asStringOrNull(json['description']),
      thumbnailUrl: asStringOrNull(json['thumbnailUrl']),
      shopId: asInt(json['shopId']),
      shopName: asStringOrNull(json['shopName']),
      categoryId: asIntOrNull(json['categoryId']),
      categoryName: asStringOrNull(json['categoryName']),
      totalStock: asInt(json['totalStock']),
      hasVariants: asBool(json['hasVariants']),
      isActive: asBool(json['isActive'], true),
      minPrice: min,
      maxPrice: asDouble(json['maxPrice'], min),
      soldCount: asIntOrNull(
        json['soldCount'] ?? json['sold'] ?? json['totalSold'],
      ),
      rating: asDoubleOrNull(json['averageRating'] ?? json['rating']),
      reviewCount: asIntOrNull(json['reviewCount'] ?? json['totalReviews']),
    );
  }
}

/// Chi tiết sản phẩm — khớp `GET /products/{id}`.
class ProductDetail {
  const ProductDetail({
    required this.product,
    required this.images,
    required this.variants,
  });

  final Product product;
  final List<String> images;
  final List<Variant> variants;

  factory ProductDetail.fromJson(Map<String, dynamic> json) {
    final images = asMapList(json['images'])
        .map((i) => asStringOrNull(i['imageUrl']))
        .whereType<String>()
        .toList();
    final variants = asMapList(json['variants']).map(Variant.fromJson).toList();
    final active = variants.where((v) => v.isActive).map((v) => v.price);
    final base = Product.fromJson({
      ...json,
      'thumbnailUrl':
          json['thumbnailUrl'] ?? (images.isEmpty ? null : images.first),
      if (json['minPrice'] == null && active.isNotEmpty)
        'minPrice': active.reduce((a, b) => a < b ? a : b),
      if (json['maxPrice'] == null && active.isNotEmpty)
        'maxPrice': active.reduce((a, b) => a > b ? a : b),
    });
    return ProductDetail(product: base, images: images, variants: variants);
  }

  ProductDetail copyWith({List<Variant>? variants}) => ProductDetail(
    product: product,
    images: images,
    variants: variants ?? this.variants,
  );
}
