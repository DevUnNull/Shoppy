class CodBalance {
  const CodBalance({
    required this.totalCollected,
    required this.totalRemitted,
    required this.currentBalance,
  });
  final double totalCollected, totalRemitted, currentBalance;

  factory CodBalance.fromJson(Map<String, dynamic> json) => CodBalance(
    totalCollected: codAmount(json['totalCollected']),
    totalRemitted: codAmount(json['totalRemitted']),
    currentBalance: codAmount(json['currentBalance']),
  );
}

double codAmount(dynamic value) {
  if (value is! num || !value.isFinite || value < 0) {
    throw const FormatException('Số tiền COD không hợp lệ');
  }
  return value.toDouble();
}

String? validateCodRemittance(String input, double balance) {
  final text = input.trim();
  if (text.isEmpty) return 'Vui lòng nhập số tiền nộp.';
  if (!RegExp(r'^[0-9]+$').hasMatch(text)) {
    return 'Chỉ nhập số nguyên dương, không dùng dấu phân cách.';
  }
  final amount = int.tryParse(text);
  if (amount == null) return 'Số tiền không hợp lệ.';
  if (amount < 1000) return 'Số tiền nộp tối thiểu là 1.000 VNĐ.';
  if (amount > balance) return 'Số tiền nộp vượt quá số dư COD đang giữ.';
  return null;
}
