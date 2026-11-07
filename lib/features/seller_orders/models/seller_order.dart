class SellerOrder {
  const SellerOrder({
    required this.id,
    required this.shopId,
    required this.status,
    required this.grandTotal,
    required this.totalAmount,
    required this.shippingFee,
    required this.paymentMethod,
    required this.shippingAddress,
    required this.createdAt,
    this.recipientName,
    this.recipientPhone,
    this.trackingNumber,
    this.note,
    this.items = const [],
    this.trackings = const [],
  });

  final int id;
  final int shopId;
  final String status;
  final double grandTotal;
  final double totalAmount;
  final double shippingFee;
  final String paymentMethod;
  final String shippingAddress;
  final String createdAt;
  final String? recipientName;
  final String? recipientPhone;
  final String? trackingNumber;
  final String? note;
  final List<SellerOrderItem> items;
  final List<SellerOrderTracking> trackings;

  // Backend chưa trả mã đơn riêng nên hiển thị theo ID, ví dụ #6.
  String get displayCode => '#$id';

  factory SellerOrder.fromJson(Map<String, dynamic> json) {
    final items = json['items'] as List<dynamic>? ?? [];
    final trackings = json['trackings'] as List<dynamic>? ?? [];

    return SellerOrder(
      id: (json['id'] as num).toInt(),
      shopId: (json['shopId'] as num).toInt(),
      status: json['status'] as String,
      grandTotal: (json['grandTotal'] as num).toDouble(),
      totalAmount: (json['totalAmount'] as num).toDouble(),
      shippingFee: (json['shippingFee'] as num).toDouble(),
      paymentMethod: json['paymentMethod'] as String,
      shippingAddress: json['shippingAddress'] as String,
      createdAt: json['createdAt'] as String,
      recipientName: json['recipientName'] as String?,
      recipientPhone: json['recipientPhone'] as String?,
      trackingNumber: json['trackingNumber'] as String?,
      note: json['note'] as String?,
      items: items
          .map(
            (item) => SellerOrderItem.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      trackings: trackings
          .map(
            (tracking) => SellerOrderTracking.fromJson(
              Map<String, dynamic>.from(tracking as Map),
            ),
          )
          .toList(),
    );
  }
}

class SellerOrderItem {
  const SellerOrderItem({
    required this.productName,
    required this.variantName,
    required this.price,
    required this.quantity,
    required this.subtotal,
  });

  final String productName;
  final String variantName;
  final double price;
  final int quantity;
  final double subtotal;

  factory SellerOrderItem.fromJson(Map<String, dynamic> json) {
    return SellerOrderItem(
      productName: json['productNameSnapshot'] as String,
      variantName: json['variantNameSnapshot'] as String,
      price: (json['priceSnapshot'] as num).toDouble(),
      quantity: (json['quantity'] as num).toInt(),
      subtotal: (json['subtotal'] as num).toDouble(),
    );
  }
}

class SellerOrderTracking {
  const SellerOrderTracking({
    required this.status,
    required this.description,
    required this.createdAt,
  });

  final String status;
  final String description;
  final String createdAt;

  factory SellerOrderTracking.fromJson(Map<String, dynamic> json) {
    return SellerOrderTracking(
      status: json['status'] as String,
      description: json['description'] as String,
      createdAt: json['createdAt'] as String,
    );
  }
}
