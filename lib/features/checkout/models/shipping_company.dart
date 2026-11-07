import '../../../core/network/json_utils.dart';

/// Đơn vị vận chuyển — khớp `GET /shipping-companies`.
class ShippingCompany {
  const ShippingCompany({
    required this.id,
    required this.name,
    required this.code,
    required this.baseFee,
    this.logoUrl,
    this.estimatedDays,
    this.isActive = true,
  });

  final int id;
  final String name;
  final String code;
  final String? logoUrl;

  /// Phí ship cố định của ĐVVC (backend tính phí đơn = baseFee).
  final double baseFee;

  /// Backend chưa trả thời gian dự kiến; hiển thị nếu có.
  final String? estimatedDays;
  final bool isActive;

  factory ShippingCompany.fromJson(Map<String, dynamic> json) {
    final days = json['estimatedDays'] ?? json['estimatedDeliveryTime'];
    return ShippingCompany(
      id: asInt(json['id']),
      name: asString(json['name']),
      code: asString(json['code']),
      logoUrl: asStringOrNull(json['logoUrl']),
      baseFee: asDouble(json['baseFee'] ?? json['fee']),
      estimatedDays: days?.toString(),
      isActive: asString(json['status'], 'ACTIVE') == 'ACTIVE',
    );
  }
}
