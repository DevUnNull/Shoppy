import '../models/shipper_order.dart';
import '../services/shipper_order_service.dart';

class ShipperOrderRepository {
  ShipperOrderRepository(this.service);
  final ShipperOrderService service;

  Future<List<ShipperOrder>> getAvailableOrders() async {
    final rows = _rows(await service.getAvailableOrders());
    final ids = rows
        .where(
          (row) =>
              row['status'] == 'READY_TO_SHIP' ||
              row['status'] == 'READY_FOR_PICKUP',
        )
        .map((row) => (row['id'] as num).toInt())
        .toSet()
        .toList();
    final details = await _details(ids);
    return details.where((order) => order.canAssign).toList();
  }

  Future<List<ShipperOrder>> getMyDeliveries({
    String status = 'SHIPPING',
  }) async {
    final rows = _rows(await service.getMyDeliveries(status: status));
    // Chỉ cần ID từ danh sách; thông tin còn lại dùng API chi tiết đã có mẫu.
    final ids = rows.map((row) => (row['id'] as num).toInt()).toSet().toList();
    return (await _details(ids))
        .where((order) => order.status == status)
        .toList();
  }

  List<Map<String, dynamic>> _rows(dynamic data) {
    try {
      if (data is! List) throw const FormatException();
      return data.map((row) => Map<String, dynamic>.from(row as Map)).toList();
    } catch (_) {
      throw const ShipperOrderException(
        'Không đọc được danh sách đơn giao từ backend.',
      );
    }
  }

  Future<List<ShipperOrder>> _details(List<int> ids) async {
    final result = <ShipperOrder>[];
    // Tối đa 4 request cùng lúc để lấy tên người nhận và kiểm tra shipperId.
    for (var index = 0; index < ids.length; index += 4) {
      final batch = ids.skip(index).take(4);
      final orders = await Future.wait(batch.map(_detailIfExists));
      result.addAll(orders.whereType<ShipperOrder>());
    }
    return result;
  }

  Future<ShipperOrder?> _detailIfExists(int id) async {
    try {
      return await getOrderDetail(id);
    } on ShipperOrderException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow; // Không bỏ qua lỗi quyền, không hiển thị đơn chưa xác minh được.
    }
  }

  Future<ShipperOrder> getOrderDetail(int id) async {
    final data = await service.getOrderDetail(id);
    try {
      final order = ShipperOrder.fromJson(
        Map<String, dynamic>.from(data as Map),
      );
      if (order.id != id) throw const FormatException();
      return order;
    } catch (_) {
      throw const ShipperOrderException(
        'Chi tiết đơn không đúng định dạng hoặc không đúng ID được yêu cầu.',
      );
    }
  }

  Future<void> assign(int id) => service.assign(id);
  Future<void> delivered(int id) => service.delivered(id);

  // Giữ nguyên JSON COD. Model/màn hình COD sẽ được làm khi có đặc tả riêng.
  Future<dynamic> getCodBalance() => service.getCodBalance();
  Future<dynamic> getCodTransactions() => service.getCodTransactions();
}
