class ShipperOrder {
  const ShipperOrder({
    required this.id,
    required this.status,
    required this.grandTotal,
    required this.paymentMethod,
    required this.shippingAddress,
    required this.createdAt,
    this.shopId,
    this.shopAddress,
    this.recipientName,
    this.recipientPhone,
    this.trackingNumber,
    this.shipperId,
    this.shippingCompanyId,
    this.hasAssignmentInfo = false,
    this.note,
    this.items = const [],
    this.trackings = const [],
  });

  final int id;
  final String status, paymentMethod, shippingAddress, createdAt;
  final double grandTotal;
  final int? shopId, shipperId, shippingCompanyId;
  final String? shopAddress,
      recipientName,
      recipientPhone,
      trackingNumber,
      note;
  final bool hasAssignmentInfo;
  final List<ShipperOrderItem> items;
  final List<ShipperOrderTracking> trackings;

  String get displayCode => '#$id';
  bool get isReady => status == 'READY_TO_SHIP' || status == 'READY_FOR_PICKUP';
  bool get canAssign => isReady && hasAssignmentInfo && shipperId == null;
  double? get cashToCollect => switch (paymentMethod) {
    'COD' => grandTotal,
    'WALLET' => 0,
    _ => null,
  };
  String get statusLabel => switch (status) {
    'READY_TO_SHIP' || 'READY_FOR_PICKUP' => 'Chờ lấy hàng',
    'SHIPPING' => 'Đang giao',
    'DELIVERED' => 'Đã giao',
    'CANCELLED' => 'Đã hủy',
    'PROCESSING' => 'Đang chuẩn bị',
    'PENDING' => 'Chờ xác nhận',
    _ => status,
  };

  factory ShipperOrder.fromJson(Map<String, dynamic> json) {
    final amount = (json['grandTotal'] as num).toDouble();
    if (!amount.isFinite || amount < 0) {
      throw const FormatException('Số tiền không hợp lệ');
    }
    return ShipperOrder(
      id: (json['id'] as num).toInt(),
      status: json['status'] as String,
      grandTotal: amount,
      paymentMethod: json['paymentMethod'] as String,
      shippingAddress: json['shippingAddress'] as String,
      createdAt: json['createdAt'] as String,
      // JSON chi tiết mới không có shopId; đây là thông tin không bắt buộc.
      shopId: (json['shopId'] as num?)?.toInt(),
      shopAddress: json['shopAddress'] as String?,
      shipperId: (json['shipperId'] as num?)?.toInt(),
      shippingCompanyId: (json['shippingCompanyId'] as num?)?.toInt(),
      hasAssignmentInfo: json.containsKey('shipperId'),
      recipientName: json['recipientName'] as String?,
      recipientPhone: json['recipientPhone'] as String?,
      trackingNumber: json['trackingNumber'] as String?,
      note: json['note'] as String?,
      items: (json['items'] as List<dynamic>? ?? [])
          .map(
            (item) => ShipperOrderItem.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      trackings: (json['trackings'] as List<dynamic>? ?? [])
          .map(
            (item) => ShipperOrderTracking.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}

class ShipperOrderItem {
  const ShipperOrderItem({
    required this.name,
    required this.variant,
    required this.quantity,
  });
  final String name, variant;
  final int quantity;
  factory ShipperOrderItem.fromJson(Map<String, dynamic> json) =>
      ShipperOrderItem(
        name: json['productNameSnapshot'] as String,
        variant: json['variantNameSnapshot'] as String,
        quantity: (json['quantity'] as num).toInt(),
      );
}

class ShipperOrderTracking {
  const ShipperOrderTracking({
    required this.description,
    required this.createdAt,
  });
  final String description, createdAt;
  factory ShipperOrderTracking.fromJson(Map<String, dynamic> json) =>
      ShipperOrderTracking(
        description: json['description'] as String,
        createdAt: json['createdAt'] as String,
      );
}
