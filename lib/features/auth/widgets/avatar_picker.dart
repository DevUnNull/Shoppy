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
  const AvatarPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.maxBytes = 5 * 1024 * 1024,
    this.currentUrl,
    this.size = 96,
  });

  final PickedAvatar? value;
  final ValueChanged<PickedAvatar?> onChanged;

  /// Dung lượng tối đa cho phép (Đăng ký: 5MB, Hồ sơ: 1MB).
  final int maxBytes;

  /// Ảnh hiện tại trên server (màn Hồ sơ, khi chưa chọn ảnh mới).
  final String? currentUrl;
  final double size;

  String get _limitLabel => maxBytes >= 1024 * 1024
      ? '${maxBytes ~/ (1024 * 1024)}MB'
      : '${maxBytes ~/ 1024}KB';

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
      final name = file.name.toLowerCase();
      if (!(name.endsWith('.jpg') ||
          name.endsWith('.jpeg') ||
          name.endsWith('.png'))) {
        AppToast.error(context, 'Chỉ hỗ trợ ảnh định dạng JPEG hoặc PNG');
        return;
      }
      if (bytes.lengthInBytes > maxBytes) {
        AppToast.error(
          context,
          'Ảnh vượt quá $_limitLabel, vui lòng chọn ảnh khác',
        );
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
    final ImageProvider? image = avatar != null
        ? MemoryImage(avatar.bytes)
        : (currentUrl != null ? NetworkImage(currentUrl!) : null);
    return Column(
      children: [
        GestureDetector(
          onTap: () => _pick(context),
          child: Stack(
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.background,
                  border: Border.all(color: AppColors.border),
                  image: image == null
                      ? null
                      : DecorationImage(image: image, fit: BoxFit.cover),
                ),
                child: image == null
                    ? Icon(
                        Icons.person,
                        size: size * 0.58,
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
            OutlinedButton(
              onPressed: () => _pick(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.title,
                backgroundColor: Colors.white,
                side: const BorderSide(color: AppColors.border),
                minimumSize: const Size(0, 36),
              ),
              child: Text(avatar == null ? 'Chọn ảnh' : 'Đổi ảnh'),
            ),
            if (avatar != null)
              TextButton(
                onPressed: () => onChanged(null),
                child: const Text(
                  'Bỏ chọn',
                  style: TextStyle(color: AppColors.caption),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Dung lượng tối đa $_limitLabel\nĐịnh dạng: .JPEG, .PNG',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.caption, fontSize: 12),
        ),
      ],
    );
  }
}
