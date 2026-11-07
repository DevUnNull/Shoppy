import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cod_transaction.dart';
import '../providers/cod_remittance_provider.dart';
import '../providers/shipper_cod_provider.dart';
import '../widgets/cod_balance_card.dart';
import '../widgets/cod_transaction_tile.dart';
import '../widgets/shipper_order_widgets.dart';
import 'cod_remittance_screen.dart';

class ShipperCodScreen extends ConsumerStatefulWidget {
  const ShipperCodScreen({super.key});
  @override
  ConsumerState<ShipperCodScreen> createState() => _ShipperCodScreenState();
}

class _ShipperCodScreenState extends ConsumerState<ShipperCodScreen> {
  CodFilter _filter = CodFilter.all;
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.invalidate(codBalanceProvider);
      ref.invalidate(codTransactionsProvider);
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(codBalanceProvider);
    ref.invalidate(codTransactionsProvider);
    try {
      await Future.wait<dynamic>([
        ref.read(codBalanceProvider.future),
        ref.read(codTransactionsProvider(_filter).future),
      ]);
    } catch (_) {
      /* Hai vùng nội dung tự hiển thị lỗi. */
    }
  }

  Future<void> _openForm() async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (context) => const CodRemittanceScreen(),
      ),
    );
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final balance = ref.watch(codBalanceProvider);
    final transactions = ref.watch(codTransactionsProvider(_filter));
    final action = ref.watch(codRemittanceProvider);
    final current = balance.hasValue ? balance.requireValue : null;
    final canRemit =
        current != null &&
        current.currentBalance >= 1000 &&
        !balance.isLoading &&
        !balance.hasError &&
        !action.isBusy &&
        !action.needsCheck;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tiền thu hộ COD'),
        actions: [
          IconButton(
            tooltip: 'Làm mới COD',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                balance.when(
                  skipLoadingOnRefresh: false,
                  data: (value) => CodBalanceCard(balance: value),
                  loading: () => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, stack) => ShipperErrorView(
                    error: error,
                    onRetry: () => ref.invalidate(codBalanceProvider),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: canRemit ? _openForm : null,
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Nộp tiền COD'),
                ),
                if (current != null && current.currentBalance < 1000)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Số dư COD chưa đủ mức nộp tối thiểu 1.000 VNĐ.',
                    ),
                  ),
                if (action.needsCheck)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(action.message),
                        OutlinedButton(
                          onPressed: action.isBusy ? null : _openForm,
                          child: const Text('Kiểm tra lần nộp trước'),
                        ),
                      ],
                    ),
                  ),
                if (action.completed && action.transaction != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Giao dịch nộp COD #${action.transaction!.id} đã hoàn tất.',
                    ),
                  ),
                const SizedBox(height: 28),
                const Text(
                  'Lịch sử thu hộ',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: CodFilter.values
                      .map(
                        (filter) => ChoiceChip(
                          label: Text(filter.label),
                          selected: _filter == filter,
                          onSelected: (selected) {
                            if (!selected || filter == _filter) return;
                            setState(() => _filter = filter);
                            ref.invalidate(codTransactionsProvider(filter));
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                transactions.when(
                  skipLoadingOnRefresh: false,
                  loading: () => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, stack) => ShipperErrorView(
                    error: error,
                    onRetry: () =>
                        ref.invalidate(codTransactionsProvider(_filter)),
                  ),
                  data: (items) => items.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Chưa có giao dịch COD.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : Column(
                          children: items
                              .map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: CodTransactionTile(
                                    key: ValueKey(item.id),
                                    transaction: item,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
