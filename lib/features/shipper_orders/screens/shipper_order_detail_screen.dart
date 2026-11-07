import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/shipper_assign_provider.dart';
import '../providers/shipper_delivery_provider.dart';
import '../providers/shipper_orders_provider.dart';
import '../widgets/pickup_location.dart';
import '../widgets/shipper_assign_button.dart';
import '../widgets/shipper_delivered_button.dart';
import '../widgets/shipper_order_widgets.dart';

class ShipperOrderDetailScreen extends ConsumerWidget {
  const ShipperOrderDetailScreen({super.key, required this.orderId});
  final int orderId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = shipperOrderDetailProvider(orderId);
    final detail = ref.watch(provider);
    final assignment = ref.watch(shipperAssignProvider(orderId));
    final delivery = ref.watch(shipperDeliveryProvider(orderId));
    final current = detail.hasValue ? detail.requireValue : null;
    return PopScope(
      canPop: !assignment.isBusy && !delivery.isBusy,
      child: Scaffold(
        appBar: AppBar(title: Text('Chi tiết đơn giao #$orderId')),
        bottomNavigationBar:
            current == null ||
                (!current.canAssign && current.status != 'SHIPPING')
            ? null
            : SafeArea(
                top: false,
                child: Align(
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: current.status == 'SHIPPING'
                          ? ShipperDeliveredButton(
                              order: current,
                              isRefreshing: detail.isLoading,
                            )
                          : ShipperAssignButton(
                              order: current,
                              isRefreshing: detail.isLoading,
                            ),
                    ),
                  ),
                ),
              ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: detail.when(
              skipError: true,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: ShipperErrorView(
                  error: error,
                  onRetry: () => ref.invalidate(provider),
                ),
              ),
              data: (order) => RefreshIndicator(
                onRefresh: () async {
                  try {
                    if (order.status == 'SHIPPING' ||
                        order.status == 'DELIVERED') {
                      await ref
                          .read(shipperDeliveryProvider(orderId).notifier)
                          .checkStatus();
                    } else {
                      await ref
                          .read(shipperAssignProvider(orderId).notifier)
                          .checkStatus();
                    }
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('$error')));
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
                        child: ShipperStatusBadge(order: order),
                      ),
                      const SizedBox(height: 12),
                      Text('Mã vận đơn: ${order.trackingNumber ?? 'Chưa có'}'),
                      Text('Ngày đặt: ${_date(order.createdAt)}'),
                    ]),
                    _section('Lấy hàng', [
                      if (order.shopId != null) Text('Shop #${order.shopId}'),
                      PickupLocation(address: order.shopAddress),
                    ]),
                    _section('Người nhận', [
                      Text(order.recipientName ?? 'Chưa có tên người nhận'),
                      Text(order.recipientPhone ?? 'Chưa có số điện thoại'),
                      Text(order.shippingAddress),
                      if (order.note != null && order.note!.trim().isNotEmpty)
                        Text('Ghi chú: ${order.note}'),
                    ]),
                    _section('Thanh toán', [ShipperPaymentInfo(order: order)]),
                    _section('Sản phẩm', [
                      if (order.items.isEmpty)
                        const Text('Chưa có thông tin sản phẩm'),
                      for (final item in order.items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text('Phân loại: ${item.variant}'),
                              Text('Số lượng: ${item.quantity}'),
                            ],
                          ),
                        ),
                    ]),
                    _section('Hành trình đơn hàng', [
                      if (order.trackings.isEmpty)
                        const Text('Chưa có cập nhật hành trình'),
                      for (final event in order.trackings)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(event.description),
                              Text(
                                _date(event.createdAt),
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ]),
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
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    ),
  );
  String _date(String value) {
    final date = DateTime.tryParse(value);
    return date == null ? value : DateFormat('dd/MM/yyyy HH:mm').format(date);
  }
}
