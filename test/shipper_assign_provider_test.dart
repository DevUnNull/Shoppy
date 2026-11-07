import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoppy/features/shipper_orders/providers/shipper_assign_provider.dart';
import 'package:shoppy/features/shipper_orders/providers/shipper_orders_provider.dart';
import 'package:shoppy/features/shipper_orders/services/shipper_order_service.dart';

import 'helpers/shipper_order_fakes.dart';

void main() {
  late FakeShipperBackend backend;
  late FakeShipperOrderRepository repository;
  late ProviderContainer container;
  late ShipperAssignNotifier notifier;
  final provider = shipperAssignProvider(6);
  setUp(() async {
    backend = FakeShipperBackend([makeShipperOrder()]);
    repository = FakeShipperOrderRepository(backend: backend);
    container = ProviderContainer(
      overrides: [shipperOrderRepositoryProvider.overrideWithValue(repository)],
    );
    notifier = container.read(provider.notifier);
    await container.read(shipperOrderDetailProvider(6).future);
  });
  tearDown(() {
    container.dispose();
    repository.service.close();
  });

  test(
    'Nhận thành công tải lại chi tiết và hai danh sách từ backend',
    () async {
      expect(await notifier.assign(backend.orders[6]!), isTrue);
      expect(
        container.read(shipperOrderDetailProvider(6)).requireValue.status,
        'SHIPPING',
      );
      expect(
        await container.read(availableShipperOrdersProvider.future),
        isEmpty,
      );
      expect(
        (await container.read(myShipperDeliveriesProvider.future)).single.id,
        6,
      );
      expect(repository.assignCalls, [6]);
    },
  );
  test('Dùng chung khóa: nhấn ở danh sách/chi tiết chỉ gửi một PUT', () async {
    final pending = Completer<void>();
    repository.onAssign = (id) => pending.future;
    final order = backend.orders[6]!;
    final first = notifier.assign(order);
    expect(await container.read(provider.notifier).assign(order), isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(repository.assignCalls, [6]);
    backend.orders[6] = makeShipperOrder(status: 'SHIPPING', driverId: 100);
    pending.complete();
    await first;
  });
  for (final status in [
    'PENDING',
    'PROCESSING',
    'SHIPPING',
    'DELIVERED',
    'CANCELLED',
  ]) {
    test('Không nhận được trạng thái $status', () async {
      await expectLater(
        notifier.assign(makeShipperOrder(status: status)),
        throwsA(isA<ShipperOrderException>()),
      );
      expect(repository.assignCalls, isEmpty);
    });
  }
  test('READY_TO_SHIP có tài xế vẫn không nhận được', () async {
    await expectLater(
      notifier.assign(makeShipperOrder(driverId: 200)),
      throwsA(isA<ShipperOrderException>()),
    );
    expect(repository.assignCalls, isEmpty);
  });
  test(
    'Đơn bị đổi trạng thái trước khi xác nhận: tải mới và không gửi PUT',
    () async {
      final old = backend.orders[6]!;
      backend.orders[6] = makeShipperOrder(status: 'CANCELLED');
      await expectLater(
        notifier.assign(old),
        throwsA(isA<ShipperOrderException>()),
      );
      expect(
        container.read(shipperOrderDetailProvider(6)).requireValue.status,
        'CANCELLED',
      );
      expect(repository.assignCalls, isEmpty);
    },
  );
  test('Lỗi backend giữ trạng thái, không tự chuyển SHIPPING', () async {
    repository.onAssign = (id) async =>
        throw const ShipperOrderException('Không nhận được đơn');
    await expectLater(
      notifier.assign(backend.orders[6]!),
      throwsA(isA<ShipperOrderException>()),
    );
    expect(
      container.read(shipperOrderDetailProvider(6)).requireValue.status,
      'READY_TO_SHIP',
    );
    expect(container.read(provider).isBusy, isFalse);
    expect(container.read(provider).needsCheck, isFalse);
  });
  test('Timeout nhưng backend đã gán cho mình: kiểm tra my-deliveries, không gửi lại PUT', () async {
    repository.onAssign = (id) async {
      backend.orders[id] = makeShipperOrder(status: 'SHIPPING', driverId: 100);
      throw const ShipperOrderException('Timeout', isTimeout: true);
    };
    expect(await notifier.assign(backend.orders[6]!), isTrue);
    expect(repository.deliveriesCalls, 1);
    expect(repository.assignCalls, [6]);
  });
  test(
    'Timeout và tài xế khác đã nhận: không báo thành công cho mình',
    () async {
      repository.onAssign = (id) async {
        backend.orders[id] = makeShipperOrder(
          status: 'SHIPPING',
          driverId: 200,
        );
        throw const ShipperOrderException('Timeout', isTimeout: true);
      };
      await expectLater(
        notifier.assign(backend.orders[6]!),
        throwsA(
          isA<ShipperOrderException>().having(
            (error) => error.message,
            'message',
            contains('tài xế khác'),
          ),
        ),
      );
      expect(repository.assignCalls, [6]);
    },
  );
  test(
    'Timeout và GET trạng thái lỗi: khóa PUT đến khi kiểm tra lại thành công',
    () async {
      repository.onAssign = (id) async {
        repository.onDetail = (id) async =>
            throw const ShipperOrderException('Mất mạng');
        throw const ShipperOrderException('Timeout', isTimeout: true);
      };
      final order = backend.orders[6]!;
      await expectLater(
        notifier.assign(order),
        throwsA(isA<ShipperOrderException>()),
      );
      expect(container.read(provider).needsCheck, isTrue);
      expect(await notifier.assign(order), isFalse);
      repository.onDetail = null;
      repository.onAssign = null;
      await notifier.checkStatus();
      expect(await notifier.assign(order), isTrue);
      expect(repository.assignCalls, [6, 6]);
    },
  );
  test('Hai tài xế tranh một đơn với backend giả lập: xử lý một thắng, một nhận lỗi', () async {
    final secondRepo = FakeShipperOrderRepository(
      backend: backend,
      driverId: 200,
    );
    final second = ProviderContainer(
      overrides: [shipperOrderRepositoryProvider.overrideWithValue(secondRepo)],
    );
    addTearDown(second.dispose);
    addTearDown(secondRepo.service.close);
    final order = backend.orders[6]!;
    final outcomes = await Future.wait([
      notifier
          .assign(order)
          .then((value) => value, onError: (Object error) => false),
      second
          .read(provider.notifier)
          .assign(order)
          .then((value) => value, onError: (Object error) => false),
    ]);
    expect(outcomes.where((result) => result).length, 1);
    expect(backend.orders[6]!.status, 'SHIPPING');
    expect(
      (await repository.getMyDeliveries()).length +
          (await secondRepo.getMyDeliveries()).length,
      1,
    );
  });
  test('Đơn khác hãng bị backend từ chối trước PUT', () async {
    backend.orders[6] = makeShipperOrder(companyId: 2);
    await expectLater(
      notifier.assign(backend.orders[6]!),
      throwsA(
        isA<ShipperOrderException>().having(
          (error) => error.statusCode,
          'code',
          403,
        ),
      ),
    );
    expect(repository.assignCalls, isEmpty);
  });
}
