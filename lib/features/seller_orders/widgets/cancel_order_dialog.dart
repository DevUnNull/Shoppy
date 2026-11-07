import 'package:flutter/material.dart';

class CancelOrderDialog extends StatefulWidget {
  const CancelOrderDialog({super.key});

  @override
  State<CancelOrderDialog> createState() => _CancelOrderDialogState();
}

class _CancelOrderDialogState extends State<CancelOrderDialog> {
  final _reasonController = TextEditingController(text: 'Shop hết hàng');
  final _formKey = GlobalKey<FormState>();
  bool _closing = false;

  void _close(String? reason) {
    if (_closing) return;
    _closing = true;
    Navigator.pop(context, reason);
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Hủy đơn do hết hàng'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Bạn có chắc muốn hủy đơn hàng này?'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Lý do hủy',
                  border: OutlineInputBorder(),
                ),
                minLines: 2,
                maxLines: 4,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Vui lòng nhập lý do hủy đơn.'
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => _close(null),
          child: const Text('Quay lại'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              _close(_reasonController.text.trim());
            }
          },
          child: const Text('Xác nhận hủy'),
        ),
      ],
    );
  }
}
