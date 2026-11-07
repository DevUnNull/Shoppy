import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../account/widgets/account_shell.dart';
import '../../auth/providers/auth_provider.dart';
import '../../orders/providers/order_providers.dart';
import '../../profile/providers/profile_providers.dart';
import '../services/partner_service.dart';

/// Đăng ký trở thành Người bán (mở Shop) hoặc Tài xế (Shipper).
class PartnerRegisterScreen extends ConsumerWidget {
  const PartnerRegisterScreen({super.key, this.shipper = false});

  final bool shipper;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider.select((s) => s.user));
    // Backend chỉ cho tài khoản CUSTOMER đăng ký (đã xác minh).
    final eligible = user?.isCustomer ?? false;
    return AccountShell(
      section: AccountSection.partner,
      child: DefaultTabController(
        length: 2,
        initialIndex: shipper ? 1 : 0,
        child: Builder(
          builder: (context) {
            final controller = DefaultTabController.of(context);
            return AnimatedBuilder(
              animation: controller,
              builder: (context, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AccountPageHeader(
                    title: 'Trở thành đối tác Shoppy',
                    subtitle: 'Mở gian hàng để bán hàng, hoặc đăng ký làm tài xế giao nhận',
                  ),
                  if (!eligible)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBF0),
                        border: Border.all(color: AppColors.pending),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AppColors.pending,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tài khoản của bạn đang là '
                              '${user?.role.name.toUpperCase() ?? '—'}. '
                              'Chỉ tài khoản Khách hàng mới có thể đăng ký mở Shop hoặc làm Shipper.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  const TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: [
                      Tab(
                        icon: Icon(Icons.storefront_outlined),
                        text: 'Đăng ký bán hàng',
                      ),
                      Tab(
                        icon: Icon(Icons.two_wheeler),
                        text: 'Đăng ký làm Shipper',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  IndexedStack(
                    index: controller.index,
                    children: [
                      _ShopForm(enabled: eligible),
                      _ShipperForm(enabled: eligible),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

Future<void> _showSubmitted(
  BuildContext context,
  String what,
) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
    icon: const Icon(Icons.check_circle, color: AppColors.success, size: 48),
    title: const Text('Đã gửi đăng ký!'),
    content: Text(
      'Hồ sơ $what của bạn đã được gửi. Shoppy sẽ xét duyệt và gửi thông báo '
      'khi có kết quả.',
      textAlign: TextAlign.center,
    ),
    actions: [
      FilledButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('ĐÃ HIỂU'),
      ),
    ],
  ),
);

class _ShopForm extends ConsumerStatefulWidget {
  const _ShopForm({required this.enabled});

  final bool enabled;

  @override
  ConsumerState<_ShopForm> createState() => _ShopFormState();
}

class _ShopFormState extends ConsumerState<_ShopForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _description = TextEditingController();
  final _phone = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _address, _description, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await showConfirmDialog(
      context,
      title: 'Gửi đăng ký mở Shop?',
      message:
          'Gian hàng "${_name.text.trim()}" sẽ được gửi cho Shoppy xét duyệt.',
      confirmLabel: 'Gửi đăng ký',
      icon: Icons.storefront_outlined,
    );
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(partnerServiceProvider)
          .registerShop(
            ShopRegistration(
              name: _name.text,
              address: _address.text,
              description: _description.text,
              phone: _phone.text,
            ),
          );
      if (!mounted) return;
      await _showSubmitted(context, 'mở Shop');
      ref.read(authProvider.notifier).refreshProfile().ignore();
    } catch (e) {
      if (mounted) AppToast.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.enabled && !_saving;
    return Form(
      key: _formKey,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _text(
              _name,
              'Tên gian hàng',
              on,
              maxLength: 60,
              validator: (v) {
                final e = Validators.required(v, 'Tên gian hàng');
                if (e != null) return e;
                return v!.trim().length < 3
                    ? 'Tên gian hàng tối thiểu 3 ký tự'
                    : null;
              },
            ),
            _text(
              _address,
              'Địa chỉ lấy hàng của shop',
              on,
              validator: (v) => Validators.required(v, 'Địa chỉ shop'),
            ),
            _text(
              _phone,
              'Hotline',
              on,
              keyboard: TextInputType.phone,
              validator: Validators.phone,
            ),
            _text(
              _description,
              'Mô tả ngắn về shop',
              on,
              maxLines: 4,
              maxLength: 500,
              validator: (v) => Validators.required(v, 'Mô tả'),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: on ? _submit : null,
                icon: const Icon(Icons.send, size: 18),
                label: Text(_saving ? 'Đang gửi…' : 'Gửi đăng ký mở Shop'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShipperForm extends ConsumerStatefulWidget {
  const _ShipperForm({required this.enabled});

  final bool enabled;

  @override
  ConsumerState<_ShipperForm> createState() => _ShipperFormState();
}

class _ShipperFormState extends ConsumerState<_ShipperForm> {
  final _formKey = GlobalKey<FormState>();
  final _identity = TextEditingController();
  final _plate = TextEditingController();
  final _area = TextEditingController();
  int? _companyId;
  bool _saving = false;

  static final _identityPattern = RegExp(r'^\d{9,12}$');
  static final _platePattern = RegExp(
    r'^\d{2}[A-Z]{1,2}\d?-?\d{3,5}(\.\d{2})?$',
    caseSensitive: false,
  );

  @override
  void dispose() {
    _identity.dispose();
    _plate.dispose();
    _area.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await showConfirmDialog(
      context,
      title: 'Gửi đăng ký Shipper?',
      message: 'Thông tin tài xế sẽ được gửi cho Shoppy xét duyệt.',
      confirmLabel: 'Gửi đăng ký',
      icon: Icons.two_wheeler,
    );
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(partnerServiceProvider)
          .registerShipper(
            ShipperRegistration(
              shippingCompanyId: _companyId!,
              identityNumber: _identity.text,
              licensePlate: _plate.text.toUpperCase(),
              operatingArea: _area.text,
            ),
          );
      if (!mounted) return;
      await _showSubmitted(context, 'tài xế');
      ref.read(authProvider.notifier).refreshProfile().ignore();
    } catch (e) {
      if (mounted) AppToast.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.enabled && !_saving;
    final companies = ref.watch(shippingCompaniesProvider);
    return Form(
      key: _formKey,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: DropdownButtonFormField<int>(
                initialValue: _companyId,
                decoration: InputDecoration(
                  labelText: 'Đơn vị vận chuyển hợp tác',
                  helperText: companies.isLoading
                      ? 'Đang tải danh sách…'
                      : null,
                  errorText: companies.hasError
                      ? 'Không tải được danh sách ĐVVC'
                      : null,
                ),
                items: [
                  for (final c in companies.value ?? const [])
                    DropdownMenuItem(
                      value: c.id,
                      child: Text('${c.name} (${c.code})'),
                    ),
                ],
                onChanged: on ? (v) => setState(() => _companyId = v) : null,
                validator: (v) =>
                    v == null ? 'Vui lòng chọn đơn vị vận chuyển' : null,
              ),
            ),
            _text(
              _identity,
              'Số CCCD / Bằng lái xe',
              on,
              keyboard: TextInputType.number,
              validator: (v) {
                final e = Validators.required(v, 'Số CCCD/Bằng lái');
                if (e != null) return e;
                return _identityPattern.hasMatch(v!.trim())
                    ? null
                    : 'Số giấy tờ gồm 9–12 chữ số';
              },
            ),
            _text(
              _plate,
              'Biển số xe (vd. 59X1-12345)',
              on,
              validator: (v) {
                final e = Validators.required(v, 'Biển số xe');
                if (e != null) return e;
                return _platePattern.hasMatch(v!.trim().replaceAll(' ', ''))
                    ? null
                    : 'Biển số xe không hợp lệ';
              },
            ),
            _text(
              _area,
              'Khu vực giao nhận hoạt động (vd. Quận 1, TP.HCM)',
              on,
              validator: (v) => Validators.required(v, 'Khu vực hoạt động'),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: on ? _submit : null,
                icon: const Icon(Icons.send, size: 18),
                label: Text(_saving ? 'Đang gửi…' : 'Gửi đăng ký Shipper'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _text(
  TextEditingController controller,
  String label,
  bool enabled, {
  FormFieldValidator<String>? validator,
  TextInputType? keyboard,
  int maxLines = 1,
  int? maxLength,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: controller,
      enabled: enabled,
      validator: validator,
      keyboardType: keyboard,
      maxLines: maxLines,
      maxLength: maxLength,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: maxLines > 1,
      ),
    ),
  );
}
