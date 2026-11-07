import '../models/cod_balance.dart';
import '../models/cod_transaction.dart';
import '../services/shipper_order_service.dart';

class ShipperCodRepository {
  ShipperCodRepository(this.service);
  final ShipperOrderService service;

  Future<CodBalance> getBalance() async {
    final data = await service.getCodBalance();
    try {
      return CodBalance.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (_) {
      throw const ShipperOrderException('Không đọc được số dư COD từ backend.');
    }
  }

  Future<List<CodTransaction>> getTransactions({
    CodFilter filter = CodFilter.all,
  }) async {
    final data = await service.getCodTransactions(type: filter.apiValue);
    try {
      if (data is! List) throw const FormatException();
      final unique = <int, CodTransaction>{};
      for (final row in data) {
        final transaction = CodTransaction.fromJson(
          Map<String, dynamic>.from(row as Map),
        );
        if (filter == CodFilter.all || transaction.type == filter.apiValue) {
          unique[transaction.id] = transaction;
        }
      }
      return unique.values.toList();
    } catch (_) {
      throw const ShipperOrderException(
        'Không đọc được lịch sử COD từ backend.',
      );
    }
  }

  Future<CodTransaction> remit(int amount, String note) async {
    final data = await service.remitCod(amount, note);
    try {
      final transaction = CodTransaction.fromJson(
        Map<String, dynamic>.from(data as Map),
      );
      if (!transaction.isRemittance ||
          transaction.status != 'COMPLETED' ||
          transaction.amount != amount) {
        throw const FormatException();
      }
      return transaction;
    } catch (_) {
      // Có thể backend đã ghi tiền: để provider kiểm tra lại, không gửi lại POST.
      throw const ShipperOrderException(
        'Chưa xác nhận được giao dịch nộp COD. Cần kiểm tra số dư và lịch sử.',
      );
    }
  }
}
