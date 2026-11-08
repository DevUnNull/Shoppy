import 'dart:async';

import 'package:flutter/material.dart';

import '../models/seller_product.dart';
import '../services/product_service.dart';
import 'create_product_dialog.dart';
import 'product_detail_screen.dart';

class MyProductsScreen extends StatefulWidget {
  const MyProductsScreen({
    super.key,
    required this.repository,
    this.pageSize = 20,
    this.showTitle = true,
  });

  final ProductRepository repository;
  final int pageSize;
  final bool showTitle;

  @override
  State<MyProductsScreen> createState() => _MyProductsScreenState();
}

class _MyProductsScreenState extends State<MyProductsScreen> {
  late final ProductRepository _repository;
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  ProductStockStatus _stockStatus = ProductStockStatus.all;
  SellerProductPage? _result;
  Object? _error;
  bool _isLoading = true;
  int _requestedPage = 0;
  int _requestSequence = 0;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository;
    _loadProducts();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _loadProducts(page: 0);
    });
  }

  Future<void> _loadProducts({int? page}) async {
    _searchDebounce?.cancel();
    _searchDebounce = null;
    final requestSequence = ++_requestSequence;
    final pageToLoad = page ?? _requestedPage;
    setState(() {
      _requestedPage = pageToLoad;
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _repository.getProducts(
        stockStatus: _stockStatus,
        keyword: _searchController.text,
        page: pageToLoad,
        size: widget.pageSize,
      );
      if (!mounted || requestSequence != _requestSequence) return;
      setState(() {
        _result = result;
        _requestedPage = result.page;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || requestSequence != _requestSequence) return;
      setState(() {
        _error = error;
        _isLoading = false;
      });
    }
  }

  Future<void> _createProduct() async {
    final product = await showDialog<SellerProduct>(
      context: context,
      useSafeArea: false,
      builder: (_) => CreateProductDialog(repository: _repository),
    );
    if (!mounted || product == null) return;

    await _loadProducts(page: 0);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã tạo sản phẩm "${product.name}".')),
    );
  }

  Future<void> _openProductDetails(SellerProduct product) async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            ProductDetailScreen(productId: product.id, repository: _repository),
      ),
    );
    if (deleted == true && mounted) {
      await _loadProducts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              if (widget.showTitle)
                Expanded(
                  child: Text(
                    'Sản phẩm của tôi',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                )
              else
                const Spacer(),
              FilledButton.icon(
                key: const ValueKey('create-product-button'),
                onPressed: _isLoading ? null : _createProduct,
                icon: const Icon(Icons.add),
                label: const Text('Tạo sản phẩm'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            children: [
              TextField(
                key: const ValueKey('product-search-field'),
                controller: _searchController,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Tìm theo tên sản phẩm',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Xóa tìm kiếm',
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                          icon: const Icon(Icons.clear),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.filter_list, size: 20),
                  const SizedBox(width: 8),
                  const Text('Tồn kho'),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<ProductStockStatus>(
                      key: const ValueKey('product-stock-filter'),
                      initialValue: _stockStatus,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: ProductStockStatus.all,
                          child: Text('Tất cả'),
                        ),
                        DropdownMenuItem(
                          value: ProductStockStatus.inStock,
                          child: Text('Còn hàng'),
                        ),
                        DropdownMenuItem(
                          value: ProductStockStatus.outOfStock,
                          child: Text('Hết hàng'),
                        ),
                      ],
                      onChanged: _isLoading
                          ? null
                          : (value) {
                              if (value == null) return;
                              setState(() => _stockStatus = value);
                              _loadProducts(page: 0);
                            },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(child: _buildContent(context)),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_isLoading && _result == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _result == null) {
      return _ProductsError(error: _error!, onRetry: _loadProducts);
    }

    final result = _result;
    if (result == null) {
      return _ProductsError(
        error: StateError('Không tìm thấy danh sách sản phẩm.'),
        onRetry: _loadProducts,
      );
    }

    return Column(
      children: [
        if (_isLoading) const LinearProgressIndicator(minHeight: 2),
        if (_error != null)
          MaterialBanner(
            content: Text(_error.toString()),
            actions: [
              TextButton(
                onPressed: _loadProducts,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        Expanded(
          child: result.content.isEmpty
              ? _ProductsEmptyState(
                  hasKeyword: _searchController.text.trim().isNotEmpty,
                  onRefresh: _loadProducts,
                )
              : RefreshIndicator(
                  onRefresh: _loadProducts,
                  child: ListView.separated(
                    key: const ValueKey('product-list'),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    itemCount: result.content.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final product = result.content[index];
                      return _ProductCard(
                        product: product,
                        onTap: () => _openProductDetails(product),
                      );
                    },
                  ),
                ),
        ),
        _PaginationBar(
          page: result.page,
          totalPages: result.totalPages,
          totalElements: result.totalElements,
          hasPrevious: result.hasPrevious && !_isLoading,
          hasNext: result.hasNext && !_isLoading,
          onPrevious: () => _loadProducts(page: result.page - 1),
          onNext: () => _loadProducts(page: result.page + 1),
        ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onTap});

  final SellerProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasStock = product.totalStock > 0;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: InkWell(
        key: ValueKey('product-card-${product.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProductThumbnail(url: product.thumbnailUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      product.categoryName,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _priceRange(product),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _ProductBadge(
                          label: hasStock
                              ? 'Còn ${product.totalStock}'
                              : 'Hết hàng',
                          color: hasStock ? colors.primary : colors.error,
                        ),
                        if (!product.isActive)
                          _ProductBadge(
                            label: 'Đã ẩn',
                            color: colors.onSurfaceVariant,
                          ),
                        if (product.hasVariants)
                          _ProductBadge(
                            label: 'Có phân loại',
                            color: colors.tertiary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _priceRange(SellerProduct product) {
    final minimum = _formatPrice(product.minPrice);
    if (product.minPrice == product.maxPrice) {
      return '$minimum đ';
    }
    return '$minimum - ${_formatPrice(product.maxPrice)} đ';
  }

  String _formatPrice(double value) => value
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => '.');
}

class _ProductThumbnail extends StatelessWidget {
  const _ProductThumbnail({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(url ?? '');
    final validUrl =
        uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 84,
        height: 84,
        child: validUrl
            ? Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _ProductImagePlaceholder(),
              )
            : const _ProductImagePlaceholder(),
      ),
    );
  }
}

class _ProductImagePlaceholder extends StatelessWidget {
  const _ProductImagePlaceholder();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: const Icon(Icons.image_outlined, size: 32),
  );
}

class _ProductBadge extends StatelessWidget {
  const _ProductBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.page,
    required this.totalPages,
    required this.totalElements,
    required this.hasPrevious,
    required this.hasNext,
    required this.onPrevious,
    required this.onNext,
  });

  final int page;
  final int totalPages;
  final int totalElements;
  final bool hasPrevious;
  final bool hasNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Row(
          children: [
            IconButton(
              key: const ValueKey('products-previous-page'),
              tooltip: 'Trang trước',
              onPressed: hasPrevious ? onPrevious : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                totalPages == 0
                    ? 'Chưa có sản phẩm'
                    : 'Trang ${page + 1}/$totalPages · $totalElements sản phẩm',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            IconButton(
              key: const ValueKey('products-next-page'),
              tooltip: 'Trang sau',
              onPressed: hasNext ? onNext : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductsEmptyState extends StatelessWidget {
  const _ProductsEmptyState({
    required this.hasKeyword,
    required this.onRefresh,
  });

  final bool hasKeyword;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 280,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 44),
                  const SizedBox(height: 12),
                  Text(
                    hasKeyword
                        ? 'Không tìm thấy sản phẩm phù hợp.'
                        : 'Chưa có sản phẩm trong bộ lọc này.',
                    textAlign: TextAlign.center,
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

class _ProductsError extends StatelessWidget {
  const _ProductsError({required this.error, required this.onRetry});

  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 44,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(error.toString(), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}
