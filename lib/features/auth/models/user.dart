import '../../../core/network/json_utils.dart';

enum UserRole { customer, seller, shipper, admin, unknown }

enum Gender {
  male('MALE', 'Nam'),
  female('FEMALE', 'Nữ'),
  other('OTHER', 'Khác');

  const Gender(this.value, this.label);

  final String value;
  final String label;

  static Gender? parse(dynamic raw) {
    final v = raw?.toString().toUpperCase();
    for (final g in values) {
      if (g.value == v) return g;
    }
    return null;
  }
}

/// Hồ sơ người dùng (UserProfile) — khớp `GET /users/profile`.
///
/// `gender` / `dateOfBirth` hiện backend CHƯA trả về; FE vẫn đọc nếu có.
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
    this.gender,
    this.dateOfBirth,
    this.createdAt,
  });

  final int id;
  final String email;
  final String fullName;
  final String? phone;
  final String? avatarUrl;
  final UserRole role;
  final String? status;

  /// Số dư Ví Shoppy (VNĐ).
  final double balance;
  final Gender? gender;
  final DateTime? dateOfBirth;
  final DateTime? createdAt;

  String get displayName => fullName.isNotEmpty ? fullName : email;

  bool get isSeller => role == UserRole.seller;

  bool get isCustomer => role == UserRole.customer;

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
        'SHIPPER' => UserRole.shipper,
        'ADMIN' => UserRole.admin,
        _ => UserRole.unknown,
      },
      status: asStringOrNull(json['status']),
      balance: asDouble(json['balance']),
      gender: Gender.parse(json['gender']),
      dateOfBirth: asDate(json['dateOfBirth'] ?? json['dob']),
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
    'gender': gender?.value,
    'dateOfBirth': dateOfBirth?.toIso8601String(),
    'createdAt': createdAt?.toIso8601String(),
  };
}

/// Tên theo đặc tả FE2.
typedef UserProfile = User;
