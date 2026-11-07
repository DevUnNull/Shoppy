import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_toast.dart';
import '../models/register_request.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_layout.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/avatar_picker.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  PickedAvatar? _avatar;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final autoLoggedIn = await ref
          .read(authProvider.notifier)
          .register(
            RegisterRequest(
              fullName: _name.text,
              email: _email.text,
              password: _password.text,
              phone: _phone.text,
              avatarBytes: _avatar?.bytes,
              avatarFileName: _avatar?.fileName,
            ),
          );
      if (!mounted) return;
      if (autoLoggedIn) {
        AppToast.success(
          context,
          'Đăng ký thành công! Chào mừng bạn đến Shoppy',
        );
        AppRouter.backToHome(context);
      } else {
        AppToast.success(context, 'Đăng ký thành công! Vui lòng đăng nhập');
        AppRouter.login(context, replace: true);
      }
    } catch (e) {
      if (mounted) AppToast.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Đăng ký',
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthFormTitle('Đăng ký'),
              AvatarPicker(
                value: _avatar,
                onChanged: _loading
                    ? (_) {}
                    : (v) => setState(() => _avatar = v),
              ),
              const SizedBox(height: 16),
              AuthTextField(
                controller: _name,
                hint: 'Họ và tên',
                prefixIcon: Icons.person_outline,
                autofillHints: const [AutofillHints.name],
                validator: (v) => Validators.required(v, 'Họ và tên'),
                enabled: !_loading,
              ),
              AuthTextField(
                controller: _email,
                hint: 'Email',
                prefixIcon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                validator: Validators.email,
                enabled: !_loading,
              ),
              AuthTextField(
                controller: _phone,
                hint: 'Số điện thoại',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                validator: Validators.phone,
                enabled: !_loading,
              ),
              AuthTextField(
                controller: _password,
                hint: 'Mật khẩu (6-32 ký tự)',
                prefixIcon: Icons.lock_outline,
                obscure: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                validator: Validators.password,
                onSubmitted: (_) => _submit(),
                enabled: !_loading,
              ),
              const SizedBox(height: 8),
              AuthSubmitButton(
                label: 'Đăng ký',
                loading: _loading,
                onPressed: _submit,
              ),
              const SizedBox(height: 12),
              const Text(
                'Bằng việc đăng ký, bạn đã đồng ý với Shoppy về Điều khoản dịch vụ & Chính sách bảo mật',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.caption, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Bạn đã có tài khoản?',
                    style: TextStyle(color: AppColors.caption),
                  ),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => AppRouter.login(context, replace: true),
                    child: const Text('Đăng nhập'),
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
