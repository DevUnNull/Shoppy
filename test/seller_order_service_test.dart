import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoppy/features/seller_orders/models/seller_order.dart';
import 'package:shoppy/features/seller_orders/models/seller_orders_page.dart';
import 'package:shoppy/features/seller_orders/services/seller_order_service.dart';

import 'helpers/seller_order_fakes.dart';

class MemoryAdapter implements HttpClientAdapter {
  MemoryAdapter({this.statusCode = 200, this.body, this.failureType});
  final int statusCode;
  final dynamic body;
  final DioExceptionType? failureType;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (failureType != null) {
      throw DioException(requestOptions: options, type: failureType!);
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

SellerOrderService createService(
  MemoryAdapter adapter, {
  String token = 'seller-test-token',
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
  dio.httpClientAdapter = adapter;
  final service = SellerOrderService(dio: dio, token: token);
  addTearDown(service.close);
  return service;
}

void main() {
  test('Đóng gói gửi đúng PUT với Bearer, không có body hay query', () async {
    final adapter = MemoryAdapter(
      body: {
        'status': 'success',
        'message': 'Đóng gói thành công',
        'data': null,
      },
    );
    await createService(adapter).readyToShip(6);
    final request = adapter.requests.single;
    expect(request.method, 'PUT');
    expect(request.path, '/orders/6/ready-to-ship');
    expect(request.headers['Authorization'], 'Bearer seller-test-token');
    expect(request.data, isNull);
    expect(request.queryParameters, isEmpty);
  });

  test('Hủy đơn gửi đúng PUT, JSON reason và token Seller', () async {
    final adapter = MemoryAdapter(body: {'status': 'success'});
    await createService(adapter).cancelOrder(6, 'Shop hết hàng màu trắng');
    final request = adapter.requests.single;
    expect(request.method, 'PUT');
    expect(request.path, '/seller/orders/6/cancel');
    expect(request.headers['Authorization'], 'Bearer seller-test-token');
    expect(request.contentType, Headers.jsonContentType);
    expect(request.data, {'reason': 'Shop hết hàng màu trắng'});
  });

  test(
    'PUT trả 204 được coi là thành công, không cần parse chi tiết',
    () async {
      final adapter = MemoryAdapter(statusCode: 204);
      await createService(adapter).readyToShip(6);
      expect(adapter.requests.length, 1);
    },
  );

  for (final cancel in [false, true]) {
    for (final code in [401, 403, 409, 500]) {
      test(
        'PUT ${cancel ? 'hủy' : 'đóng gói'} lỗi $code không có message vẫn báo lỗi',
        () async {
          final adapter = MemoryAdapter(statusCode: code);
          final service = createService(adapter);
          await expectLater(
            cancel
                ? service.cancelOrder(6, 'Shop hết hàng')
                : service.readyToShip(6),
            throwsA(
              isA<SellerOrderException>()
                  .having((error) => error.statusCode, 'statusCode', code)
                  .having((error) => error.message, 'message', isNotEmpty),
            ),
          );
          expect(adapter.requests.length, 1);
        },
      );
    }
  }

  for (final type in [
    DioExceptionType.connectionError,
    DioExceptionType.sendTimeout,
    DioExceptionType.receiveTimeout,
  ]) {
    test('PUT lỗi $type không tự gửi lại yêu cầu', () async {
      final adapter = MemoryAdapter(failureType: type);
      await expectLater(
        createService(adapter).cancelOrder(6, 'Shop hết hàng'),
        throwsA(isA<SellerOrderException>()),
      );
      expect(adapter.requests.length, 1);
    });
  }

  test('GET seller/orders gửi đúng Bearer, status và phân trang', () async {
    final adapter = MemoryAdapter(
      body: {
        'status': 'success',
        'data': {
          'content': [orderJson(status: 'READY_TO_SHIP')],
          'page': 2,
          'hasNext': true,
        },
      },
    );
    final service = createService(adapter);
    final result = SellerOrdersPage.fromJson(
      await service.getOrders(status: 'READY_TO_SHIP', page: 2),
    );
    final request = adapter.requests.single;
    expect(request.method, 'GET');
    expect(request.path, '/seller/orders');
    expect(request.headers['Authorization'], 'Bearer seller-test-token');
    expect(request.queryParameters, {
      'status': 'READY_TO_SHIP',
      'page': 2,
      'size': 10,
    });
    expect(result.orders.single.grandTotal, 930000);
    expect(result.orders.single.totalAmount, 900000);
    expect(result.orders.single.recipientName, isNull);
    expect(result.orders.single.trackingNumber, isNull);
    expect(result.hasNext, isTrue);
  });

  test(
    'GET đúng chi tiết theo ID, đọc snapshot và tracking status riêng',
    () async {
      final detail = orderJson(status: 'PROCESSING', name: 'Nguyễn Văn A');
      detail['items'] = [
        {
          'productNameSnapshot': 'Giày sneaker trắng',
          'variantNameSnapshot': 'Mặc định',
          'priceSnapshot': 450000.0,
          'quantity': 2,
          'subtotal': 900000.0,
        },
      ];
      detail['trackings'] = [
        {
          'status': 'PREPARING',
          'description': 'Shop đang chuẩn bị hàng',
          'createdAt': '2026-11-07T17:38:29.742893',
        },
      ];
      final adapter = MemoryAdapter(
        body: {'status': 'success', 'data': detail},
      );
      final service = createService(adapter);
      final order = SellerOrder.fromJson(await service.getOrderDetail(6));
      expect(adapter.requests.single.path, '/orders/6');
      expect(order.items.single.productName, 'Giày sneaker trắng');
      expect(order.items.single.price, 450000);
      expect(order.items.single.quantity, 2);
      expect(order.trackings.single.status, 'PREPARING');
      expect(order.status, 'PROCESSING');
    },
  );

  for (final code in [401, 403]) {
    for (final body in [
      null,
      <String, dynamic>{'message': ''},
      '<html>Forbidden</html>',
    ]) {
      test('HTTP $code không có message hữu ích vẫn có thông báo rõ', () async {
        final service = createService(
          MemoryAdapter(statusCode: code, body: body),
        );
        await expectLater(
          service.getOrders(status: 'PENDING', page: 0),
          throwsA(
            isA<SellerOrderException>()
                .having((error) => error.statusCode, 'statusCode', code)
                .having(
                  (error) => error.message,
                  'message',
                  contains(code == 401 ? 'JWT' : 'SELLER'),
                ),
          ),
        );
      });
    }
  }

  test('Không gửi request khi chưa điền token', () async {
    final adapter = MemoryAdapter();
    final service = createService(adapter, token: '  ');
    await expectLater(
      service.getOrders(status: 'PENDING', page: 0),
      throwsA(isA<SellerOrderException>()),
    );
    expect(adapter.requests, isEmpty);
  });

  test('Mất kết nối có thông báo và không tự gọi lại', () async {
    final adapter = MemoryAdapter(
      failureType: DioExceptionType.connectionError,
    );
    final service = createService(adapter);
    await expectLater(
      service.getOrders(status: 'PENDING', page: 0),
      throwsA(
        isA<SellerOrderException>().having(
          (error) => error.message,
          'message',
          contains('Kiểm tra mạng'),
        ),
      ),
    );
    expect(adapter.requests.length, 1);
  });

  test('Response lỗi HTTP 200 không có message vẫn được xử lý', () async {
    final service = createService(
      MemoryAdapter(body: {'status': 'error', 'message': null}),
    );
    await expectLater(
      service.getOrders(status: 'PENDING', page: 0),
      throwsA(
        isA<SellerOrderException>().having(
          (error) => error.message,
          'message',
          isNotEmpty,
        ),
      ),
    );
  });
}
