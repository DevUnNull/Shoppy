import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/product_service.dart';

class AddVariantDialog extends StatefulWidget {
  const AddVariantDialog({
    super.key,
    required this.repository,
    required this.productId,
  });

  final ProductRepository repository;
  final int productId;

  @override
  State<AddVariantDialog> createState() => _AddVariantDialogState();
}

class _AddVariantDialogState extends State<AddVariantDialog> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _skuController = TextEditingController();
  final _imageUrlController = TextEditingController();
  XFile? _image;
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _skuController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (!mounted || image == null) return;
      setState(() {
        _image = image;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Không thể chọn ảnh: $error');
    }
  }

  double? _parsePrice(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final variant = await widget.repository.addVariant(
        productId: widget.productId,
        variantName: _nameController.text,
        price: _parsePrice(_priceController.text)!,
        stockQuantity: int.parse(_stockController.text.trim()),
        sku: _skuController.text,
        imageUrl: _imageUrlController.text.trim().isEmpty
            ? null
            : _imageUrlController.text.trim(),
        image: _image,
      );
      if (!mounted) return;
      Navigator.of(context).pop(variant);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Thêm biến thể'),
    content: SizedBox(
      width: 420,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const ValueKey('new-variant-name'),
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Tên biến thể *'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Nhập tên biến thể.'
                    : null,
              ),
              TextFormField(
                key: const ValueKey('new-variant-price'),
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
                key: const ValueKey('new-variant-stock'),
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
                key: const ValueKey('new-variant-sku'),
                controller: _skuController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'SKU *'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Nhập SKU.' : null,
              ),
              TextFormField(
                key: const ValueKey('new-variant-image-url'),
                controller: _imageUrlController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'URL ảnh (không bắt buộc)',
                ),
              ),
              if (_image != null)
                InputChip(
                  key: const ValueKey('new-variant-image'),
                  label: Text(_image!.name),
                  onDeleted: _isSubmitting
                      ? null
                      : () => setState(() => _image = null),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('pick-new-variant-image'),
                  onPressed: _isSubmitting ? null : _pickImage,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(_image == null ? 'Chọn ảnh' : 'Chọn ảnh khác'),
                ),
              ),
              if (_error != null)
                Text(
                  _error!,
                  key: const ValueKey('add-variant-error'),
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
        key: const ValueKey('save-new-variant'),
        onPressed: _isSubmitting ? null : _submit,
        child: _isSubmitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Thêm'),
      ),
    ],
  );
}
