import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/hover_card.dart';
import '../../../core/widgets/skeleton.dart';
import '../models/product.dart';

/// Chiều cao phần text bên dưới ảnh vuông của thẻ sản phẩm.
const productCardInfoHeight = 88.0;

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      onTap: () => AppRouter.product(context, product.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppNetworkImage(url: product.thumbnailUrl),
                if (product.isOutOfStock)
                  Container(
                    color: Colors.black.withValues(alpha: 0.35),
                    alignment: Alignment.center,
                    child: Container(
                      width: 76,
                      height: 76,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Text(
                        'HẾT HÀNG',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                if (_badge case final badge?)
                  Positioned(top: 8, left: 0, child: badge),
              ],
            ),
          ),
          SizedBox(
            height: productCardInfoHeight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2, // line-clamp-2
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: AppColors.title,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          formatVnd(product.minPrice),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _secondaryLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.caption,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// "Đã bán xxx" nếu backend có số liệu, ngược lại hiển thị tồn kho.
  String get _secondaryLabel {
    final sold = product.soldCount;
    if (sold != null) return 'Đã bán ${formatCompact(sold)}';
    if (product.isOutOfStock) return 'Hết hàng';
    return 'Kho ${formatCompact(product.totalStock)}';
  }

  Widget? get _badge {
    if (product.isMall) {
      return const _Badge(label: 'Mall', color: Color(0xFFD0011B));
    }
    if (product.hasVariants) {
      return const _Badge(label: 'Nhiều phân loại', color: AppColors.primary);
    }
    return null;
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(2)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border, width: 0.8),
        borderRadius: BorderRadius.circular(2),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(aspectRatio: 1, child: Skeleton()),
          SizedBox(
            height: productCardInfoHeight,
            child: Padding(
              padding: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(height: 12),
                  SizedBox(height: 6),
                  Skeleton(height: 12, width: 80),
                  Spacer(),
                  Skeleton(height: 16, width: 70),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
