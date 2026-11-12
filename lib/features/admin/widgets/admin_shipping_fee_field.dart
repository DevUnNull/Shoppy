import 'package:flutter/material.dart';

class AdminShippingFeeField extends StatelessWidget {
  const AdminShippingFeeField({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      key: const ValueKey('admin-form-baseFee'),
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        labelText: 'Cước phí cơ bản (VNĐ) *',
        helperText: 'Nhập số không âm, ví dụ: 30000',
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Vui lòng nhập cước phí';
        }
        final fee = num.tryParse(value.trim());
        return fee == null || !fee.isFinite || fee < 0
            ? 'Cước phí phải là số không âm hợp lệ'
            : null;
      },
      onFieldSubmitted: onSubmitted,
    ),
  );
}
