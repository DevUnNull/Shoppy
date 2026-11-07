import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoppy/features/shipper_orders/models/cod_transaction.dart';
import 'package:shoppy/features/shipper_orders/repositories/shipper_cod_repository.dart';
import 'package:shoppy/features/shipper_orders/services/shipper_order_service.dart';

class CodAdapter implements HttpClientAdapter {
  CodAdapter(this.respond);
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

ResponseBody codResponse(dynamic data, {int code = 200}) =>
    ResponseBody.fromString(
      jsonEncode(data),
      code,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
ShipperOrderService codService(CodAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
    ..httpClientAdapter = adapter;
  final service = ShipperOrderService(dio: dio, token: 'test-shipper-cod');
  addTearDown(service.close);
  return service;
}

const remittanceData = {
  'amount': 5000,
  'createdAt': '2026-11-07T23:25:47.116900522',
  'id': 13,
  'note': 'Shipper nộp tiền mặt đợt 1 về bưu cục GHN',
  'orderId': null,
  'shipperId': 16,
  'status': 'COMPLETED',
  'type': 'REMITTANCE',
};

void main() {
  test('Đọc đúng JSON balance thực tế, số 0 là hợp lệ', () async {
    final adapter = CodAdapter(
      (options) => codResponse({
        'status': 'success',
        'data': {
          'totalCollected': 930000.0,
          'totalRemitted': 0,
          'currentBalance': 930000.0,
        },
      }),
    );
    final balance = await ShipperCodRepository(codService(adapter))
        .getBalance();
    expect(balance.totalCollected, 930000);
    expect(balance.totalRemitted, 0);
    expect(balance.currentBalance, 930000);
    expect(adapter.calls.single.path, '/shipper/cod/balance');
    expect(
      adapter.calls.single.headers['Authorization'],
      'Bearer test-shipper-cod',
    );
  });
  for (final filter in CodFilter.values) {
    test('GET transactions bộ lọc ${filter.label} gửi đúng query', () async {
      final adapter = CodAdapter(
        (options) => codResponse({'status': 'success', 'data': []}),
      );
      expect(
        await ShipperCodRepository(codService(adapter))
            .getTransactions(filter: filter),
        isEmpty,
      );
      expect(adapter.calls.single.path, '/shipper/cod/transactions');
      expect(
        adapter.calls.single.queryParameters,
        filter.apiValue == null ? {} : {'type': filter.apiValue},
      );
    });
  }
  test(
    'Đọc JSON transaction thực tế, orderId và ghi chú có thể vắng',
    () async {
      final adapter = CodAdapter(
        (options) => codResponse({
          'status': 'success',
          'data': [
            {
              'amount': 930000.0,
              'createdAt': '2026-11-07T22:41:47.876311',
              'id': 1,
              'note': 'Thu tiền mặt COD đơn hàng #6',
              'orderId': 6,
              'shipperId': 16,
              'status': 'COMPLETED',
              'type': 'COLLECTION',
            },
            {
              'amount': 500000,
              'createdAt': '2026-11-07T23:00:00',
              'id': 2,
              'orderId': null,
              'note': null,
              'shipperId': 16,
              'status': 'COMPLETED',
              'type': 'REMITTANCE',
            },
          ],
        }),
      );
      final result = await ShipperCodRepository(codService(adapter))
          .getTransactions();
      expect(result.first.sign, '+');
      expect(result.first.orderId, 6);
      expect(result.last.sign, '−');
      expect(result.last.orderId, isNull);
    },
  );
  test('Không tự coi thiếu trường tiền là số dư 0', () async {
    final adapter = CodAdapter(
      (options) => codResponse({
        'status': 'success',
        'data': {'currentBalance': 0},
      }),
    );
    await expectLater(
      ShipperCodRepository(codService(adapter)).getBalance(),
      throwsA(isA<ShipperOrderException>()),
    );
  });
  test(
    'Nộp về công ty: gửi đúng JSON/token và đọc giao dịch thành công thực tế',
    () async {
      final adapter = CodAdapter(
        (options) => codResponse({
          'status': 'success',
          'message': 'Nộp tiền COD về công ty thành công!',
          'data': remittanceData,
        }),
      );
      final transaction = await ShipperCodRepository(codService(adapter))
          .remit(5000, remittanceData['note'] as String);
      expect(transaction.id, 13);
      expect(transaction.amount, 5000);
      expect(transaction.type, 'REMITTANCE');
      expect(transaction.status, 'COMPLETED');
      expect(transaction.orderId, isNull);
      expect(transaction.shipperId, 16);
      expect(transaction.createdAt, remittanceData['createdAt']);
      expect(transaction.note, remittanceData['note']);
      final request = adapter.calls.single;
      expect(request.method, 'POST');
      expect(request.path, '/shipper/cod/remittance');
      expect(request.contentType, Headers.jsonContentType);
      expect(request.data, {'amount': 5000, 'note': remittanceData['note']});
      expect(request.data['amount'], isA<int>());
      expect(request.headers['Authorization'], 'Bearer test-shipper-cod');
    },
  );
  final invalidReceipts = <String, dynamic>{
    'thiếu data': null,
    'thiếu trường giao dịch': <String, dynamic>{},
    'khác loại nộp tiền': {...remittanceData, 'type': 'COLLECTION'},
    'chưa hoàn tất': {...remittanceData, 'status': 'PENDING'},
    'khác số tiền đã gửi': {...remittanceData, 'amount': 10000},
  };
  for (final entry in invalidReceipts.entries) {
    test('Không báo nộp thành công khi ${entry.key}', () async {
      final adapter = CodAdapter(
        (options) => codResponse({'status': 'success', 'data': entry.value}),
      );
      await expectLater(
        ShipperCodRepository(codService(adapter)).remit(5000, 'Cuối ca'),
        throwsA(
          isA<ShipperOrderException>().having(
            (error) => error.isRejected,
            'Kết quả chưa rõ, cần đối chiếu trước khi gửi lại',
            isFalse,
          ),
        ),
      );
      expect(adapter.calls, hasLength(1));
    });
  }
  for (final code in [400, 401, 403, 500]) {
    test('POST lỗi $code không có message vẫn có thông báo', () async {
      final adapter = CodAdapter((options) => codResponse(null, code: code));
      await expectLater(
        codService(adapter).remitCod(500000, 'Cuối ca'),
        throwsA(
          isA<ShipperOrderException>()
              .having((error) => error.statusCode, 'code', code)
              .having((error) => error.message, 'message', isNotEmpty),
        ),
      );
      expect(adapter.calls, hasLength(1));
    });
  }
  test('Không tự gửi lại POST khi timeout', () async {
    final adapter = CodAdapter(
      (options) => throw DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      ),
    );
    await expectLater(
      codService(adapter).remitCod(500000, 'Ca'),
      throwsA(
        isA<ShipperOrderException>().having(
          (error) => error.isTimeout,
          'timeout',
          isTrue,
        ),
      ),
    );
    expect(adapter.calls, hasLength(1));
  });
}
