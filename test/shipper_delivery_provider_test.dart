import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoppy/features/shipper_orders/models/shipper_order.dart';
import 'package:shoppy/features/shipper_orders/providers/shipper_cod_provider.dart';
import 'package:shoppy/features/shipper_orders/providers/shipper_delivery_provider.dart';
import 'package:shoppy/features/shipper_orders/providers/shipper_orders_provider.dart';
import 'package:shoppy/features/shipper_orders/services/shipper_order_service.dart';

import 'helpers/shipper_order_fakes.dart';

void main() {
  late FakeShipperBackend backend;
  late FakeShipperOrderRepository repository;
  late ProviderContainer container;
  late ShipperDeliveryNotifier notifier;
  final provider = shipperDeliveryProvider(6);
  final detail = shipperOrderDetailProvider(6);
  setUp(() async {
    backend = FakeShipperBackend([
      makeShipperOrder(status: 'SHIPPING', driverId: 100),
    ]);
    backend.codBalances[100] = 500000;
    repository = FakeShipperOrderRepository(backend: backend);
    container = ProviderContainer(
      overrides: [shipperOrderRepositoryProvider.overrideWithValue(repository)],
    );
    notifier = container.read(provider.notifier);
    await container.read(detail.future);
  });
  tearDown(() {
    container.dispose();
    repository.service.close();
  });

  Future<void> watchCod() async {
    container.listen(shipperCodBalanceProvider, (previous, next) {});
    container.listen(shipperCodTransactionsProvider, (previous, next) {});
    await container.read(shipperCodBalanceProvider.future);
    await container.read(shipperCodTransactionsProvider.future);
  }

  test('COD: BE giả lập ghi đúng một lần, FE tải lại số dư/lịch sử, chuyển đúng tab', () async {
    await watchCod();
    final old = backend.orders[6]!;
    expect(await notifier.delivered(old, cashCollected: true), isTrue);
    expect(container.read(detail).requireValue.status, 'DELIVERED');
    expect(
      container.read(detail).requireValue.trackings.last.description,
      'Giao hàng thành công',
    );
    expect(await container.read(myShipperDeliveriesProvider.future), isEmpty);
    expect(
      (await container.read(shipperDeliveryHistoryProvider.future)).single.id,
      6,
    );
    expect(
      (await container.read(
        shipperCodBalanceProvider.future,
      ))['currentBalance'],
      1430000,
    );
    expect(
      (await container.read(shipperCodTransactionsProvider.future)) as List,
      hasLength(1),
    );
    expect(repository.balanceCalls, 2);
    expect(repository.transactionsCalls, 2);
    await expectLater(
      notifier.delivered(old, cashCollected: true),
      throwsA(isA<ShipperOrderException>()),
    );
    expect(repository.deliveredCalls, [6]);
    expect(backend.collections, hasLength(1));
    expect(backend.codBalances[100], 1430000);
  });
  test(
    'WALLET giao thành công không tăng COD hay tạo giao dịch thu tiền',
    () async {
      backend.orders[6] = makeShipperOrder(
        status: 'SHIPPING',
        driverId: 100,
        payment: 'WALLET',
      );
      await watchCod();
      expect(await notifier.delivered(backend.orders[6]!), isTrue);
      expect(backend.codBalances[100], 500000);
      expect(backend.collections, isEmpty);
      expect(container.read(detail).requireValue.status, 'DELIVERED');
      expect(
        (await container.read(
          shipperCodBalanceProvider.future,
        ))['currentBalance'],
        500000,
      );
    },
  );
  test('COD chưa xác nhận thu đủ tiền không gửi PUT', () async {
    await expectLater(
      notifier.delivered(backend.orders[6]!),
      throwsA(isA<ShipperOrderException>()),
    );
    expect(repository.deliveredCalls, isEmpty);
  });
  for (final status in [
    'PENDING',
    'PROCESSING',
    'READY_TO_SHIP',
    'DELIVERED',
    'CANCELLED',
  ]) {
    test('Không gửi delivered cho trạng thái $status', () async {
      await expectLater(
        notifier.delivered(
          makeShipperOrder(status: status, driverId: 100),
          cashCollected: true,
        ),
        throwsA(isA<ShipperOrderException>()),
      );
      expect(repository.deliveredCalls, isEmpty);
    });
  }
  test('Không được xác nhận đơn của tài xế khác cùng hãng', () async {
    backend.orders[6] = makeShipperOrder(status: 'SHIPPING', driverId: 200);
    await expectLater(
      notifier.delivered(backend.orders[6]!, cashCollected: true),
      throwsA(
        isA<ShipperOrderException>().having(
          (error) => error.statusCode,
          'statusCode',
          403,
        ),
      ),
    );
    expect(repository.deliveredCalls, isEmpty);
    expect(backend.collections, isEmpty);
  });
  test(
    'Nhấn liên tục chỉ có một PUT và một lần ghi COD ở BE giả lập',
    () async {
      final pending = Completer<void>();
      repository.onDelivered = (id) async {
        await pending.future;
        backend.completeDelivery(id, 100, 1);
      };
      final order = backend.orders[6]!;
      final first = notifier.delivered(order, cashCollected: true);
      expect(await notifier.delivered(order, cashCollected: true), isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(repository.deliveredCalls, [6]);
      pending.complete();
      await first;
      expect(backend.collections, hasLength(1));
    },
  );
  test('PUT thất bại không tự chuyển DELIVERED và không cộng COD', () async {
    repository.onDelivered = (id) async =>
        throw const ShipperOrderException('Backend từ chối');
    await expectLater(
      notifier.delivered(backend.orders[6]!, cashCollected: true),
      throwsA(isA<ShipperOrderException>()),
    );
    expect(container.read(detail).requireValue.status, 'SHIPPING');
    expect(backend.codBalances[100], 500000);
    expect(backend.collections, isEmpty);
    expect(container.read(provider).isBusy, isFalse);
  });
  test(
    'Timeout sau khi BE xử lý: kiểm tra lịch sử, không gửi PUT lặp',
    () async {
      repository.onDelivered = (id) async {
        backend.completeDelivery(id, 100, 1);
        throw const ShipperOrderException('Timeout', isTimeout: true);
      };
      expect(
        await notifier.delivered(backend.orders[6]!, cashCollected: true),
        isTrue,
      );
      expect(repository.deliveryStatuses, contains('DELIVERED'));
      expect(repository.deliveredCalls, [6]);
      expect(backend.collections, hasLength(1));
    },
  );
  test(
    'Timeout chưa xử lý: GET lại SHIPPING rồi mới cho thử lại thủ công',
    () async {
      repository.onDelivered = (id) async =>
          throw const ShipperOrderException('Timeout', isTimeout: true);
      final order = backend.orders[6]!;
      await expectLater(
        notifier.delivered(order, cashCollected: true),
        throwsA(isA<ShipperOrderException>()),
      );
      expect(container.read(detail).requireValue.status, 'SHIPPING');
      expect(container.read(provider).needsCheck, isFalse);
      repository.onDelivered = null;
      expect(await notifier.delivered(order, cashCollected: true), isTrue);
      expect(repository.deliveredCalls, [6, 6]);
      expect(backend.collections, hasLength(1));
    },
  );
  test(
    'Timeout và GET lỗi: chặn PUT đến khi kiểm tra lại thành công',
    () async {
      repository.onDelivered = (id) async {
        repository.onDetail = (id) async =>
            throw const ShipperOrderException('Mất mạng');
        throw const ShipperOrderException('Timeout', isTimeout: true);
      };
      final order = backend.orders[6]!;
      await expectLater(
        notifier.delivered(order, cashCollected: true),
        throwsA(isA<ShipperOrderException>()),
      );
      expect(container.read(provider).needsCheck, isTrue);
      expect(await notifier.delivered(order, cashCollected: true), isFalse);
      expect(repository.deliveredCalls, [6]);
      repository.onDetail = null;
      repository.onDelivered = null;
      await notifier.checkStatus();
      expect(await notifier.delivered(order, cashCollected: true), isTrue);
      expect(backend.collections, hasLength(1));
    },
  );
  test(
    'PUT thành công GET lỗi: giữ dữ liệu cũ, kiểm tra lại thấy DELIVERED',
    () async {
      repository.onDelivered = (id) async {
        backend.completeDelivery(id, 100, 1);
        repository.onDetail = (id) async =>
            throw const ShipperOrderException('Mất mạng');
      };
      final order = backend.orders[6]!;
      await expectLater(
        notifier.delivered(order, cashCollected: true),
        throwsA(isA<ShipperOrderException>()),
      );
      expect(container.read(detail).requireValue.status, 'SHIPPING');
      expect(container.read(provider).needsCheck, isTrue);
      expect(await notifier.delivered(order, cashCollected: true), isFalse);
      repository.onDetail = null;
      await notifier.checkStatus();
      expect(container.read(detail).requireValue.status, 'DELIVERED');
      expect(backend.collections, hasLength(1));
      expect(repository.deliveredCalls, [6]);
    },
  );
  for (final code in [401, 403]) {
    test('Lỗi quyền $code không thay trạng thái và không ghi COD', () async {
      repository.onDelivered = (id) async =>
          throw ShipperOrderException('Lỗi quyền', statusCode: code);
      await expectLater(
        notifier.delivered(backend.orders[6]!, cashCollected: true),
        throwsA(
          isA<ShipperOrderException>().having(
            (error) => error.statusCode,
            'statusCode',
            code,
          ),
        ),
      );
      expect(container.read(detail).requireValue.status, 'SHIPPING');
      expect(backend.collections, isEmpty);
    });
  }
  test(
    'Số tiền thay đổi sau hộp thoại thì yêu cầu xem và xác nhận lại',
    () async {
      final json = shipperOrderJson(status: 'SHIPPING', driverId: 100);
      json['grandTotal'] = 900000.0;
      await expectLater(
        notifier.delivered(ShipperOrder.fromJson(json), cashCollected: true),
        throwsA(
          isA<ShipperOrderException>().having(
            (error) => error.message,
            'message',
            contains('thanh toán đã thay đổi'),
          ),
        ),
      );
      expect(repository.deliveredCalls, isEmpty);
    },
  );
}
