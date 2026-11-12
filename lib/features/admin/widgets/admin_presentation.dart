import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../models/admin_models.dart';

const adminNavy = Color(0xFF17243C);
const adminMuted = Color(0xFF6B778C);

IconData adminSectionIcon(AdminSection section) => switch (section) {
  AdminSection.users => Icons.people_outline,
  AdminSection.shops => Icons.storefront_outlined,
  AdminSection.categories => Icons.category_outlined,
  AdminSection.shippingCompanies => Icons.local_shipping_outlined,
  AdminSection.orders => Icons.receipt_long_outlined,
};

String adminStatusLabel(String value) => switch (value) {
  'ACTIVE' => 'Đang hoạt động',
  'INACTIVE' => 'Tạm ngưng',
  'BLOCKED' => 'Đã khóa',
  'PENDING' => 'Chờ xác nhận',
  'PROCESSING' => 'Đang chuẩn bị',
  'READY_TO_SHIP' => 'Chờ lấy hàng',
  'SHIPPING' => 'Đang giao',
  'DELIVERED' => 'Đã giao',
  'CANCELLED' => 'Đã hủy',
  _ => value.isEmpty ? 'Chưa xác định' : value,
};

String adminRoleLabel(String value) => switch (value) {
  'CUSTOMER' => 'Khách hàng',
  'SELLER' => 'Người bán',
  'SHIPPER' => 'Shipper',
  'ADMIN' => 'Quản trị viên',
  _ => value,
};

String adminStatusActionLabel(AdminSection section, String status) =>
    switch ((section, status)) {
      (AdminSection.users, 'ACTIVE') => 'Kích hoạt tài khoản',
      (AdminSection.users, 'INACTIVE') => 'Tạm ngưng tài khoản',
      (AdminSection.users, 'BLOCKED') => 'Khóa tài khoản',
      (AdminSection.shops, 'ACTIVE') => 'Mở cửa hàng',
      (AdminSection.shops, 'INACTIVE') => 'Tạm ngưng cửa hàng',
      (AdminSection.shops, 'BLOCKED') => 'Khóa cửa hàng',
      (_, 'ACTIVE') => 'Bật hoạt động',
      (_, 'INACTIVE') => 'Tắt hoạt động',
      _ => adminStatusLabel(status),
    };

extension AdminSectionPresentation on AdminSection {
  String get subtitle => switch (this) {
    AdminSection.users => 'Quản lý tài khoản, trạng thái và phân quyền.',
    AdminSection.shops => 'Theo dõi cửa hàng và hoạt động kinh doanh.',
    AdminSection.categories => 'Sắp xếp hệ thống danh mục sản phẩm.',
    AdminSection.shippingCompanies => 'Quản lý các đối tác giao nhận trên sàn.',
    AdminSection.orders =>
      'Giám sát đơn hàng và xử lý các tình huống khẩn cấp.',
  };

  List<String> get columns => switch (this) {
    AdminSection.users => ['Người dùng', 'Email', 'Vai trò'],
    AdminSection.shops => ['Cửa hàng', 'Chủ sở hữu', 'Địa chỉ'],
    AdminSection.categories => ['Danh mục', 'Slug', 'Danh mục cha', 'Thứ tự'],
    AdminSection.shippingCompanies => [
      'Đơn vị vận chuyển',
      'Mã hãng',
      'Phí cơ bản',
    ],
    AdminSection.orders => ['Đơn hàng', 'Cửa hàng', 'Thanh toán', 'Tổng tiền'],
  };

  List<String> values(AdminRecord record) {
    final r = record.raw;
    String text(Object? v) =>
        v == null || v.toString().isEmpty ? '—' : v.toString();
    return switch (this) {
      AdminSection.users => [
        record.name,
        text(r['email']),
        adminRoleLabel(record.role),
      ],
      AdminSection.shops => [
        record.name,
        text(r['ownerName'] ?? r['userId']),
        text(r['address']),
      ],
      AdminSection.categories => [
        record.name,
        record.slug,
        text(r['parentId']),
        '${record.displayOrder}',
      ],
      AdminSection.shippingCompanies => [
        record.name,
        record.code,
        r['baseFee'] is num ? formatVnd(r['baseFee']) : '—',
      ],
      AdminSection.orders => [
        'Đơn #${record.id}',
        text(r['shopName'] ?? r['shopId']),
        text(r['paymentMethod']),
        r['grandTotal'] is num ? formatVnd(r['grandTotal']) : '—',
      ],
    };
  }
}
