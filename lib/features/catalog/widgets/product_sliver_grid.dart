import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/utils/breakpoints.dart';
import '../models/product.dart';
import 'product_card.dart';

/// Padding ngang để nội dung sliver căn giữa trong khung tối đa 1200px.
double centeredGutter(double width, {double minGutter = 12}) =>
    math.max(minGutter, (width - Breakpoints.maxContentWidth) / 2 + minGutter);

/// Grid sản phẩm 6 cột desktop (co về 2 cột mobile), có skeleton khi tải.
class ProductSliverGrid extends StatelessWidget {
  const ProductSliverGrid({
    super.key,
    required this.products,
    this.skeletonCount = 0,
    this.centered = true,
  });

  final List<Product> products;

  /// Số thẻ skeleton nối thêm ở cuối (tải trang đầu / tải thêm).
  final int skeletonCount;

  /// true: căn giữa khung 1200px; false: lấp đầy vùng chứa (vd. cạnh sidebar).
  final bool centered;

  static const spacing = 10.0;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final total = constraints.crossAxisExtent;
        final gutter = centered ? centeredGutter(total) : 0.0;
        final width = total - gutter * 2;
        // Grid toàn trang tính theo viewport (desktop >= 1200px -> 6 cột);
        // grid cạnh sidebar tính theo vùng chứa thực tế.
        final columns = Breakpoints.productColumns(centered ? total : width);
        final tileWidth = (width - spacing * (columns - 1)) / columns;
        return SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              mainAxisExtent: tileWidth + productCardInfoHeight + 2,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => index < products.length
                  ? ProductCard(product: products[index])
                  : const ProductCardSkeleton(),
              childCount: products.length + skeletonCount,
            ),
          ),
        );
      },
    );
  }
}
