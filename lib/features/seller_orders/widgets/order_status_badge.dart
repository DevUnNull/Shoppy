import 'package:flutter/material.dart';

import '../models/seller_order_status.dart';

class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'DELIVERED' => Colors.green.shade700,
      'CANCELLED' => Colors.red.shade700,
      'SHIPPING' => Colors.blue.shade700,
      'READY_TO_SHIP' => Colors.teal.shade700,
      _ => Colors.orange.shade900,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        SellerOrderStatus.labelOf(status),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
