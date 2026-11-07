import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class ShopAvatar extends StatelessWidget {
  const ShopAvatar({
    super.key,
    required this.url,
    required this.name,
    this.size = 80,
  });

  final String? url;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? 'S' : name.characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primaryLight,
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null
          ? Center(
              child: Text(
                initial,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: size * 0.4,
                ),
              ),
            )
          : Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: size * 0.4,
                  ),
                ),
              ),
            ),
    );
  }
}
