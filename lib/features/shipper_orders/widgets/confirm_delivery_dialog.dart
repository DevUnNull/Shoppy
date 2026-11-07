import 'package:flutter/material.dart';

import '../models/shipper_order.dart';
import 'shipper_order_widgets.dart';

class ConfirmDeliveryDialog extends StatefulWidget {
  const ConfirmDeliveryDialog({super.key, required this.order});
  final ShipperOrder order;
  @override
  State<ConfirmDeliveryDialog> createState() => _ConfirmDeliveryDialogState();
}

class _ConfirmDeliveryDialogState extends State<ConfirmDeliveryDialog> {
  bool _cashCollected = false;
  bool _closing = false;

  void _close(bool confirmed) {
    if (_closing) return;
    _closing = true;
    Navigator.pop(context, confirmed);
  }

  @override
  Widget build(BuildContext context) {
    final cod = widget.order.paymentMethod == 'COD';
    final canConfirm =
        widget.order.paymentMethod == 'WALLET' || (cod && _cashCollected);
    return AlertDialog(
      title: const Text('Xác nhận đã giao hàng cho người nhận?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Đơn ${widget.order.displayCode}'),
            const SizedBox(height: 16),
            if (cod) ...[
              Text(
                'Số tiền COD cần thu: ${shipperMoney(widget.order.grandTotal)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Tôi đã thu đủ tiền COD'),
                value: _cashCollected,
                onChanged: (value) =>
                    setState(() => _cashCollected = value ?? false),
              ),
            ] else if (widget.order.paymentMethod == 'WALLET')
              const Text('Khách đã thanh toán qua ví — Không thu tiền')
            else
              const Text(
                'Chưa xác định phương thức thanh toán. Vui lòng tải lại đơn.',
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => _close(false),
          child: const Text('Quay lại'),
        ),
        FilledButton(
          onPressed: canConfirm ? () => _close(true) : null,
          child: const Text('Xác nhận'),
        ),
      ],
    );
  }
}
