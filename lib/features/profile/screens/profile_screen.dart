import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/breakpoints.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../account/widgets/account_shell.dart';
import '../../auth/models/user.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/widgets/avatar_picker.dart';
import '../providers/profile_providers.dart';
import '../services/profile_service.dart';
import '../widgets/password_strength.dart';

/// Hồ sơ cá nhân: tab "Hồ sơ của tôi" và "Đổi mật khẩu".
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.changePassword = false});

  final bool changePassword;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(
    length: 2,
    vsync: this,
    initialIndex: widget.changePassword ? 1 : 0,
  )..addListener(() => setState(() {}));

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Sidebar sáng đúng mục theo tab đang mở.
    return AccountShell(
      section: _tabs.index == 1
          ? AccountSection.password
          : AccountSection.profile,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(text: 'Hồ sơ của tôi'),
              Tab(text: 'Đổi mật khẩu'),
            ],
          ),
          const SizedBox(height: 24),
          // Không dùng TabBarView để chiều cao co theo nội dung.
          IndexedStack(
            index: _tabs.index,
            children: const [_ProfileForm(), _ChangePasswordForm()],
          ),
        ],
      ),
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm();

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  Gender? _gender;
  DateTime? _dob;
  PickedAvatar? _avatar;
  bool _saving = false;
  int? _loadedFor;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _load(User user) {
    _loadedFor = user.id;
    _name.text = user.fullName;
    _phone.text = user.phone ?? '';
    _gender = user.gender;
    _dob = user.dateOfBirth;
  }

  bool _isDirty(User user) =>
      _avatar != null ||
      _name.text.trim() != user.fullName ||
      _phone.text.trim() != (user.phone ?? '') ||
      _gender != user.gender ||
      _dob != user.dateOfBirth;

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 20),
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year - 10, now.month, now.day),
      helpText: 'Chọn ngày sinh',
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _save(User user) async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isDirty(user)) {
      AppToast.info(context, 'Bạn chưa thay đổi thông tin nào');
      return;
    }
    setState(() => _saving = true);
    try {
      final sentExtra = _gender != null || _dob != null;
      final updated = await ref
          .read(profileServiceProvider)
          .updateProfile(
            ProfileUpdate(
              fullName: _name.text,
              phone: _phone.text,
              gender: _gender,
              dateOfBirth: _dob,
              avatar: _avatar,
            ),
          );
      final notifier = ref.read(authProvider.notifier);
      final fresh = updated ?? await notifier.refreshProfile();
      if (updated != null) notifier.replaceUser(updated);
      if (!mounted) return;
      setState(() => _avatar = null);
      AppToast.success(context, 'Cập nhật hồ sơ thành công');
      // Báo rõ nếu backend chưa lưu giới tính / ngày sinh.
      if (sentExtra &&
          fresh != null &&
          fresh.gender == null &&
          fresh.dateOfBirth == null) {
        await Future<void>.delayed(const Duration(milliseconds: 2300));
        if (mounted) {
          AppToast.info(
            context,
            'Lưu ý: máy chủ hiện chưa lưu Giới tính / Ngày sinh',
          );
        }
      }
    } catch (e) {
      if (mounted) AppToast.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider.select((s) => s.user));
    if (user == null) return const SizedBox.shrink();
    if (_loadedFor != user.id) _load(user);
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.desktop;

    final form = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _field(
            'Tên',
            TextFormField(
              controller: _name,
              enabled: !_saving,
              maxLength: 50,
              validator: (v) => Validators.required(v, 'Họ và tên'),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(counterText: ''),
            ),
          ),
          _field(
            'Email',
            Row(
              children: [
                Text(maskEmail(user.email)),
                const SizedBox(width: 8),
                const Tooltip(
                  message: 'Email dùng để đăng nhập, không thể thay đổi',
                  child: Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppColors.caption,
                  ),
                ),
              ],
            ),
          ),
          _field(
            'Số điện thoại',
            TextFormField(
              controller: _phone,
              enabled: !_saving,
              keyboardType: TextInputType.phone,
              validator: Validators.phone,
              onChanged: (_) => setState(() {}),
            ),
          ),
          _field(
            'Giới tính',
            RadioGroup<Gender>(
              groupValue: _gender,
              onChanged: (g) => setState(() => _gender = g),
              child: Wrap(
                children: [
                  for (final g in Gender.values)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Radio<Gender>(value: g, activeColor: AppColors.primary),
                        Text(g.label),
                        const SizedBox(width: 12),
                      ],
                    ),
                ],
              ),
            ),
          ),
          _field(
            'Ngày sinh',
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _saving ? null : _pickDob,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.title,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: AppColors.border),
                ),
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                label: Text(
                  _dob == null ? 'Chọn ngày sinh' : formatDate(_dob!),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _field(
            '',
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: _saving ? null : () => _save(user),
                style: FilledButton.styleFrom(minimumSize: const Size(90, 40)),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Lưu'),
              ),
            ),
          ),
        ],
      ),
    );

    final avatar = AvatarPicker(
      value: _avatar,
      currentUrl: user.avatarUrl,
      maxBytes: 1024 * 1024,
      onChanged: _saving ? (_) {} : (v) => setState(() => _avatar = v),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AccountPageHeader(
          title: 'Hồ Sơ Của Tôi',
          subtitle: 'Quản lý thông tin hồ sơ để bảo mật tài khoản',
        ),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: form),
              Container(
                width: 1,
                height: 220,
                color: AppColors.divider,
                margin: const EdgeInsets.symmetric(horizontal: 32),
              ),
              SizedBox(width: 240, child: avatar),
            ],
          )
        else ...[
          avatar,
          const SizedBox(height: 24),
          form,
        ],
      ],
    );
  }

  Widget _field(String label, Widget child) {
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.tablet;
    final labelWidget = Text(
      label,
      textAlign: wide ? TextAlign.right : TextAlign.left,
      style: const TextStyle(color: AppColors.caption),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: wide
          ? Row(
              children: [
                SizedBox(width: 130, child: labelWidget),
                const SizedBox(width: 20),
                Expanded(child: child),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (label.isNotEmpty) ...[
                  labelWidget,
                  const SizedBox(height: 6),
                ],
                child,
              ],
            ),
    );
  }
}

