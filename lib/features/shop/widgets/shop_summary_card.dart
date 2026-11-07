import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/breakpoints.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/content_container.dart';
import '../../../core/widgets/skeleton.dart';
import '../models/shop.dart';
import '../providers/shop_providers.dart';
import 'shop_avatar.dart';

/// Card tóm tắt shop dưới trang chi tiết sản phẩm.
class ShopSummaryCard extends ConsumerWidget {
  const ShopSummaryCard({super.key, required this.shopId, this.fallbackName});

  final int shopId;
  final String? fallbackName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopAsync = ref.watch(shopProvider(shopId));
    return SectionCard(
      padding: const EdgeInsets.all(20),
      child: shopAsync.when(
        loading: () => const Row(
          children: [
            Skeleton.circle(size: 78),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(width: 180, height: 16),
                  SizedBox(height: 10),
                  Skeleton(width: 120, height: 28),
                ],
              ),
            ),
          ],
        ),
        error: (error, _) => Row(
          children: [
            Expanded(
              child: Text(
                fallbackName == null
                    ? 'Không tải được thông tin shop'
                    : fallbackName!,
                style: const TextStyle(color: AppColors.body),
              ),
            ),
            TextButton(
              onPressed: () => ref.invalidate(shopProvider(shopId)),
              child: const Text('Thử lại'),
            ),
          ],
        ),
        data: (shop) => _content(context, shop),
      ),
    );
  }

  Widget _content(BuildContext context, Shop shop) {
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.desktop;
    final identity = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ShopAvatar(url: shop.logoUrl, name: shop.name, size: 78),
        const SizedBox(width: 16),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                shop.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, color: AppColors.title),
              ),
              Text(
                shop.isActive ? 'Đang hoạt động' : 'Tạm nghỉ',
                style: const TextStyle(color: AppColors.caption, fontSize: 13),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => AppRouter.shop(context, shop.id),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 34)),
                icon: const Icon(Icons.storefront_outlined, size: 18),
                label: const Text('Xem Shop'),
              ),
            ],
          ),
        ),
      ],
    );
    final stats = Wrap(
      spacing: 40,
      runSpacing: 12,
      children: [
        _stat(
          'Sản phẩm',
          shop.productCount == null ? '—' : '${shop.productCount}',
        ),
        _stat(
          'Tham gia',
          shop.createdAt == null ? '—' : formatJoinedAgo(shop.createdAt!),
        ),
        _stat(
          'Tỉ lệ phản hồi',
          shop.responseRate == null ? '—' : '${shop.responseRate!.round()}%',
        ),
      ],
    );
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [identity, const Divider(height: 28), stats],
      );
    }
    return Row(
      children: [
        Flexible(child: identity),
        Container(
          width: 1,
          height: 80,
          margin: const EdgeInsets.symmetric(horizontal: 28),
          color: AppColors.divider,
        ),
        Expanded(child: stats),
      ],
    );
  }

  Widget _stat(String label, String value) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: '$label  ',
          style: const TextStyle(color: AppColors.caption),
        ),
        TextSpan(
          text: value,
          style: const TextStyle(color: AppColors.primary),
        ),
      ],
    ),
  );
}
