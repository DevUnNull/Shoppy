import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_toast.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_layout.dart';
import '../widgets/auth_text_field.dart';

/// Đăng nhập. Pop về màn trước với `true` khi thành công.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await ref
          .read(authProvider.notifier)
          .login(email: _email.text, password: _password.text);
      if (!mounted) return;
      AppToast.success(context, 'Xin chào, ${user.displayName}!');
      final navigator = Navigator.of(context);
      navigator.canPop() ? navigator.pop(true) : AppRouter.backToHome(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      AppToast.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Đăng nhập',
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthFormTitle('Đăng nhập'),
              if (_error != null) _ErrorBanner(message: _error!),
              AuthTextField(
                controller: _email,
                hint: 'Email',
                prefixIcon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [
                  AutofillHints.email,
                  AutofillHints.username,
                ],
                validator: Validators.email,
                enabled: !_loading,
              ),
              AuthTextField(
                controller: _password,
                hint: 'Mật khẩu',
                prefixIcon: Icons.lock_outline,
                obscure: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                validator: (v) => Validators.required(v, 'Mật khẩu'),
                onSubmitted: (_) => _submit(),
                enabled: !_loading,
              ),
              const SizedBox(height: 8),
              AuthSubmitButton(
                label: 'Đăng nhập',
                loading: _loading,
                onPressed: _submit,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _loading
                      ? null
                      : () => AppRouter.forgotPassword(context),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF0055AA),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text(
                    'Quên mật khẩu',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Bạn mới biết đến Shoppy?',
                    style: TextStyle(color: AppColors.caption),
                  ),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => AppRouter.register(context, replace: true),
                    child: const Text('Đăng ký'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
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
        ],
      ),
    );
  }
}
