import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Phân trang chuẩn Shopee: `<  1 2 3 ... 10  >` (page bắt đầu từ 0).
class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.page,
    required this.totalPages,
    required this.onChanged,
  });

  final int page;
  final int totalPages;
  final ValueChanged<int> onChanged;

  List<int?> _pages() {
    if (totalPages <= 7) return List.generate(totalPages, (i) => i);
    final items = <int?>{0, totalPages - 1};
    for (var i = page - 1; i <= page + 1; i++) {
      if (i > 0 && i < totalPages - 1) items.add(i);
    }
    final sorted = items.whereType<int>().toList()..sort();
    final result = <int?>[];
    for (var i = 0; i < sorted.length; i++) {
      if (i > 0 && sorted[i] - sorted[i - 1] > 1) result.add(null);
      result.add(sorted[i]);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 6,
        children: [
          _arrow(
            Icons.chevron_left,
            page > 0 ? () => onChanged(page - 1) : null,
          ),
          for (final p in _pages())
            p == null
                ? const SizedBox(
                    width: 32,
                    child: Text('...', textAlign: TextAlign.center),
                  )
                : _PageButton(
                    label: '${p + 1}',
                    selected: p == page,
                    onTap: () => onChanged(p),
                  ),
          _arrow(
            Icons.chevron_right,
            page < totalPages - 1 ? () => onChanged(page + 1) : null,
          ),
        ],
      ),
    );
  }

  Widget _arrow(IconData icon, VoidCallback? onTap) => IconButton(
    onPressed: onTap,
    icon: Icon(icon),
    color: AppColors.body,
    disabledColor: AppColors.border,
    visualDensity: VisualDensity.compact,
  );
}

class _PageButton extends StatelessWidget {
  const _PageButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: selected ? null : onTap,
      borderRadius: BorderRadius.circular(2),
      child: Container(
        constraints: const BoxConstraints(minWidth: 36),
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.body,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
