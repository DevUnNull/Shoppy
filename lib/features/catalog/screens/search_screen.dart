import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/content_container.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/widgets/shoppy_header.dart';
import '../providers/product_list_provider.dart';
import '../widgets/infinite_product_list.dart';

/// Kết quả tìm kiếm `GET /products/getAll?search=` có Infinite Scroll.
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key, required this.keyword});

  final String keyword;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ShoppyHeader(initialQuery: keyword, replaceOnSearch: true),
          Expanded(
            child: InfiniteProductList(
              keyword: keyword,
              leading: [
                SliverToBoxAdapter(child: _ResultHeader(keyword: keyword)),
              ],
              emptyBuilder: (context) => EmptyStateView(
                title: 'Không tìm thấy kết quả nào',
                message: 'Hãy thử sử dụng các từ khoá chung chung hơn',
                actionLabel: 'Về trang chủ',
                onAction: () => AppRouter.backToHome(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultHeader extends ConsumerWidget {
  const _ResultHeader({required this.keyword});

  final String keyword;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(productListProvider(keyword));
    return ContentContainer(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
      child: Row(
        children: [
          const Icon(
            Icons.lightbulb_outline,
            color: AppColors.caption,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(color: AppColors.body, fontSize: 15),
                children: [
                  const TextSpan(text: 'Kết quả tìm kiếm cho từ khoá \''),
                  TextSpan(
                    text: keyword,
                    style: const TextStyle(color: AppColors.primary),
                  ),
                  const TextSpan(text: '\''),
                  if (!state.isLoading && state.error == null)
                    TextSpan(
                      text: '  ·  ${state.totalElements} sản phẩm',
                      style: const TextStyle(
                        color: AppColors.caption,
                        fontSize: 13,
                      ),
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
