import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/seller_product.dart';
import '../services/product_service.dart';

class CreateProductDialog extends StatefulWidget {
  const CreateProductDialog({super.key, required this.repository});

  final ProductRepository repository;

  @override
  State<CreateProductDialog> createState() => _CreateProductDialogState();
}

class _CreateProductDialogState extends State<CreateProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _imagePicker = ImagePicker();
  final List<_VariantFields> _variants = [];
  List<ProductCategory> _categories = [];
  List<XFile> _images = [];
  ProductCategory? _category;
  bool _hasVariants = false;
  bool _isLoadingCategories = true;
  bool _isSubmitting = false;
  Object? _categoryError;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    for (final variant in _variants) {
      variant.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await widget.repository.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _category = categories.isEmpty ? null : categories.first;
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

  Future<void> _pickProductImages() async {
    try {
      final picked = await _imagePicker.pickMultiImage();
      if (!mounted || picked.isEmpty) return;
      setState(() {
        _images = [..._images, ...picked];
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitError = 'Không thể chọn ảnh: $error');
    }
  }

  Future<void> _pickVariantImage(_VariantFields variant) async {
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (!mounted || image == null) return;
      setState(() => variant.image = image);
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

    final variants = <ProductVariantInput>[];
    if (_hasVariants) {
      for (final variant in _variants) {
        final price = _parsePrice(variant.price.text);
        final stock = int.tryParse(variant.stock.text.trim());
        if (variant.name.text.trim().isEmpty ||
            variant.sku.text.trim().isEmpty ||
            price == null ||
            price <= 0 ||
            stock == null ||
            stock < 0) {
          setState(
            () => _submitError = 'Vui lòng nhập tên, SKU, giá hợp lệ và tồn kho cho từng biến thể.',
          );
          return;
        }
        variants.add(
          ProductVariantInput(
            variantName: variant.name.text,
            price: price,
            stockQuantity: stock,
            sku: variant.sku.text,
            image: variant.image,
          ),
        );
      }
      if (variants.isEmpty) {
        setState(() => _submitError = 'Hãy thêm ít nhất một biến thể.');
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final product = await widget.repository.createProduct(
        name: _nameController.text,
        description: _descriptionController.text,
        categoryId: category.id,
        images: _images,
        basePrice: _hasVariants ? null : _parsePrice(_priceController.text),
        baseStock: _hasVariants ? null : int.parse(_stockController.text),
        variants: variants,
      );
      if (!mounted) return;
      Navigator.of(context).pop(product);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitError = error.toString();
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tạo sản phẩm'),
          leading: IconButton(
            tooltip: 'Đóng',
            onPressed: _isSubmitting ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
          actions: [
            TextButton(
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
            ? _CategoryLoadError(
                error: _categoryError!,
                onRetry: _loadCategories,
              )
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
            key: const ValueKey('new-product-name'),
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
          const SizedBox(height: 14),
          DropdownButtonFormField<ProductCategory>(
            key: const ValueKey('new-product-category'),
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
            onChanged: (value) => setState(() => _category = value),
            validator: (value) => value == null ? 'Chọn danh mục.' : null,
          ),
          const SizedBox(height: 18),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Sản phẩm có biến thể'),
            subtitle: const Text('Ví dụ: màu sắc, kích thước'),
            value: _hasVariants,
            onChanged: (value) {
              setState(() {
                _hasVariants = value;
                _submitError = null;
                if (value && _variants.isEmpty) {
                  _variants.add(_VariantFields());
                }
              });
            },
          ),
          const Divider(),
          if (_hasVariants) ...[
            for (var index = 0; index < _variants.length; index++)
              _buildVariantFields(index, _variants[index]),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () =>
                    setState(() => _variants.add(_VariantFields())),
                icon: const Icon(Icons.add),
                label: const Text('Thêm biến thể'),
              ),
            ),
          ] else
            _buildSingleProductFields(),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const ValueKey('pick-product-images'),
            onPressed: _isSubmitting ? null : _pickProductImages,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(
              _images.isEmpty
                  ? 'Thêm ảnh sản phẩm'
                  : 'Thêm ảnh (${_images.length})',
            ),
          ),
          if (_images.isNotEmpty)
            Wrap(
              spacing: 8,
              children: [
                for (var index = 0; index < _images.length; index++)
                  InputChip(
                    label: Text(_images[index].name),
                    onDeleted: _isSubmitting
                        ? null
                        : () => setState(() => _images.removeAt(index)),
                  ),
              ],
            ),
          if (_submitError != null) ...[
            const SizedBox(height: 12),
            Text(
              _submitError!,
              key: const ValueKey('create-product-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSingleProductFields() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            key: const ValueKey('new-product-price'),
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Giá bán *',
              suffixText: 'đ',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              final price = _parsePrice(value ?? '');
              return price == null || price <= 0 ? 'Giá không hợp lệ.' : null;
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            key: const ValueKey('new-product-stock'),
            controller: _stockController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Tồn kho *',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              final stock = int.tryParse(value?.trim() ?? '');
              return stock == null || stock < 0
                  ? 'Số lượng không hợp lệ.'
                  : null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVariantFields(int index, _VariantFields variant) {
    return Card(
      key: ValueKey('product-variant-$index'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Biến thể ${index + 1}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (_variants.length > 1)
                  IconButton(
                    tooltip: 'Xóa biến thể',
                    onPressed: _isSubmitting
                        ? null
                        : () => setState(() {
                            _variants.removeAt(index).dispose();
                          }),
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            TextFormField(
              controller: variant.name,
              decoration: const InputDecoration(
                labelText: 'Tên biến thể *',
                hintText: 'Trắng - Size M',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  _hasVariants && value != null && value.trim().isEmpty
                  ? 'Nhập tên biến thể.'
                  : null,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: variant.price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Giá *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (!_hasVariants) return null;
                      final price = _parsePrice(value ?? '');
                      return price == null || price <= 0
                          ? 'Giá không hợp lệ.'
                          : null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: variant.stock,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Tồn kho *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (!_hasVariants) return null;
                      final stock = int.tryParse(value?.trim() ?? '');
                      return stock == null || stock < 0
                          ? 'Tồn kho không hợp lệ.'
                          : null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: variant.sku,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'SKU *',
                hintText: 'AO-TRANG-M',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  _hasVariants && value != null && value.trim().isEmpty
                  ? 'Nhập SKU.'
                  : null,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _isSubmitting
                    ? null
                    : () => _pickVariantImage(variant),
                icon: const Icon(Icons.image_outlined),
                label: Text(
                  variant.image?.name ?? 'Ảnh biến thể (không bắt buộc)',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double? _parsePrice(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));
}

class _VariantFields {
  final name = TextEditingController();
  final price = TextEditingController();
  final stock = TextEditingController();
  final sku = TextEditingController();
  XFile? image;

  void dispose() {
    name.dispose();
    price.dispose();
    stock.dispose();
    sku.dispose();
  }
}

class _CategoryLoadError extends StatelessWidget {
  const _CategoryLoadError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Không tải được danh mục: $error',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tải lại danh mục'),
            ),
          ],
        ),
      ),
    );
  }
}
