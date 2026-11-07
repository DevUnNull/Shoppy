import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/seller_order.dart';
import '../providers/seller_order_action_provider.dart';
import '../providers/seller_orders_provider.dart';
import '../widgets/order_error_view.dart';
import '../widgets/order_status_badge.dart';
import '../widgets/seller_order_card.dart';
import '../widgets/seller_order_actions.dart';

class SellerOrderDetailScreen extends ConsumerWidget {
  const SellerOrderDetailScreen({super.key, required this.orderId});

  final int orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = sellerOrderDetailProvider(orderId);
    final detail = ref.watch(provider);
    final action = ref.watch(sellerOrderActionProvider);
    final currentOrder = detail.hasValue ? detail.requireValue : null;
    return PopScope(
      canPop: !action.isBusy,
      child: Scaffold(
        appBar: AppBar(title: Text('Chi tiết đơn #$orderId')),
        bottomNavigationBar: currentOrder == null
            ? null
            : SellerOrderActions(
                order: currentOrder,
                isRefreshing: detail.isLoading,
              ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: detail.when(
              // Giữ thông tin đang có nếu GET tải lại lỗi sau khi thao tác.
              skipError: true,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: OrderErrorView(
                  message: '$error',
                  onRetry: () => ref.invalidate(provider),
                ),
              ),
              data: (order) => RefreshIndicator(
                onRefresh: () async {
                  try {
                    await ref
                        .read(sellerOrderActionProvider.notifier)
                        .reloadDetail(orderId);
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Chưa tải được chi tiết. $error'),
                        ),
                      );
                    }
                  }
                },
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _section('Đơn ${order.displayCode}', [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OrderStatusBadge(status: order.status),
                      ),
                      const SizedBox(height: 12),
                      Text('Ngày đặt: ${_date(order.createdAt)}'),
                      Text('Mã vận đơn: ${order.trackingNumber ?? 'Chưa có'}'),
                    ]),
                    _section('Người nhận', [
                      Text(order.recipientName ?? 'Chưa có tên người nhận'),
                      Text(order.recipientPhone ?? 'Chưa có số điện thoại'),
                      Text(order.shippingAddress),
                      if (order.note != null && order.note!.isNotEmpty)
                        Text('Ghi chú: ${order.note}'),
                    ]),
                    _section('Sản phẩm', [
                      if (order.items.isEmpty)
                        const Text('Chưa có thông tin sản phẩm.'),
                      for (final item in order.items) ...[
                        Text(
                          item.productName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(item.variantName),
                        Text(
                          '${formatOrderMoney(item.price)} × ${item.quantity}',
                        ),
                        Text('Thành tiền: ${formatOrderMoney(item.subtotal)}'),
                        const SizedBox(height: 12),
                      ],
                    ]),
                    _section('Thanh toán', [
                      Text('Phương thức: ${order.paymentMethod}'),
                      const SizedBox(height: 8),
                      Text('Tiền hàng: ${formatOrderMoney(order.totalAmount)}'),
                      Text(
                        'Phí vận chuyển: ${formatOrderMoney(order.shippingFee)}',
                      ),
                      const Divider(),
                      Text(
                        'Tổng thanh toán: ${formatOrderMoney(order.grandTotal)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ]),
                    _section('Hành trình đơn hàng', _trackingWidgets(order)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    ),
  );

  List<Widget> _trackingWidgets(SellerOrder order) => [
    if (order.trackings.isEmpty) const Text('Chưa có cập nhật hành trình.'),
    for (final tracking in order.trackings)
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tracking.description),
            Text(
              _date(tracking.createdAt),
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
  ];

  String _date(String value) {
    final date = DateTime.tryParse(value);
    return date == null ? value : DateFormat('dd/MM/yyyy HH:mm').format(date);
  }
}
