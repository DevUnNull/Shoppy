import 'package:flutter/material.dart';

import '../../../core/widgets/pagination_bar.dart';
import '../../../core/widgets/state_views.dart';
import '../models/product.dart';
import '../models/product_sort.dart';
import 'product_sliver_grid.dart';
import 'sort_bar.dart';

const clientPageSize = 24;

/// Sort bar + grid + phân trang chuẩn Shopee trên danh sách đã có sẵn
/// (dùng cho màn Danh mục và tab "Tất cả sản phẩm" của Shop).
List<Widget> pagedProductSlivers({
  required List<Product>? products,
  required ProductSort sort,
  required int page,
  required ValueChanged<ProductSort> onSortChanged,
  required ValueChanged<int> onPageChanged,
  required Widget empty,
  bool centered = false,
}) {
  final loading = products == null;
  final totalPages = loading ? 0 : (products.length / clientPageSize).ceil();
  final safePage = totalPages == 0 ? 0 : page.clamp(0, totalPages - 1);
  final visible = loading
      ? const <Product>[]
      : products.skip(safePage * clientPageSize).take(clientPageSize).toList();

  Widget boxed(Widget child) => SliverToBoxAdapter(
    child: centered
        ? LayoutBuilder(
            builder: (context, c) => Padding(
              padding: EdgeInsets.symmetric(
                horizontal: centeredGutter(c.maxWidth),
              ),
              child: child,
            ),
          )
        : child,
  );

  return [
    boxed(
      SortBar(
        value: sort,
        onChanged: onSortChanged,
        page: safePage,
        totalPages: totalPages,
        onPageChanged: onPageChanged,
      ),
    ),
    const SliverToBoxAdapter(child: SizedBox(height: 10)),
    if (!loading && products.isEmpty)
      boxed(empty)
    else
      ProductSliverGrid(
        products: visible,
        skeletonCount: loading ? 12 : 0,
        centered: centered,
      ),
    boxed(
      PaginationBar(
        page: safePage,
        totalPages: totalPages,
        onChanged: onPageChanged,
      ),
    ),
  ];
}

/// Empty state mặc định cho danh sách đã lọc.
Widget filteredEmpty({required VoidCallback? onClear}) => EmptyStateView(
  icon: Icons.filter_alt_off_outlined,
  title: 'Không tìm thấy sản phẩm phù hợp',
  message: 'Hãy thử bỏ bớt bộ lọc hoặc chọn danh mục khác',
  actionLabel: onClear == null ? null : 'Xoá bộ lọc',
  onAction: onClear,
);
