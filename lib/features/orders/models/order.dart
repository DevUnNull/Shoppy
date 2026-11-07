import 'package:flutter/material.dart';

import '../../../core/network/json_utils.dart';
import '../../../core/theme/app_colors.dart';

/// Trạng thái đơn hàng phía backend.
enum OrderStatus {
  pending('PENDING', 'Chờ xác nhận', AppColors.pending),
  processing('PROCESSING', 'Đang chuẩn bị', AppColors.pending),
  readyToShip('READY_TO_SHIP', 'Chờ lấy hàng', AppColors.pending),
  shipping('SHIPPING', 'Đang giao', AppColors.success),
  delivered('DELIVERED', 'Đã giao', AppColors.success),
  cancelled('CANCELLED', 'Đã hủy', AppColors.primary),
  unknown('UNKNOWN', 'Không xác định', AppColors.caption);

  const OrderStatus(this.value, this.label, this.color);

  final String value;
  final String label;
  final Color color;

  static OrderStatus parse(dynamic raw) {
    final v = raw?.toString().toUpperCase();
    for (final s in values) {
      if (s.value == v) return s;
    }
    return unknown;
  }

  /// Khách chỉ được hủy khi shop chưa giao cho ĐVVC.
  bool get canCancel => this == pending || this == processing;

  bool get isInProgress =>
      this == pending ||
      this == processing ||
      this == readyToShip ||
      this == shipping;
}

enum PaymentMethod {
  cod('COD', 'Thanh toán khi nhận hàng'),
  wallet('WALLET', 'Ví Shoppy');

  const PaymentMethod(this.value, this.label);

  final String value;
  final String label;

  static PaymentMethod parse(dynamic raw) =>
      raw?.toString().toUpperCase() == 'WALLET' ? wallet : cod;
}

/// Một dòng sản phẩm trong đơn (giá/tên là snapshot lúc đặt).
class OrderItem {
  const OrderItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    this.variantId,
    this.variantName,
    this.imageUrl,
    double? subtotal,
  }) : subtotal = subtotal ?? price * quantity;

  final int id;
  final int productId;
  final int? variantId;
  final String productName;
  final String? variantName;
  final double price;
  final int quantity;
  final double subtotal;

  /// Backend chưa trả ảnh trong đơn; FE tự lấy theo productId nếu thiếu.
  final String? imageUrl;

  bool get hasVariantLabel =>
      variantName != null && variantName!.toLowerCase() != 'mặc định';

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final price = asDouble(json['priceSnapshot'] ?? json['price']);
    final quantity = asInt(json['quantity'], 1);
    return OrderItem(
      id: asInt(json['id']),
      productId: asInt(json['productId']),
      variantId: asIntOrNull(json['productVariantId'] ?? json['variantId']),
      productName: asString(
        json['productNameSnapshot'] ?? json['productName'],
        'Sản phẩm',
      ),
      variantName: asStringOrNull(
        json['variantNameSnapshot'] ?? json['variantName'],
      ),
      price: price,
      quantity: quantity,
      subtotal: asDoubleOrNull(json['subtotal']),
      imageUrl: asStringOrNull(
        json['imageUrl'] ?? json['thumbnailUrl'] ?? json['productImage'],
      ),
    );
  }
}

/// Một bản ghi trong hành trình đơn hàng (`trackings`).
class TrackingStep {
  const TrackingStep({
    required this.id,
    required this.status,
    required this.description,
    required this.createdAt,
    this.location,
  });

  final int id;

  /// ORDER_PLACED, PREPARING, READY_FOR_PICKUP, PICKED_UP, DELIVERED, CANCELLED…
  final String status;
  final String description;
  final DateTime? createdAt;
  final String? location;

  factory TrackingStep.fromJson(Map<String, dynamic> json) => TrackingStep(
    id: asInt(json['id']),
    status: asString(json['status']).toUpperCase(),
    description: asString(json['description'] ?? json['note']),
    createdAt: asDate(json['createdAt'] ?? json['time']),
    location: asStringOrNull(json['location'] ?? json['address']),
  );
}

/// 4 mốc của thanh tiến trình kiểu Shopee.
enum TrackingMilestone {
  placed('Đơn hàng đã đặt', Icons.receipt_long, {'ORDER_PLACED'}),
  waitingPickup('Chờ ĐVVC lấy hàng', Icons.inventory_2_outlined, {
    'PREPARING',
    'READY_FOR_PICKUP',
    'READY_TO_SHIP',
    'PROCESSING',
  }),
  shipping('Đang giao hàng', Icons.local_shipping_outlined, {
    'PICKED_UP',
    'SHIPPING',
    'IN_TRANSIT',
    'OUT_FOR_DELIVERY',
  }),
  delivered('Giao hàng thành công', Icons.check_circle_outline, {'DELIVERED'});