class _ChangePasswordForm extends ConsumerStatefulWidget {
  const _ChangePasswordForm();

  @override
  ConsumerState<_ChangePasswordForm> createState() =>
      _ChangePasswordFormState();
}

class _ChangePasswordFormState extends ConsumerState<_ChangePasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  final _hidden = [true, true, true];
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await showConfirmDialog(
      context,
      title: 'Đổi mật khẩu?',
      message: 'Bạn sẽ dùng mật khẩu mới cho các lần đăng nhập sau.',
      confirmLabel: 'Đổi mật khẩu',
      icon: Icons.lock_reset,
    );
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(profileServiceProvider)
          .changePassword(oldPassword: _current.text, newPassword: _new.text);
      if (!mounted) return;
      _formKey.currentState!.reset();
      _current.clear();
      _new.clear();
      _confirm.clear();
      AppToast.success(context, 'Đổi mật khẩu thành công');
    } catch (e) {
      if (mounted) AppToast.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AccountPageHeader(
              title: 'Đổi Mật Khẩu',
              subtitle: 'Để bảo mật tài khoản, vui lòng không chia sẻ mật khẩu cho người khác',
            ),
            _password(
              0,
              _current,
              'Mật khẩu hiện tại',
              (v) => (v == null || v.isEmpty)
                  ? 'Vui lòng nhập mật khẩu hiện tại'
                  : null,
            ),
            _password(
              1,
              _new,
              'Mật khẩu mới',
              (v) => validateNewPassword(v, current: _current.text),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16, top: 2),
              child: PasswordStrengthBar(password: _new.text),
            ),
            _password(
              2,
              _confirm,
              'Xác nhận mật khẩu mới',
              (v) => v != _new.text ? 'Mật khẩu xác nhận không khớp' : null,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton(
                  onPressed: _saving ? null : _submit,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(140, 42),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Xác nhận'),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => AppRouter.forgotPassword(context),
                  child: const Text('Quên mật khẩu?'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _password(
    int index,
    TextEditingController controller,
    String label,
    FormFieldValidator<String> validator,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        obscureText: _hidden[index],
        enabled: !_saving,
        validator: validator,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: IconButton(
            tooltip: _hidden[index] ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
            onPressed: () => setState(() => _hidden[index] = !_hidden[index]),
            icon: Icon(
              _hidden[index]
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
