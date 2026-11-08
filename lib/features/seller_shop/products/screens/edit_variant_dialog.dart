import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/seller_product.dart';
import '../services/product_service.dart';

class EditVariantDialog extends StatefulWidget {
  const EditVariantDialog({
    super.key,
    required this.repository,
    required this.variant,
  });

  final ProductRepository repository;
  final ProductVariantDetail variant;

  @override
  State<EditVariantDialog> createState() => _EditVariantDialogState();
}

class _EditVariantDialogState extends State<EditVariantDialog> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;
  late final TextEditingController _skuController;
  XFile? _replacementImage;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final variant = widget.variant;
    _nameController = TextEditingController(text: variant.variantName);
    _priceController = TextEditingController(text: variant.price.toString());
    _stockController = TextEditingController(
      text: variant.stockQuantity.toString(),
    );
    _skuController = TextEditingController(text: variant.sku ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _skuController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (!mounted || image == null) return;
      setState(() {
        _replacementImage = image;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Không thể chọn ảnh: $error');
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final price = double.parse(
      _priceController.text.trim().replaceAll(',', '.'),
    );
    final stockQuantity = int.parse(_stockController.text.trim());
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final updatedVariant = await widget.repository.updateVariant(
        variantId: widget.variant.id,
        variantName: _nameController.text,
        price: price,
        stockQuantity: stockQuantity,
        sku: _skuController.text,
        imageUrl: _replacementImage == null ? _existingImageUrl() : null,
        image: _replacementImage,
      );
      if (!mounted) return;
      Navigator.of(context).pop(updatedVariant);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isSubmitting = false;
      });
    }
  }

  double? _parsePrice(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  String? _existingImageUrl() =>
      widget.variant.imageUrl ??
      (widget.variant.images.isEmpty
          ? null
          : widget.variant.images.first.imageUrl);

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Sửa biến thể'),
    content: SizedBox(
      width: 420,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const ValueKey('edit-variant-name'),
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Tên biến thể *'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Nhập tên biến thể.'
                    : null,
              ),
              TextFormField(
                key: const ValueKey('edit-variant-price'),
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Giá *'),
                validator: (value) {
                  final price = _parsePrice(value ?? '');
                  return price == null || price <= 0
                      ? 'Giá không hợp lệ.'
                      : null;
                },
              ),
              TextFormField(
                key: const ValueKey('edit-variant-stock'),
                controller: _stockController,
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
                key: const ValueKey('edit-variant-sku'),
                controller: _skuController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'SKU'),
                validator: (value) =>
                    widget.variant.sku?.trim().isNotEmpty == true &&
                        (value == null || value.trim().isEmpty)
                    ? 'SKU không được để trống.'
                    : null,
              ),
              const SizedBox(height: 12),
              if (_replacementImage == null && _existingImageUrl() != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _existingImageUrl()!,
                    height: 100,
                    width: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.broken_image_outlined, size: 48),
                  ),
                ),
              if (_replacementImage != null)
                InputChip(
                  key: const ValueKey('replacement-variant-image'),
                  label: Text(_replacementImage!.name),
                  onDeleted: _isSubmitting
                      ? null
                      : () => setState(() => _replacementImage = null),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('pick-edit-variant-image'),
                  onPressed: _isSubmitting ? null : _pickImage,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(
                    _replacementImage == null ? 'Thay ảnh' : 'Chọn ảnh khác',
                  ),
                ),
              ),
              if (_error != null)
                Text(
                  _error!,
                  key: const ValueKey('edit-variant-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
        child: const Text('Hủy'),
      ),
      FilledButton(
        key: const ValueKey('save-variant-changes'),
        onPressed: _isSubmitting ? null : _save,
        child: _isSubmitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Lưu'),
      ),
    ],
  );
}
