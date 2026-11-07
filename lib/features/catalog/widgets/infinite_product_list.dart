import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
import '../providers/product_list_provider.dart';
import 'product_sliver_grid.dart';

/// CustomScrollView có Infinite Scroll cho [productListProvider].
/// [leading] là các sliver hiển thị phía trên grid (banner, tiêu đề…).
class InfiniteProductList extends ConsumerStatefulWidget {
  const InfiniteProductList({
    super.key,
    required this.keyword,
    this.leading = const [],
    required this.emptyBuilder,
  });

  final String keyword;
  final List<Widget> leading;
  final Widget Function(BuildContext context) emptyBuilder;

  @override
  ConsumerState<InfiniteProductList> createState() =>
      _InfiniteProductListState();
}

class _InfiniteProductListState extends ConsumerState<InfiniteProductList> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!mounted || !_scroll.hasClients) return;
    final state = ref.read(productListProvider(widget.keyword));
    if (_scroll.position.extentAfter < 600 && state.loadMoreError == null) {
      ref.read(productListProvider(widget.keyword).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = productListProvider(widget.keyword);
    final state = ref.watch(provider);
    // Trang đầu ngắn hơn màn hình -> tự tải tiếp cho đến khi cuộn được.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadMore());

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref.read(provider.notifier).refresh(),
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          ...widget.leading,
          if (state.error != null)
            SliverToBoxAdapter(
              child: ErrorStateView(
                message: state.error!,
                onRetry: () => ref.read(provider.notifier).refresh(),
              ),
            )
          else if (state.isEmpty)
            SliverToBoxAdapter(child: widget.emptyBuilder(context))
          else
            ProductSliverGrid(
              products: state.items,
              skeletonCount: state.isLoading
                  ? 12
                  : (state.isLoadingMore ? 6 : 0),
            ),
          SliverToBoxAdapter(child: _footer(state)),
        ],
      ),
    );
  }

  Widget _footer(ProductListState state) {
    if (state.loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              state.loadMoreError!,
              style: const TextStyle(color: AppColors.caption),
            ),
            TextButton(
              onPressed: () => ref
                  .read(productListProvider(widget.keyword).notifier)
                  .loadMore(),
              child: const Text('Tải lại'),
            ),
          ],
        ),
      );
    }
    if (!state.isLoading && !state.hasNext && state.items.isNotEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'Bạn đã xem hết sản phẩm',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.caption),
        ),
      );
    }
    return const SizedBox(height: 24);
  }
}
