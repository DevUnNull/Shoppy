/// Hàm đọc JSON an toàn: backend đôi khi trả số dạng int/double/string.
Map<String, dynamic> asMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> asMapList(dynamic value) =>
    value is List ? value.whereType<Map>().map(asMap).toList() : const [];

int asInt(dynamic value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

int? asIntOrNull(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double asDouble(dynamic value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

double? asDoubleOrNull(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

String asString(dynamic value, [String fallback = '']) =>
    value is String ? value : (value?.toString() ?? fallback);

String? asStringOrNull(dynamic value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

bool asBool(dynamic value, [bool fallback = false]) =>
    value is bool ? value : fallback;

DateTime? asDate(dynamic value) =>
    value is String ? DateTime.tryParse(value) : null;
