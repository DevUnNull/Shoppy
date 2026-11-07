import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/cod_transaction.dart';
import 'shipper_order_widgets.dart';

class CodTransactionTile extends StatelessWidget {
  const CodTransactionTile({super.key, required this.transaction});
  final CodTransaction transaction;
  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(transaction.createdAt);
    final color = transaction.isCollection
        ? Colors.green.shade700
        : transaction.isRemittance
        ? Colors.deepOrange.shade700
        : Colors.grey.shade700;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  transaction.typeLabel,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${transaction.sign}${shipperMoney(transaction.amount)}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              date == null
                  ? transaction.createdAt
                  : DateFormat('dd/MM/yyyy HH:mm').format(date),
            ),
            if (transaction.orderId != null)
              Text('Đơn #${transaction.orderId}'),
            if (transaction.note != null && transaction.note!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(transaction.note!),
              ),
            if (transaction.status != 'COMPLETED')
              Text('Trạng thái: ${transaction.status}'),
          ],
        ),
      ),
    );
  }
}
