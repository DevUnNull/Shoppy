import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/state_views.dart';
import '../../account/widgets/account_shell.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/wallet_transaction.dart';
import '../providers/wallet_providers.dart';
import '../widgets/deposit_dialog.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  TransactionFilter _filter = TransactionFilter.all;
  bool _hidden = false;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_refreshBalance);
  }

  Future<void> _refreshBalance() async {
    if (!mounted) return;
    setState(() => _refreshing = true);
    try {
      await ref.read(authProvider.notifier).refreshProfile();
    } catch (_) {
      // Giữ số dư đang lưu nếu mạng lỗi.
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = ref.watch(authProvider.select((s) => s.user?.balance));
    final tx = ref.watch(transactionsProvider);
    final items = tx.filtered(_filter);

    return AccountShell(
      section: AccountSection.wallet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AccountPageHeader(
            title: 'Ví Shoppy',
            subtitle: 'Thanh toán nhanh, hoàn tiền tức thì khi hủy đơn',
          ),
          _BalanceCard(
            balance: balance,
            hidden: _hidden,
            loading: _refreshing && balance == null,
            onToggle: () => setState(() => _hidden = !_hidden),
            onRefresh: _refreshBalance,
            onDeposit: () => showDepositDialog(context),
          ),
          const SizedBox(height: 28),
          const Text(
            'Lịch sử biến động số dư',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final f in TransactionFilter.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f.label),
                    selected: f == _filter,
                    showCheckmark: false,
                    selectedColor: AppColors.primary,
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      color: f == _filter ? Colors.white : AppColors.title,
                    ),
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(2),
                    ),
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (tx.isLoading)
            ...List.generate(4, (_) => const _TransactionSkeleton())
          else if (tx.error != null)
            ErrorBanner(
              message: tx.error!,
              onRetry: () => ref.read(transactionsProvider.notifier).refresh(),
            )
          else if (items.isEmpty)
            EmptyStateView(
              icon: Icons.receipt_outlined,
              title: _filter == TransactionFilter.all
                  ? 'Chưa có giao dịch nào'
                  : 'Không có giao dịch ${_filter == TransactionFilter.credit ? 'tiền vào' : 'tiền ra'}',
              message: 'Nạp tiền vào ví để thanh toán đơn hàng nhanh hơn',
            )
          else ...[
            for (final t in items) _TransactionTile(tx: t, hidden: _hidden),
            if (tx.hasNext)
              Center(
                child: TextButton(
                  onPressed: tx.isLoadingMore
                      ? null
                      : () =>
                            ref.read(transactionsProvider.notifier).loadMore(),
                  child: Text(tx.isLoadingMore ? 'Đang tải…' : 'Xem thêm'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.balance,
    required this.hidden,
    required this.loading,
    required this.onToggle,
    required this.onRefresh,
    required this.onDeposit,
  });

  final double? balance;
  final bool hidden;
  final bool loading;
  final VoidCallback onToggle;
  final VoidCallback onRefresh;
  final VoidCallback onDeposit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF53D2D), Color(0xFFFF7337)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.end,
        runSpacing: 16,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    color: Colors.white,
                    size: 26,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Số dư khả dụng',
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  loading
                      ? const Skeleton(width: 180, height: 34)
                      : Text(
                          hidden ? '₫ ******' : formatVnd(balance ?? 0),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                  IconButton(
                    tooltip: hidden ? 'Hiện số dư' : 'Ẩn số dư',
                    onPressed: onToggle,
                    icon: Icon(
                      hidden ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Làm mới số dư',
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh, color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
          FilledButton.icon(
            onPressed: onDeposit,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              minimumSize: const Size(160, 46),
            ),
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Nạp tiền ví'),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.tx, required this.hidden});

  final WalletTransaction tx;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final color = tx.isCredit ? AppColors.success : AppColors.primary;
    return InkWell(
      onTap: tx.referenceId != null && !tx.isCredit
          ? () => AppRouter.orderDetail(context, tx.referenceId!)
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(
                tx.isCredit ? Icons.south_west : Icons.north_east,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.description,
                    style: const TextStyle(color: AppColors.title),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      tx.displayCode,
                      if (tx.createdAt != null) formatDateTime(tx.createdAt!),
                    ].join(' · '),
                    style: const TextStyle(
                      color: AppColors.caption,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  hidden
                      ? '******'
                      : '${tx.isCredit ? '+' : '-'}${formatVnd(tx.amount)}',
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (tx.balanceAfter != null && !hidden)
                  Text(
                    'Số dư: ${formatVnd(tx.balanceAfter!)}',
                    style: const TextStyle(
                      color: AppColors.caption,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionSkeleton extends StatelessWidget {
  const _TransactionSkeleton();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        Skeleton.circle(size: 40),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Skeleton(width: 200, height: 14),
              SizedBox(height: 6),
              Skeleton(width: 140, height: 12),
            ],
          ),
        ),
        Skeleton(width: 90, height: 16),
      ],
    ),
  );
}
