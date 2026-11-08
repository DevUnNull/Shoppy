import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/seller_product.dart';
import '../services/product_service.dart';

class EditProductDialog extends StatefulWidget {
  const EditProductDialog({
    super.key,
    required this.repository,
    required this.product,
  });

  final ProductRepository repository;
  final ProductDetail product;

  @override
  State<EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends State<EditProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  final _imagePicker = ImagePicker();
  late final List<_VariantEditState> _variantEdits;

  List<ProductCategory> _categories = [];
  List<XFile> _replacementImages = [];
  ProductCategory? _category;
  bool _isLoadingCategories = true;
  bool _isSubmitting = false;
  bool _replaceExistingImages = false;
  Object? _categoryError;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product.name);
    _descriptionController = TextEditingController(
      text: widget.product.description ?? '',
    );
    _variantEdits = [
      for (final variant in widget.product.variants) _VariantEditState(variant),
    ];
    _loadCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    for (final variant in _variantEdits) {
      variant.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await widget.repository.getCategories();
      if (!mounted) return;
      final availableCategories = [...categories];
      final currentCategoryExists = availableCategories.any(
        (category) => category.id == widget.product.categoryId,
      );
      if (!currentCategoryExists) {
        availableCategories.add(
          ProductCategory(
            id: widget.product.categoryId,
            name: widget.product.categoryName,
          ),
        );
      }

      setState(() {
        _categories = availableCategories;
        _category = availableCategories.firstWhere(
          (category) => category.id == widget.product.categoryId,
        );
        _isLoadingCategories = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _categoryError = error;
        _isLoadingCategories = false;
      });
    }
  }

  Future<void> _pickReplacementImages() async {
    try {
      final images = await _imagePicker.pickMultiImage();
      if (!mounted || images.isEmpty) return;
      setState(() {
        _replacementImages = images;
        _replaceExistingImages = true;
        _submitError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitError = 'Không thể chọn ảnh: $error');
    }
  }

  void _removeExistingImages() {
    setState(() {
      _replacementImages = [];
      _replaceExistingImages = true;
      _submitError = null;
    });
  }

  void _cancelImageChanges() {
    setState(() {
      _replacementImages = [];
      _replaceExistingImages = false;
      _submitError = null;
    });
  }

  Future<void> _pickVariantImage(_VariantEditState variant) async {
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (!mounted || image == null) return;
      setState(() {
        variant.replacementImage = image;
        _submitError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitError = 'Không thể chọn ảnh biến thể: $error');
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final category = _category;
    if (category == null) {
      setState(() => _submitError = 'Vui lòng chọn danh mục sản phẩm.');
      return;
    }
    if (_replaceExistingImages &&
        widget.product.images.any((image) => image.id == null)) {
      setState(
        () => _submitError =
            'Không thể thay ảnh vì ảnh hiện tại thiếu mã ảnh từ máy chủ.',
      );
      return;
    }

    for (final variant in _variantEdits) {
      if (!_validateVariant(variant)) return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      var updatedProduct = await widget.repository.updateProduct(
        productId: widget.product.id,
        name: _nameController.text,
        description: _descriptionController.text,
        categoryId: category.id,
        images: _replacementImages,
        deleteImageIds: _replaceExistingImages
            ? widget.product.images.map((image) => image.id!).toList()
            : const [],
      );
      final updatedVariants = <int, ProductVariantDetail>{};
      for (final variant in _variantEdits.where((item) => item.hasChanges)) {
        try {
          updatedVariants[variant.original.id] = await widget.repository
              .updateVariant(
                variantId: variant.original.id,
                variantName: variant.nameController.text,
                price: double.parse(
                  variant.priceController.text.trim().replaceAll(',', '.'),
                ),
                stockQuantity: int.parse(variant.stockController.text.trim()),
                sku: variant.skuController.text,
                imageUrl: variant.replacementImage == null
                    ? _existingVariantImageUrl(variant.original)
                    : null,
                image: variant.replacementImage,
              );
        } catch (error) {
          throw StateError(
            'Sản phẩm đã được cập nhật, nhưng không thể cập nhật biến thể '
            '"${variant.original.variantName}": $error',
          );
        }
      }

      if (updatedVariants.isNotEmpty) {
        final variants = [
          for (final variant in widget.product.variants)
            updatedVariants[variant.id] ?? variant,
        ];
        updatedProduct = updatedProduct.copyWith(
          variants: variants,
          totalStock: variants.fold<int>(
            0,
            (total, variant) => total + variant.stockQuantity,
          ),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(updatedProduct);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitError = error.toString();
        _isSubmitting = false;
      });
    }
  }

  bool _validateVariant(_VariantEditState variant) {
    final name = variant.nameController.text.trim();
    final price = double.tryParse(
      variant.priceController.text.trim().replaceAll(',', '.'),
    );
    final stock = int.tryParse(variant.stockController.text.trim());
    final sku = variant.skuController.text.trim();
    if (name.isEmpty ||
        price == null ||
        price <= 0 ||
        stock == null ||
        stock < 0) {
      setState(
        () => _submitError =
            'Kiểm tra tên, giá và tồn kho của các biến thể trước khi lưu.',
      );
      return false;
    }
    if (variant.original.sku?.trim().isNotEmpty == true && sku.isEmpty) {
      setState(() => _submitError = 'SKU của biến thể không được để trống.');
      return false;
    }
    return true;
  }

  String? _existingVariantImageUrl(ProductVariantDetail variant) =>
      variant.imageUrl ??
      (variant.images.isEmpty ? null : variant.images.first.imageUrl);

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sửa sản phẩm'),
          leading: IconButton(
            tooltip: 'Đóng',
            onPressed: _isSubmitting ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
          actions: [
            TextButton(
              key: const ValueKey('save-product-changes'),
              onPressed:
                  _isSubmitting ||
                      _isLoadingCategories ||
                      _categoryError != null
                  ? null
                  : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Lưu'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: _isLoadingCategories
            ? const Center(child: CircularProgressIndicator())
            : _categoryError != null
            ? _CategoryError(error: _categoryError!, onRetry: _loadCategories)
            : _buildForm(context),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextFormField(
            key: const ValueKey('edit-product-name'),
            controller: _nameController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Tên sản phẩm *',
              border: OutlineInputBorder(),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Nhập tên sản phẩm.'
                : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            key: const ValueKey('edit-product-description'),
            controller: _descriptionController,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Mô tả',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 18),
          _buildProductImages(),
          if (_variantEdits.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Thông tin biến thể',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            for (final variant in _variantEdits)
              _buildVariantEditor(context, variant),
          ],
          const SizedBox(height: 14),
          DropdownButtonFormField<ProductCategory>(
            key: const ValueKey('edit-product-category'),
            initialValue: _category,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Danh mục *',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final category in _categories)
                DropdownMenuItem(
                  value: category,
                  child: Text(category.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _isSubmitting
                ? null
                : (category) => setState(() => _category = category),
            validator: (category) => category == null ? 'Chọn danh mục.' : null,
          ),
          if (_submitError != null) ...[
            const SizedBox(height: 12),
            Text(
              _submitError!,
              key: const ValueKey('edit-product-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildVariantEditor(BuildContext context, _VariantEditState variant) {
    final imageUrl = _existingVariantImageUrl(variant.original);
    return Card(
      key: ValueKey('edit-product-variant-${variant.original.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              variant.original.variantName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: ValueKey('edit-product-variant-name-${variant.original.id}'),
              controller: variant.nameController,
              decoration: const InputDecoration(labelText: 'Tên biến thể *'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Nhập tên biến thể.'
                  : null,
            ),
            TextFormField(
              key: ValueKey(
                'edit-product-variant-price-${variant.original.id}',
              ),
              controller: variant.priceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Giá *'),
              validator: (value) {
                final price = double.tryParse(
                  (value ?? '').trim().replaceAll(',', '.'),
                );
                return price == null || price <= 0 ? 'Giá không hợp lệ.' : null;
              },
            ),
            TextFormField(
              key: ValueKey(
                'edit-product-variant-stock-${variant.original.id}',
              ),
              controller: variant.stockController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Tồn kho *'),
              validator: (value) {
                final stock = int.tryParse(value?.trim() ?? '');
                return stock == null || stock < 0
                    ? 'Tồn kho không hợp lệ.'
                    : null;
              },
            ),
            TextFormField(
              key: ValueKey('edit-product-variant-sku-${variant.original.id}'),
              controller: variant.skuController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'SKU'),
              validator: (value) =>
                  variant.original.sku?.trim().isNotEmpty == true &&
                      (value == null || value.trim().isEmpty)
                  ? 'SKU của biến thể không được để trống.'
                  : null,
            ),
            const SizedBox(height: 10),
            if (variant.replacementImage == null && imageUrl != null)
              Align(
                alignment: Alignment.centerLeft,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    height: 88,
                    width: 88,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.broken_image_outlined, size: 48),
                  ),
                ),
              ),
            if (variant.replacementImage != null)
              InputChip(
                key: ValueKey(
                  'replacement-product-variant-image-${variant.original.id}',
                ),
                label: Text(variant.replacementImage!.name),
                onDeleted: _isSubmitting
                    ? null
                    : () => setState(() => variant.replacementImage = null),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: ValueKey(
                  'pick-product-variant-image-${variant.original.id}',
                ),
                onPressed: _isSubmitting
                    ? null
                    : () => _pickVariantImage(variant),
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(
                  variant.replacementImage == null
                      ? 'Thay ảnh biến thể'
                      : 'Chọn ảnh khác',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImages() {
    final existingImages = widget.product.images;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ảnh sản phẩm', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (!_replaceExistingImages && existingImages.isNotEmpty) ...[
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: existingImages.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  existingImages[index].imageUrl,
                  width: 92,
                  height: 92,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 92,
                    height: 92,
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (_replaceExistingImages)
          Text(
            _replacementImages.isEmpty
                ? 'Ảnh hiện có sẽ bị xóa khi lưu.'
                : 'Ảnh hiện có sẽ được thay bằng ảnh mới đã chọn.',
          )
        else if (existingImages.isEmpty)
          const Text('Chưa có ảnh sản phẩm.'),
        if (_replacementImages.isNotEmpty)
          Wrap(
            spacing: 8,
            children: [
              for (var index = 0; index < _replacementImages.length; index++)
                InputChip(
                  key: ValueKey('replacement-product-image-$index'),
                  label: Text(_replacementImages[index].name),
                  onDeleted: _isSubmitting
                      ? null
                      : () => setState(() {
                          _replacementImages.removeAt(index);
                          if (_replacementImages.isEmpty) {
                            _replaceExistingImages = false;
                          }
                        }),
                ),
            ],
          ),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('pick-edit-product-images'),
              onPressed: _isSubmitting ? null : _pickReplacementImages,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                _replaceExistingImages ? 'Chọn ảnh thay thế' : 'Thay ảnh',
              ),
            ),
            if (!_replaceExistingImages && existingImages.isNotEmpty)
              TextButton.icon(
                key: const ValueKey('remove-edit-product-images'),
                onPressed: _isSubmitting ? null : _removeExistingImages,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Xóa tất cả ảnh'),
              ),
            if (_replaceExistingImages)
              TextButton(
                key: const ValueKey('cancel-edit-product-image-changes'),
                onPressed: _isSubmitting ? null : _cancelImageChanges,
                child: const Text('Hủy thay đổi ảnh'),
              ),
          ],
        ),
      ],
    );
  }
}

class _VariantEditState {
  _VariantEditState(this.original)
    : nameController = TextEditingController(text: original.variantName),
      priceController = TextEditingController(text: original.price.toString()),
      stockController = TextEditingController(
        text: original.stockQuantity.toString(),
      ),
      skuController = TextEditingController(text: original.sku ?? '');

  final ProductVariantDetail original;
  final TextEditingController nameController;
  final TextEditingController priceController;
  final TextEditingController stockController;
  final TextEditingController skuController;
  XFile? replacementImage;

  bool get hasChanges =>
      nameController.text.trim() != original.variantName ||
      double.tryParse(priceController.text.trim().replaceAll(',', '.')) !=
          original.price ||
      int.tryParse(stockController.text.trim()) != original.stockQuantity ||
      skuController.text.trim() != (original.sku ?? '').trim() ||
      replacementImage != null;

  void dispose() {
    nameController.dispose();
    priceController.dispose();
    stockController.dispose();
    skuController.dispose();
  }
}

class _CategoryError extends StatelessWidget {
  const _CategoryError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Không thể tải danh mục sản phẩm.\n$error',
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
