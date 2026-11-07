import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/shipper_order.dart';

String shipperMoney(num amount) => NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
).format(amount);

class ShipperStatusBadge extends StatelessWidget {
  const ShipperStatusBadge({super.key, required this.order});
  final ShipperOrder order;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      order.statusLabel,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );
}

class ShipperPaymentInfo extends StatelessWidget {
  const ShipperPaymentInfo({super.key, required this.order});
  final ShipperOrder order;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (order.paymentMethod == 'COD') ...[
        const Text('COD · Số tiền cần thu'),
        const SizedBox(height: 4),
        Text(
          shipperMoney(order.grandTotal),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ] else if (order.paymentMethod == 'WALLET')
        const Text(
          'Đã thanh toán qua ví — Không thu tiền',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green),
        )
      else
        Text(
          'Phương thức thanh toán: ${order.paymentMethod}. Chưa xác định số tiền cần thu.',
        ),
    ],
  );
}

class ShipperErrorView extends StatelessWidget {
  const ShipperErrorView({
    super.key,
    required this.error,
    required this.onRetry,
  });
  final Object error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.error_outline,
          color: Theme.of(context).colorScheme.error,
          size: 32,
        ),
        const SizedBox(height: 12),
        Text('$error', textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Thử lại'),
        ),
      ],
    ),
  );
}
