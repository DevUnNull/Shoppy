import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/breakpoints.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/content_container.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/widgets/cart_sheet.dart';
import '../../../shared/widgets/shoppy_header.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cart/providers/cart_provider.dart';
import '../../shop/widgets/shop_summary_card.dart';
import '../models/product.dart';
import '../models/variant.dart';
import '../models/variant_matrix.dart';
import '../providers/catalog_providers.dart';
import '../widgets/image_gallery.dart';
import '../widgets/quantity_selector.dart';
import '../widgets/variant_selector.dart';

class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final int productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(productDetailProvider(productId));
    return Scaffold(
      body: Column(
        children: [
          const ShoppyHeader(),
          Expanded(
            child: detail.when(
              loading: () => const _DetailSkeleton(),
              error: (error, _) => Center(
                child: ErrorStateView(
                  message: error.toString(),
                  onRetry: () =>
                      ref.invalidate(productDetailProvider(productId)),
                ),
              ),
              data: (data) => _DetailBody(detail: data),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailBody extends ConsumerStatefulWidget {
  const _DetailBody({required this.detail});

  final ProductDetail detail;

  @override
  ConsumerState<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends ConsumerState<_DetailBody> {
  late VariantMatrix _matrix;
  late List<String?> _selection;
  int _quantity = 1;
  bool _showVariantError = false;

  Product get _product => widget.detail.product;

  @override
  void initState() {
    super.initState();
    _initMatrix();
  }

  @override
  void didUpdateWidget(covariant _DetailBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.detail != widget.detail) _initMatrix();
  }

  void _initMatrix() {
    _matrix = VariantMatrix.from(widget.detail.variants);
    _selection = _matrix.initialSelection();
  }

  bool get _hasVariants => _matrix.variants.isNotEmpty;

  /// Biến thể sẽ được thêm vào giỏ (null = chưa chọn đủ hoặc không có biến thể).
  Variant? get _selectedVariant {
    if (!_hasVariants) return null;
    if (_matrix.isTrivial) return _matrix.variants.first;
    return _matrix.resolve(_selection);
  }

  bool get _needsSelection => _hasVariants && _selectedVariant == null;

  /// Tồn kho khả dụng theo lựa chọn hiện tại.
  int get _stock {
    final selected = _selectedVariant;
    if (selected != null) return selected.isActive ? selected.stockQuantity : 0;
    if (!_hasVariants) return _product.totalStock;
    return _matrix
        .matching(_selection)
        .fold(0, (sum, v) => sum + v.stockQuantity);
  }

  String get _priceText {
    final selected = _selectedVariant;
    if (selected != null) return formatVnd(selected.price);
    if (!_hasVariants) {
      return formatPriceRange(_product.minPrice, _product.maxPrice);
    }
    final matching = _matrix.matching(_selection);
    final pool = matching.any((v) => v.isAvailable)
        ? matching.where((v) => v.isAvailable)
        : matching;
    if (pool.isEmpty) {
      return formatPriceRange(_product.minPrice, _product.maxPrice);
    }
    final prices = pool.map((v) => v.price);
    return formatPriceRange(
      prices.reduce((a, b) => a < b ? a : b),
      prices.reduce((a, b) => a > b ? a : b),
    );
  }

  String? get _variantImage {
    // Biến thể "Mặc định" không ghi đè ảnh sản phẩm.
    if (_matrix.isTrivial) return null;
    final selected = _selectedVariant;
    if (selected?.imageUrl != null) return selected!.imageUrl;
    if (_selection.isEmpty || _selection.first == null) return null;
    final probe = _matrix.emptySelection()..[0] = _selection.first;
    final urls = _matrix
        .matching(probe)
        .map((v) => v.imageUrl)
        .whereType<String>()
        .toSet();
    return urls.length == 1 ? urls.first : null;
  }

  List<String> get _galleryImages {
    final images = <String>[
      ...widget.detail.images,
      if (_product.thumbnailUrl != null) _product.thumbnailUrl!,
      if (!_matrix.isTrivial)
        for (final v in _matrix.variants) ...[
          if (v.imageUrl != null) v.imageUrl!,
          ...v.images,
        ],
    ];
    return images.toSet().toList();
  }

  void _onSelectionChanged(List<String?> selection) {
    setState(() {
      _selection = selection;
      _showVariantError = false;
      final stock = _stock;
      if (stock > 0 && _quantity > stock) _quantity = stock;
      if (_quantity < 1) _quantity = 1;
    });
  }

  Future<void> _addToCart({required bool buyNow}) async {
    if (_needsSelection) {
      setState(() => _showVariantError = true);
      return;
    }
    if (_stock <= 0) {
      AppToast.error(context, 'Sản phẩm đã hết hàng');
      return;
    }
    if (!ref.read(authProvider).isLoggedIn) {
      AppToast.info(context, 'Vui lòng đăng nhập để mua hàng');
      final loggedIn = await AppRouter.login(context);
      if (!loggedIn || !mounted) return;
    }
    final inCart = ref
        .read(cartProvider.notifier)
        .add(_product, _selectedVariant, _quantity, maxStock: _stock);
    if (!mounted) return;
    if (buyNow) {
      showCartSheet(context);
    } else {
      AppToast.success(
        context,
        inCart < _quantity
            ? 'Đã đạt số lượng tối đa trong kho ($inCart)'
            : 'Sản phẩm đã được thêm vào Giỏ hàng',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.desktop;
    final gallery = ImageGallery(
      images: _galleryImages,
      overrideImage: _variantImage,
    );
    final info = _info();

    return SingleChildScrollView(
      child: ContentContainer(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Breadcrumb(product: _product),
            const SizedBox(height: 12),
            SectionCard(
              padding: const EdgeInsets.all(16),
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 450, child: gallery),
                        const SizedBox(width: 28),
                        Expanded(child: info),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [gallery, const SizedBox(height: 16), info],
                    ),
            ),
            const SizedBox(height: 16),
            ShopSummaryCard(
              shopId: _product.shopId,
              fallbackName: _product.shopName,
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Chi tiết sản phẩm',
              child: Column(
                children: [
                  _specRow('Danh mục', _product.categoryName ?? '—'),
                  _specRow('Kho', '${_product.totalStock}'),
                  if (_hasVariants && !_matrix.isTrivial)
                    _specRow('Số phân loại', '${_matrix.variants.length}'),
                  _specRow('Shop', _product.shopName ?? '—'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Mô tả sản phẩm',
              child: Text(
                _product.description ??
                    'Người bán chưa cập nhật mô tả cho sản phẩm này.',
                style: const TextStyle(
                  color: AppColors.body,
                  height: 1.7,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _info() {
    final stock = _stock;
    final compact = MediaQuery.sizeOf(context).width < Breakpoints.tablet;
    final canBuy = stock > 0 || _needsSelection;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              if (_product.isMall)
                const WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: _MallTag(),
                  ),
                ),
              TextSpan(text: _product.name),
            ],
          ),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: AppColors.title,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 10),
        _RatingRow(product: _product),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          color: AppColors.priceBox,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Text(
            _priceText,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 30,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (_hasVariants && !_matrix.isTrivial)
          VariantSelector(
            matrix: _matrix,
            selection: _selection,
            onChanged: _onSelectionChanged,
            showError: _showVariantError,
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8,
            children: [
              SizedBox(
                width: compact ? 80 : 110,
                child: const Text(
                  'Số lượng',
                  style: TextStyle(color: AppColors.caption),
                ),
              ),
              QuantitySelector(
                value: _quantity,
                max: stock,
                onChanged: (q) => setState(() => _quantity = q),
              ),
              const SizedBox(width: 14),
              Text(
                stock > 0 ? '$stock sản phẩm có sẵn' : 'Hết hàng',
                style: TextStyle(
                  color: stock > 0 ? AppColors.caption : AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _ctaButtons(compact: compact, enabled: canBuy),
      ],
    );
  }

  /// "Thêm vào giỏ hàng" (cam nhạt viền cam) + "Mua ngay" (cam đặc).
  /// Mobile: hai nút chia đều một hàng.
  Widget _ctaButtons({required bool compact, required bool enabled}) {
    final addToCart = OutlinedButton.icon(
      onPressed: enabled ? () => _addToCart(buyNow: false) : null,
      icon: const Icon(Icons.add_shopping_cart),
      label: const Text('Thêm vào giỏ hàng', overflow: TextOverflow.ellipsis),
    );
    final buyNow = FilledButton(
      onPressed: enabled ? () => _addToCart(buyNow: true) : null,
      child: const Text('Mua ngay'),
    );
    if (compact) {
      return Row(
        children: [
          Expanded(child: SizedBox(height: 48, child: addToCart)),
          const SizedBox(width: 10),
          Expanded(child: SizedBox(height: 48, child: buyNow)),
        ],
      );
    }
    return Row(
      children: [
        SizedBox(height: 48, child: addToCart),
        const SizedBox(width: 14),
        SizedBox(height: 48, width: 180, child: buyNow),
      ],
    );
  }

  Widget _specRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(label, style: const TextStyle(color: AppColors.caption)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(color: AppColors.title)),
        ),
      ],
    ),
  );
}

class _MallTag extends StatelessWidget {
  const _MallTag();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
    decoration: BoxDecoration(
      color: const Color(0xFFD0011B),
      borderRadius: BorderRadius.circular(2),
    ),
    child: const Text(
      'Mall',
      style: TextStyle(color: Colors.white, fontSize: 12),
    ),
  );
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final rating = product.rating;
    final divider = Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      color: AppColors.border,
    );
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (rating != null) ...[
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 16,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.primary,
            ),
          ),
          const SizedBox(width: 4),
          for (var i = 1; i <= 5; i++)
            Icon(
              rating >= i
                  ? Icons.star
                  : (rating >= i - 0.5 ? Icons.star_half : Icons.star_border),
              color: AppColors.primary,
              size: 16,
            ),
          divider,
          Text(
            '${product.reviewCount ?? 0} Đánh giá',
            style: const TextStyle(color: AppColors.body),
          ),
        ] else
          const Text(
            'Chưa có đánh giá',
            style: TextStyle(color: AppColors.caption),
          ),
        divider,
        Text(
          product.soldCount == null
              ? 'Kho ${product.totalStock}'
              : '${formatCompact(product.soldCount!)} Đã bán',
          style: const TextStyle(color: AppColors.body),
        ),
      ],
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    const link = TextStyle(color: Color(0xFF0055AA), fontSize: 13);
    const sep = Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Icon(Icons.chevron_right, size: 14, color: AppColors.caption),
    );
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        InkWell(
          onTap: () => AppRouter.backToHome(context),
          child: const Text('Shoppy', style: link),
        ),
        if (product.categoryName != null) ...[
          sep,
          InkWell(
            onTap: () =>
                AppRouter.category(context, categoryId: product.categoryId),
            child: Text(product.categoryName!, style: link),
          ),
        ],
        sep,
        Text(
          product.name,
          style: const TextStyle(color: AppColors.title, fontSize: 13),
        ),
      ],
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.desktop;
    const gallery = AspectRatio(aspectRatio: 1, child: Skeleton());
    const info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Skeleton(height: 22),
        SizedBox(height: 8),
        Skeleton(height: 22, width: 260),
        SizedBox(height: 16),
        Skeleton(height: 16, width: 200),
        SizedBox(height: 16),
        Skeleton(height: 68),
        SizedBox(height: 24),
        Skeleton(height: 40, width: 320),
        SizedBox(height: 16),
        Skeleton(height: 32, width: 220),
        SizedBox(height: 28),
        Row(
          children: [
            Skeleton(height: 48, width: 190),
            SizedBox(width: 14),
            Skeleton(height: 48, width: 180),
          ],
        ),
      ],
    );
    return SingleChildScrollView(
      child: ContentContainer(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            SectionCard(
              child: wide
                  ? const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 450, child: gallery),
                        SizedBox(width: 28),
                        Expanded(child: info),
                      ],
                    )
                  : const Column(
                      children: [gallery, SizedBox(height: 16), info],
                    ),
            ),
            const SizedBox(height: 16),
            const SectionCard(child: Skeleton(height: 80)),
          ],
        ),
      ),
    );
  }
}
