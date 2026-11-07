import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/content_container.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/widgets/shoppy_header.dart';
import '../widgets/banner_carousel.dart';
import '../widgets/category_strip.dart';
import '../widgets/infinite_product_list.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const ShoppyHeader(showBack: false),
          Expanded(
            child: InfiniteProductList(
              keyword: '',
              leading: const [
                SliverToBoxAdapter(
                  child: ContentContainer(
                    padding: EdgeInsets.fromLTRB(12, 16, 12, 0),
                    child: BannerCarousel(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: ContentContainer(
                    padding: EdgeInsets.fromLTRB(12, 16, 12, 0),
                    child: CategoryStrip(),
                  ),
                ),
                SliverToBoxAdapter(child: _SuggestionTitle()),
              ],
              emptyBuilder: (_) => const EmptyStateView(
                icon: Icons.inventory_2_outlined,
                title: 'Chưa có sản phẩm nào',
                message: 'Các shop đang cập nhật sản phẩm, quay lại sau nhé!',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionTitle extends StatelessWidget {
  const _SuggestionTitle();

  @override
  Widget build(BuildContext context) {
    return ContentContainer(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: AppColors.primary, width: 4),
          ),
        ),
        child: const Text(
          'GỢI Ý HÔM NAY',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
