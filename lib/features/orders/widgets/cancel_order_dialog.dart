import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

const cancelReasons = [
  'Tôi muốn cập nhật địa chỉ/SĐT nhận hàng',
  'Tôi muốn thêm/thay đổi mã giảm giá',
  'Tôi muốn thay đổi sản phẩm (kích thước, màu sắc, số lượng…)',
  'Thủ tục thanh toán quá rắc rối',
  'Tôi tìm thấy chỗ mua khác tốt hơn (rẻ hơn, uy tín hơn, giao nhanh hơn…)',
  'Tôi không có nhu cầu mua nữa',
];

const _otherReason = 'Lý do khác';

/// Modal chọn lý do hủy đơn. Trả về lý do, hoặc `null` nếu đóng.
Future<String?> showCancelOrderDialog(BuildContext context) =>
    showDialog<String>(context: context, builder: (_) => const _CancelDialog());

class _CancelDialog extends StatefulWidget {
  const _CancelDialog();

  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  final _other = TextEditingController();
  String? _reason;
  String? _error;

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  void _submit() {
    if (_reason == null) {
      setState(() => _error = 'Vui lòng chọn lý do hủy đơn');
      return;
    }
    if (_reason == _otherReason) {
      final text = _other.text.trim();
      if (text.length < 5) {
        setState(() => _error = 'Vui lòng nhập lý do (ít nhất 5 ký tự)');
        return;
      }
      Navigator.of(context).pop(text);
      return;
    }
    Navigator.of(context).pop(_reason);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      title: const Text('Chọn lý do hủy'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: const Color(0xFFFFFBF0),
                child: const Text(
                  'Vui lòng chọn lý do hủy. Lưu ý: thao tác này sẽ hủy tất cả '
                  'sản phẩm có trong đơn hàng và không thể hoàn tác.',
                  style: TextStyle(color: Color(0xFF8A6D3B), fontSize: 13),
                ),
              ),
              const SizedBox(height: 8),
              RadioGroup<String>(
                groupValue: _reason,
                onChanged: (v) => setState(() {
                  _reason = v;
                  _error = null;
                }),
                child: Column(
                  children: [
                    for (final r in [...cancelReasons, _otherReason])
                      RadioListTile<String>(
                        value: r,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppColors.primary,
                        title: Text(r),
                      ),
                  ],
                ),
              ),
              if (_reason == _otherReason)
                TextField(
                  controller: _other,
                  maxLines: 3,
                  maxLength: 200,
                  autofocus: true,
                  onChanged: (_) => setState(() => _error = null),
                  decoration: const InputDecoration(
                    hintText: 'Nhập lý do hủy đơn của bạn',
                  ),
                ),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: AppColors.primary)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: AppColors.body),
          child: const Text('KHÔNG PHẢI BÂY GIỜ'),
        ),
        FilledButton(onPressed: _submit, child: const Text('HỦY ĐƠN HÀNG')),
      ],
    );
  }
}
