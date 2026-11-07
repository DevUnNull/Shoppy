import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_toast.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_layout.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/otp_input.dart';

enum _Step { email, otp, password }

/// Quên mật khẩu 3 bước: Email -> OTP 6 số -> Mật khẩu mới.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  static const _resendSeconds = 60;

  final _emailForm = GlobalKey<FormState>();
  final _passwordForm = GlobalKey<FormState>();
  final _otpKey = GlobalKey<OtpInputState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  _Step _step = _Step.email;
  String _otp = '';
  bool _otpError = false;
  bool _loading = false;
  int _countdown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _countdown--);
      if (_countdown <= 0) t.cancel();
    });
  }

  Future<void> _sendOtp({bool resend = false}) async {
    if (!resend && !_emailForm.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).forgotPassword(_email.text);
      if (!mounted) return;
      AppToast.success(context, 'Mã OTP đã được gửi tới ${_email.text.trim()}');
      _startCountdown();
      setState(() {
        _step = _Step.otp;
        _otp = '';
        _otpError = false;
      });
      if (resend) _otpKey.currentState?.clear();
    } catch (e) {
      if (mounted) AppToast.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _confirmOtp() {
    if (_otp.length != 6) {
      setState(() => _otpError = true);
      AppToast.error(context, 'Vui lòng nhập đủ 6 chữ số');
      return;
    }
    setState(() => _step = _Step.password);
  }

  Future<void> _resetPassword() async {
    if (!_passwordForm.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref
          .read(authServiceProvider)
          .resetPassword(
            email: _email.text,
            otp: _otp,
            newPassword: _password.text,
          );
      if (!mounted) return;
      AppToast.success(
        context,
        'Đặt lại mật khẩu thành công! Vui lòng đăng nhập',
      );
      // Quay về màn Đăng nhập (màn đã mở trang này).
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      final message = e.toString();
      AppToast.error(context, message);
      // Backend chỉ kiểm tra OTP ở bước này -> OTP sai thì quay lại bước 2.
      if (message.toUpperCase().contains('OTP')) {
        setState(() {
          _step = _Step.otp;
          _otp = '';
          _otpError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _back() {
    switch (_step) {
      case _Step.email:
        Navigator.of(context).maybePop();
      case _Step.otp:
        setState(() => _step = _Step.email);
      case _Step.password:
        setState(() => _step = _Step.otp);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_step) {
      _Step.email => 'Đặt lại mật khẩu',
      _Step.otp => 'Nhập mã xác nhận',
      _Step.password => 'Thiết lập mật khẩu',
    };
    return AuthLayout(
      title: 'Đặt lại mật khẩu',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthFormTitle(
            title,
            leading: IconButton(
              tooltip: 'Quay lại',
              onPressed: _loading ? null : _back,
              icon: const Icon(Icons.arrow_back, color: AppColors.primary),
            ),
          ),
          _StepIndicator(current: _step.index),
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: KeyedSubtree(
              key: ValueKey(_step),
              child: switch (_step) {
                _Step.email => _emailStep(),
                _Step.otp => _otpStep(),
                _Step.password => _passwordStep(),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _emailStep() => Form(
    key: _emailForm,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthTextField(
          controller: _email,
          hint: 'Email đã đăng ký',
          prefixIcon: Icons.mail_outline,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          validator: Validators.email,
          onSubmitted: (_) => _sendOtp(),
          enabled: !_loading,
        ),
        const SizedBox(height: 8),
        AuthSubmitButton(
          label: 'Tiếp theo',
          loading: _loading,
          onPressed: _sendOtp,
        ),
      ],
    ),
  );

  Widget _otpStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text.rich(
        TextSpan(
          style: const TextStyle(color: AppColors.body, height: 1.5),
          children: [
            const TextSpan(text: 'Mã xác minh gồm 6 chữ số đã được gửi tới\n'),
            TextSpan(
              text: _email.text.trim(),
              style: const TextStyle(
                color: AppColors.title,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 20),
      OtpInput(
        key: _otpKey,
        hasError: _otpError,
        onChanged: (v) => setState(() {
          _otp = v;
          _otpError = false;
        }),
        onCompleted: (_) => _confirmOtp(),
      ),
      const SizedBox(height: 16),
      Center(
        child: _countdown > 0
            ? Text(
                'Vui lòng chờ $_countdown giây để gửi lại',
                style: const TextStyle(color: AppColors.caption),
              )
            : TextButton(
                onPressed: _loading ? null : () => _sendOtp(resend: true),
                child: const Text('Gửi lại mã'),
              ),
      ),
      const SizedBox(height: 16),
      AuthSubmitButton(
        label: 'Kế tiếp',
        loading: _loading,
        onPressed: _otp.length == 6 ? _confirmOtp : null,
      ),
    ],
  );

  Widget _passwordStep() => Form(
    key: _passwordForm,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Text(
            'Mật khẩu mới phải từ 6 đến 32 ký tự',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.caption),
          ),
        ),
        AuthTextField(
          controller: _password,
          hint: 'Mật khẩu mới',
          prefixIcon: Icons.lock_outline,
          obscure: true,
          autofillHints: const [AutofillHints.newPassword],
          validator: Validators.password,
          enabled: !_loading,
        ),
        AuthTextField(
          controller: _confirm,
          hint: 'Xác nhận mật khẩu mới',
          prefixIcon: Icons.lock_outline,
          obscure: true,
          textInputAction: TextInputAction.done,
          validator: (v) =>
              v != _password.text ? 'Mật khẩu xác nhận không khớp' : null,
          onSubmitted: (_) => _resetPassword(),
          enabled: !_loading,
        ),
        const SizedBox(height: 8),
        AuthSubmitButton(
          label: 'Xác nhận',
          loading: _loading,
          onPressed: _resetPassword,
        ),
      ],
    ),
  );
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current});

  final int current;

  static const _labels = ['Email', 'Mã OTP', 'Mật khẩu mới'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 18),
                color: i <= current ? AppColors.primary : AppColors.border,
              ),
            ),
          Column(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: i <= current
                    ? AppColors.primary
                    : AppColors.border,
                child: i < current
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : Text(
                        '${i + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
              ),
              const SizedBox(height: 4),
              Text(
                _labels[i],
                style: TextStyle(
                  fontSize: 11,
                  color: i <= current ? AppColors.primary : AppColors.caption,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
