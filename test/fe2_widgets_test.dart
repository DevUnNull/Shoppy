import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoppy/core/theme/app_theme.dart';
import 'package:shoppy/features/auth/models/user.dart';
import 'package:shoppy/features/auth/providers/auth_provider.dart';
import 'package:shoppy/features/cart/providers/cart_provider.dart';
import 'package:shoppy/features/catalog/providers/catalog_providers.dart';
import 'package:shoppy/features/checkout/screens/checkout_screen.dart';
import 'package:shoppy/features/notifications/models/notification_item.dart';
import 'package:shoppy/features/notifications/providers/notification_providers.dart';
import 'package:shoppy/features/notifications/screens/notifications_screen.dart';
import 'package:shoppy/features/orders/models/order.dart';
import 'package:shoppy/features/orders/providers/order_providers.dart';
import 'package:shoppy/features/orders/screens/my_orders_screen.dart';
import 'package:shoppy/features/orders/screens/order_detail_screen.dart';
import 'package:shoppy/features/profile/screens/profile_screen.dart';
import 'package:shoppy/features/shop/providers/shop_providers.dart';
import 'package:shoppy/features/wallet/models/wallet_transaction.dart';
import 'package:shoppy/features/wallet/providers/wallet_providers.dart';
import 'package:shoppy/features/wallet/screens/wallet_screen.dart';

import 'helpers/customer_fakes.dart';
import 'helpers/fe2_fakes.dart';

const customer = User(
  id: 1,
  email: 'a@b.com',
  fullName: 'Nguyễn Văn A',
  phone: '0912345678',
  role: UserRole.customer,
  balance: 100000,
);

/// Đăng nhập sẵn (token + user trong bộ nhớ máy) và có địa chỉ đã lưu.
void loggedIn({bool withAddress = true}) {
  SharedPreferences.setMockInitialValues({
    'shoppy.auth.token': 'jwt',
    'shoppy.auth.user': jsonEncode(customer.toJson()),
    if (withAddress)
      'shoppy.address.1': jsonEncode({
        'name': 'Nguyễn Văn A',
        'phone': '0912345678',
        'address': '123 Nguyễn Huệ, Quận 1, TP.HCM',
      }),
  });
}

Future<ProviderContainer> pumpApp(
  WidgetTester tester,
  Widget home, {
  required FakeOrderService orders,
  FakeWalletService? wallet,
  FakeNotificationService? notifications,
  Size size = const Size(1300, 1800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      authServiceProvider.overrideWithValue(FakeAuthService(profile: customer)),
      orderServiceProvider.overrideWithValue(orders),
      walletServiceProvider.overrideWithValue(wallet ?? FakeWalletService()),
      notificationServiceProvider.overrideWithValue(
        notifications ?? FakeNotificationService(const []),
      ),
      shopServiceProvider.overrideWithValue(FakeShopService()),
      productServiceProvider.overrideWithValue(FakeProductService()),
      categoryServiceProvider.overrideWithValue(FakeCategoryService()),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.light(), home: home),
    ),
  );
  // Khôi phục phiên + tải dữ liệu.
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  return container;
}

Future<void> flushToasts(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 5));

/// Chấm "chưa đọc" trên item thông báo.
final unreadDots = find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.label == 'Chưa đọc',
);

/// Ô tìm kiếm đơn hàng (header cũng có một TextField tìm sản phẩm).
final orderSearch = find.byWidgetPredicate(
  (w) =>
      w is TextField && (w.decoration?.hintText ?? '').contains('ID đơn hàng'),
);

