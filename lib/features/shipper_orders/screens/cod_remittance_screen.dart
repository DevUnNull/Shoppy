import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cod_balance.dart';
import '../providers/cod_remittance_provider.dart';
import '../providers/shipper_cod_provider.dart';
import '../widgets/confirm_remittance_dialog.dart';
import '../widgets/shipper_order_widgets.dart';

class CodRemittanceScreen extends ConsumerStatefulWidget {
  const CodRemittanceScreen({super.key});
  @override
  ConsumerState<CodRemittanceScreen> createState() =>
      _CodRemittanceScreenState();
}

class _CodRemittanceScreenState extends ConsumerState<CodRemittanceScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount, _note;
  bool _working = false;
  String? _amountError;
  @override
  void initState() {
    super.initState();
    final pending = ref.read(codRemittanceProvider);
    _amount = TextEditingController(
      text: pending.needsCheck ? '${pending.amount ?? ''}' : '',
    );
    _note = TextEditingController(text: pending.needsCheck ? pending.note : '');
    Future.microtask(() {
      if (!mounted) return;
      ref.read(codRemittanceProvider.notifier).startNew();
      ref.invalidate(codBalanceProvider);
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _showMessage(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _submit() async {
    final state = ref.read(codRemittanceProvider);
    if (_working || state.isBusy || state.needsCheck || state.completed) return;
    _amountError = null;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _working = true);
    try {
      // Lấy số dư mới trước hộp thoại; controller sẽ kiểm tra lại trước POST.
      final fresh = await ref.refresh(codBalanceProvider.future);
      if (!mounted) return;
      _amountError = validateCodRemittance(_amount.text, fresh.currentBalance);
      if (_amountError != null) {
        _formKey.currentState!.validate();
        return;
      }
      final amount = int.parse(_amount.text.trim());
      final note = _note.text.trim();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) =>
            ConfirmRemittanceDialog(amount: amount, note: note),
      );
      if (!mounted || confirmed != true) return;
      final sent = await ref
          .read(codRemittanceProvider.notifier)
          .submit(amount, note);
      if (!mounted) return;
      if (sent) {
        _showMessage(ref.read(codRemittanceProvider).message);
        Navigator.pop(context, true);
      }
    } on CodAmountException catch (error) {
      if (mounted) {
        setState(() => _amountError = error.message);
        _formKey.currentState!.validate();
      }
    } catch (error) {
      if (mounted) _showMessage('$error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _checkResult() async {
    try {
      final done = await ref.read(codRemittanceProvider.notifier).checkResult();
      if (!mounted) return;
      if (done) {
        _showMessage(ref.read(codRemittanceProvider).message);
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) _showMessage('Chưa kiểm tra được kết quả. $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = ref.watch(codBalanceProvider);
    final action = ref.watch(codRemittanceProvider);
    final current = balance.hasValue ? balance.requireValue : null;
    final busy = _working || action.isBusy;
    final lowBalance = current != null && current.currentBalance < 1000;
    final enabled =
        !busy &&
        !action.needsCheck &&
        !action.completed &&
        !balance.isLoading &&
        !balance.hasError &&
        current != null &&
        !lowBalance;
    return PopScope(
      canPop: !action.isBusy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Nộp tiền COD')),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Nộp tiền COD về công ty vận chuyển của bạn.'),
                    const SizedBox(height: 16),
                    const Text('Tiền COD hiện đang giữ'),
                    const SizedBox(height: 8),
                    if (current != null)
                      Text(
                        shipperMoney(current.currentBalance),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 28,
                        ),
                      ),
                    if (balance.isLoading || action.isBusy)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: LinearProgressIndicator(),
                      ),
                    if (balance.hasError)
                      ShipperErrorView(
                        error: balance.error!,
                        onRetry: () => ref.invalidate(codBalanceProvider),
                      ),
                    const SizedBox(height: 24),
                    TextFormField(
                      key: const ValueKey('cod-amount'),
                      controller: _amount,
                      enabled: !busy && !action.needsCheck,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: false,
                        signed: false,
                      ),
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: const InputDecoration(
                        labelText: 'Số tiền nộp (VNĐ)',
                        helperText: 'Ví dụ: 500000, không nhập dấu phân cách',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        if (_amountError != null) {
                          setState(() => _amountError = null);
                        }
                      },
                      validator: (value) =>
                          _amountError ??
                          (current == null
                              ? 'Chưa đọc được số dư COD.'
                              : validateCodRemittance(
                                  value ?? '',
                                  current.currentBalance,
                                )),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      key: const ValueKey('cod-note'),
                      controller: _note,
                      enabled: !busy && !action.needsCheck,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Ghi chú',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (lowBalance)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Text(
                          'Số dư chưa đủ mức nộp tối thiểu 1.000 VNĐ.',
                        ),
                      ),
                    if (action.needsCheck) ...[
                      Text(action.message),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: busy ? null : _checkResult,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Kiểm tra lại kết quả'),
                      ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => Navigator.pop(context, false),
                        child: const Text('Xem lịch sử'),
                      ),
                    ],
                    FilledButton(
                      onPressed: enabled ? _submit : null,
                      child: Text(busy ? 'Đang xử lý…' : 'Nộp tiền'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
