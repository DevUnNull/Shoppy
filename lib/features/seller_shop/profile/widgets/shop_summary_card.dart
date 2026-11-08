import 'package:flutter/material.dart';

import '../models/shop.dart';

class ShopSummaryCard extends StatelessWidget {
  const ShopSummaryCard({super.key, required this.shop});

  final Shop shop;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isActive = shop.status.toUpperCase() == 'ACTIVE';

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tổng quan',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _SummaryValue(
                    label: 'Số dư',
                    value: '${shop.balance.toStringAsFixed(2)} đ',
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryValue(
                    label: 'Trạng thái',
                    value: _statusLabel(shop.status),
                    icon: isActive
                        ? Icons.check_circle_outline
                        : Icons.info_outline,
                    valueColor: isActive ? colors.primary : colors.error,
                  ),
                ),
              ],
            ),
            if (shop.createdAt case final createdAt?) ...[
              const SizedBox(height: 18),
              const Divider(height: 1),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    size: 19,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Ngày tạo: ${_formatDate(createdAt)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _statusLabel(String status) => switch (status.toUpperCase()) {
    'ACTIVE' => 'Đang hoạt động',
    'INACTIVE' => 'Ngừng hoạt động',
    _ => status,
  };

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: valueColor ?? colors.primary),
          const SizedBox(height: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(color: valueColor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
