import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../orders/widgets/tracking_widgets.dart';
import '../models/checkout_models.dart';

/// Card "Địa Chỉ Nhận Hàng" với viền sọc xanh - đỏ ở mép trên.
class AddressCard extends StatelessWidget {
  const AddressCard({
    super.key,
    required this.address,
    required this.onChange,
    this.highlightError = false,
  });

  final DeliveryAddress? address;
  final VoidCallback onChange;
  final bool highlightError;

  @override
  Widget build(BuildContext context) {
    final a = address;
    final complete = a != null && a.isComplete;
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AirmailStripe(),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.location_on, color: AppColors.primary, size: 20),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Địa Chỉ Nhận Hàng',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    if (complete) ...[
                      Text(
                        '${a.name} (+84) ${a.phone.startsWith('0') ? a.phone.substring(1) : a.phone}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        a.address,
                        style: const TextStyle(color: AppColors.title),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.primary),
                        ),
                        child: const Text(
                          'Mặc Định',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ] else
                      Text(
                        'Bạn chưa có địa chỉ nhận hàng. Vui lòng thêm địa chỉ.',
                        style: TextStyle(
                          color: highlightError
                              ? AppColors.primary
                              : AppColors.caption,
                        ),
                      ),
                    TextButton(
                      onPressed: onChange,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF0055AA),
                      ),
                      child: Text(
                        complete ? 'Thay đổi địa chỉ' : '+ Thêm địa chỉ',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Form sửa địa chỉ nhận hàng. Trả về địa chỉ mới hoặc null nếu đóng.
Future<DeliveryAddress?> showAddressDialog(
  BuildContext context,
  DeliveryAddress? initial,
) => showDialog<DeliveryAddress>(
  context: context,
  builder: (_) => _AddressDialog(initial: initial),
);

class _AddressDialog extends StatefulWidget {
  const _AddressDialog({this.initial});

  final DeliveryAddress? initial;

  @override
  State<_AddressDialog> createState() => _AddressDialogState();
}

class _AddressDialogState extends State<_AddressDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _phone = TextEditingController(text: widget.initial?.phone);
  late final _address = TextEditingController(text: widget.initial?.address);

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      DeliveryAddress(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        address: _address.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      title: const Text('Địa chỉ nhận hàng'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _name,
                      autofocus: true,
                      decoration: const InputDecoration(labelText: 'Họ và tên'),
                      validator: (v) => Validators.required(v, 'Họ và tên'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Số điện thoại',
                      ),
                      validator: Validators.phone,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _address,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Địa chỉ cụ thể',
                  hintText: 'Số nhà, tên đường, Phường/Xã, Quận/Huyện, Tỉnh/Thành phố',
                  alignLabelWithHint: true,
                ),
                validator: (v) {
                  final e = Validators.required(v, 'Địa chỉ');
                  if (e != null) return e;
                  return v!.trim().length < 10
                      ? 'Vui lòng nhập địa chỉ đầy đủ (tối thiểu 10 ký tự)'
                      : null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: AppColors.body),
          child: const Text('TRỞ LẠI'),
        ),
        FilledButton(onPressed: _save, child: const Text('HOÀN THÀNH')),
      ],
    );
  }
}
