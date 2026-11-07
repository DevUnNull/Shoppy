import 'cod_balance.dart';

enum CodFilter {
  all(null, 'Tất cả'),
  collection('COLLECTION', 'Thu tiền'),
  remittance('REMITTANCE', 'Nộp tiền');

  const CodFilter(this.apiValue, this.label);
  final String? apiValue;
  final String label;
}

class CodTransaction {
  const CodTransaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.status,
    required this.createdAt,
    this.note,
    this.orderId,
    this.shipperId,
  });
  final int id;
  final double amount;
  final String type, status, createdAt;
  final String? note;
  final int? orderId, shipperId;

  bool get isCollection => type == 'COLLECTION';
  bool get isRemittance => type == 'REMITTANCE';
  String get typeLabel => isCollection
      ? 'Thu tiền'
      : isRemittance
      ? 'Nộp tiền'
      : 'Giao dịch khác';
  String get sign => isCollection
      ? '+'
      : isRemittance
      ? '−'
      : '';

  factory CodTransaction.fromJson(Map<String, dynamic> json) => CodTransaction(
    id: (json['id'] as num).toInt(),
    amount: codAmount(json['amount']),
    type: json['type'] as String,
    status: json['status'] as String,
    createdAt: json['createdAt'] as String,
    note: json['note'] as String?,
    orderId: (json['orderId'] as num?)?.toInt(),
    shipperId: (json['shipperId'] as num?)?.toInt(),
  );
}
