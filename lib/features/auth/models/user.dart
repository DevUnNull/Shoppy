import '../../../core/network/json_utils.dart';

enum UserRole { customer, seller, admin, unknown }

/// Hồ sơ người dùng — khớp `GET /users/profile`.
class User {
  const User({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    this.avatarUrl,
    this.role = UserRole.unknown,
    this.status,
    this.balance = 0,
    this.createdAt,
  });

  final int id;
  final String email;
  final String fullName;
  final String? phone;
  final String? avatarUrl;
  final UserRole role;
  final String? status;
  final double balance;
  final DateTime? createdAt;

  String get displayName => fullName.isNotEmpty ? fullName : email;

  bool get isSeller => role == UserRole.seller;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: asInt(json['id']),
      email: asString(json['email']),
      fullName: asString(json['fullName'] ?? json['name']),
      phone: asStringOrNull(json['phone']),
      avatarUrl: asStringOrNull(json['avatarUrl']),
      role: switch (asString(json['role']).toUpperCase()) {
        'CUSTOMER' || 'USER' || 'BUYER' => UserRole.customer,
        'SELLER' => UserRole.seller,
        'ADMIN' => UserRole.admin,
        _ => UserRole.unknown,
      },
      status: asStringOrNull(json['status']),
      balance: asDouble(json['balance']),
      createdAt: asDate(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'fullName': fullName,
    'phone': phone,
    'avatarUrl': avatarUrl,
    'role': role.name.toUpperCase(),
    'status': status,
    'balance': balance,
    'createdAt': createdAt?.toIso8601String(),
  };
}
