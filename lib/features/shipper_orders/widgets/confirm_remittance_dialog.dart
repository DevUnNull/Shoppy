import 'package:flutter/material.dart';

import 'shipper_order_widgets.dart';

class ConfirmRemittanceDialog extends StatefulWidget {
  const ConfirmRemittanceDialog({
    super.key,
    required this.amount,
    required this.note,
  });
  final int amount;
  final String note;
  @override
  State<ConfirmRemittanceDialog> createState() =>
      _ConfirmRemittanceDialogState();
}

class _ConfirmRemittanceDialogState extends State<ConfirmRemittanceDialog> {
  bool _closing = false;
  void _close(bool confirmed) {
    if (_closing) return;
    _closing = true;
    Navigator.pop(context, confirmed);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Xác nhận nộp tiền COD'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Nộp về công ty vận chuyển của bạn'),
          const SizedBox(height: 12),
          Text(
            'Số tiền: ${shipperMoney(widget.amount)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text('Ghi chú: ${widget.note.isEmpty ? 'Không có' : widget.note}'),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: () => _close(false), child: const Text('Quay lại')),
      FilledButton(
        onPressed: () => _close(true),
        child: const Text('Xác nhận nộp'),
      ),
    ],
  );
}
