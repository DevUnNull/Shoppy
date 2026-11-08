import 'dart:typed_data';

import '../../../core/network/api_exception.dart';
import '../../../core/network/json_utils.dart';

enum AdminSection {
  users('Người dùng', '/admin/users'),
  shops('Cửa hàng', '/admin/shops'),
  categories('Danh mục', '/admin/categories'),
  shippingCompanies('Đơn vị vận chuyển', '/admin/shipping-companies'),
  orders('Đơn hàng toàn sàn', '/orders/manage');

  const AdminSection(this.title, this.path);

  final String title;
  final String path;

  bool get supportsSearch => this != orders;
  bool get supportsRole => this == users;
  bool get supportsEdit => this == categories || this == shippingCompanies;
  bool get supportsDetail => this != categories;

  List<String> get statuses => switch (this) {
    users || shops => const ['ACTIVE', 'INACTIVE', 'BLOCKED'],
    categories || shippingCompanies => const ['ACTIVE', 'INACTIVE'],
    orders => const [
      'PENDING',
      'PROCESSING',
      'READY_TO_SHIP',
      'SHIPPING',
      'DELIVERED',
      'CANCELLED',
    ],
  };
}

const adminRoles = ['CUSTOMER', 'SELLER', 'SHIPPER', 'ADMIN'];

/// Keep nested detail fields intact: linked shop/owner/vehicle/tracking are
/// supplied by different endpoints and must not be fabricated by the client.
class AdminRecord {
  AdminRecord(Map<String, dynamic> raw)
    : raw = Map<String, dynamic>.unmodifiable(raw) {
    if (id <= 0) {
      throw const ApiException('Dữ liệu quản trị thiếu mã bản ghi hợp lệ.');
    }
  }

  final Map<String, dynamic> raw;

  int get id => asInt(raw['id']);
  String get name => asString(
    raw['fullName'] ?? raw['name'] ?? raw['shopName'] ?? raw['orderCode'],
    '#$id',
  );
  String get status => asString(raw['status']);
  String get email => asString(raw['email']);
  String get phone => asString(raw['phone']);
  String get role => asString(raw['role']);
  String get slug => asString(raw['slug']);
  String get code => asString(raw['code']);
  String? get imageUrl => asStringOrNull(
    raw['avatarUrl'] ?? raw['logoUrl'] ?? raw['imageUrl'] ?? raw['iconUrl'],
  );
  double? get balance => asDoubleOrNull(raw['balance']);
  int? get parentId => asIntOrNull(raw['parentId']);
  int get displayOrder => asInt(raw['displayOrder']);
}

class AdminPage {
  const AdminPage({
    required this.items,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.hasNext,
  });

  final List<AdminRecord> items;
  List<AdminRecord> get content => items;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool hasNext;

  factory AdminPage.fromJson(dynamic data, {int page = 0, int size = 10}) {
    if (data is! Map || data['content'] is! List) {
      throw const ApiException(
        'Danh sách quản trị trả về không đúng định dạng.',
      );
    }
    final rows = data['content'] as List;
    if (rows.any((row) => row is! Map)) {
      throw const ApiException('Danh sách quản trị có bản ghi không hợp lệ.');
    }
    final items = rows
        .map((row) => AdminRecord(Map<String, dynamic>.from(row as Map)))
        .toList();
    final currentPage = asInt(data['page'] ?? data['number'], page);
    final totalPages = asIntOrNull(data['totalPages']);
    final hasNext = data['hasNext'] is bool
        ? data['hasNext'] as bool
        : currentPage + 1 < (totalPages ?? 0);
    return AdminPage(
      items: List.unmodifiable(items),
      page: currentPage,
      size: asInt(data['size'], size),
      totalElements: asInt(data['totalElements'], items.length),
      totalPages: totalPages ?? (currentPage + (hasNext ? 2 : 1)),
      hasNext: hasNext,
    );
  }
}

class AdminQuery {
  const AdminQuery({
    this.search = '',
    this.status = '',
    this.role = '',
    this.page = 0,
    this.size = 10,
  });

  final String search;
  final String status;
  final String role;
  final int page;
  final int size;

  AdminQuery copyWith({
    String? search,
    String? status,
    String? role,
    int? page,
    int? size,
  }) => AdminQuery(
    search: search ?? this.search,
    status: status ?? this.status,
    role: role ?? this.role,
    page: page ?? this.page,
    size: size ?? this.size,
  );
}

class AdminUpload {
  const AdminUpload({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}
