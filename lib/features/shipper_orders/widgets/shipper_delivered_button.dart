import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/shipper_order.dart';
import '../providers/shipper_assign_provider.dart';
import '../providers/shipper_delivery_provider.dart';
import '../providers/shipper_orders_provider.dart';
import 'confirm_delivery_dialog.dart';

class ShipperDeliveredButton extends ConsumerStatefulWidget {
  const ShipperDeliveredButton({
    super.key,
    required this.order,
    this.isRefreshing = false,
  });
  final ShipperOrder order;
  final bool isRefreshing;
  @override
  ConsumerState<ShipperDeliveredButton> createState() =>
      _ShipperDeliveredButtonState();
}

class _ShipperDeliveredButtonState
    extends ConsumerState<ShipperDeliveredButton> {
  bool _dialogOpen = false;

  Future<void> _confirm() async {
    final provider = shipperDeliveryProvider(widget.order.id);
    if (_dialogOpen ||
        ref.read(provider).isBusy ||
        ref.read(provider).needsCheck ||
        widget.isRefreshing ||
        ref.read(shipperAssignProvider(widget.order.id)).isBusy) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _dialogOpen = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => ConfirmDeliveryDialog(order: widget.order),
      );
      if (!mounted || confirmed != true) return;
      final sent = await ref
          .read(provider.notifier)
          .delivered(
            widget.order,
            cashCollected: widget.order.paymentMethod == 'COD',
          );
      if (sent && messenger.mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Giao hàng thành công')),
        );
      }
    } catch (error) {
      if (messenger.mounted) {
        messenger.showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _dialogOpen = false);
    }
  }

  Future<void> _check() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(shipperDeliveryProvider(widget.order.id).notifier)
          .checkStatus();
    } catch (error) {
      if (messenger.mounted) {
        messenger.showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final state = ref.watch(shipperDeliveryProvider(order.id));
    final assigning = ref.watch(shipperAssignProvider(order.id)).isBusy;
    if (order.status != 'SHIPPING' || order.shipperId == null) {
      return const SizedBox.shrink();
    }
    final busy =
        state.isBusy || assigning || _dialogOpen || widget.isRefreshing;
    if (state.needsCheck) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Cần kiểm tra lại trạng thái đơn trước khi xác nhận tiếp.',
          ),
          OutlinedButton.icon(
            onPressed: busy ? null : _check,
            icon: const Icon(Icons.refresh),
            label: const Text('Kiểm tra lại trạng thái'),
          ),
        ],
      );
    }
    // /my-deliveries được backend giới hạn theo token hiện tại.
    // Không dùng userId trong JWT để đoán shipperId.
    final mine = ref.watch(myShipperDeliveriesProvider);
    return mine.when(
      skipLoadingOnRefresh: false,
      loading: () => const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Chưa kiểm tra được đơn được giao cho bạn. $error',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          TextButton(
            onPressed: busy
                ? null
                : () => ref.invalidate(myShipperDeliveriesProvider),
            child: const Text('Thử lại'),
          ),
        ],
      ),
      data: (orders) {
        final owned = orders.any(
          (item) => item.id == order.id && item.shipperId == order.shipperId,
        );
        if (!owned) return const SizedBox.shrink();
        if (order.paymentMethod != 'COD' && order.paymentMethod != 'WALLET') {
          return const Text(
            'Chưa xác định phương thức thanh toán. Vui lòng tải lại đơn.',
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.isBusy)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LinearProgressIndicator(),
              ),
            FilledButton.icon(
              onPressed: busy ? null : _confirm,
              icon: const Icon(Icons.task_alt),
              label: Text(
                state.isBusy ? 'Đang xử lý…' : 'Xác nhận giao thành công',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        );
      },
    );
  }
}
