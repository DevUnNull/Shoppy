import 'package:shoppy/features/shipper_orders/models/shipper_order.dart';
import 'package:shoppy/features/shipper_orders/repositories/shipper_order_repository.dart';
import 'package:shoppy/features/shipper_orders/services/shipper_order_service.dart';

const pickupUrl = 'https://maps.app.goo.gl/Wc5NU7xtg4hDMQqb7';

Map<String, dynamic> shipperOrderJson({
  int id = 6,
  String status = 'READY_TO_SHIP',
  String payment = 'COD',
  int? driverId,
  int companyId = 1,
  bool summary = false,
}) => {
  'id': id,
  'createdAt': '2026-11-07T17:38:29.144067',
  'grandTotal': 930000.0,
  'totalAmount': 900000.0,
  'shippingFee': 30000.0,
  'paymentMethod': payment,
  'status': status,
  'trackingNumber': 'GHN261107000066EE4',
  'shippingAddress': '123 Đường Nguyễn Huệ, Quận 1, TP.HCM',
  if (summary) ...{
    'shopId': 3,
    'itemCount': 1,
  } else ...{
    'recipientName': 'Nguyễn Văn A',
    'recipientPhone': '0912345678',
    'shipperId': driverId,
    'shippingCompanyId': companyId,
    'shopAddress': pickupUrl,
    'note': 'Giao giờ hành chính',
    'items': [
      {
        'productNameSnapshot': 'Giày sneaker trắng',
        'variantNameSnapshot': 'Mặc định',
        'quantity': 2,
        'priceSnapshot': 450000.0,
        'subtotal': 900000.0,
      },
    ],
    'trackings': [
      {
        'description': status == 'DELIVERED'
            ? 'Giao hàng thành công'
            : status == 'SHIPPING'
            ? 'Shipper đã lấy hàng và đang đi giao'
            : 'Hàng đã đóng gói xong',
        'createdAt': '2026-11-07T19:11:44.644636',
        'status': 'READY_FOR_PICKUP',
      },
    ],
  },
};

ShipperOrder makeShipperOrder({
  int id = 6,
  String status = 'READY_TO_SHIP',
  String payment = 'COD',
  int? driverId,
  int companyId = 1,
}) => ShipperOrder.fromJson(
  shipperOrderJson(
    id: id,
    status: status,
    payment: payment,
    driverId: driverId,
    companyId: companyId,
  ),
);

class FakeShipperBackend {
  FakeShipperBackend(List<ShipperOrder> orders)
    : orders = {for (final order in orders) order.id: order};
  final Map<int, ShipperOrder> orders;
  final Map<int, double> codBalances = {};
  final List<Map<String, dynamic>> collections = [];

  // Mô phỏng BE: quyền và trạng thái được kiểm tra trước khi ghi nhận COD.
  void completeDelivery(int id, int driverId, int companyId) {
    final order = orders[id];
    if (order == null ||
        order.shipperId != driverId ||
        order.shippingCompanyId != companyId) {
      throw const ShipperOrderException(
        'Không được xác nhận đơn của tài xế khác',
        statusCode: 403,
      );
    }
    if (order.status != 'SHIPPING') {
      throw const ShipperOrderException(
        'Đơn không còn đang giao',
        statusCode: 409,
      );
    }
    orders[id] = makeShipperOrder(
      id: id,
      status: 'DELIVERED',
      payment: order.paymentMethod,
      driverId: driverId,
      companyId: companyId,
    );
    if (order.paymentMethod == 'COD') {
      codBalances[driverId] = (codBalances[driverId] ?? 0) + order.grandTotal;
      collections.add({
        'orderId': id,
        'driverId': driverId,
        'amount': order.grandTotal,
        'type': 'COLLECTION',
      });
    }
  }
}

class FakeShipperOrderRepository extends ShipperOrderRepository {
  FakeShipperOrderRepository({
    required this.backend,
    this.companyId = 1,
    this.driverId = 100,
  }) : super(ShipperOrderService(token: 'test-shipper'));
  final FakeShipperBackend backend;
  final int companyId, driverId;
  final List<int> detailCalls = [], assignCalls = [];
  int availableCalls = 0, deliveriesCalls = 0;
  Future<List<ShipperOrder>> Function()? onAvailable, onDeliveries;
  Future<ShipperOrder> Function(int)? onDetail;
  Future<void> Function(int)? onAssign;
  final List<int> deliveredCalls = [];
  final List<String> deliveryStatuses = [];
  int balanceCalls = 0, transactionsCalls = 0;
  Future<void> Function(int)? onDelivered;

  @override
  Future<List<ShipperOrder>> getAvailableOrders() async {
    availableCalls++;
    if (onAvailable != null) return onAvailable!();
    return backend.orders.values
        .where(
          (order) => order.shippingCompanyId == companyId && order.canAssign,
        )
        .toList();
  }

  @override
  Future<List<ShipperOrder>> getMyDeliveries({
    String status = 'SHIPPING',
  }) async {
    deliveriesCalls++;
    deliveryStatuses.add(status);
    if (onDeliveries != null) return onDeliveries!();
    return backend.orders.values
        .where(
          (order) =>
              order.shippingCompanyId == companyId &&
              order.shipperId == driverId &&
              order.status == status,
        )
        .toList();
  }

  @override
  Future<ShipperOrder> getOrderDetail(int id) async {
    detailCalls.add(id);
    if (onDetail != null) return onDetail!(id);
    final order = backend.orders[id];
    if (order == null) {
      throw const ShipperOrderException('Không tìm thấy đơn', statusCode: 404);
    }
    if (order.shippingCompanyId != companyId) {
      throw const ShipperOrderException(
        'Không có quyền xem đơn khác hãng',
        statusCode: 403,
      );
    }
    return order;
  }

  @override
  Future<void> assign(int id) async {
    assignCalls.add(id);
    if (onAssign != null) return onAssign!(id);
    final order = backend.orders[id];
    if (order == null || order.shippingCompanyId != companyId) {
      throw const ShipperOrderException(
        'Không có quyền nhận đơn khác hãng',
        statusCode: 403,
      );
    }
    if (!order.canAssign) {
      throw const ShipperOrderException(
        'Đơn đã có tài xế nhận hoặc đã đổi trạng thái',
        statusCode: 409,
      );
    }
    backend.orders[id] = makeShipperOrder(
      id: id,
      status: 'SHIPPING',
      driverId: driverId,
      companyId: companyId,
      payment: order.paymentMethod,
    );
  }

  @override
  Future<void> delivered(int id) async {
    deliveredCalls.add(id);
    if (onDelivered != null) return onDelivered!(id);
    backend.completeDelivery(id, driverId, companyId);
  }

  @override
  Future<dynamic> getCodBalance() async {
    balanceCalls++;
    return {'currentBalance': backend.codBalances[driverId] ?? 0};
  }

  @override
  Future<dynamic> getCodTransactions() async {
    transactionsCalls++;
    return backend.collections
        .where((item) => item['driverId'] == driverId)
        .toList();
  }
}
