import 'package:shoppy/core/network/page_result.dart';
import 'package:shoppy/features/checkout/models/checkout_models.dart';
import 'package:shoppy/features/checkout/models/shipping_company.dart';
import 'package:shoppy/features/notifications/models/notification_item.dart';
import 'package:shoppy/features/notifications/services/notification_service.dart';
import 'package:shoppy/features/orders/models/order.dart';
import 'package:shoppy/features/orders/services/order_service.dart';
import 'package:shoppy/features/wallet/models/wallet_transaction.dart';
import 'package:shoppy/features/wallet/services/wallet_service.dart';

import 'customer_fakes.dart';

/// JSON thật từ `GET /orders/6` (đã rút gọn trackings giữa).
Map<String, dynamic> realOrderJson({String status = 'DELIVERED'}) => {
  'createdAt': '2026-11-07T17:38:29.144067',
  'customerId': 15,
  'grandTotal': 930000.00,
  'id': 6,
  'items': [
    {
      'id': 7,
      'priceSnapshot': 450000.00,
      'productId': 5,
      'productNameSnapshot': 'Giày sneaker trắng',
      'productVariantId': 6,
      'quantity': 2,
      'subtotal': 900000.00,
      'variantNameSnapshot': 'Mặc định',
    },
  ],
  'note': 'Giao giờ hành chính',
  'paymentMethod': 'COD',
  'recipientName': 'Nguyễn Văn A',
  'recipientPhone': '0912345678',
  'shippingAddress': '123 Đường Nguyễn Huệ, Quận 1, TP.HCM',
  'shippingCompanyId': 1,
  'shippingFee': 30000.00,
  'shopId': 3,
  'status': status,
  'totalAmount': 900000.00,
  'trackingNumber': 'GHN261107000066EE4',
  'trackings': [
    {
      'createdAt': '2026-11-07T17:38:29.231957',
      'description': 'Đơn hàng đã được đặt thành công',
      'id': 13,
      'status': 'ORDER_PLACED',
    },
    {
      'createdAt': '2026-11-07T19:11:44.644636',
      'description': 'Hàng đã đóng gói xong, sẵn sàng cho shipper lấy.',
      'id': 15,
      'status': 'READY_FOR_PICKUP',
    },
    {
      'createdAt': '2026-11-07T22:13:42.477229',
      'description': 'Shipper đã nhận đơn và bắt đầu giao hàng',
      'id': 16,
      'status': 'PICKED_UP',
    },
    if (status == 'DELIVERED')
      {
        'createdAt': '2026-11-07T22:41:47.805882',
        'description': 'Giao hàng thành công',
        'id': 17,
        'status': 'DELIVERED',
      },
  ],
  'updatedAt': '2026-11-07T22:41:48.073015',
};

Order order(
  int id, {
  String status = 'PENDING',
  String? shopName,
  String product = 'Áo',
}) => Order.fromJson({
  'id': id,
  'status': status,
  'shopId': 2,
  'shopName': shopName ?? 'Shop A',
  'paymentMethod': 'COD',
  'shippingFee': 30000,
  'totalAmount': 100000,
  'grandTotal': 130000,
  'items': [
    {
      'id': id * 10,
      'productId': 5,
      'productNameSnapshot': product,
      'priceSnapshot': 100000,
      'quantity': 1,
    },
  ],
});

const companies = [
  ShippingCompany(id: 1, name: 'Giao Hàng Nhanh', code: 'GHN', baseFee: 30000),
  ShippingCompany(
    id: 2,
    name: 'Giao Hàng Tiết Kiệm',
    code: 'GHTK',
    baseFee: 25000,
  ),
];

class FakeOrderService extends OrderService {
  FakeOrderService({this.orders = const [], this.failOnCreate})
    : super(dummyClient());

  final List<Order> orders;

  /// Lần gọi createOrder thứ mấy (0-based) sẽ lỗi.
  int? failOnCreate;
  final created = <CreateOrderRequest>[];
  final cancelled = <(int, String)>[];

  @override
  Future<List<ShippingCompany>> getShippingCompanies() async => companies;

  @override
  Future<Order?> createOrder(CreateOrderRequest request) async {
    if (failOnCreate == created.length) {
      created.add(request);
      throw Exception('Sản phẩm đã hết hàng');
    }
    created.add(request);
    return null;
  }

  @override
  Future<List<Order>> getAllMyOrders() async => orders;

  @override
  Future<Order> getOrder(int id) async => orders.firstWhere((o) => o.id == id);

  @override
  Future<void> cancelOrder(int id, String reason) async =>
      cancelled.add((id, reason));
}

class FakeWalletService extends WalletService {
  FakeWalletService({this.transactions = const []}) : super(dummyClient());

  final List<WalletTransaction> transactions;
  final deposits = <int>[];

  @override
  Future<DepositResult> deposit(int amount) async {
    deposits.add(amount);
    return const DepositResult();
  }

  @override
  Future<PageResult<WalletTransaction>> getTransactions({
    int page = 0,
    int size = 20,
  }) async => PageResult(
    content: transactions,
    page: 0,
    size: size,
    totalElements: transactions.length,
    totalPages: 1,
    hasNext: false,
  );
}

class FakeNotificationService extends NotificationService {
  FakeNotificationService(this.items) : super(dummyClient());

  final List<NotificationItem> items;
  final read = <int>[];
  int readAllCalls = 0;

  @override
  Future<PageResult<NotificationItem>> getNotifications({
    int page = 0,
    int size = 20,
  }) async => PageResult(
    content: items,
    page: 0,
    size: size,
    totalElements: items.length,
    totalPages: 1,
    hasNext: false,
  );

  @override
  Future<int> getUnreadCount() async => items.where((n) => !n.read).length;

  @override
  Future<void> markRead(int id) async => read.add(id);

  @override
  Future<void> markAllRead() async => readAllCalls++;
}
