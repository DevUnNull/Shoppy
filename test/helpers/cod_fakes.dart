import 'package:shoppy/features/shipper_orders/models/cod_balance.dart';
import 'package:shoppy/features/shipper_orders/models/cod_transaction.dart';
import 'package:shoppy/features/shipper_orders/repositories/shipper_cod_repository.dart';
import 'package:shoppy/features/shipper_orders/services/shipper_order_service.dart';

class FakeCodBackend {
  FakeCodBackend() {
    balances[16] = const CodBalance(
      totalCollected: 930000,
      totalRemitted: 0,
      currentBalance: 930000,
    );
    transactions[16] = [
      const CodTransaction(
        id: 1,
        amount: 930000,
        type: 'COLLECTION',
        status: 'COMPLETED',
        createdAt: '2026-11-07T22:41:47.876311',
        note: 'Thu tiền mặt COD đơn hàng #6',
        orderId: 6,
        shipperId: 16,
      ),
    ];
  }
  final Map<int, CodBalance> balances = {};
  final Map<int, List<CodTransaction>> transactions = {};
  int _nextId = 2;

  // Chỉ backend giả lập này làm phép cộng/trừ; FE luôn đọc lại dữ liệu.
  void remit(int shipperId, int amount, String note) {
    final balance = balances[shipperId]!;
    if (validateCodRemittance('$amount', balance.currentBalance) != null) {
      throw const ShipperOrderException(
        'Số tiền nộp không hợp lệ',
        statusCode: 400,
      );
    }
    balances[shipperId] = CodBalance(
      totalCollected: balance.totalCollected,
      totalRemitted: balance.totalRemitted + amount,
      currentBalance: balance.currentBalance - amount,
    );
    transactions
        .putIfAbsent(shipperId, () => [])
        .insert(
          0,
          CodTransaction(
            id: _nextId++,
            amount: amount.toDouble(),
            type: 'REMITTANCE',
            status: 'COMPLETED',
            createdAt: '2026-11-07T23:00:00',
            note: note,
            shipperId: shipperId,
          ),
        );
  }
}

class FakeCodRepository extends ShipperCodRepository {
  FakeCodRepository({FakeCodBackend? backend, this.shipperId = 16})
    : backend = backend ?? FakeCodBackend(),
      super(ShipperOrderService(token: 'test-cod'));
  final FakeCodBackend backend;
  final int shipperId;
  int balanceCalls = 0;
  final List<CodFilter> filterCalls = [];
  final List<Map<String, dynamic>> postCalls = [];
  Future<CodBalance> Function()? onBalance;
  Future<List<CodTransaction>> Function(CodFilter filter)? onTransactions;
  Future<void> Function(int amount, String note)? onRemit;

  @override
  Future<CodBalance> getBalance() async {
    balanceCalls++;
    if (onBalance != null) return onBalance!();
    return backend.balances[shipperId]!;
  }

  @override
  Future<List<CodTransaction>> getTransactions({
    CodFilter filter = CodFilter.all,
  }) async {
    filterCalls.add(filter);
    if (onTransactions != null) return onTransactions!(filter);
    return (backend.transactions[shipperId] ?? [])
        .where(
          (item) => filter == CodFilter.all || item.type == filter.apiValue,
        )
        .toList();
  }

  @override
  Future<CodTransaction> remit(int amount, String note) async {
    postCalls.add({'amount': amount, 'note': note});
    if (onRemit != null) {
      await onRemit!(amount, note);
    } else {
      backend.remit(shipperId, amount, note);
    }
    return backend.transactions[shipperId]!.first;
  }
}
