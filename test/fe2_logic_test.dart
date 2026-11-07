import 'package:flutter_test/flutter_test.dart';
import 'package:shoppy/features/cart/providers/cart_provider.dart';
import 'package:shoppy/features/checkout/models/checkout_models.dart';
import 'package:shoppy/features/checkout/providers/checkout_controller.dart';
import 'package:shoppy/features/notifications/models/notification_item.dart';
import 'package:shoppy/features/orders/models/order.dart';
import 'package:shoppy/features/orders/providers/order_providers.dart';
import 'package:shoppy/features/profile/widgets/password_strength.dart';
import 'package:shoppy/features/wallet/models/wallet_transaction.dart';
import 'package:shoppy/features/wallet/widgets/deposit_dialog.dart';

import 'helpers/customer_fakes.dart';
import 'helpers/fe2_fakes.dart';

const address = DeliveryAddress(
  name: 'Nguyễn Văn A',
  phone: '0912345678',
  address: '123 Nguyễn Huệ, Quận 1, TP.HCM',
);

List<ShopGroup> twoShops() => ShopGroup.fromItems([
  CartItem(
    product: product(1, price: 100000),
    variant: variant(11, 'Mặc định', price: 100000),
    quantity: 2,
  ),
  CartItem(
    product: product(2, shopId: 9, price: 50000),
    variant: variant(22, 'Đen', price: 50000),
    quantity: 1,
  ),
]);