void main() {
  setUp(loggedIn);

  testWidgets('Checkout: 2 shop -> 2 đơn, xoá khỏi giỏ, chuyển sang Đơn mua', (
    tester,
  ) async {
    final orders = FakeOrderService();
    final items = [
      CartItem(
        product: product(1, name: 'Giày A'),
        variant: variant(11, 'Mặc định', price: 100000),
        quantity: 2,
      ),
      CartItem(
        product: product(2, name: 'Áo B', shopId: 9),
        variant: variant(22, 'Đen', price: 50000),
        quantity: 1,
      ),
    ];
    final container = await pumpApp(
      tester,
      CheckoutScreen(items: items),
      orders: orders,
    );
    for (final i in items) {
      container
          .read(cartProvider.notifier)
          .add(i.product, i.variant, i.quantity, maxStock: 9);
    }
    await tester.pump();

    expect(find.text('Địa Chỉ Nhận Hàng'), findsOneWidget);
    expect(find.textContaining('123 Nguyễn Huệ'), findsOneWidget);
    expect(find.text('Shop 2'), findsOneWidget);
    expect(find.text('Shop 9'), findsOneWidget);
    // 250.000 hàng + 2 x 30.000 ship (GHN chọn sẵn)
    expect(find.text('₫310.000'), findsOneWidget);

    // Chọn GHTK cho shop thứ hai -> tổng giảm 5.000
    await tester.tap(find.text('Giao Hàng Tiết Kiệm').last);
    await tester.pump();
    expect(find.text('₫305.000'), findsOneWidget);

    // Ví không đủ -> cảnh báo + link nạp nhanh
    await tester.tap(find.text('Ví Shoppy'));
    await tester.pump();
    expect(find.textContaining('Số dư không đủ'), findsOneWidget);
    expect(find.text('Nạp tiền ngay'), findsOneWidget);

    await tester.tap(find.text('Thanh toán khi nhận hàng'));
    await tester.pump();
    await tester.tap(find.text('Đặt hàng'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(orders.created.length, 2);
    expect(orders.created.first.toJson()['paymentMethod'], 'COD');
    expect(orders.created.last.shippingCompanyId, 2);
    expect(container.read(cartProvider), isEmpty);
    expect(find.text('Chưa có đơn hàng'), findsOneWidget);
    await flushToasts(tester);
  });

  testWidgets('Checkout: chưa có địa chỉ thì mở form địa chỉ', (tester) async {
    loggedIn(withAddress: false);
    final orders = FakeOrderService();
    await pumpApp(
      tester,
      CheckoutScreen(
        items: [
          CartItem(
            product: product(1),
            variant: variant(11, 'Mặc định'),
            quantity: 1,
          ),
        ],
      ),
      orders: orders,
    );
    await tester.tap(find.text('Đặt hàng'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Địa chỉ cụ thể'), findsOneWidget);
    expect(orders.created, isEmpty);
    await flushToasts(tester);
  });

  testWidgets('Checkout mobile 390px không tràn layout', (tester) async {
    await pumpApp(
      tester,
      CheckoutScreen(
        items: [
          CartItem(
            product: product(1),
            variant: variant(11, 'Đen / XL'),
            quantity: 3,
          ),
        ],
      ),
      orders: FakeOrderService(),
      size: const Size(390, 1600),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Đặt hàng'), findsOneWidget);
  });

  testWidgets('Đơn mua: tab đếm, tìm kiếm, hủy đơn có chọn lý do', (
    tester,
  ) async {
    final orders = FakeOrderService(
      orders: [
        order(1, status: 'PENDING', shopName: 'Shop Alpha'),
        order(2, status: 'SHIPPING', shopName: 'Shop Beta'),
        order(3, status: 'DELIVERED'),
      ],
    );
    await pumpApp(tester, const MyOrdersScreen(), orders: orders);

    expect(find.text('Chờ xác nhận (1)'), findsOneWidget);
    expect(find.text('Đang giao (1)'), findsOneWidget);
    expect(find.text('ĐANG GIAO'), findsOneWidget);

    await tester.enterText(orderSearch, 'beta');
    await tester.pump();
    expect(find.text('Shop Alpha'), findsNothing);
    expect(find.text('Shop Beta'), findsOneWidget);
    await tester.enterText(orderSearch, '');
    await tester.pump();

    await tester.tap(find.text('Hủy đơn hàng'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('HỦY ĐƠN HÀNG'));
    await tester.pump();
    expect(find.text('Vui lòng chọn lý do hủy đơn'), findsOneWidget);

    await tester.tap(find.text('Tôi không có nhu cầu mua nữa'));
    await tester.pump();
    await tester.tap(find.text('HỦY ĐƠN HÀNG'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(orders.cancelled.single, (1, 'Tôi không có nhu cầu mua nữa'));
    await flushToasts(tester);
  });

  testWidgets('Đơn mua rỗng hiển thị Empty State', (tester) async {
    await pumpApp(tester, const MyOrdersScreen(), orders: FakeOrderService());
    expect(find.text('Chưa có đơn hàng'), findsOneWidget);
    expect(find.text('Mua sắm ngay'), findsOneWidget);
  });

  testWidgets(
    'Chi tiết đơn: stepper 4 mốc, mã vận đơn, timeline, nút hủy bị khoá',
    (tester) async {
      final orders = FakeOrderService(
        orders: [Order.fromJson(realOrderJson())],
      );
      await pumpApp(
        tester,
        const OrderDetailScreen(orderId: 6),
        orders: orders,
      );

      expect(find.text('MÃ ĐƠN HÀNG. #6'), findsOneWidget);
      for (final m in TrackingMilestone.values) {
        expect(find.text(m.label), findsWidgets);
      }
      expect(
        find.textContaining('GHN261107000066EE4', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.text('Shipper đã nhận đơn và bắt đầu giao hàng'),
        findsOneWidget,
      );
      expect(find.text('₫930.000'), findsWidgets);
      final cancel = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Hủy đơn hàng'),
      );
      expect(cancel.onPressed, isNull, reason: 'đơn đã giao không được hủy');
    },
  );

  testWidgets('Ví: số dư, ẩn/hiện, lọc giao dịch, nạp tiền có xác nhận', (
    tester,
  ) async {
    final wallet = FakeWalletService(
      transactions: [
        WalletTransaction.fromJson({
          'id': 1,
          'type': 'DEPOSIT',
          'amount': 200000,
        }),
        WalletTransaction.fromJson({
          'id': 2,
          'type': 'PAYMENT',
          'amount': 50000,
          'referenceId': 6,
        }),
      ],
    );
    await pumpApp(
      tester,
      const WalletScreen(),
      orders: FakeOrderService(),
      wallet: wallet,
    );

    expect(find.text('₫100.000'), findsOneWidget);
    expect(find.text('+₫200.000'), findsOneWidget);
    expect(find.text('-₫50.000'), findsOneWidget);

    await tester.tap(find.byTooltip('Ẩn số dư'));
    await tester.pump();
    expect(find.text('₫ ******'), findsOneWidget);

    await tester.tap(find.text('Tiền ra (-)'));
    await tester.pump();
    expect(find.text('+₫200.000'), findsNothing);

    await tester.tap(find.text('Nạp tiền ví'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextFormField), '5000');
    await tester.tap(find.text('NẠP TIỀN'));
    await tester.pump();
    expect(find.text('Số tiền nạp tối thiểu là ₫10.000'), findsOneWidget);

    await tester.tap(find.text('100.000đ'));
    await tester.pump();
    await tester.tap(find.text('NẠP TIỀN'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Xác nhận nạp tiền'), findsOneWidget);
    await tester.tap(find.text('NẠP TIỀN').last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(wallet.deposits, [100000]);
    await flushToasts(tester);
  });

  testWidgets('Thông báo: chấm chưa đọc, đánh dấu tất cả đã đọc', (
    tester,
  ) async {
    final service = FakeNotificationService([
      NotificationItem.fromJson({
        'id': 1,
        'type': 'ORDER_STATUS_UPDATED',
        'title': 'Đơn hàng đang giao',
        'message': 'Đơn #6 đang trên đường giao',
        'referenceId': 6,
        'read': false,
      }),
      NotificationItem.fromJson({
        'id': 2,
        'type': 'PROMOTION',
        'title': 'Siêu sale 11.11',
        'message': 'Giảm đến 50%',
        'read': true,
      }),
    ]);
    await pumpApp(
      tester,
      const NotificationsScreen(),
      orders: FakeOrderService(),
      notifications: service,
    );
    expect(unreadDots, findsOneWidget);
    expect(find.text('Cập nhật đơn hàng (1)'), findsOneWidget);

    await tester.tap(find.text('Khuyến mãi'));
    await tester.pump();
    expect(find.text('Đơn hàng đang giao'), findsNothing);
    expect(find.text('Siêu sale 11.11'), findsOneWidget);

    await tester.tap(find.text('Đánh dấu tất cả đã đọc'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(service.readAllCalls, 1);
    expect(unreadDots, findsNothing);
    await flushToasts(tester);
  });

  testWidgets('Đổi mật khẩu: validate độ mạnh và xác nhận khớp', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const ProfileScreen(changePassword: true),
      orders: FakeOrderService(),
    );
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'old123');
    await tester.enterText(fields.at(1), 'abcdefgh');
    await tester.enterText(fields.at(2), 'khac');
    await tester.tap(find.text('Xác nhận'));
    await tester.pump();
    expect(find.text('Mật khẩu cần có cả chữ và số'), findsOneWidget);
    expect(find.text('Mật khẩu xác nhận không khớp'), findsOneWidget);
  });
}
