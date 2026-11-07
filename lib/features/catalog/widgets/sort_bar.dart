import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/product_sort.dart';

/// Thanh sắp xếp chuẩn Shopee: Phổ biến | Mới nhất | Bán chạy | Giá ▾  ·  1/5 < >
class SortBar extends StatelessWidget {
  const SortBar({
    super.key,
    required this.value,
    required this.onChanged,
    this.page,
    this.totalPages,
    this.onPageChanged,
  });

  final ProductSort value;
  final ValueChanged<ProductSort> onChanged;
  final int? page;
  final int? totalPages;
  final ValueChanged<int>? onPageChanged;

  @override
  Widget build(BuildContext context) {
    final pager = page != null && totalPages != null && totalPages! > 0;
    return Container(
      color: const Color(0xFFEDEDED),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Text(
                    'Sắp xếp theo',
                    style: TextStyle(color: AppColors.body),
                  ),
                  const SizedBox(width: 12),
                  for (final sort in [
                    ProductSort.popular,
                    ProductSort.newest,
                    ProductSort.bestSelling,
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _SortButton(
                        label: sort.label,
                        selected: value == sort,
                        onTap: () => onChanged(sort),
                      ),
                    ),
                  _PriceMenu(value: value, onChanged: onChanged),
                ],
              ),
            ),
          ),
          if (pager) ...[
            const SizedBox(width: 12),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${page! + 1}',
                    style: const TextStyle(color: AppColors.primary),
                  ),
                  TextSpan(text: '/$totalPages'),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _PagerArrow(
              icon: Icons.chevron_left,
              onTap: page! > 0 ? () => onPageChanged?.call(page! - 1) : null,
            ),
            _PagerArrow(
              icon: Icons.chevron_right,
              onTap: page! < totalPages! - 1
                  ? () => onPageChanged?.call(page! + 1)
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(2),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.title,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _PriceMenu extends StatelessWidget {
  const _PriceMenu({required this.value, required this.onChanged});

  final ProductSort value;
  final ValueChanged<ProductSort> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ProductSort>(
      tooltip: 'Sắp xếp theo giá',
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      itemBuilder: (_) => [
        for (final sort in [ProductSort.priceAsc, ProductSort.priceDesc])
          PopupMenuItem(
            value: sort,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    sort.label,
                    style: TextStyle(
                      color: value == sort
                          ? AppColors.primary
                          : AppColors.title,
                    ),
                  ),
                ),
                if (value == sort)
                  const Icon(Icons.check, size: 16, color: AppColors.primary),
              ],
            ),
          ),
      ],
      child: Container(
        height: 34,
        width: 190,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(2),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value.isPrice ? value.label : 'Giá',
                style: TextStyle(
                  color: value.isPrice ? AppColors.primary : AppColors.title,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: AppColors.caption,
            ),
          ],
        ),
      ),
    );
  }
}

class _PagerArrow extends StatelessWidget {
  const _PagerArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        margin: const EdgeInsets.only(left: 2),
        color: onTap == null ? const Color(0xFFF9F9F9) : Colors.white,
        child: Icon(
          icon,
          size: 18,
          color: onTap == null ? AppColors.border : AppColors.body,
        ),
      ),
    );
  }
}
