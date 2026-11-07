import 'package:flutter/material.dart';

import '../../../core/network/json_utils.dart';
import '../../../core/theme/app_colors.dart';

enum NotificationCategory {
  all('Tất cả', Icons.notifications_none),
  order('Cập nhật đơn hàng', Icons.local_shipping_outlined),
  promotion('Khuyến mãi', Icons.local_offer_outlined),
  system('Hệ thống', Icons.info_outline);

  const NotificationCategory(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Một thông báo — `GET /notifications`.
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.read,
    this.referenceId,
    this.createdAt,
  });

  final int id;

  /// Ví dụ: NEW_ORDER_FOR_SELLER, ORDER_STATUS_UPDATED, PROMOTION…
  final String type;
  final String title;
  final String message;
  final bool read;

  /// Thường là ID đơn hàng liên quan.
  final int? referenceId;
  final DateTime? createdAt;

  NotificationCategory get category {
    final t = type.toUpperCase();
    if (t.contains('ORDER') || t.contains('SHIP') || t.contains('DELIVER')) {
      return NotificationCategory.order;
    }
    if (t.contains('PROMO') ||
        t.contains('VOUCHER') ||
        t.contains('SALE') ||
        t.contains('DISCOUNT')) {
      return NotificationCategory.promotion;
    }
    return NotificationCategory.system;
  }

  bool get isSellerOrder => type.toUpperCase().contains('SELLER');

  ({IconData icon, Color color}) get visual {
    final t = type.toUpperCase();
    if (t.contains('CANCEL')) {
      return (icon: Icons.cancel_outlined, color: AppColors.primary);
    }
    if (t.contains('DELIVERED')) {
      return (icon: Icons.check_circle_outline, color: AppColors.success);
    }
    if (t.contains('WALLET') || t.contains('DEPOSIT') || t.contains('REFUND')) {
      return (
        icon: Icons.account_balance_wallet_outlined,
        color: AppColors.success,
      );
    }
    return switch (category) {
      NotificationCategory.order => (
        icon: Icons.local_shipping_outlined,
        color: AppColors.primary,
      ),
      NotificationCategory.promotion => (
        icon: Icons.local_offer_outlined,
        color: AppColors.pending,
      ),
      _ => (icon: Icons.info_outline, color: AppColors.caption),
    };
  }

  NotificationItem markRead() => NotificationItem(
    id: id,
    type: type,
    title: title,
    message: message,
    read: true,
    referenceId: referenceId,
    createdAt: createdAt,
  );

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      NotificationItem(
        id: asInt(json['id']),
        type: asString(json['type'], 'SYSTEM'),
        title: asString(json['title'], 'Thông báo'),
        message: asString(json['message'] ?? json['content']),
        read: asBool(json['read'] ?? json['isRead']),
        referenceId: asIntOrNull(json['referenceId']),
        createdAt: asDate(json['createdAt']),
      );
}
