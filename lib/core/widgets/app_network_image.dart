import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'skeleton.dart';

/// Ảnh mạng có skeleton khi đang tải và icon thay thế khi lỗi/thiếu URL.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  final String? url;
  final BoxFit fit;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final src = url;
    if (src == null || src.isEmpty) return _fallback();
    return Image.network(
      src,
      fit: fit,
      width: width,
      height: height,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : Skeleton(
              width: width ?? double.infinity,
              height: height ?? double.infinity,
            ),
      errorBuilder: (context, error, stackTrace) => _fallback(),
    );
  }

  Widget _fallback() => Container(
    width: width,
    height: height,
    color: AppColors.divider,
    alignment: Alignment.center,
    child: const Icon(Icons.image_outlined, color: AppColors.caption),
  );
}
