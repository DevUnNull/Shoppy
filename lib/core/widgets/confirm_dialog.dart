import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Modal xác nhận trước các hành động quan trọng (hủy đơn, đổi mật khẩu,
/// nạp ví…). Trả về `true` nếu người dùng đồng ý.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Xác nhận',
  String cancelLabel = 'Trở lại',
  bool destructive = false,
  IconData? icon,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      icon: icon == null
          ? null
          : Icon(
              icon,
              size: 44,
              color: destructive ? AppColors.primary : AppColors.success,
            ),
      title: Text(title, textAlign: icon == null ? null : TextAlign.center),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Text(
          message,
          style: const TextStyle(color: AppColors.body, height: 1.5),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(foregroundColor: AppColors.body),
          child: Text(cancelLabel.toUpperCase()),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel.toUpperCase()),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Banner lỗi API dạng dải đỏ nhạt (dùng phía trên form/danh sách).
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9FA),
        border: Border.all(color: const Color(0xFFFF424F)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFFF424F), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.title),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}
