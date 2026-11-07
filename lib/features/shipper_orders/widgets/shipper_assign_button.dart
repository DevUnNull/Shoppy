import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/shipper_order.dart';
import '../providers/shipper_assign_provider.dart';

class ShipperAssignButton extends ConsumerStatefulWidget {
  const ShipperAssignButton({
    super.key,
    required this.order,
    this.isRefreshing = false,
  });
  final ShipperOrder order;
  final bool isRefreshing;
  @override
  ConsumerState<ShipperAssignButton> createState() =>
      _ShipperAssignButtonState();
}

class _ShipperAssignButtonState extends ConsumerState<ShipperAssignButton> {
  bool _dialogOpen = false;
  Future<void> _assign() async {
    final provider = shipperAssignProvider(widget.order.id);
    final state = ref.read(provider);
    if (_dialogOpen ||
        state.isBusy ||
        state.needsCheck ||
        widget.isRefreshing ||
        !widget.order.canAssign) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _dialogOpen = true);
    var answered = false;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Nhận đơn giao hàng'),
          content: Text(
            'Bạn muốn nhận đơn ${widget.order.displayCode} để đi giao?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (answered) return;
                answered = true;
                Navigator.pop(context, false);
              },
              child: const Text('Quay lại'),
            ),
            FilledButton(
              onPressed: () {
                if (answered) return;
                answered = true;
                Navigator.pop(context, true);
              },
              child: const Text('Xác nhận nhận đơn'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
      final sent = await ref.read(provider.notifier).assign(widget.order);
      // Thẻ có thể đã biến mất khỏi danh sách sau khi nhận thành công.
      if (sent && messenger.mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Nhận đơn thành công')),
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
          .read(shipperAssignProvider(widget.order.id).notifier)
          .checkStatus();
    } catch (error) {
      if (messenger.mounted) {
        messenger.showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(shipperAssignProvider(widget.order.id));
    if (!widget.order.canAssign) return const SizedBox.shrink();
    final busy = state.isBusy || _dialogOpen || widget.isRefreshing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (state.isBusy)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: LinearProgressIndicator(),
          ),
        if (state.needsCheck) ...[
          const Text('Cần kiểm tra lại trạng thái đơn trước khi thử nhận.'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: busy ? null : _check,
            icon: const Icon(Icons.refresh),
            label: const Text('Kiểm tra lại trạng thái'),
          ),
        ] else
          FilledButton.icon(
            onPressed: busy ? null : _assign,
            icon: const Icon(Icons.local_shipping_outlined),
            label: Text(state.isBusy ? 'Đang xử lý…' : 'Nhận đơn'),
          ),
      ],
    );
  }
}
