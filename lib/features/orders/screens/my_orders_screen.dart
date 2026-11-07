import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/state_views.dart';
import '../../account/widgets/account_shell.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/order.dart';
import '../providers/order_providers.dart';
import '../widgets/cancel_order_dialog.dart';
import '../widgets/order_card.dart';

/// Hủy đơn: chọn lý do -> `PUT /orders/{id}/cancel` -> làm mới dữ liệu.
Future<bool> cancelOrderFlow(
  BuildContext context,
  WidgetRef ref,
  Order order,
) async {
  final reason = await showCancelOrderDialog(context);
  if (reason == null || !context.mounted) return false;
  try {
    await ref.read(orderServiceProvider).cancelOrder(order.id, reason);
    ref.invalidate(myOrdersProvider);
    ref.invalidate(orderDetailProvider(order.id));
    // Đơn trả bằng ví sẽ được hoàn tiền -> cập nhật lại số dư.
    if (order.paymentMethod == PaymentMethod.wallet) {
      ref.read(authProvider.notifier).refreshProfile().ignore();
    }
    if (context.mounted) {
      AppToast.success(context, 'Đã hủy đơn hàng #${order.id}');
    }
    return true;
  } catch (e) {
    if (context.mounted) AppToast.error(context, e.toString());
    return false;
  }
}

class MyOrdersScreen extends ConsumerStatefulWidget {
  const MyOrdersScreen({super.key, this.initialTab = OrderTab.all});

  final OrderTab initialTab;

  @override
  ConsumerState<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends ConsumerState<MyOrdersScreen> {
  late OrderTab _tab = widget.initialTab;
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(myOrdersProvider);
    final all = async.value ?? const <Order>[];
    final visible = filterOrders(all, _tab, _query);

    return AccountShell(
      section: AccountSection.orders,
      padded: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Tabs(
            current: _tab,
            counts: {
              for (final t in OrderTab.values) t: all.where(t.matches).length,
            },
            onChanged: (t) => setState(() => _tab = t),
          ),
          const SizedBox(height: 12),
          Container(
            color: const Color(0xFFEAEAEA),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFEAEAEA),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                prefixIcon: const Icon(Icons.search, color: AppColors.caption),
                hintText: 'Bạn có thể tìm kiếm theo tên Shop, ID đơn hàng hoặc Tên Sản phẩm',
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Xoá tìm kiếm',
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() {
                          _search.clear();
                          _query = '';
                        }),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (async.isLoading && !async.hasValue)
            ...List.generate(3, (_) => const OrderCardSkeleton())
          else if (async.hasError && !async.hasValue)
            ErrorBanner(
              message: async.error.toString(),
              onRetry: () => ref.invalidate(myOrdersProvider),
            )
          else if (visible.isEmpty)
            Container(
              color: Colors.white,
              height: 420,
              alignment: Alignment.center,
              child: EmptyStateView(
                icon: Icons.receipt_long_outlined,
                title: _query.isNotEmpty
                    ? 'Không tìm thấy đơn hàng phù hợp'
                    : 'Chưa có đơn hàng',
                message: _query.isNotEmpty
                    ? 'Thử tìm theo mã đơn (vd. 12) hoặc tên shop khác'
                    : 'Hãy khám phá thêm sản phẩm và đặt đơn đầu tiên nhé!',
                actionLabel: _query.isNotEmpty ? null : 'Mua sắm ngay',
                onAction: _query.isNotEmpty
                    ? null
                    : () => AppRouter.backToHome(context),
              ),
            )
          else
            for (final order in visible)
              OrderCard(
                order: order,
                onCancel: () => cancelOrderFlow(context, ref, order),
              ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.current,
    required this.counts,
    required this.onChanged,
  });

  final OrderTab current;
  final Map<OrderTab, int> counts;
  final ValueChanged<OrderTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      height: 54,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fill = constraints.maxWidth >= 720;
          final tabs = [for (final t in OrderTab.values) _tab(t, fill: fill)];
          return fill
              ? Row(children: tabs)
              : ListView(scrollDirection: Axis.horizontal, children: tabs);
        },
      ),
    );
  }

  Widget _tab(OrderTab t, {required bool fill}) {
    final selected = t == current;
    final count = counts[t] ?? 0;
    final child = InkWell(
      onTap: () => onChanged(t),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? AppColors.primary : AppColors.divider,
              width: 2,
            ),
          ),
        ),
        child: Text(
          t.showsBadge && count > 0 ? '${t.label} ($count)' : t.label,
          style: TextStyle(
            color: selected ? AppColors.primary : AppColors.title,
            fontSize: 15,
          ),
        ),
      ),
    );
    return fill ? Expanded(child: child) : child;
  }
}
