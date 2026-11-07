import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_network_image.dart';

/// Ảnh lớn + dải thumbnail; hover (desktop) hoặc chạm (mobile) để đổi ảnh.
class ImageGallery extends StatefulWidget {
  const ImageGallery({super.key, required this.images, this.overrideImage});

  final List<String> images;

  /// Ảnh của biến thể đang chọn — ưu tiên hiển thị ở khung lớn.
  final String? overrideImage;

  @override
  State<ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<ImageGallery> {
  int _index = 0;
  bool _showOverride = true;

  @override
  void didUpdateWidget(covariant ImageGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.overrideImage != oldWidget.overrideImage) _showOverride = true;
    if (_index >= widget.images.length) _index = 0;
  }

  void _select(int index) => setState(() {
    _index = index;
    _showOverride = false;
  });

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    final main =
        (_showOverride ? widget.overrideImage : null) ??
        (images.isEmpty ? null : images[_index]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: AppNetworkImage(
              key: ValueKey(main),
              url: main,
              fit: BoxFit.contain,
            ),
          ),
        ),
        if (images.length > 1) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 82,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final active = main == images[i];
                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => _select(i),
                  child: GestureDetector(
                    onTap: () => _select(i),
                    child: Container(
                      width: 82,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: active
                              ? AppColors.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: AppNetworkImage(url: images[i]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