  const TrackingMilestone(this.label, this.icon, this.trackingStatuses);

  final String label;
  final IconData icon;
  final Set<String> trackingStatuses;
}

class Order {
  const Order({
    required this.id,
    required this.status,
    required this.items,
    required this.totalAmount,
    required this.shippingFee,
    required this.grandTotal,
    required this.paymentMethod,
    this.shopId,
    this.shopName,
    this.discount = 0,
    this.recipientName,
    this.recipientPhone,
    this.shippingAddress,
    this.note,
    this.shippingCompanyId,
    this.trackingNumber,
    this.cancelReason,
    this.trackings = const [],
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int? shopId;
  final String? shopName;
  final OrderStatus status;
  final List<OrderItem> items;

  /// Tổng tiền hàng (chưa gồm phí ship).
  final double totalAmount;
  final double shippingFee;
  final double discount;
  final double grandTotal;
  final PaymentMethod paymentMethod;
  final String? recipientName;
  final String? recipientPhone;
  final String? shippingAddress;
  final String? note;
  final int? shippingCompanyId;
  final String? trackingNumber;
  final String? cancelReason;
  final List<TrackingStep> trackings;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  int get totalQuantity => items.fold(0, (sum, i) => sum + i.quantity);

  /// Mốc đã đạt tới (0..3), -1 nếu đơn đã hủy.
  int get reachedMilestone {
    if (status == OrderStatus.cancelled) return -1;
    var reached = switch (status) {
      OrderStatus.delivered => 3,
      OrderStatus.shipping => 2,
      OrderStatus.readyToShip => 1,
      _ => 0,
    };
    for (final m in TrackingMilestone.values) {
      if (trackings.any((t) => m.trackingStatuses.contains(t.status)) &&
          m.index > reached) {
        reached = m.index;
      }
    }
    return reached;
  }

  /// Thời điểm đạt từng mốc (lấy bản ghi tracking sớm nhất của mốc đó).
  DateTime? milestoneTime(TrackingMilestone milestone) {
    final times =
        trackings
            .where((t) => milestone.trackingStatuses.contains(t.status))
            .map((t) => t.createdAt)
            .whereType<DateTime>()
            .toList()
          ..sort();
    if (times.isNotEmpty) return times.first;
    return milestone == TrackingMilestone.placed ? createdAt : null;
  }

  /// Log mới nhất lên đầu.
  List<TrackingStep> get timeline => [...trackings]
    ..sort(
      (a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
    );

  Order copyWith({String? shopName}) => Order(
    id: id,
    shopId: shopId,
    shopName: shopName ?? this.shopName,
    status: status,
    items: items,
    totalAmount: totalAmount,
    shippingFee: shippingFee,
    discount: discount,
    grandTotal: grandTotal,
    paymentMethod: paymentMethod,
    recipientName: recipientName,
    recipientPhone: recipientPhone,
    shippingAddress: shippingAddress,
    note: note,
    shippingCompanyId: shippingCompanyId,
    trackingNumber: trackingNumber,
    cancelReason: cancelReason,
    trackings: trackings,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  factory Order.fromJson(Map<String, dynamic> json) {
    final items = asMapList(json['items'] ?? json['orderItems'])
        .map(OrderItem.fromJson)
        .toList();
    final itemsTotal = items.fold<double>(0, (sum, i) => sum + i.subtotal);
    final total = asDouble(json['totalAmount'], itemsTotal);
    final fee = asDouble(json['shippingFee']);
    final discount = asDouble(json['discountAmount'] ?? json['discount']);
    return Order(
      id: asInt(json['id']),
      shopId: asIntOrNull(json['shopId']),
      shopName: asStringOrNull(json['shopName']),
      status: OrderStatus.parse(json['status']),
      items: items,
      totalAmount: total,
      shippingFee: fee,
      discount: discount,
      grandTotal: asDouble(json['grandTotal'], total + fee - discount),
      paymentMethod: PaymentMethod.parse(json['paymentMethod']),
      recipientName: asStringOrNull(json['recipientName']),
      recipientPhone: asStringOrNull(json['recipientPhone']),
      shippingAddress: asStringOrNull(json['shippingAddress']),
      note: asStringOrNull(json['note']),
      shippingCompanyId: asIntOrNull(json['shippingCompanyId']),
      trackingNumber: asStringOrNull(json['trackingNumber']),
      cancelReason: asStringOrNull(
        json['cancelReason'] ?? json['cancelledReason'],
      ),
      trackings: asMapList(json['trackings'] ?? json['trackingHistory'])
          .map(TrackingStep.fromJson)
          .toList(),
      createdAt: asDate(json['createdAt']),
      updatedAt: asDate(json['updatedAt']),
    );
  }
}
