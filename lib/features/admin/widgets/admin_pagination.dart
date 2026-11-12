import 'package:flutter/material.dart';

import 'admin_presentation.dart';

class AdminPagination extends StatelessWidget {
  const AdminPagination({
    super.key,
    required this.page,
    required this.totalPages,
    required this.onChanged,
  });

  final int page;
  final int totalPages;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();
    final pages = <int>{0, totalPages - 1};
    for (var i = page - 1; i <= page + 1; i++) {
      if (i >= 0 && i < totalPages) {
        pages.add(i);
      }
    }
    if (totalPages <= 7) {
      pages.addAll(List.generate(totalPages, (i) => i));
    }
    final sorted = pages.toList()..sort();
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 8,
        children: [
          IconButton(
            tooltip: 'Trang trước',
            onPressed: onChanged != null && page > 0
                ? () => onChanged!(page - 1)
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          for (var i = 0; i < sorted.length; i++) ...[
            if (i > 0 && sorted[i] - sorted[i - 1] > 1)
              const SizedBox(
                width: 20,
                child: Text('…', textAlign: TextAlign.center),
              ),
            SizedBox(
              width: 36,
              height: 36,
              child: TextButton(
                onPressed: onChanged == null || sorted[i] == page
                    ? null
                    : () => onChanged!(sorted[i]),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(36, 36),
                  backgroundColor: sorted[i] == page ? primary : null,
                  foregroundColor: adminNavy,
                  disabledForegroundColor: sorted[i] == page
                      ? Colors.white
                      : adminMuted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: Text('${sorted[i] + 1}'),
              ),
            ),
          ],
          IconButton(
            tooltip: 'Trang sau',
            onPressed: onChanged != null && page + 1 < totalPages
                ? () => onChanged!(page + 1)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
