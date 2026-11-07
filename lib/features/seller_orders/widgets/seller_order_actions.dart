import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/seller_order.dart';
import '../providers/seller_order_action_provider.dart';
import 'cancel_order_dialog.dart';

class SellerOrderActions extends ConsumerStatefulWidget {
  const SellerOrderActions({
    super.key,
    required this.order,
    this.isRefreshing = false,
  });

  final SellerOrder order;
  final bool isRefreshing;

  @override
  ConsumerState<SellerOrderActions> createState() => _SellerOrderActionsState();
}

class _SellerOrderActionsState extends ConsumerState<SellerOrderActions> {
  bool _dialogOpen = false;

  Future<void> _confirmAction({required bool cancel}) async {
    final action = ref.read(sellerOrderActionProvider);
    if (_dialogOpen ||
        action.isBusy ||
        action.needsReload ||
        widget.isRefreshing ||
        widget.order.status != 'PROCESSING') {
      return;
    }
    setState(() => _dialogOpen = true);
    try {
      String? reason;
      if (cancel) {
        reason = await showDialog<String>(
          context: context,
          builder: (context) => const CancelOrderDialog(),
        );
        if (reason == null) return;
      } else {
        var answered = false;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Xác nhận đóng gói'),
            content: const Text('Bạn đã đóng gói xong đơn hàng này?'),
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
                child: const Text('Xác nhận'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
      }
      if (!mounted) return;
      final notifier = ref.read(sellerOrderActionProvider.notifier);
      final sent = cancel
          ? await notifier.cancelOrder(widget.order, reason!)
          : await notifier.readyToShip(widget.order);
      if (mounted && sent) {
        _showMessage(
          cancel ? 'Đã hủy đơn hàng.' : 'Đã xác nhận đóng gói hoàn tất.',
        );
      }
    } catch (error) {
      if (mounted) _showMessage('$error');
    } finally {
      if (mounted) setState(() => _dialogOpen = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _reload() async {
    try {
      await ref
          .read(sellerOrderActionProvider.notifier)
          .reloadDetail(widget.order.id);
    } catch (error) {
      if (mounted) _showMessage('Chưa tải được chi tiết. $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(sellerOrderActionProvider);
    if (widget.order.status != 'PROCESSING') return const SizedBox.shrink();
    final disabled = action.isBusy || _dialogOpen || widget.isRefreshing;
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Align(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (action.isBusy) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    const Text(
                      'Đang xử lý, vui lòng chờ…',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (action.needsReload) ...[
                    const Text(
                      'Chưa xác nhận được trạng thái mới của đơn. Hãy tải lại chi tiết trước khi thao tác tiếp.',
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: disabled ? null : _reload,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tải lại chi tiết'),
                    ),
                  ] else ...[
                    FilledButton.icon(
                      onPressed: disabled
                          ? null
                          : () => _confirmAction(cancel: false),
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: const Text(
                        'Xác nhận đóng gói hoàn tất',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: disabled
                          ? null
                          : () => _confirmAction(cancel: true),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Hủy đơn do hết hàng'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
