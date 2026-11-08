class Shop {
  const Shop({
    required this.id,
    required this.userId,
    required this.name,
    required this.description,
    required this.logoUrl,
    required this.address,
    required this.balance,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final int userId;
  final String name;
  final String? description;
  final String? logoUrl;
  final String? address;
  final double balance;
  final String status;
  final DateTime? createdAt;

  factory Shop.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final userId = json['userId'];
    final name = json['name'];
    final balance = _number(json['balance'], 'balance');
    final status = json['status'];
    if (id is! num || userId is! num || name is! String || status is! String) {
      throw const FormatException('Shop response is missing required fields.');
    }

    return Shop(
      id: id.toInt(),
      userId: userId.toInt(),
      name: name,
      description: _nullableString(json['description'], 'description'),
      logoUrl: _nullableString(json['logoUrl'], 'logoUrl'),
      address: _nullableString(
        json['address'] ?? json['googleMapUrl'],
        'address',
      ),
      balance: balance.toDouble(),
      status: status,
      createdAt: _dateTime(json['createdAt'], 'createdAt'),
    );
  }

  static String? _nullableString(Object? value, String field) {
    if (value == null) return null;
    if (value is String) return value;
    throw FormatException('Shop field "$field" must be a string or null.');
  }

  static num _number(Object? value, String field) {
    if (value is num) return value;
    throw FormatException('Shop field "$field" must be a number.');
  }

  static DateTime? _dateTime(Object? value, String field) {
    if (value == null) return null;
    if (value is! String) {
      throw FormatException('Shop field "$field" must be a date string.');
    }
    final date = DateTime.tryParse(value);
    if (date == null) {
      throw FormatException('Shop field "$field" is not a valid date.');
    }
    return date;
  }
}
