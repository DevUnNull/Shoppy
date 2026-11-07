import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_network_image.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/state_views.dart';
import '../../features/cart/providers/cart_provider.dart';

Future<void> showCartSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: Colors.white,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
  ),
  builder: (_) => const _CartSheet(),
);

class _CartSheet extends ConsumerWidget {
  const _CartSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(cartProvider);
    final total = items.fold<double>(
      0,
      (sum, i) => sum + i.unitPrice * i.quantity,
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Giỏ hàng',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
          ),
          const Divider(height: 1),
          if (items.isEmpty)
            const EmptyStateView(
              icon: Icons.remove_shopping_cart_outlined,
              title: 'Giỏ hàng của bạn còn trống',
              message: 'Hãy chọn thêm sản phẩm để mua sắm nhé',
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                    leading: SizedBox.square(
                      dimension: 56,
                      child: AppNetworkImage(
                        url:
                            item.variant?.imageUrl ?? item.product.thumbnailUrl,
                      ),
                    ),
                    title: Text(
                      item.product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                    subtitle: Text(
                      [
                        if (item.variant != null &&
                            item.variant!.name != 'Mặc định')
                          'Phân loại: ${item.variant!.name}',
                        'x${item.quantity}',
                      ].join(' · '),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatVnd(item.unitPrice * item.quantity),
                          style: const TextStyle(color: AppColors.primary),
                        ),
                        InkWell(
                          onTap: () =>
                              ref.read(cartProvider.notifier).remove(item.key),
                          child: const Text(
                            'Xoá',
                            style: TextStyle(
                              color: AppColors.caption,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          if (items.isNotEmpty)
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.divider)),
                ),
                child: Row(
                  children: [
                    const Text('Tổng thanh toán: '),
                    Expanded(
                      child: Text(
                        formatVnd(total),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    FilledButton(
                      onPressed: () => AppToast.info(
                        context,
                        'Thanh toán thuộc phân hệ Checkout (FE khác) và sẽ được nối API sau.',
                      ),
                      child: Text('Mua hàng (${items.length})'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
