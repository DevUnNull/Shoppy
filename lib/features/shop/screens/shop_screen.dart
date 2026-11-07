import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/content_container.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/widgets/shoppy_header.dart';
import '../../auth/providers/auth_provider.dart';
import '../../catalog/models/product_sort.dart';
import '../../catalog/widgets/paged_product_section.dart';
import '../models/shop.dart';
import '../providers/shop_providers.dart';
import '../widgets/shop_header_card.dart';

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key, required this.shopId});

  final int shopId;

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  final _scroll = ScrollController();
  int _tab = 0;
  ProductSort _sort = ProductSort.popular;
  int _page = 0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _setPage({ProductSort? sort, int page = 0}) {
    setState(() {
      if (sort != null) _sort = sort;
      _page = page;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _follow() async {
    if (!ref.read(authProvider).isLoggedIn) {
      final ok = await AppRouter.login(context);
      if (!ok || !mounted) return;
    }
    final followed = ref
        .read(followedShopsProvider.notifier)
        .toggle(widget.shopId);
    AppToast.success(
      context,
      followed ? 'Đã theo dõi shop' : 'Đã bỏ theo dõi shop',
    );
  }

  @override
  Widget build(BuildContext context) {
    final shopAsync = ref.watch(shopProvider(widget.shopId));
    final productsAsync = ref.watch(shopProductsProvider(widget.shopId));
    final following = ref.watch(followedShopsProvider).contains(widget.shopId);

    if (shopAsync.hasError && !shopAsync.hasValue) {
      return Scaffold(
        body: Column(
          children: [
            const ShoppyHeader(),
            Expanded(
              child: Center(
                child: ErrorStateView(
                  message: shopAsync.error.toString(),
                  onRetry: () => ref.invalidate(shopProvider(widget.shopId)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final shop = shopAsync.value;
    final sorted = productsAsync.whenData(
      (items) => applyCatalogQuery(items, sort: _sort),
    );

    return Scaffold(
      body: Column(
        children: [
          const ShoppyHeader(),
          Expanded(
            child: CustomScrollView(
              controller: _scroll,
              slivers: [
                SliverToBoxAdapter(
                  child: ContentContainer(
                    child: Column(
                      children: [
                        shop == null
                            ? const ShopHeaderSkeleton()
                            : ShopHeaderCard(
                                shop: shop,
                                isFollowing: following,
                                onFollow: _follow,
                                onChat: () => AppToast.info(
                                  context,
                                  'Tính năng Chat đang được phát triển',
                                ),
                              ),
                        _TabBar(
                          index: _tab,
                          onChanged: (i) => setState(() => _tab = i),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                if (_tab == 0) ...[
                  if (sorted.hasError && !sorted.hasValue)
                    SliverToBoxAdapter(
                      child: ErrorStateView(
                        message: sorted.error.toString(),
                        onRetry: () =>
                            ref.invalidate(shopProductsProvider(widget.shopId)),
                      ),
                    )
                  else
                    ...pagedProductSlivers(
                      products: sorted.value,
                      sort: _sort,
                      page: _page,
                      centered: true,
                      onSortChanged: (s) => _setPage(sort: s),
                      onPageChanged: (p) => _setPage(page: p),
                      empty: const EmptyStateView(
                        icon: Icons.inventory_2_outlined,
                        title: 'Shop chưa có sản phẩm nào',
                      ),
                    ),
                ] else
                  SliverToBoxAdapter(
                    child: shop == null
                        ? const SizedBox.shrink()
                        : ContentContainer(child: _ShopProfile(shop: shop)),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const tabs = ['Tất cả sản phẩm', 'Hồ sơ shop'];
    return Container(
      color: Colors.white,
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            InkWell(
              onTap: () => onChanged(i),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: i == index
                          ? AppColors.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  tabs[i],
                  style: TextStyle(
                    color: i == index ? AppColors.primary : AppColors.title,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ShopProfile extends StatelessWidget {
  const _ShopProfile({required this.shop});

  final Shop shop;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Thông tin shop',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row('Tên shop', shop.name),
          _row('Trạng thái', shop.isActive ? 'Đang hoạt động' : 'Tạm nghỉ'),
          _row(
            'Ngày tham gia',
            shop.createdAt == null ? '—' : formatDate(shop.createdAt!),
          ),
          _row('Số sản phẩm', shop.productCount?.toString() ?? '—'),
          _row('Địa chỉ', shop.address ?? '—'),
          const Divider(height: 32),
          const Text(
            'Giới thiệu',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: AppColors.title,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            shop.description ?? 'Shop chưa có lời giới thiệu.',
            style: const TextStyle(color: AppColors.body, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(label, style: const TextStyle(color: AppColors.caption)),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(color: AppColors.title),
          ),
        ),
      ],
    ),
  );
}
