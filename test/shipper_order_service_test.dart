import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoppy/features/shipper_orders/models/shipper_order.dart';
import 'package:shoppy/features/shipper_orders/repositories/shipper_order_repository.dart';
import 'package:shoppy/features/shipper_orders/services/shipper_order_service.dart';

import 'helpers/shipper_order_fakes.dart';

class ShipperMemoryAdapter implements HttpClientAdapter {
  ShipperMemoryAdapter(this.respond);
  final ResponseBody Function(RequestOptions) respond;
  final List<RequestOptions> calls = [];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody response(dynamic data, {int code = 200}) =>
    ResponseBody.fromString(
      jsonEncode(data),
      code,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
ShipperOrderService makeService(
  ShipperMemoryAdapter adapter, {
  String token = 'shipper-test-token',
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
  dio.httpClientAdapter = adapter;
  final service = ShipperOrderService(dio: dio, token: token);
  addTearDown(service.close);
  return service;
}

void main() {
  test(
    'Delivered dùng đúng PUT, orderId, token Shipper và không có body',
    () async {
      final adapter = ShipperMemoryAdapter(
        (options) => response({'status': 'success'}),
      );
      await makeService(adapter).delivered(6);
      final request = adapter.calls.single;
      expect(request.method, 'PUT');
      expect(request.path, '/shipper/orders/6/delivered');
      expect(request.headers['Authorization'], 'Bearer shipper-test-token');
      expect(request.data, isNull);
    },
  );
  test('Lịch sử truyền DELIVERED, data rỗng được hỗ trợ', () async {
    final adapter = ShipperMemoryAdapter(
      (options) => response({'status': 'success', 'data': []}),
    );
    expect(
      await ShipperOrderRepository(makeService(adapter))
          .getMyDeliveries(status: 'DELIVERED'),
      isEmpty,
    );
    expect(adapter.calls.single.queryParameters, {'status': 'DELIVERED'});
  });
  for (final code in [401, 403, 409, 500]) {
    test('Delivered lỗi $code không có message vẫn có thông báo', () async {
      final adapter = ShipperMemoryAdapter(
        (options) => response(null, code: code),
      );
      await expectLater(
        makeService(adapter).delivered(6),
        throwsA(
          isA<ShipperOrderException>()
              .having((error) => error.statusCode, 'statusCode', code)
              .having((error) => error.message, 'message', isNotEmpty),
        ),
      );
      expect(adapter.calls, hasLength(1));
    });
  }
  test(
    'API COD giữ nguyên data backend trả về, không tự tính số dư hay giao dịch',
    () async {
      final adapter = ShipperMemoryAdapter(
        (options) => response({
          'status': 'success',
          'data': options.path.endsWith('balance')
              ? {'currentBalance': 123000.0}
              : [
                  {'type': 'COLLECTION', 'amount': 123000.0},
                ],
        }),
      );
      final repository = ShipperOrderRepository(makeService(adapter));
      expect((await repository.getCodBalance())['currentBalance'], 123000);
      expect((await repository.getCodTransactions()) as List, hasLength(1));
      expect(adapter.calls.map((item) => item.path), [
        '/shipper/cod/balance',
        '/shipper/cod/transactions',
      ]);
    },
  );
  test(
    'Available là mảng, gửi JWT Shipper, không tự thêm phân trang',
    () async {
      final adapter = ShipperMemoryAdapter(
        (options) => response({
          'status': 'success',
          'data': [shipperOrderJson(summary: true)],
        }),
      );
      expect(await makeService(adapter).getAvailableOrders(), isA<List>());
      expect(adapter.calls.single.path, '/shipper/orders/available');
      expect(
        adapter.calls.single.headers['Authorization'],
        'Bearer shipper-test-token',
      );
      expect(adapter.calls.single.queryParameters, isEmpty);
    },
  );
  test('Đơn đang giao đọc được data rỗng, gửi status SHIPPING', () async {
    final adapter = ShipperMemoryAdapter(
      (options) => response({'status': 'success', 'data': []}),
    );
    expect(
      await ShipperOrderRepository(makeService(adapter)).getMyDeliveries(),
      isEmpty,
    );
    expect(adapter.calls.single.path, '/shipper/orders/my-deliveries');
    expect(adapter.calls.single.queryParameters, {'status': 'SHIPPING'});
  });
  test(
    'My deliveries chỉ dùng ID rồi lấy chi tiết, không đoán các trường còn lại',
    () async {
      final adapter = ShipperMemoryAdapter(
        (options) => response({
          'status': 'success',
          'data': options.path.endsWith('my-deliveries')
              ? [
                  {'id': 6},
                ]
              : shipperOrderJson(status: 'SHIPPING', driverId: 100),
        }),
      );
      expect(
        (await ShipperOrderRepository(
          makeService(adapter),
        ).getMyDeliveries()).single.status,
        'SHIPPING',
      );
      expect(adapter.calls.length, 2);
    },
  );
  test('GET đúng ID, PUT assign đúng path, Bearer và không body', () async {
    final adapter = ShipperMemoryAdapter(
      (options) => response({'status': 'success', 'data': shipperOrderJson()}),
    );
    final service = makeService(adapter);
    await service.getOrderDetail(6);
    await service.assign(6);
    expect(adapter.calls.map((call) => call.path), [
      '/shipper/orders/6',
      '/shipper/orders/6/assign',
    ]);
    expect(adapter.calls.last.method, 'PUT');
    expect(adapter.calls.last.data, isNull);
  });
  test('Chi tiết không có shopId vẫn đọc được shopAddress và sản phẩm', () {
    final order = makeShipperOrder();
    expect(order.shopId, isNull);
    expect(order.shopAddress, pickupUrl);
    expect(order.items.single.quantity, 2);
    expect(order.items.single.name, 'Giày sneaker trắng');
  });
  test('COD dùng grandTotal, WALLET không thu tiền và hai trạng thái sẵn sàng cùng nghĩa', () {
    expect(makeShipperOrder().cashToCollect, 930000);
    expect(makeShipperOrder(payment: 'WALLET').cashToCollect, 0);
    expect(
      makeShipperOrder(status: 'READY_FOR_PICKUP').statusLabel,
      makeShipperOrder().statusLabel,
    );
    expect(
      ShipperOrder.fromJson(shipperOrderJson(summary: true)).canAssign,
      isFalse,
    );
  });
  test('Lấy tên người nhận từ chi tiết và lọc đơn đã có tài xế', () async {
    final adapter = ShipperMemoryAdapter((options) {
      final dynamic data = options.path.endsWith('available')
          ? [
              shipperOrderJson(summary: true),
              shipperOrderJson(id: 7, summary: true),
            ]
          : shipperOrderJson(
              id: options.path.endsWith('/7') ? 7 : 6,
              status: options.path.endsWith('/7')
                  ? 'SHIPPING'
                  : 'READY_TO_SHIP',
              driverId: options.path.endsWith('/7') ? 200 : null,
            );
      return response({'status': 'success', 'data': data});
    });
    final orders = await ShipperOrderRepository(makeService(adapter))
        .getAvailableOrders();
    expect(orders.single.id, 6);
    expect(orders.single.recipientName, 'Nguyễn Văn A');
  });
  for (final code in [401, 403, 409, 500]) {
    test(
      'Lỗi $code không có message có thông báo, PUT không tự gửi lại',
      () async {
        final adapter = ShipperMemoryAdapter(
          (options) => response(null, code: code),
        );
        await expectLater(
          makeService(adapter).assign(6),
          throwsA(
            isA<ShipperOrderException>()
                .having((error) => error.statusCode, 'code', code)
                .having((error) => error.message, 'message', isNotEmpty),
          ),
        );
        expect(adapter.calls.length, 1);
      },
    );
  }
  test('Timeout được nhận biết, không tự lặp PUT', () async {
    final adapter = ShipperMemoryAdapter(
      (options) => throw DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      ),
    );
    await expectLater(
      makeService(adapter).assign(6),
      throwsA(
        isA<ShipperOrderException>().having(
          (error) => error.isTimeout,
          'timeout',
          isTrue,
        ),
      ),
    );
    expect(adapter.calls.length, 1);
  });
  test('Chưa có JWT không gửi request', () async {
    final adapter = ShipperMemoryAdapter((options) => response(null));
    await expectLater(
      makeService(adapter, token: '').getAvailableOrders(),
      throwsA(isA<ShipperOrderException>()),
    );
    expect(adapter.calls, isEmpty);
  });
}
