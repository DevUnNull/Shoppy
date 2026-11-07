import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_network_image.dart';
import '../models/order.dart';
import '../providers/order_providers.dart';

/// Một dòng sản phẩm trong đơn: thumbnail, tên, phân loại, xSL, giá.
class OrderItemRow extends ConsumerWidget {
  const OrderItemRow({super.key, required this.item, this.onTap});

  final OrderItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumb =
        item.imageUrl ??
        ref.watch(productThumbnailProvider(item.productId)).value;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
              ),
              child: AppNetworkImage(url: thumb),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.title,
                    ),
                  ),
                  if (item.hasVariantLabel)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Phân loại hàng: ${item.variantName}',
                        style: const TextStyle(color: AppColors.caption),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    'x${item.quantity}',
                    style: const TextStyle(color: AppColors.title),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              formatVnd(item.price),
              style: const TextStyle(color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nhãn trạng thái đơn góc phải (chữ in hoa, màu theo trạng thái).
class OrderStatusLabel extends StatelessWidget {
  const OrderStatusLabel({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final color =
        status == OrderStatus.pending ||
            status == OrderStatus.processing ||
            status == OrderStatus.readyToShip
        ? const Color(0xFFD48F00) // vàng đậm cho dễ đọc trên nền trắng
        : status.color;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (status == OrderStatus.delivered) ...[
          const Icon(
            Icons.local_shipping_outlined,
            size: 16,
            color: AppColors.success,
          ),
          const SizedBox(width: 4),
          const Text(
            'Giao hàng thành công',
            style: TextStyle(color: AppColors.success),
          ),
          Container(
            width: 1,
            height: 14,
            color: AppColors.border,
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ],
        Text(
          status.label.toUpperCase(),
          style: TextStyle(color: color, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
