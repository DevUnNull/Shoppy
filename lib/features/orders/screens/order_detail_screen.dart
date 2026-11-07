import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/breakpoints.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/skeleton.dart';
import '../../account/widgets/account_shell.dart';
import '../models/order.dart';
import '../providers/order_providers.dart';
import '../widgets/order_item_row.dart';
import '../widgets/tracking_widgets.dart';
import 'my_orders_screen.dart';

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final int orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(orderDetailProvider(orderId));
    return AccountShell(
      section: AccountSection.orders,
      padded: false,
      child: async.when(
        loading: () => const _DetailSkeleton(),
        error: (e, _) => ErrorBanner(
          message: e.toString(),
          onRetry: () => ref.invalidate(orderDetailProvider(orderId)),
        ),
        data: (order) => _DetailBody(order: order),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.desktop;
    final cancelled = order.status == OrderStatus.cancelled;

    final address = _Section(
      title: 'Địa chỉ nhận hàng',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            order.recipientName ?? '—',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            order.recipientPhone ?? '',
            style: const TextStyle(color: AppColors.caption),
          ),
          const SizedBox(height: 4),
          Text(
            order.shippingAddress ?? '',
            style: const TextStyle(color: AppColors.caption),
          ),
          if (order.note != null) ...[
            const SizedBox(height: 10),
            Text(
              'Lời nhắn: ${order.note}',
              style: const TextStyle(
                color: AppColors.body,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
    final timeline = _Section(
      title: 'Hành trình đơn hàng',
      child: TrackingTimeline(steps: order.timeline),
    );

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Thanh tiêu đề: TRỞ LẠI | MÃ ĐƠN | trạng thái
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.caption,
                  ),
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('TRỞ LẠI'),
                ),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('MÃ ĐƠN HÀNG. #${order.id}'),
                    Container(
                      width: 1,
                      height: 14,
                      color: AppColors.border,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    OrderStatusLabel(status: order.status),
                  ],
                ),
              ],
            ),
          ),
          const AirmailStripe(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            child: cancelled
                ? _CancelledBanner(order: order)
                : TrackingStepper(order: order),
          ),
          if (order.trackingNumber != null)
            Container(
              color: const Color(0xFFFFFCF5),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.qr_code_2, color: AppColors.caption),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Mã vận đơn: '),
                          TextSpan(
                            text: order.trackingNumber,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: order.trackingNumber!),
                      );
                      AppToast.success(context, 'Đã sao chép mã vận đơn');
                    },
                    child: const Text('SAO CHÉP'),
                  ),
                ],
              ),
            ),
          _ActionsBar(order: order),
          const AirmailStripe(),
          Padding(
            padding: const EdgeInsets.all(20),
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 300, child: address),
                      Container(
                        width: 1,
                        height: 180,
                        color: AppColors.divider,
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      Expanded(child: timeline),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [address, const Divider(height: 32), timeline],
                  ),
          ),
          const Divider(height: 1),
          // Sản phẩm
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.storefront, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        order.shopName ?? 'Shop',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (order.shopId != null)
                      TextButton(
                        onPressed: () => AppRouter.shop(context, order.shopId!),
                        child: const Text('Xem Shop'),
                      ),
                  ],
                ),
                for (final item in order.items)
                  OrderItemRow(
                    item: item,
                    onTap: () => AppRouter.product(context, item.productId),
                  ),
              ],
            ),
          ),
          _CostTable(order: order),
        ],
      ),
    );
  }
}

class _ActionsBar extends ConsumerWidget {
  const _ActionsBar({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hint = switch (order.status) {
      OrderStatus.pending || OrderStatus.processing =>
        'Bạn có thể hủy đơn khi shop chưa giao hàng cho ĐVVC.',
      OrderStatus.readyToShip => 'Đơn đã được đóng gói, không thể hủy.',
      OrderStatus.shipping => 'Đơn hàng đang trên đường giao đến bạn.',
      OrderStatus.delivered => 'Cảm ơn bạn đã mua sắm tại Shoppy!',
      OrderStatus.cancelled => 'Đơn hàng đã được hủy.',
      OrderStatus.unknown => '',
    };
    return Container(
      color: const Color(0xFFFFFEFB),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 10,
        children: [
          Text(
            hint,
            style: const TextStyle(color: AppColors.caption, fontSize: 13),
          ),
          Wrap(
            spacing: 10,
            children: [
              if (order.status == OrderStatus.delivered ||
                  order.status == OrderStatus.cancelled)
                FilledButton(
                  onPressed: () =>
                      AppRouter.product(context, order.items.first.productId),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(180, 40),
                  ),
                  child: const Text('Mua lại'),
                ),
              // Luôn hiển thị nút, chỉ kích hoạt khi được phép hủy.
              OutlinedButton(
                onPressed: order.status.canCancel
                    ? () => cancelOrderFlow(context, ref, order)
                    : null,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(180, 40),
                  foregroundColor: AppColors.body,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: AppColors.border),
                ),
                child: const Text('Hủy đơn hàng'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CancelledBanner extends StatelessWidget {
  const _CancelledBanner({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        children: [
          const Icon(Icons.cancel_outlined, color: AppColors.primary, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Đã hủy đơn hàng',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (order.updatedAt != null)
                  Text(
                    'Vào ${formatDateTime(order.updatedAt!)}',
                    style: const TextStyle(color: AppColors.caption),
                  ),
                if (order.cancelReason != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Lý do: ${order.cancelReason}'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CostTable extends StatelessWidget {
  const _CostTable({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String, bool)>[
      ('Tổng tiền hàng', formatVnd(order.totalAmount), false),
      ('Phí vận chuyển', formatVnd(order.shippingFee), false),
      if (order.discount > 0)
        ('Giảm giá', '-${formatVnd(order.discount)}', false),
      ('Thành tiền', formatVnd(order.grandTotal), true),
      ('Phương thức thanh toán', order.paymentMethod.label, false),
    ];
    return Container(
      color: const Color(0xFFFFFEFB),
      child: Column(
        children: [
          for (final (label, value, highlight) in rows)
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppColors.divider,
                    style: BorderStyle.solid,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Text(
                        label,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: AppColors.caption,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 220,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(
                        left: BorderSide(color: AppColors.divider),
                      ),
                    ),
                    child: Text(
                      value,
                      textAlign: TextAlign.right,
                      style: highlight
                          ? const TextStyle(
                              color: AppColors.primary,
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                            )
                          : const TextStyle(color: AppColors.title),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, color: AppColors.title),
        ),
        const SizedBox(height: 14),
        child,
      ],
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton(width: 260, height: 18),
          SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Skeleton.circle(size: 60),
              Skeleton.circle(size: 60),
              Skeleton.circle(size: 60),
              Skeleton.circle(size: 60),
            ],
          ),
          SizedBox(height: 32),
          Skeleton(height: 120),
          SizedBox(height: 20),
          Skeleton(height: 80),
        ],
      ),
    );
  }
}
