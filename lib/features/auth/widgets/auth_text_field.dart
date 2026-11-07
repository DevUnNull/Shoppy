import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Ô nhập liệu form Auth; `obscure: true` tự thêm icon ẩn/hiện mật khẩu.
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.validator,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.prefixIcon,
    this.autofillHints,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String hint;
  final FormFieldValidator<String>? validator;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final IconData? prefixIcon;
  final Iterable<String>? autofillHints;
  final bool enabled;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: TextFormField(
        controller: widget.controller,
        validator: widget.validator,
        obscureText: _hidden,
        enabled: widget.enabled,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        onFieldSubmitted: widget.onSubmitted,
        autofillHints: widget.autofillHints,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        style: const TextStyle(fontSize: 14, color: AppColors.title),
        decoration: InputDecoration(
          hintText: widget.hint,
          helperText: ' ', // giữ chỗ để layout không nhảy khi hiện lỗi
          helperStyle: const TextStyle(height: 0.7),
          errorStyle: const TextStyle(color: AppColors.primary, height: 0.7),
          prefixIcon: widget.prefixIcon == null
              ? null
              : Icon(widget.prefixIcon, size: 20, color: AppColors.caption),
          suffixIcon: widget.obscure
              ? IconButton(
                  tooltip: _hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                  onPressed: () => setState(() => _hidden = !_hidden),
                  icon: Icon(
                    _hidden
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: AppColors.caption,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

/// Nút submit cam full-width có spinner khi đang gửi.
class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 42,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(label.toUpperCase()),
      ),
    );
  }
}
