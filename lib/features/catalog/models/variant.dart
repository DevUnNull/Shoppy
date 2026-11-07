import '../../../core/network/json_utils.dart';

/// Biến thể (SKU) của sản phẩm — khớp `GET /products/{id}/variants`.
class Variant {
  const Variant({
    required this.id,
    required this.name,
    required this.price,
    required this.stockQuantity,
    this.sku,
    this.imageUrl,
    this.images = const [],
    this.isActive = true,
  });

  final int id;

  /// Ví dụ "Đen / 42". Backend lưu phẳng; FE tách thành các nhóm phân loại.
  final String name;
  final String? sku;
  final double price;
  final int stockQuantity;
  final String? imageUrl;
  final List<String> images;
  final bool isActive;

  bool get isAvailable => isActive && stockQuantity > 0;

  factory Variant.fromJson(Map<String, dynamic> json) {
    final images = asMapList(json['images'])
        .map((i) => asStringOrNull(i['imageUrl']))
        .whereType<String>()
        .toList();
    return Variant(
      id: asInt(json['id']),
      name: asString(json['variantName'] ?? json['name']).trim(),
      sku: asStringOrNull(json['sku']),
      price: asDouble(json['price']),
      stockQuantity: asInt(json['stockQuantity'] ?? json['stock']),
      imageUrl:
          asStringOrNull(json['imageUrl']) ??
          (images.isEmpty ? null : images.first),
      images: images,
      isActive: asBool(json['isActive'], true),
    );
  }
}
