import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoppy/core/network/api_client.dart';
import 'package:shoppy/core/network/api_exception.dart';
import 'package:shoppy/core/theme/app_theme.dart';
import 'package:shoppy/core/utils/formatters.dart';
import 'package:shoppy/features/admin/models/admin_models.dart';
import 'package:shoppy/features/admin/providers/admin_providers.dart';
import 'package:shoppy/features/admin/screens/admin_hub_screen.dart';
import 'package:shoppy/features/admin/services/admin_service.dart';
import 'package:shoppy/features/auth/models/user.dart';
import 'package:shoppy/features/auth/providers/auth_provider.dart';

class _Session extends AuthNotifier {
  _Session(this.role);
  final UserRole role;

  @override
  AuthState build() => AuthState.authenticated(
    User(
      id: 99,
      email: 'admin@example.test',
      fullName: 'Quản trị kiểm thử',
      role: role,
    ),
    'test-admin-token',
  );
}

class _Service extends AdminService {
  _Service() : super(ApiClient(readToken: () => null));

  final lists = <(AdminSection, AdminQuery)>[];
  final details = <(AdminSection, int)>[];
  final writes = <String>[];
  bool rejectDelete = false;
  bool longLabels = false;
  Completer<void>? cancelGate;
  String userRole = 'CUSTOMER';
  String userStatus = 'ACTIVE';
  String orderStatus = 'SHIPPING';

  Map<String, dynamic> row(AdminSection section) => {
    'id': 101,
    'name': longLabels
        ? 'Tên thực thể quản trị rất dài cần tự xuống dòng trên điện thoại nhỏ'
        : '${section.title} kiểm thử',
    'fullName': section == AdminSection.users
        ? longLabels
              ? 'Nguyễn Thị Hoàng Minh Anh người dùng có họ tên rất dài để kiểm tra'
              : 'Người dùng mẫu'
        : null,
    'email': 'user@example.test',
    'role': userRole,
    'status': section == AdminSection.orders
        ? orderStatus
        : section == AdminSection.users
        ? userStatus
        : 'ACTIVE',
    'phone': '0900000000',
    'userId': 17,
    'address': longLabels
        ? 'Địa chỉ cửa hàng rất dài bao gồm số nhà, đường, phường và thành phố'
        : 'Địa chỉ mẫu',
    'slug': 'danh-muc-mau',
    'displayOrder': 1,
    'code': 'GHN',
    'baseFee': 30000,
    'shopId': 7,
    'grandTotal': 250000,
    'paymentMethod': 'WALLET',
  };

  @override
  Future<AdminPage> list(
    AdminSection section, {
    String search = '',
    String status = '',
    String role = '',
    int page = 0,
    int size = 10,
  }) async {
    lists.add((
      section,
      AdminQuery(
        search: search,
        status: status,
        role: role,
        page: page,
        size: size,
      ),
    ));
    return AdminPage(
      items: [AdminRecord(row(section))],
      page: page,
      size: size,
      totalElements: 21,
      totalPages: 3,
      hasNext: page < 2,
    );
  }

  @override
  Future<AdminRecord> detail(AdminSection section, int id) async {
    details.add((section, id));
    return AdminRecord({
      ...row(section),
      'balance': 123456,
      'shop': {'id': 7, 'name': 'Shop liên kết mẫu'},
      'shippingCompany': {'id': 8, 'name': 'Hãng vận chuyển mẫu'},
      'vehicleType': 'Xe máy',
      'licensePlate': '59-A1 12345',
      'owner': {
        'id': 17,
        'fullName': 'Chủ shop mẫu',
        'email': 'owner@example.test',
        'phone': '0911111111',
      },
      'totalProductsCount': 37,
      'totalOrdersCount': 129,
    });
  }

  @override
  Future<void> setStatus(AdminSection section, int id, String status) async {
    writes.add('status:${section.name}:$id:$status');
    if (section == AdminSection.users) userStatus = status;
  }

  @override
  Future<void> setUserRole(int id, String role) async {
    writes.add('role:$id:$role');
    userRole = role;
  }

  @override
  Future<void> delete(AdminSection section, int id) async {
    writes.add('delete:${section.name}:$id');
    if (rejectDelete) {
      throw const ApiException('Danh mục đang có sản phẩm kinh doanh');
    }
  }

