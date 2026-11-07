import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/skeleton.dart';
import '../models/order.dart';
import 'order_item_row.dart';

/// Card đơn hàng trong danh sách "Đơn mua".
class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order, required this.onCancel});

  final Order order;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    void openDetail() => AppRouter.orderDetail(context, order.id);
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.storefront,
                      size: 18,
                      color: AppColors.title,
                    ),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Text(
                        order.shopName ?? 'Shop',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (order.shopId != null)
                      OutlinedButton.icon(
                        onPressed: () => AppRouter.shop(context, order.shopId!),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 26),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          foregroundColor: AppColors.body,
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: AppColors.border),
                        ),
                        icon: const Icon(Icons.storefront_outlined, size: 14),
                        label: const Text(
                          'Xem Shop',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
                OrderStatusLabel(status: order.status),
              ],
            ),
          ),
          const Divider(height: 24, indent: 20, endIndent: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                for (final item in order.items)
                  OrderItemRow(item: item, onTap: openDetail),
              ],
            ),
          ),
          Container(
            color: const Color(0xFFFFFEFB),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Thành tiền:  '),
                      TextSpan(
                        text: formatVnd(order.grandTotal),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    if (order.createdAt != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12, right: 8),
                        child: Text(
                          'Đặt lúc ${formatDateTime(order.createdAt!)}',
                          style: const TextStyle(
                            color: AppColors.caption,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (order.status.canCancel)
                      _action('Hủy đơn hàng', onCancel, primary: false),
                    if (order.status == OrderStatus.delivered ||
                        order.status == OrderStatus.cancelled)
                      _action(
                        'Mua lại',
                        () => AppRouter.product(
                          context,
                          order.items.first.productId,
                        ),
                        primary: true,
                      ),
                    _action('Xem chi tiết', openDetail, primary: false),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _action(String label, VoidCallback onTap, {required bool primary}) {
    final style = primary
        ? FilledButton.styleFrom(minimumSize: const Size(150, 40))
        : null;
    return primary
        ? FilledButton(onPressed: onTap, style: style, child: Text(label))
        : OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(150, 40),
              foregroundColor: AppColors.body,
              backgroundColor: Colors.white,
              side: const BorderSide(color: AppColors.border),
            ),
            child: Text(label),
          );
  }
}

class OrderCardSkeleton extends StatelessWidget {
  const OrderCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Skeleton(width: 160, height: 16),
              Spacer(),
              Skeleton(width: 90, height: 16),
            ],
          ),
          SizedBox(height: 20),
          Row(
            children: [
              Skeleton(width: 80, height: 80),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(height: 14),
                    SizedBox(height: 8),
                    Skeleton(width: 120, height: 12),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: Skeleton(width: 200, height: 22),
          ),
        ],
      ),
    );
  }
}
