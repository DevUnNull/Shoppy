import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_toast.dart';

class PickedAvatar {
  const PickedAvatar({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}

/// Chọn ảnh đại diện từ thư viện, hiển thị preview tròn.
class AvatarPicker extends StatelessWidget {
  const AvatarPicker({super.key, required this.value, required this.onChanged});

  final PickedAvatar? value;
  final ValueChanged<PickedAvatar?> onChanged;

  static const _maxBytes = 5 * 1024 * 1024;

  Future<void> _pick(BuildContext context) async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!context.mounted) return;
      if (bytes.lengthInBytes > _maxBytes) {
        AppToast.error(context, 'Ảnh vượt quá 5MB, vui lòng chọn ảnh khác');
        return;
      }
      onChanged(PickedAvatar(bytes: bytes, fileName: file.name));
    } catch (_) {
      if (context.mounted) {
        AppToast.error(
          context,
          'Không mở được thư viện ảnh. Hãy cấp quyền truy cập ảnh.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatar = value;
    return Column(
      children: [
        GestureDetector(
          onTap: () => _pick(context),
          child: Stack(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.background,
                  border: Border.all(color: AppColors.border),
                  image: avatar == null
                      ? null
                      : DecorationImage(
                          image: MemoryImage(avatar.bytes),
                          fit: BoxFit.cover,
                        ),
                ),
                child: avatar == null
                    ? const Icon(
                        Icons.person,
                        size: 56,
                        color: AppColors.border,
                      )
                    : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.photo_camera,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => _pick(context),
              child: Text(avatar == null ? 'Chọn ảnh đại diện' : 'Đổi ảnh'),
            ),
            if (avatar != null)
              TextButton(
                onPressed: () => onChanged(null),
                child: const Text(
                  'Xoá',
                  style: TextStyle(color: AppColors.caption),
                ),
              ),
          ],
        ),
        const Text(
          'Dung lượng tối đa 5MB · JPEG, PNG',
          style: TextStyle(color: AppColors.caption, fontSize: 12),
        ),
      ],
    );
  }
}
