import 'package:intl/intl.dart';

final _vnd = NumberFormat('#,###', 'en_US');

/// 25000 -> "₫25.000"
String formatVnd(num value) =>
    '₫${_vnd.format(value.round()).replaceAll(',', '.')}';

/// Khoảng giá kiểu Shopee: "₫12.000 - ₫25.000" hoặc 1 giá nếu bằng nhau.
String formatPriceRange(num min, num max) =>
    min == max ? formatVnd(min) : '${formatVnd(min)} - ${formatVnd(max)}';

/// 1234 -> "1,2k" giống cách Shopee rút gọn số lượng đã bán.
String formatCompact(int value) {
  if (value < 1000) return '$value';
  final k = value / 1000;
  final text = k >= 10 ? k.toStringAsFixed(0) : k.toStringAsFixed(1);
  return '${text.replaceAll('.', ',').replaceAll(',0', '')}k';
}

String formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';

/// "3 tháng trước", "2 năm trước"… dùng cho chỉ số "Tham gia" của shop.
String formatJoinedAgo(DateTime date, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(date);
  if (diff.inDays >= 365) return '${diff.inDays ~/ 365} năm trước';
  if (diff.inDays >= 30) return '${diff.inDays ~/ 30} tháng trước';
  if (diff.inDays >= 1) return '${diff.inDays} ngày trước';
  return 'Hôm nay';
}

/// "14:05 07/11/2026"
String formatDateTime(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:'
    '${date.minute.toString().padLeft(2, '0')} ${formatDate(date)}';

/// "Vừa xong", "5 phút trước", "3 giờ trước", hoặc ngày giờ đầy đủ.
String formatRelative(DateTime date, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(date);
  if (diff.inMinutes < 1) return 'Vừa xong';
  if (diff.inHours < 1) return '${diff.inMinutes} phút trước';
  if (diff.inDays < 1) return '${diff.inHours} giờ trước';
  if (diff.inDays < 7) return '${diff.inDays} ngày trước';
  return formatDateTime(date);
}

/// "a***@gmail.com" — che email giống Shopee.
String maskEmail(String email) {
  final at = email.indexOf('@');
  if (at <= 1) return email;
  return '${email.substring(0, 2)}${'*' * (at - 2).clamp(1, 6)}${email.substring(at)}';
}
