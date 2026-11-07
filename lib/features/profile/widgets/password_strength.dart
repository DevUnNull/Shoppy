import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

enum PasswordStrength {
  empty('', AppColors.border, 0),
  weak('Yếu', AppColors.primary, 1),
  medium('Trung bình', AppColors.pending, 2),
  strong('Mạnh', AppColors.success, 3);

  const PasswordStrength(this.label, this.color, this.level);

  final String label;
  final Color color;
  final int level;

  /// Chấm điểm: độ dài, chữ thường, chữ hoa, số, ký tự đặc biệt.
  static PasswordStrength of(String password) {
    if (password.isEmpty) return empty;
    var score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (RegExp('[a-z]').hasMatch(password)) score++;
    if (RegExp('[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'\d').hasMatch(password)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score++;
    if (password.length < 6 || score <= 2) return weak;
    if (score <= 4) return medium;
    return strong;
  }
}

/// Validator mật khẩu mới: 6–32 ký tự (rule backend) + có cả chữ và số.
String? validateNewPassword(String? value, {String? current}) {
  final v = value ?? '';
  if (v.isEmpty) return 'Vui lòng nhập mật khẩu mới';
  if (v.length < 6 || v.length > 32) return 'Mật khẩu phải từ 6 đến 32 ký tự';
  if (!RegExp('[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
    return 'Mật khẩu cần có cả chữ và số';
  }
  if (current != null && v == current) {
    return 'Mật khẩu mới phải khác mật khẩu hiện tại';
  }
  return null;
}

class PasswordStrengthBar extends StatelessWidget {
  const PasswordStrengthBar({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final strength = PasswordStrength.of(password);
    return Row(
      children: [
        for (var i = 1; i <= 3; i++)
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 4,
              margin: const EdgeInsets.only(right: 4),
              color: strength.level >= i ? strength.color : AppColors.border,
            ),
          ),
        SizedBox(
          width: 80,
          child: Text(
            strength.label,
            textAlign: TextAlign.right,
            style: TextStyle(color: strength.color, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