void main() {
  group('Order từ JSON thật (/orders/6)', () {
    test('parse đầy đủ, tracking đủ 4 mốc', () {
      final o = Order.fromJson(realOrderJson());
      expect(o.status, OrderStatus.delivered);
      expect(o.items.single.productName, 'Giày sneaker trắng');
      expect(
        o.items.single.hasVariantLabel,
        isFalse,
        reason: '"Mặc định" ẩn đi',
      );
      expect(o.grandTotal, 930000);
      expect(o.paymentMethod, PaymentMethod.cod);
      expect(o.reachedMilestone, 3);
      expect(o.timeline.first.status, 'DELIVERED', reason: 'mới nhất lên đầu');
      expect(
        o.milestoneTime(TrackingMilestone.waitingPickup),
        DateTime.parse('2026-11-07T19:11:44.644636'),
      );
    });

    test('đơn đang giao dừng ở mốc 3, đơn hủy là -1', () {
      expect(
        Order.fromJson(realOrderJson(status: 'SHIPPING')).reachedMilestone,
        2,
      );
      expect(order(1, status: 'CANCELLED').reachedMilestone, -1);
      expect(OrderStatus.pending.canCancel, isTrue);
      expect(OrderStatus.readyToShip.canCancel, isFalse);
    });
  });

  group('Đơn mua: lọc tab + tìm kiếm', () {
    final orders = [
      order(1, status: 'PENDING', shopName: 'Shoppy Official'),
      order(
        2,
        status: 'READY_TO_SHIP',
        shopName: 'Shop B',
        product: 'Giày sneaker',
      ),
      order(3, status: 'DELIVERED'),
      order(14, status: 'CANCELLED'),
    ];

    test('tab gom đúng trạng thái', () {
      expect(filterOrders(orders, OrderTab.all, '').length, 4);
      expect(filterOrders(orders, OrderTab.toShip, '').map((o) => o.id), [2]);
      expect(filterOrders(orders, OrderTab.cancelled, '').map((o) => o.id), [
        14,
      ]);
    });

    test('tìm theo mã đơn (#), tên shop, tên sản phẩm', () {
      expect(filterOrders(orders, OrderTab.all, '#14').map((o) => o.id), [14]);
      expect(filterOrders(orders, OrderTab.all, 'official').map((o) => o.id), [
        1,
      ]);
      expect(filterOrders(orders, OrderTab.all, 'SNEAKER').map((o) => o.id), [
        2,
      ]);
    });
  });

  group('Checkout', () {
    test('gom nhóm theo shop và tính tổng', () {
      final groups = twoShops();
      expect(groups.length, 2);
      final totals = CheckoutTotals.of(groups, {2: 1, 9: 2}, companies);
      expect(totals.merchandise, 250000);
      expect(totals.shipping, 55000);
      expect(totals.total, 305000);
    });

    test('validate: thiếu địa chỉ, thiếu ĐVVC, ví không đủ', () {
      final groups = twoShops();
      List<(ShopGroup, CreateOrderRequest)> build({
        DeliveryAddress? a = address,
        Map<int, int> ship = const {2: 1, 9: 2},
        PaymentMethod pay = PaymentMethod.cod,
        double balance = 0,
      }) => buildOrderRequests(
        groups: groups,
        address: a,
        shippingByShop: ship,
        notes: const {},
        payment: pay,
        walletBalance: balance,
        total: 305000,
      );

      expect(
        () => build(a: null),
        throwsA(
          isA<CheckoutValidationError>().having(
            (e) => e.field,
            'field',
            'address',
          ),
        ),
      );
      expect(
        () => build(ship: const {2: 1}),
        throwsA(
          isA<CheckoutValidationError>().having(
            (e) => e.field,
            'field',
            'shipping',
          ),
        ),
      );
      expect(
        () => build(pay: PaymentMethod.wallet, balance: 100000),
        throwsA(
          isA<CheckoutValidationError>().having(
            (e) => e.field,
            'field',
            'wallet',
          ),
        ),
      );
      expect(build(pay: PaymentMethod.wallet, balance: 305000).length, 2);
    });

    test('body POST /orders đúng tên trường backend', () {
      final requests = buildOrderRequests(
        groups: twoShops(),
        address: address,
        shippingByShop: const {2: 1, 9: 2},
        notes: const {2: '  Giao giờ hành chính '},
        payment: PaymentMethod.wallet,
        walletBalance: 1e9,
        total: 305000,
      );
      expect(requests.first.$2.toJson(), {
        'shippingCompanyId': 1,
        'recipientName': 'Nguyễn Văn A',
        'recipientPhone': '0912345678',
        'shippingAddress': '123 Nguyễn Huệ, Quận 1, TP.HCM',
        'paymentMethod': 'WALLET',
        'note': 'Giao giờ hành chính',
        'items': [
          {'productVariantId': 11, 'quantity': 2},
        ],
      });
      expect(requests.last.$2.toJson().containsKey('note'), isFalse);
    });

    test('gửi lần lượt, dừng ở đơn lỗi đầu tiên', () async {
      final service = FakeOrderService()..failOnCreate = 1;
      final requests = buildOrderRequests(
        groups: twoShops(),
        address: address,
        shippingByShop: const {2: 1, 9: 2},
        notes: const {},
        payment: PaymentMethod.cod,
        walletBalance: 0,
        total: 0,
      );
      final result = await submitOrders(service, requests);
      expect(result.isComplete, isFalse);
      expect(result.placedGroups.single.shopId, 2);
      expect(service.created.length, 2);
    });
  });

  group('Ví & thông báo', () {
    test('giao dịch: chiều tiền theo type hoặc dấu amount', () {
      final deposit = WalletTransaction.fromJson({
        'id': 1,
        'type': 'DEPOSIT',
        'amount': 50000,
      });
      final pay = WalletTransaction.fromJson({
        'id': 2,
        'type': 'PAYMENT',
        'amount': 930000,
        'referenceId': 6,
      });
      final negative = WalletTransaction.fromJson({'id': 3, 'amount': -20000});
      expect(deposit.isCredit, isTrue);
      expect(deposit.description, 'Nạp tiền vào ví');
      expect(pay.isCredit, isFalse);
      expect(pay.description, 'Thanh toán đơn #6');
      expect(negative.signedAmount, -20000);
      expect(deposit.displayCode, 'GD00000001');
    });

    test('thông báo thật được phân loại "Cập nhật đơn hàng"', () {
      final n = NotificationItem.fromJson({
        'id': 13,
        'type': 'NEW_ORDER_FOR_SELLER',
        'title': 'Có đơn hàng mới',
        'message': 'Shop của bạn vừa nhận được đơn hàng mới #6.',
        'referenceId': 6,
        'createdAt': '2026-11-07T17:38:29.331114',
        'read': false,
      });
      expect(n.category, NotificationCategory.order);
      expect(n.isSellerOrder, isTrue);
      expect(n.markRead().read, isTrue);
    });

    test('nạp ví tối thiểu 10.000đ', () {
      expect(validateDeposit(''), isNotNull);
      expect(validateDeposit('9.000'), contains('tối thiểu'));
      expect(validateDeposit('10.000'), isNull);
      expect(parseAmount('1.000.000'), 1000000);
    });

    test('mật khẩu mới: độ dài, chữ + số, khác mật khẩu cũ, độ mạnh', () {
      expect(validateNewPassword('abc'), isNotNull);
      expect(validateNewPassword('abcdefgh'), contains('chữ và số'));
      expect(
        validateNewPassword('abc12345', current: 'abc12345'),
        contains('khác'),
      );
      expect(validateNewPassword('abc12345'), isNull);
      expect(PasswordStrength.of('abc123'), PasswordStrength.weak);
      expect(PasswordStrength.of('Abc12345'), PasswordStrength.medium);
      expect(PasswordStrength.of('Abc!12345678'), PasswordStrength.strong);
    });
  });
}
