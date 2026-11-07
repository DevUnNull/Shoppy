import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/seller_order.dart';
import '../providers/seller_orders_provider.dart';
import 'order_status_badge.dart';

String formatOrderMoney(num amount) {
  return NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  ).format(amount);
}

class SellerOrderCard extends StatelessWidget {
  const SellerOrderCard({super.key, required this.order, required this.onTap});

  final SellerOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Đơn ${order.displayCode}',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  OrderStatusBadge(status: order.status),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.person_outline, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: OrderRecipient(order: order)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.shippingAddress,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Divider(height: 28),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Tổng thanh toán'),
                  Text(
                    formatOrderMoney(order.grandTotal),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OrderRecipient extends ConsumerWidget {
  const OrderRecipient({super.key, required this.order});

  final SellerOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // API danh sách chưa có recipientName. Chỉ tải chi tiết cho thẻ đang hiển thị.
    if (order.recipientName != null) return _name(order.recipientName!);
    final detailProvider = sellerOrderDetailProvider(order.id);
    final detail = ref.watch(detailProvider);
    return detail.when(
      data: (value) => _name(value.recipientName ?? ''),
      loading: () => const Text('Đang tải người nhận…'),
      error: (error, stack) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Không tải được người nhận. $error',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          TextButton(
            onPressed: () => ref.invalidate(detailProvider),
            child: const Text('Thử lại tên người nhận'),
          ),
        ],
      ),
    );
  }

  Widget _name(String name) => Text(
    name.trim().isEmpty ? 'Chưa có tên người nhận' : name,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
  );
}
