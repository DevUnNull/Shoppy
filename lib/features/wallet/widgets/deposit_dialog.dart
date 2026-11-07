import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/wallet_providers.dart';
import '../services/wallet_service.dart';

const quickDepositAmounts = [50000, 100000, 200000, 500000, 1000000];

/// Mở form nạp ví. Trả về `true` nếu nạp thành công.
/// [suggested]: số tiền gợi ý (vd. phần còn thiếu khi thanh toán bằng ví).
Future<bool> showDepositDialog(BuildContext context, {int? suggested}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => _DepositDialog(suggested: suggested),
  );
  return ok ?? false;
}

/// Định dạng "1.000.000" khi gõ.
class ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final text = formatVnd(int.parse(digits)).substring(1);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

int? parseAmount(String text) =>
    int.tryParse(text.replaceAll(RegExp(r'\D'), ''));

/// Rule nạp ví (khớp backend: tối thiểu 10.000đ).
String? validateDeposit(String? text) {
  final amount = parseAmount(text ?? '');
  if (amount == null || amount == 0) return 'Vui lòng nhập số tiền cần nạp';
  if (amount < minDepositAmount) {
    return 'Số tiền nạp tối thiểu là ${formatVnd(minDepositAmount)}';
  }
  if (amount > 50000000) return 'Mỗi lần nạp tối đa ${formatVnd(50000000)}';
  return null;
}

class _DepositDialog extends ConsumerStatefulWidget {
  const _DepositDialog({this.suggested});

  final int? suggested;

  @override
  ConsumerState<_DepositDialog> createState() => _DepositDialogState();
}

class _DepositDialogState extends ConsumerState<_DepositDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text: widget.suggested == null
        ? ''
        : formatVnd(
            widget.suggested! < minDepositAmount
                ? minDepositAmount
                : widget.suggested!,
          ).substring(1),
  );
  bool _loading = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = parseAmount(_amount.text)!;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Xác nhận nạp tiền',
      message: 'Nạp ${formatVnd(amount)} vào Ví Shoppy của bạn?',
      confirmLabel: 'Nạp tiền',
      icon: Icons.account_balance_wallet_outlined,
    );
    if (!confirmed || !mounted) return;
    setState(() => _loading = true);
    try {
      final result = await ref.read(walletServiceProvider).deposit(amount);
      await ref.read(authProvider.notifier).refreshProfile();
      ref.invalidate(transactionsProvider);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      if (result.paymentUrl != null) {
        await _showPaymentLink(result.paymentUrl!);
      } else {
        AppToast.success(context, 'Nạp ${formatVnd(amount)} thành công!');
      }
    } catch (e) {
      if (mounted) AppToast.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Một số cấu hình backend trả link cổng thanh toán thay vì cộng tiền ngay.
  Future<void> _showPaymentLink(String url) {
    final nav = Navigator.of(context, rootNavigator: true);
    return showDialog<void>(
      context: nav.context,
      builder: (context) => AlertDialog(
        title: const Text('Hoàn tất thanh toán'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mở liên kết sau để hoàn tất giao dịch nạp tiền:'),
            const SizedBox(height: 8),
            SelectableText(
              url,
              style: const TextStyle(color: Color(0xFF0055AA)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              Navigator.of(context).pop();
            },
            child: const Text('SAO CHÉP & ĐÓNG'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = parseAmount(_amount.text);
    final balance = ref.watch(authProvider.select((s) => s.user?.balance)) ?? 0;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      title: const Text('Nạp tiền vào Ví Shoppy'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Số dư hiện tại: ${formatVnd(balance)}',
                style: const TextStyle(color: AppColors.caption),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amount,
                autofocus: true,
                enabled: !_loading,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsFormatter()],
                validator: validateDeposit,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                onChanged: (_) => setState(() {}),
                onFieldSubmitted: (_) => _submit(),
                style: const TextStyle(fontSize: 22, color: AppColors.primary),
                decoration: const InputDecoration(
                  labelText: 'Số tiền cần nạp',
                  prefixText: '₫ ',
                  helperText: 'Tối thiểu 10.000đ',
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final v in quickDepositAmounts)
                    ChoiceChip(
                      label: Text('${formatVnd(v).substring(1)}đ'),
                      selected: selected == v,
                      showCheckmark: false,
                      selectedColor: AppColors.primaryLight,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: selected == v
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                      labelStyle: TextStyle(
                        color: selected == v
                            ? AppColors.primary
                            : AppColors.title,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(2),
                      ),
                      onSelected: _loading
                          ? null
                          : (_) => setState(
                              () => _amount.text = formatVnd(v).substring(1),
                            ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(foregroundColor: AppColors.body),
          child: const Text('TRỞ LẠI'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('NẠP TIỀN'),
        ),
      ],
    );
  }
}
