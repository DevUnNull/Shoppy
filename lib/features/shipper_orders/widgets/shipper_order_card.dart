import 'package:flutter/material.dart';

import '../models/shipper_order.dart';
import 'pickup_location.dart';
import 'shipper_assign_button.dart';
import 'shipper_order_widgets.dart';

class ShipperOrderCard extends StatelessWidget {
  const ShipperOrderCard({
    super.key,
    required this.order,
    required this.onTap,
    this.allowAssign = true,
  });
  final ShipperOrder order;
  final VoidCallback onTap;
  final bool allowAssign;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Đơn ${order.displayCode}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ShipperStatusBadge(order: order),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              order.recipientName ?? 'Chưa có tên người nhận',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              'Giao đến: ${order.shippingAddress}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (order.shopAddress != null &&
                order.shopAddress!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              PickupLocation(address: order.shopAddress),
            ],
            const Divider(height: 28),
            ShipperPaymentInfo(order: order),
            if (allowAssign) ...[
              const SizedBox(height: 16),
              ShipperAssignButton(order: order),
            ],
          ],
        ),
      ),
    ),
  );
}
