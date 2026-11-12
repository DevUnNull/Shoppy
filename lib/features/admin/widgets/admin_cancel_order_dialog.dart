import 'package:flutter/material.dart';

Future<String?> showAdminCancelOrderDialog(BuildContext context, int id) async {
  return showDialog<String>(
    context: context,
    builder: (_) => _CancelOrderDialog(id: id),
  );
}

class _CancelOrderDialog extends StatefulWidget {
  const _CancelOrderDialog({required this.id});
  final int id;

  @override
  State<_CancelOrderDialog> createState() => _CancelOrderDialogState();
}

class _CancelOrderDialogState extends State<_CancelOrderDialog> {
  final _controller = TextEditingController();
  final _key = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Hủy khẩn cấp đơn #${widget.id}?'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Form(
          key: _key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Đơn sẽ bị hủy. Nếu đã thanh toán, hệ thống sẽ xử lý hoàn tiền vào ví.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _controller,
                autofocus: true,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Lý do hủy đơn'),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Vui lòng nhập lý do hủy đơn'
                    : null,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Trở lại'),
      ),
      FilledButton(
        onPressed: () {
          if (_key.currentState!.validate()) {
            Navigator.of(context).pop(_controller.text.trim());
          }
        },
        child: const Text('Xác nhận hủy đơn'),
      ),
    ],
  );
}