  @override
  Future<void> cancelOrder(int id, String reason) async {
    writes.add('cancel:$id:$reason');
    if (cancelGate != null) await cancelGate!.future;
    orderStatus = 'CANCELLED';
  }
}

Future<void> _open(
  WidgetTester tester,
  _Service service, {
  Size size = const Size(1600, 1100),
  UserRole role = UserRole.admin,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(service.client.close);
  addTearDown(() async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        authProvider.overrideWith(() => _Session(role)),
        adminServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: const AdminHubScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _navigate(WidgetTester tester, AdminSection section) async {
  if (tester.view.physicalSize.width < 1050) {
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(ValueKey('admin-nav-${section.name}')));
  await tester.pumpAndSettle();
}

Future<void> _action(WidgetTester tester, String text) async {
  final action = find.byKey(const ValueKey('admin-actions-101'));
  await tester.ensureVisible(action);
  await tester.tap(action);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Desktop mở đủ năm phân hệ với danh sách riêng', (tester) async {
    final service = _Service();
    await _open(tester, service);
    final firstPageButton = find.ancestor(
      of: find.text('1'),
      matching: find.byType(TextButton),
    );
    expect(tester.getSize(firstPageButton), const Size(36, 36));
    for (final section in AdminSection.values.skip(1)) {
      await _navigate(tester, section);
      expect(find.byKey(const ValueKey('admin-actions-101')), findsOneWidget);
    }
    expect(service.lists.map((call) => call.$1), AdminSection.values);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Bộ lọc gửi server và luôn đặt lại về trang 0', (tester) async {
    final service = _Service();
    await _open(tester, service);
    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();
    expect(service.lists.last.$2.page, 2);

    await tester.tap(find.byKey(const ValueKey('admin-role-')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Người bán').last);
    await tester.pumpAndSettle();
    expect(service.lists.last.$2.role, 'SELLER');
    expect(service.lists.last.$2.page, 0);

    await tester.tap(find.byKey(const ValueKey('admin-status-')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đã khóa').last);
    await tester.pumpAndSettle();
    expect(service.lists.last.$2.status, 'BLOCKED');
    expect(service.lists.last.$2.role, 'SELLER');

    await tester.enterText(
      find.byKey(const ValueKey('admin-search')),
      '  minh  ',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(service.lists.last.$2.search, 'minh');
    expect(service.lists.last.$2.page, 0);

    await tester.tap(find.text('Đặt lại'));
    await tester.pumpAndSettle();
    final reset = service.lists.last.$2;
    expect(
      (reset.search, reset.role, reset.status, reset.page),
      ('', '', '', 0),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Chi tiết user đúng ID, có ví, shop và thông tin xe', (
    tester,
  ) async {
    final service = _Service();
    await _open(tester, service);
    await _action(tester, 'Xem chi tiết');
    expect(service.details, [(AdminSection.users, 101)]);
    expect(find.text('Chi tiết người dùng #101'), findsOneWidget);
    expect(find.text(formatVnd(123456)), findsOneWidget);
    expect(find.text('Shop liên kết mẫu'), findsOneWidget);
    expect(find.text('Hãng vận chuyển mẫu'), findsOneWidget);
    expect(find.text('59-A1 12345'), findsOneWidget);
    await tester.tap(find.text('Đóng'));
    await tester.pumpAndSettle();
    expect(service.writes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Khóa/đổi role cần xác nhận, Trở lại không ghi API', (
    tester,
  ) async {
    final service = _Service();
    await _open(tester, service);
    await _action(tester, 'Khóa tài khoản');
    expect(find.text('Khóa tài khoản?'), findsOneWidget);
    expect(service.writes, isEmpty);
    await tester.tap(find.text('TRỞ LẠI'));
    await tester.pumpAndSettle();
    expect(service.writes, isEmpty);

    await _action(tester, 'Đổi vai trò: Người bán');
    await tester.tap(find.text('TRỞ LẠI'));
    await tester.pumpAndSettle();
    expect(service.writes, isEmpty);

    await _action(tester, 'Đổi vai trò: Người bán');
    await tester.tap(find.text('XÁC NHẬN'));
    await tester.pumpAndSettle();
    expect(service.writes, ['role:101:SELLER']);
    expect(service.userRole, 'SELLER');

    await _action(tester, 'Khóa tài khoản');
    await tester.tap(find.text('XÁC NHẬN'));
    await tester.pumpAndSettle();
    expect(service.writes.last, 'status:users:101:BLOCKED');
    expect(service.userStatus, 'BLOCKED');
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Xóa danh mục bị backend từ chối giữ bản ghi và báo lý do', (
    tester,
  ) async {
    final service = _Service()..rejectDelete = true;
    await _open(tester, service);
    await _navigate(tester, AdminSection.categories);
    await _action(tester, 'Xóa');
    await tester.tap(find.text('XÁC NHẬN'));
    await tester.pumpAndSettle();
    expect(service.writes, ['delete:categories:101']);
    expect(find.byKey(const ValueKey('admin-actions-101')), findsOneWidget);
    expect(find.text('Danh mục đang có sản phẩm kinh doanh'), findsWidgets);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Admin hủy đơn SHIPPING với lý do, khóa thao tác khi đang gửi', (
    tester,
  ) async {
    final service = _Service()..cancelGate = Completer<void>();
    await _open(tester, service);
    await _navigate(tester, AdminSection.orders);
    await _action(tester, 'Hủy đơn khẩn cấp');
    expect(find.text('Hủy khẩn cấp đơn #101?'), findsOneWidget);
    await tester.tap(find.text('Xác nhận hủy đơn'));
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập lý do hủy đơn'), findsOneWidget);
    expect(service.writes, isEmpty);
    final reasonField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(reasonField, '  Nghi vấn giao dịch gian lận  ');
    await tester.tap(find.text('Xác nhận hủy đơn'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(service.writes, ['cancel:101:Nghi vấn giao dịch gian lận']);
    final menu = tester.widget<PopupMenuButton<String>>(
      find.byKey(const ValueKey('admin-actions-101')),
    );
    expect(menu.enabled, isFalse);
    final nav = tester.widget<ListTile>(
      find.byKey(const ValueKey('admin-nav-users')),
    );
    expect(nav.onTap, isNull);
    service.cancelGate!.complete();
    await tester.pumpAndSettle();
    expect(service.writes.length, 1);
    expect(find.text('Đã hủy'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Chi tiết shop dùng đúng totalProductsCount/totalOrdersCount', (
    tester,
  ) async {
    final service = _Service();
    await _open(tester, service);
    await _navigate(tester, AdminSection.shops);
    await _action(tester, 'Xem chi tiết');
    expect(service.details, [(AdminSection.shops, 101)]);
    expect(find.text('Chủ shop mẫu'), findsOneWidget);
    expect(find.text('owner@example.test'), findsOneWidget);
    expect(find.text('Tổng sản phẩm'), findsOneWidget);
    expect(find.text('37'), findsOneWidget);
    expect(find.text('Tổng đơn đã bán'), findsOneWidget);
    expect(find.text('129'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mobile 360px: tên dài tự xuống dòng và điều hướng bằng drawer', (
    tester,
  ) async {
    final service = _Service()..longLabels = true;
    await _open(tester, service, size: const Size(360, 800));
    expect(find.byType(DataTable), findsNothing);
    expect(find.byKey(const ValueKey('admin-row-101')), findsOneWidget);
    expect(tester.takeException(), isNull);
    for (final section in AdminSection.values.skip(1)) {
      await _navigate(tester, section);
      expect(find.byKey(const ValueKey('admin-row-101')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: section.name);
    }
    expect(service.lists.map((call) => call.$1), AdminSection.values);
  });

  testWidgets('Landscape 720x360: drawer cuộn được tới phân hệ đơn hàng', (
    tester,
  ) async {
    final service = _Service()..longLabels = true;
    await _open(tester, service, size: const Size(720, 360));
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    final orders = find.byKey(const ValueKey('admin-nav-orders'));
    await tester.scrollUntilVisible(
      orders,
      180,
      scrollable: find.descendant(
        of: find.byType(Drawer),
        matching: find.byType(Scrollable),
      ).first,
    );
    await tester.tap(orders);
    await tester.pumpAndSettle();
    expect(service.lists.last.$1, AdminSection.orders);
    expect(find.byKey(const ValueKey('admin-row-101')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final role in [UserRole.customer, UserRole.seller, UserRole.shipper]) {
    testWidgets('Chặn ${role.name} trước khi gọi API quản trị', (tester) async {
      final service = _Service();
      await _open(tester, service, role: role);
      expect(find.text('Khu vực dành cho quản trị viên'), findsOneWidget);
      expect(service.lists, isEmpty);
      expect(service.details, isEmpty);
      expect(service.writes, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
}
