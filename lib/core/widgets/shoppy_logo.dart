import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Logo chữ "Shoppy" kèm biểu tượng túi mua sắm (không dùng asset ngoài).
class ShoppyLogo extends StatelessWidget {
  const ShoppyLogo({super.key, this.color = Colors.white, this.size = 28});

  /// Logo cam trên nền trắng (dùng cho Auth header).
  const ShoppyLogo.brand({super.key, this.size = 28})
    : color = AppColors.primary;

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.shopping_bag, color: color, size: size * 1.25),
        const SizedBox(width: 6),
        Text(
          'Shoppy',
          style: TextStyle(
            color: color,
            fontSize: size,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}
