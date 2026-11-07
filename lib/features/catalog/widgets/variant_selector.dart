import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/variant_matrix.dart';

/// Bộ chọn biến thể dạng pill: tự làm mờ/disable phân loại hết hàng.
class VariantSelector extends StatelessWidget {
  const VariantSelector({
    super.key,
    required this.matrix,
    required this.selection,
    required this.onChanged,
    this.showError = false,
  });

  final VariantMatrix matrix;
  final List<String?> selection;
  final ValueChanged<List<String?>> onChanged;

  /// Nền đỏ nhạt + nhắc nhở khi bấm mua mà chưa chọn đủ (giống Shopee).
  final bool showError;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      color: showError ? const Color(0xFFFFF5F5) : Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var g = 0; g < matrix.groups.length; g++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: MediaQuery.sizeOf(context).width < 600 ? 80 : 110,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        matrix.groups[g].name,
                        style: const TextStyle(color: AppColors.caption),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final option in matrix.groups[g].options)
                          _Pill(
                            label: option,
                            image: _imageFor(g, option),
                            selected: selection[g] == option,
                            enabled: matrix.isOptionAvailable(
                              g,
                              option,
                              selection,
                            ),
                            onTap: () {
                              final next = [...selection];
                              next[g] = selection[g] == option ? null : option;
                              onChanged(next);
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (showError)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Vui lòng chọn Phân loại hàng',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
        ],
      ),
    );
  }

  /// Ảnh nhỏ trên pill chỉ dùng cho nhóm đầu tiên (thường là màu sắc).
  String? _imageFor(int group, String option) {
    if (group != 0) return null;
    final probe = matrix.emptySelection()..[0] = option;
    final matches = matrix.matching(probe);
    final urls = matches.map((v) => v.imageUrl).whereType<String>().toSet();
    return urls.length == 1 && matrix.variants.length > 1 ? urls.first : null;
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.image,
  });

  final String label;
  final String? image;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = !enabled
        ? Colors.black26
        : (selected ? AppColors.primary : AppColors.title);
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: MouseRegion(
        cursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.forbidden,
        child: GestureDetector(
          onTap: enabled || selected ? onTap : null,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                constraints: const BoxConstraints(minWidth: 80, minHeight: 40),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: enabled ? Colors.white : const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                    color: selected
                        ? AppColors.primary
                        : Colors.black.withValues(alpha: 0.09),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (image != null) ...[
                      Image.network(
                        image!,
                        width: 24,
                        height: 24,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        color: color,
                        decoration: enabled ? null : TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: CustomPaint(
                    size: const Size(15, 15),
                    painter: _CornerTickPainter(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tam giác cam có dấu ✓ ở góc dưới phải pill đang chọn.
class _CornerTickPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final triangle = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(triangle, Paint()..color = AppColors.primary);
    final tick = Path()
      ..moveTo(size.width * 0.45, size.height * 0.72)
      ..lineTo(size.width * 0.62, size.height * 0.88)
      ..lineTo(size.width * 0.92, size.height * 0.5);
    canvas.drawPath(
      tick,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
