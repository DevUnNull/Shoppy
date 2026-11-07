import '../../../core/network/json_utils.dart';

/// Thông tin công khai của shop — khớp `GET /shops/{id}`.
class Shop {
  const Shop({
    required this.id,
    required this.name,
    this.description,
    this.logoUrl,
    this.address,
    this.status,
    this.createdAt,
    this.productCount,
    this.responseRate,
    this.followerCount,
    this.rating,
  });

  final int id;
  final String name;
  final String? description;
  final String? logoUrl;
  final String? address;
  final String? status;
  final DateTime? createdAt;

  /// Lấy từ `products.totalElements` đi kèm response.
  final int? productCount;

  /// Backend hiện chưa trả các chỉ số dưới; FE hiển thị "—" nếu thiếu.
  final double? responseRate;
  final int? followerCount;
  final double? rating;

  bool get isActive => (status ?? 'ACTIVE') == 'ACTIVE';

  factory Shop.fromJson(Map<String, dynamic> json) {
    final products = json['products'];
    return Shop(
      id: asInt(json['id']),
      name: asString(json['name']),
      description: asStringOrNull(json['description']),
      logoUrl: asStringOrNull(json['logoUrl']),
      address: asStringOrNull(json['address']),
      status: asStringOrNull(json['status']),
      createdAt: asDate(json['createdAt']),
      productCount:
          asIntOrNull(json['productCount']) ??
          (products is Map ? asIntOrNull(products['totalElements']) : null),
      responseRate: asDoubleOrNull(json['responseRate']),
      followerCount: asIntOrNull(json['followerCount']),
      rating: asDoubleOrNull(json['rating']),
    );
  }
}
