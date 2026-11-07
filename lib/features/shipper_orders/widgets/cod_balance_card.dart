import 'package:flutter/material.dart';

import '../models/cod_balance.dart';
import 'shipper_order_widgets.dart';

class CodBalanceCard extends StatelessWidget {
  const CodBalanceCard({super.key, required this.balance});
  final CodBalance balance;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Tiền COD đang giữ'),
          const SizedBox(height: 8),
          Text(
            shipperMoney(balance.currentBalance),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const Divider(height: 32),
          Text('Tổng tiền đã thu: ${shipperMoney(balance.totalCollected)}'),
          const SizedBox(height: 8),
          Text('Tổng tiền đã nộp: ${shipperMoney(balance.totalRemitted)}'),
        ],
      ),
    ),
  );
}
