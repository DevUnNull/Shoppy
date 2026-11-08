import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';

typedef AdminCatalogSave = Future<void> Function(
  Map<String, dynamic> fields,
  Uint8List? imageBytes,
  String? imageName,
);

/// Creates/edits catalog metadata without coupling the form to an API client.
Future<bool> showAdminCatalogForm(
  BuildContext context, {
  required bool isCategory,
  Map<String, dynamic>? initial,
  required AdminCatalogSave onSave,
}) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AdminCatalogForm(
        isCategory: isCategory,
        initial: initial,
        onSave: onSave,
      ),
    ) ??
    false;

class _AdminCatalogForm extends StatefulWidget {
  const _AdminCatalogForm({
    required this.isCategory,
    required this.initial,
    required this.onSave,
  });

  final bool isCategory;
  final Map<String, dynamic>? initial;
  final AdminCatalogSave onSave;

  @override
  State<_AdminCatalogForm> createState() => _AdminCatalogFormState();
}

class _AdminCatalogFormState extends State<_AdminCatalogForm> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields;
  Uint8List? _imageBytes;
  String? _imageName;
  String? _error;
  bool _saving = false;
  bool _picking = false;

  bool get _busy => _saving || _picking;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial ?? const <String, dynamic>{};
    final parent = initial['parent'];
    _fields = {
      for (final key in [
        'name',
        'slug',
        'parentId',
        'displayOrder',
        'code',
        'phone',
        'email',
        'website',
      ])
        key: TextEditingController(
          text:
              (initial[key] ??
                      (key == 'parentId' && parent is Map
                          ? parent['id']
                          : null) ??
                      (key == 'displayOrder' ? 0 : ''))
                  .toString(),
        ),
    };
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_busy) return;
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image == null || !mounted) return;
      if (!RegExp(
        r'\.(png|jpe?g|webp)$',
        caseSensitive: false,
      ).hasMatch(image.name)) {
        throw const FormatException('Chỉ hỗ trợ ảnh PNG, JPEG hoặc WEBP.');
      }
      if (await image.length() > 5 * 1024 * 1024) {
        throw const FormatException(
          'Ảnh tối đa 5 MB. Vui lòng chọn ảnh nhỏ hơn.',
        );
      }
      final bytes = await image.readAsBytes();
      if (bytes.isEmpty) {
        throw const FormatException('Tệp ảnh không có dữ liệu.');
      }
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _imageName = image.name;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is FormatException
              ? error.message.toString()
              : 'Không thể chọn ảnh. Vui lòng kiểm tra quyền truy cập ảnh.';
        });
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    final values = <String, dynamic>{'name': _fields['name']!.text.trim()};
    if (widget.isCategory) {
      values.addAll({
        'slug': _fields['slug']!.text.trim(),
        'parentId': int.tryParse(_fields['parentId']!.text.trim()),
        'displayOrder': int.parse(_fields['displayOrder']!.text.trim()),
      });
    } else {
      for (final field in ['code', 'phone', 'email', 'website']) {
        final value = _fields[field]!.text.trim();
        // Detail responses may omit existing contact data. Leaving an unknown
        // field blank must not erase the value held by the backend.
        final absentContact =
            field != 'code' &&
            widget.initial != null &&
            !widget.initial!.containsKey(field);
        if (!absentContact || value.isNotEmpty) values[field] = value;
      }
    }
    try {
      await widget.onSave(values, _imageBytes, _imageName);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? 'Vui lòng nhập thông tin này'
      : null;

  Widget _field(
    String key,
    String label, {
    String? helper,
    String? Function(String?)? validator,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      key: ValueKey('admin-form-$key'),
      controller: _fields[key],
      enabled: !_busy,
      keyboardType: keyboard,
      maxLength: key == 'name' ? 255 : null,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        counterText: '',
      ),
      validator: validator,
      onFieldSubmitted: (_) => _submit(),
    ),
  );

  Widget _imagePreview() {
    final initial = widget.initial;
    final url =
        initial?['imageUrl'] ??
        initial?['iconUrl'] ??
        initial?['logoUrl'] ??
        initial?['logo'];
    const placeholder = Icon(
      Icons.image_outlined,
      color: AppColors.caption,
      size: 40,
    );
    Widget preview = placeholder;
    if (_imageBytes != null) {
      preview = Image.memory(
        _imageBytes!,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Tooltip(
          message: 'Không đọc được ảnh xem trước',
          child: placeholder,
        ),
      );
    } else if (url is String && url.isNotEmpty) {
      preview = Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => placeholder,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.isCategory ? 'Ảnh biểu tượng' : 'Logo hãng vận chuyển'),
        const SizedBox(height: 8),
        Container(
          height: 96,
          width: 120,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: preview,
        ),
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('admin-form-image'),
              onPressed: _busy ? null : _pickImage,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(_picking ? 'Đang chọn ảnh…' : 'Chọn ảnh'),
            ),
            if (_imageBytes != null)
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _imageBytes = null;
                        _imageName = null;
                      }),
                child: const Text('Bỏ ảnh mới'),
              ),
          ],
        ),
        Text(
          _imageName ?? 'PNG, JPEG, WEBP • Tối đa 5 MB',
          style: const TextStyle(color: AppColors.caption, fontSize: 12),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text(
        '${widget.initial == null ? 'Thêm' : 'Sửa'} ${widget.isCategory ? 'danh mục' : 'hãng vận chuyển'}',
      ),
      content: SizedBox(
        width: 520,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.65,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _field('name', 'Tên *', validator: _required),
                  if (widget.isCategory) ...[
                    _field(
                      'slug',
                      'Slug *',
                      helper: 'Ví dụ: thiet-bi-dien-tu',
                      validator: (value) {
                        if (_required(value) != null) return _required(value);
                        return RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$')
                                .hasMatch(value!.trim())
                            ? null
                            : 'Slug gồm chữ thường, số và dấu gạch nối';
                      },
                    ),
                    _field(
                      'parentId',
                      'ID danh mục cha',
                      helper: 'Để trống nếu là danh mục gốc',
                      keyboard: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return null;
                        final id = int.tryParse(value.trim());
                        if (id == null || id <= 0) {
                          return 'ID danh mục cha phải là số nguyên dương';
                        }
                        if (id.toString() == widget.initial?['id']?.toString()) {
                          return 'Danh mục không thể là cha của chính nó';
                        }
                        return null;
                      },
                    ),
                    _field(
                      'displayOrder',
                      'Thứ tự hiển thị *',
                      keyboard: TextInputType.number,
                      validator: (value) {
                        final order = int.tryParse(value?.trim() ?? '');
                        return order == null || order < 0
                            ? 'Nhập số nguyên không âm'
                            : null;
                      },
                    ),
                  ] else ...[
                    _field('code', 'Mã hãng *', validator: _required),
                    _field(
                      'phone',
                      'Số điện thoại',
                      keyboard: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return null;
                        return RegExp(r'^\+?[0-9 ()-]{6,20}$')
                                .hasMatch(value.trim())
                            ? null
                            : 'Số điện thoại không hợp lệ';
                      },
                    ),
                    _field(
                      'email',
                      'Email',
                      keyboard: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return null;
                        return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                .hasMatch(value.trim())
                            ? null
                            : 'Email không hợp lệ';
                      },
                    ),
                    _field(
                      'website',
                      'Website',
                      keyboard: TextInputType.url,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return null;
                        final uri = Uri.tryParse(value.trim());
                        return uri != null &&
                                ['http', 'https'].contains(uri.scheme) &&
                                uri.host.contains('.')
                            ? null
                            : 'Nhập địa chỉ http:// hoặc https:// hợp lệ';
                      },
                    ),
                  ],
                  _imagePreview(),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      key: const ValueKey('admin-form-error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          key: const ValueKey('admin-form-save'),
          onPressed: _busy ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Lưu'),
        ),
      ],
    ),
  );
}
