import 'package:flutter/material.dart';

import '../models/seller_product.dart';
import '../services/product_service.dart';
import 'add_variant_dialog.dart';
import 'edit_product_dialog.dart';
import 'edit_variant_dialog.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.productId,
    required this.repository,
  });

  final int productId;
  final ProductRepository repository;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  ProductDetail? _product;
  Object? _error;
  bool _isLoading = true;
  bool _isUpdatingStatus = false;
  bool _isDeletingProduct = false;
  final Set<int> _updatingVariantIds = {};

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final product = await widget.repository.getProductDetails(
        widget.productId,
      );
      if (!mounted) return;
      setState(() {
        _product = product;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _isLoading = false;
      });
    }
  }

  Future<void> _editProduct(ProductDetail product) async {
    final updatedProduct = await showDialog<ProductDetail>(
      context: context,
      useSafeArea: false,
      builder: (_) =>
          EditProductDialog(repository: widget.repository, product: product),
    );
    if (!mounted || updatedProduct == null) return;

    setState(() => _product = updatedProduct);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã cập nhật "${updatedProduct.name}".')),
    );
  }

  Future<void> _setProductActive(ProductDetail product, bool active) async {
    setState(() => _isUpdatingStatus = true);
    try {
      await widget.repository.setProductActive(
        productId: product.id,
        active: active,
      );
      if (!mounted) return;
      setState(() {
        _product = product.copyWith(isActive: active);
        _isUpdatingStatus = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            active ? 'Đã mở bán sản phẩm.' : 'Đã ẩn sản phẩm khỏi sàn.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isUpdatingStatus = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể cập nhật trạng thái: $error')),
      );
    }
  }

  Future<void> _setVariantActive(
    ProductVariantDetail variant,
    bool active,
  ) async {
    setState(() => _updatingVariantIds.add(variant.id));
    try {
      final updatedVariant = await widget.repository.setVariantActive(
        variantId: variant.id,
        active: active,
      );
      if (!mounted) return;
      final currentProduct = _product;
      if (currentProduct != null) {
        setState(() {
          _product = currentProduct.copyWith(
            variants: [
              for (final currentVariant in currentProduct.variants)
                currentVariant.id == updatedVariant.id
                    ? updatedVariant
                    : currentVariant,
            ],
          );
          _updatingVariantIds.remove(variant.id);
        });
      } else {
        setState(() => _updatingVariantIds.remove(variant.id));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(active ? 'Đã kích hoạt biến thể.' : 'Đã tắt biến thể.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _updatingVariantIds.remove(variant.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể cập nhật trạng thái: $error')),
      );
    }
  }

  Future<void> _updateVariantStock(ProductVariantDetail variant) async {
    final stockQuantity = await showDialog<int>(
      context: context,
      builder: (_) =>
          _UpdateVariantStockDialog(initialStock: variant.stockQuantity),
    );
    if (!mounted || stockQuantity == null) return;

    setState(() => _updatingVariantIds.add(variant.id));
    try {
      final updatedVariant = await widget.repository.updateVariantStock(
        variantId: variant.id,
        stockQuantity: stockQuantity,
      );
      if (!mounted) return;
      final currentProduct = _product;
      if (currentProduct != null) {
        setState(() {
          _product = currentProduct.copyWith(
            totalStock:
                currentProduct.totalStock +
                updatedVariant.stockQuantity -
                variant.stockQuantity,
            variants: [
              for (final currentVariant in currentProduct.variants)
                currentVariant.id == updatedVariant.id
                    ? updatedVariant
                    : currentVariant,
            ],
          );
          _updatingVariantIds.remove(variant.id);
        });
      } else {
        setState(() => _updatingVariantIds.remove(variant.id));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật số lượng tồn kho.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _updatingVariantIds.remove(variant.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể cập nhật tồn kho: $error')),
      );
    }
  }

  Future<void> _editVariant(ProductVariantDetail variant) async {
    final updatedVariant = await showDialog<ProductVariantDetail>(
      context: context,
      builder: (_) =>
          EditVariantDialog(repository: widget.repository, variant: variant),
    );
    if (!mounted || updatedVariant == null) return;

    final currentProduct = _product;
    if (currentProduct == null) return;
    setState(() {
      _product = currentProduct.copyWith(
        totalStock:
            currentProduct.totalStock +
            updatedVariant.stockQuantity -
            variant.stockQuantity,
        variants: [
          for (final currentVariant in currentProduct.variants)
            currentVariant.id == updatedVariant.id
                ? updatedVariant
                : currentVariant,
        ],
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã cập nhật "${updatedVariant.variantName}".')),
    );
  }

  Future<void> _addVariant(ProductDetail product) async {
    final addedVariant = await showDialog<ProductVariantDetail>(
      context: context,
      builder: (_) => AddVariantDialog(
        repository: widget.repository,
        productId: product.id,
      ),
    );
    if (!mounted || addedVariant == null) return;

    final currentProduct = _product;
    if (currentProduct == null) return;
    setState(() {
      _product = currentProduct.copyWith(
        hasVariants: true,
        totalStock: currentProduct.totalStock + addedVariant.stockQuantity,
        variants: [...currentProduct.variants, addedVariant],
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã thêm "${addedVariant.variantName}".')),
    );
  }

  Future<void> _deleteProduct(ProductDetail product) async {
    final confirmed = await _confirmDelete(
      title: 'Xóa sản phẩm?',
      message: '“${product.name}” sẽ bị ẩn khỏi sàn.',
      confirmLabel: 'Xóa sản phẩm',
    );
    if (!mounted || confirmed != true) return;

    setState(() => _isDeletingProduct = true);
    try {
      await widget.repository.deleteProduct(product.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isDeletingProduct = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể xóa sản phẩm: $error')));
    }
  }

  Future<void> _deleteVariant(
    ProductDetail product,
    ProductVariantDetail variant,
  ) async {
    if (product.variants.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể xóa biến thể cuối cùng của sản phẩm.'),
        ),
      );
      return;
    }

    final confirmed = await _confirmDelete(
      title: 'Xóa biến thể?',
      message: 'Bạn có chắc muốn xóa “${variant.variantName}”?',
      confirmLabel: 'Xóa biến thể',
    );
    if (!mounted || confirmed != true) return;

    setState(() => _updatingVariantIds.add(variant.id));
    try {
      await widget.repository.deleteVariant(variant.id);
      if (!mounted) return;
      final currentProduct = _product;
      if (currentProduct != null) {
        final remainingVariants = currentProduct.variants
            .where((item) => item.id != variant.id)
            .toList();
        setState(() {
          _product = currentProduct.copyWith(
            totalStock: currentProduct.totalStock - variant.stockQuantity,
            hasVariants: remainingVariants.isNotEmpty,
            variants: remainingVariants,
          );
          _updatingVariantIds.remove(variant.id);
        });
      } else {
        setState(() => _updatingVariantIds.remove(variant.id));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã xóa biến thể "${variant.variantName}".')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _updatingVariantIds.remove(variant.id));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể xóa biến thể: $error')));
    }
  }

  Future<bool?> _confirmDelete({
    required String title,
    required String message,
    required String confirmLabel,
  }) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          key: const ValueKey('cancel-delete'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          key: const ValueKey('confirm-delete'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final product = _product;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết sản phẩm'),
        actions: [
          if (product != null)
            IconButton(
              key: const ValueKey('delete-product-button'),
              tooltip: 'Xóa sản phẩm',
              onPressed: _isLoading || _isDeletingProduct
                  ? null
                  : () => _deleteProduct(product),
              icon: _isDeletingProduct
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
            ),
          if (product != null)
            IconButton(
              key: const ValueKey('edit-product-button'),
              tooltip: 'Sửa sản phẩm',
              onPressed: _isLoading ? null : () => _editProduct(product),
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: _isLoading && product == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && product == null
          ? _ProductDetailError(error: _error!, onRetry: _loadProduct)
          : product == null
          ? _ProductDetailError(
              error: StateError('Không tìm thấy chi tiết sản phẩm.'),
              onRetry: _loadProduct,
            )
          : RefreshIndicator(
              onRefresh: _loadProduct,
              child: ListView(
                key: const ValueKey('product-detail-content'),
                padding: const EdgeInsets.all(16),
                children: [
                  if (_isLoading) const LinearProgressIndicator(),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error.toString(),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: SwitchListTile(
                      key: const ValueKey('product-status-switch'),
                      title: const Text('Trạng thái kinh doanh'),
                      subtitle: Text(
                        _isUpdatingStatus
                            ? 'Đang cập nhật...'
                            : product.isActive
                            ? 'Sản phẩm đang được hiển thị trên sàn'
                            : 'Sản phẩm đang được ẩn khỏi sàn',
                      ),
                      secondary: Icon(
                        product.isActive
                            ? Icons.storefront_outlined
                            : Icons.storefront,
                      ),
                      value: product.isActive,
                      onChanged: _isUpdatingStatus || _isLoading
                          ? null
                          : (active) => _setProductActive(product, active),
                    ),
                  ),
                  _ProductImageGallery(images: product.images),
                  const SizedBox(height: 16),
                  Text(
                    product.name,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoChip(
                        icon: Icons.category_outlined,
                        label: product.categoryName,
                      ),
                      _InfoChip(
                        icon: Icons.inventory_2_outlined,
                        label: 'Tồn kho: ${product.totalStock}',
                      ),
                      _InfoChip(
                        icon: product.isActive
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        label: product.isActive ? 'Đang bán' : 'Đã ẩn',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _DetailSection(
                    title: 'Thông tin sản phẩm',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DetailRow(label: 'Shop', value: product.shopName),
                        _DetailRow(
                          label: 'Danh mục',
                          value: product.categoryName,
                        ),
                        _DetailRow(
                          label: 'Loại sản phẩm',
                          value: product.hasVariants
                              ? 'Có phân loại'
                              : 'Sản phẩm đơn',
                        ),
                        if (product.description?.trim().isNotEmpty ?? false)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(product.description!),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DetailSection(
                    title: 'Phân loại (${product.variants.length})',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            key: const ValueKey('add-product-variant'),
                            onPressed: _isLoading
                                ? null
                                : () => _addVariant(product),
                            icon: const Icon(Icons.add),
                            label: const Text('Thêm biến thể'),
                          ),
                        ),
                        if (product.variants.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('Sản phẩm chưa có biến thể.'),
                          ),
                        for (final variant in product.variants)
                          _VariantDetailTile(
                            variant: variant,
                            isUpdating: _updatingVariantIds.contains(
                              variant.id,
                            ),
                            onToggle: (active) =>
                                _setVariantActive(variant, active),
                            onUpdateStock: () => _updateVariantStock(variant),
                            onEdit: () => _editVariant(variant),
                            onDelete: () => _deleteVariant(product, variant),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ProductImageGallery extends StatelessWidget {
  const _ProductImageGallery({required this.images});

  final List<ProductDetailImage> images;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return const _ImagePlaceholder(height: 240);
    }

    return SizedBox(
      height: 240,
      child: PageView.builder(
        itemCount: images.length,
        itemBuilder: (context, index) => ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: _NetworkProductImage(url: images[index].imageUrl, height: 240),
        ),
      ),
    );
  }
}

class _VariantDetailTile extends StatelessWidget {
  const _VariantDetailTile({
    required this.variant,
    required this.isUpdating,
    required this.onToggle,
    required this.onUpdateStock,
    required this.onEdit,
    required this.onDelete,
  });

  final ProductVariantDetail variant;
  final bool isUpdating;
  final ValueChanged<bool> onToggle;
  final VoidCallback onUpdateStock;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final imageUrl =
        variant.imageUrl ??
        (variant.images.isEmpty ? null : variant.images.first.imageUrl);
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NetworkProductImage(url: imageUrl, height: 68, width: 68),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      variant.variantName,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'SKU: ${variant.sku?.trim().isNotEmpty == true ? variant.sku : 'Chưa có'}',
                    ),
                    Text('Tồn kho: ${variant.stockQuantity}'),
                    Text(
                      '${_formatPrice(variant.price)} đ',
                      style: TextStyle(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _VariantStatusBadge(isActive: variant.isActive),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                IconButton(
                  key: ValueKey('variant-delete-${variant.id}'),
                  tooltip: 'Xóa biến thể',
                  onPressed: isUpdating ? null : onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
                TextButton.icon(
                  key: ValueKey('variant-edit-${variant.id}'),
                  onPressed: isUpdating ? null : onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Sửa biến thể'),
                ),
                TextButton.icon(
                  key: ValueKey('variant-stock-update-${variant.id}'),
                  onPressed: isUpdating ? null : onUpdateStock,
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Cập nhật kho'),
                ),
                OutlinedButton.icon(
                  key: ValueKey('variant-status-toggle-${variant.id}'),
                  onPressed: isUpdating
                      ? null
                      : () => onToggle(!variant.isActive),
                  icon: isUpdating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          variant.isActive
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                  label: Text(
                    isUpdating
                        ? 'Đang cập nhật...'
                        : variant.isActive
                        ? 'Tắt biến thể'
                        : 'Kích hoạt biến thể',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UpdateVariantStockDialog extends StatefulWidget {
  const _UpdateVariantStockDialog({required this.initialStock});

  final int initialStock;

  @override
  State<_UpdateVariantStockDialog> createState() =>
      _UpdateVariantStockDialogState();
}

class _UpdateVariantStockDialogState extends State<_UpdateVariantStockDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.initialStock}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final stockQuantity = int.tryParse(_controller.text.trim());
    if (stockQuantity == null || stockQuantity < 0) {
      setState(() => _errorText = 'Nhập số nguyên từ 0 trở lên.');
      return;
    }
    Navigator.of(context).pop(stockQuantity);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Cập nhật tồn kho'),
    content: TextField(
      key: const ValueKey('variant-stock-quantity-input'),
      controller: _controller,
      autofocus: true,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Số lượng mới',
        errorText: _errorText,
      ),
      onChanged: (_) {
        if (_errorText != null) setState(() => _errorText = null);
      },
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Hủy'),
      ),
      FilledButton(
        key: const ValueKey('save-variant-stock'),
        onPressed: _submit,
        child: const Text('Lưu'),
      ),
    ],
  );
}

class _VariantStatusBadge extends StatelessWidget {
  const _VariantStatusBadge({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? Icons.check_circle_outline : Icons.visibility_off,
              size: 15,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              isActive ? 'Biến thể đang hoạt động' : 'Biến thể đã tắt',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _NetworkProductImage extends StatelessWidget {
  const _NetworkProductImage({
    required this.url,
    required this.height,
    this.width,
  });

  final String? url;
  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(url ?? '');
    final validUrl =
        uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;

    return SizedBox(
      height: height,
      width: width,
      child: validUrl
          ? Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  _ImagePlaceholder(height: height, width: width),
            )
          : _ImagePlaceholder(height: height, width: width),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.height, this.width});

  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: width,
    child: ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.image_outlined, size: 36)),
    ),
  );
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) =>
      Chip(avatar: Icon(icon, size: 18), label: Text(label));
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

class _ProductDetailError extends StatelessWidget {
  const _ProductDetailError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 40),
          const SizedBox(height: 12),
          Text(
            'Không thể tải chi tiết sản phẩm.\n$error',
            textAlign: TextAlign.center,
          ),
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

String _formatPrice(double value) => value
    .toStringAsFixed(0)
    .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => '.');
