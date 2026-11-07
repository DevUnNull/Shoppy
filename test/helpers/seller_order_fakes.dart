import 'package:shoppy/features/seller_orders/models/seller_order.dart';
import 'package:shoppy/features/seller_orders/models/seller_orders_page.dart';
import 'package:shoppy/features/seller_orders/repositories/seller_order_repository.dart';
import 'package:shoppy/features/seller_orders/services/seller_order_service.dart';

Map<String, dynamic> orderJson({
  int id = 6,
  String status = 'PENDING',
  String? name,
  String paymentMethod = 'COD',
}) => {
  'id': id,
  'shopId': 3,
  'status': status,
  'grandTotal': 930000.0,
  'totalAmount': 900000.0,
  'shippingFee': 30000.0,
  'paymentMethod': paymentMethod,
  'shippingAddress': '123 Đường Nguyễn Huệ, Quận 1, TP.HCM',
  'createdAt': '2026-11-07T17:38:29.144067',
  'trackingNumber': null,
  'recipientName': name,
};

SellerOrder makeOrder({
  int id = 6,
  String status = 'PENDING',
  String? name,
  String paymentMethod = 'COD',
}) => SellerOrder.fromJson(
  orderJson(id: id, status: status, name: name, paymentMethod: paymentMethod),
);

SellerOrder changedOrder(SellerOrder order, String status) => SellerOrder(
  id: order.id,
  shopId: order.shopId,
  status: status,
  grandTotal: order.grandTotal,
  totalAmount: order.totalAmount,
  shippingFee: order.shippingFee,
  paymentMethod: order.paymentMethod,
  shippingAddress: order.shippingAddress,
  createdAt: order.createdAt,
  recipientName: order.recipientName,
  recipientPhone: order.recipientPhone,
  trackingNumber: order.trackingNumber,
  note: order.note,
  items: order.items,
  trackings: [
    ...order.trackings,
    SellerOrderTracking(
      status: status,
      description: status == 'CANCELLED'
          ? 'Shop đã hủy đơn do hết hàng'
          : 'Shop đã đóng gói xong',
      createdAt: '2026-11-07T18:00:00',
    ),
  ],
);

class FakeSellerOrderRepository extends SellerOrderRepository {
  FakeSellerOrderRepository({this.orders = const []})
    : super(SellerOrderService(token: 'test-only'));

  List<SellerOrder> orders;
  final List<String> listCalls = [];
  final List<int> detailCalls = [];
  Future<SellerOrdersPage> Function(String status, int page)? onGetOrders;
  Future<SellerOrder> Function(int id)? onGetDetail;
  final List<int> readyCalls = [];
  final List<Map<String, dynamic>> cancelCalls = [];
  Future<void> Function(int id)? onReady;
  Future<void> Function(int id, String reason)? onCancel;

  void _changeStatus(int id, String status) {
    final index = orders.indexWhere((order) => order.id == id);
    if (index < 0) {
      throw const SellerOrderException('Không tìm thấy đơn', statusCode: 404);
    }
    if (orders[index].status != 'PROCESSING') {
      throw const SellerOrderException(
        'Đơn không còn ở trạng thái PROCESSING',
        statusCode: 409,
      );
    }
    orders = [...orders];
    orders[index] = changedOrder(orders[index], status);
  }

  @override
  Future<void> readyToShip(int orderId) async {
    readyCalls.add(orderId);
    if (onReady != null) return onReady!(orderId);
    _changeStatus(orderId, 'READY_TO_SHIP');
  }

  @override
  Future<void> cancelOrder(int orderId, String reason) async {
    cancelCalls.add({'id': orderId, 'reason': reason});
    if (onCancel != null) return onCancel!(orderId, reason);
    _changeStatus(orderId, 'CANCELLED');
  }

  @override
  Future<SellerOrdersPage> getOrders({
    required String status,
    required int page,
  }) async {
    listCalls.add('$status:$page');
    if (onGetOrders != null) return onGetOrders!(status, page);
    final filtered = orders.where((order) => order.status == status).toList();
    return SellerOrdersPage(
      orders: filtered.skip(page * 10).take(10).toList(),
      page: page,
      hasNext: (page + 1) * 10 < filtered.length,
    );
  }

  @override
  Future<SellerOrder> getOrderDetail(int orderId) async {
    detailCalls.add(orderId);
    if (onGetDetail != null) return onGetDetail!(orderId);
    return orders.firstWhere((order) => order.id == orderId);
  }
}
