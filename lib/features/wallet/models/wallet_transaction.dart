import '../../../core/network/json_utils.dart';

enum TransactionFilter {
  all('Tất cả'),
  credit('Tiền vào (+)'),
  debit('Tiền ra (-)');

  const TransactionFilter(this.label);

  final String label;
}

/// Một biến động số dư — `GET /users/wallet/transactions`.
///
/// Tài khoản test chưa có giao dịch nên shape được đọc linh hoạt:
/// `amount` âm hoặc `type` thuộc nhóm "chi" => tiền ra.
class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.description,
    this.code,
    this.createdAt,
    this.balanceAfter,
    this.referenceId,
    this.status,
  });

  final int id;

  /// Luôn là giá trị dương; chiều tiền xem [isCredit].
  final double amount;
  final String type;
  final String description;
  final String? code;
  final DateTime? createdAt;
  final double? balanceAfter;
  final int? referenceId;
  final String? status;

  static const _debitTypes = {
    'PAYMENT',
    'PURCHASE',
    'ORDER_PAYMENT',
    'WITHDRAW',
    'WITHDRAWAL',
    'DEBIT',
    'TRANSFER_OUT',
  };

  bool get isCredit => !_debitTypes.contains(type);

  double get signedAmount => isCredit ? amount : -amount;

  /// Mã hiển thị (backend có thì dùng, không thì sinh từ id).
  String get displayCode => code ?? 'GD${id.toString().padLeft(8, '0')}';

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    final raw = asDouble(json['amount']);
    var type = asString(json['type'] ?? json['transactionType']).toUpperCase();
    if (type.isEmpty) type = raw < 0 ? 'DEBIT' : 'CREDIT';
    if (raw < 0 && !_debitTypes.contains(type)) type = 'DEBIT';
    final ref = asIntOrNull(json['referenceId'] ?? json['orderId']);
    return WalletTransaction(
      id: asInt(json['id']),
      amount: raw.abs(),
      type: type,
      description:
          asStringOrNull(json['description'] ?? json['note']) ??
          _describe(type, ref),
      code: asStringOrNull(
        json['transactionCode'] ?? json['code'] ?? json['referenceCode'],
      ),
      createdAt: asDate(json['createdAt'] ?? json['transactionDate']),
      balanceAfter: asDoubleOrNull(json['balanceAfter']),
      referenceId: ref,
      status: asStringOrNull(json['status']),
    );
  }

  static String _describe(String type, int? ref) => switch (type) {
    'DEPOSIT' || 'TOP_UP' => 'Nạp tiền vào ví',
    'REFUND' => ref == null ? 'Hoàn tiền' : 'Hoàn tiền đơn #$ref',
    'PAYMENT' || 'PURCHASE' || 'ORDER_PAYMENT' =>
      ref == null ? 'Thanh toán đơn hàng' : 'Thanh toán đơn #$ref',
    'WITHDRAW' || 'WITHDRAWAL' => 'Rút tiền',
    _ => 'Giao dịch ví',
  };
}
