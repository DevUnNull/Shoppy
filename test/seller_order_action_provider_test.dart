import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoppy/features/seller_orders/models/seller_order.dart';
import 'package:shoppy/features/seller_orders/models/seller_order_status.dart';
import 'package:shoppy/features/seller_orders/providers/seller_order_action_provider.dart';
import 'package:shoppy/features/seller_orders/providers/seller_orders_provider.dart';
import 'package:shoppy/features/seller_orders/services/seller_order_service.dart';

import 'helpers/seller_order_fakes.dart';

void main() {
  late FakeSellerOrderRepository repository;
  late ProviderContainer container;
  late SellerOrderActionNotifier notifier;
  final detailProvider = sellerOrderDetailProvider(6);

  setUp(() async {
    repository = FakeSellerOrderRepository(
      orders: [makeOrder(status: 'PROCESSING')],
    );
    container = ProviderContainer(
      overrides: [sellerOrderRepositoryProvider.overrideWithValue(repository)],
    );
    container.listen(sellerOrderActionProvider, (previous, next) {});
    container.listen(detailProvider, (previous, next) {});
    notifier = container.read(sellerOrderActionProvider.notifier);
    await container.read(detailProvider.future);
  });

  tearDown(() {
    container.dispose();
    repository.service.close();
  });

  test('Đóng gói tải lại trạng thái và hành trình từ backend', () async {
    expect(await notifier.readyToShip(repository.orders.single), isTrue);
    final order = container.read(detailProvider).requireValue;
    expect(order.status, 'READY_TO_SHIP');
    expect(order.trackings.last.description, 'Shop đã đóng gói xong');
    expect(repository.readyCalls, [6]);
    expect(repository.detailCalls, [6, 6]);
    expect(container.read(sellerOrderActionProvider).isBusy, isFalse);
  });

  test(
    'Hủy đơn WALLET gửi lý do, đọc trạng thái mới và giữ nguyên tổng tiền',
    () async {
      repository.orders = [
        makeOrder(status: 'PROCESSING', paymentMethod: 'WALLET'),
      ];
      expect(
        await notifier.cancelOrder(
          repository.orders.single,
          '  Shop hết hàng màu trắng  ',
        ),
        isTrue,
      );
      final order = container.read(detailProvider).requireValue;
      expect(order.status, 'CANCELLED');
      expect(order.paymentMethod, 'WALLET');
      expect(order.grandTotal, 930000);
      expect(repository.cancelCalls, [
        {'id': 6, 'reason': 'Shop hết hàng màu trắng'},
      ]);
      expect(order.trackings.last.description, 'Shop đã hủy đơn do hết hàng');
    },
  );

  for (final status in SellerOrderStatus.values.where(
    (value) => value.value != 'PROCESSING',
  )) {
    test('Không gửi cả hai thao tác cho ${status.value}', () async {
      final order = makeOrder(status: status.value);
      await expectLater(
        notifier.readyToShip(order),
        throwsA(isA<SellerOrderException>()),
      );
      await expectLater(
        notifier.cancelOrder(order, 'Shop hết hàng'),
        throwsA(isA<SellerOrderException>()),
      );
      expect(repository.readyCalls, isEmpty);
      expect(repository.cancelCalls, isEmpty);
    });
  }

  test('Bấm lặp/cả hai thao tác trong lúc gửi chỉ có một yêu cầu', () async {
    final pending = Completer<void>();
    repository.onReady = (id) => pending.future;
    final order = repository.orders.single;
    final first = notifier.readyToShip(order);
    expect(container.read(sellerOrderActionProvider).isBusy, isTrue);
    expect(await notifier.readyToShip(order), isFalse);
    expect(await notifier.cancelOrder(order, 'Shop hết hàng'), isFalse);
    expect(repository.readyCalls, [6]);
    expect(repository.cancelCalls, isEmpty);
    repository.orders = [changedOrder(order, 'READY_TO_SHIP')];
    pending.complete();
    await first;
  });

  test('Khóa thao tác cho đến khi GET tải lại hoàn tất', () async {
    final pending = Completer<SellerOrder>();
    repository.onGetDetail = (id) => pending.future;
    final order = repository.orders.single;
    final first = notifier.readyToShip(order);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(sellerOrderActionProvider).isBusy, isTrue);
    expect(await notifier.cancelOrder(order, 'Shop hết hàng'), isFalse);
    pending.complete(repository.orders.single);
    await first;
    expect(container.read(sellerOrderActionProvider).isBusy, isFalse);
  });

  test(
    'PUT lỗi giữ dữ liệu, không tự chuyển trạng thái và cho thử lại',
    () async {
      repository.onCancel = (id, reason) async =>
          throw const SellerOrderException('Không hủy được đơn');
      final order = repository.orders.single;
      await expectLater(
        notifier.cancelOrder(order, 'Shop hết hàng'),
        throwsA(isA<SellerOrderException>()),
      );
      expect(container.read(detailProvider).requireValue.status, 'PROCESSING');
      expect(container.read(sellerOrderActionProvider).isBusy, isFalse);
      repository.onCancel = null;
      expect(await notifier.cancelOrder(order, 'Shop hết hàng'), isTrue);
      expect(container.read(detailProvider).requireValue.status, 'CANCELLED');
    },
  );

  test('Đơn đổi trạng thái nơi khác: báo lỗi và tải lại dữ liệu mới', () async {
    final oldOrder = repository.orders.single;
    repository.orders = [changedOrder(oldOrder, 'SHIPPING')];
    await expectLater(
      notifier.readyToShip(oldOrder),
      throwsA(isA<SellerOrderException>()),
    );
    expect(container.read(detailProvider).requireValue.status, 'SHIPPING');
    expect(repository.detailCalls, [6, 6]);
  });

  test(
    'Mất kết nối sau khi backend đã xử lý: lấy đúng trạng thái thực tế',
    () async {
      repository.onReady = (id) async {
        repository.orders = [
          changedOrder(repository.orders.single, 'READY_TO_SHIP'),
        ];
        throw const SellerOrderException('Không kết nối được máy chủ');
      };
      await expectLater(
        notifier.readyToShip(repository.orders.single),
        throwsA(isA<SellerOrderException>()),
      );
      expect(
        container.read(detailProvider).requireValue.status,
        'READY_TO_SHIP',
      );
      expect(repository.readyCalls, [6]);
    },
  );

  test(
    'PUT thành công nhưng GET lỗi: giữ dữ liệu cũ, chỉ cho tải lại',
    () async {
      repository.onGetDetail = (id) async =>
          throw const SellerOrderException('Mất mạng khi tải lại');
      final oldOrder = repository.orders.single;
      await expectLater(
        notifier.readyToShip(oldOrder),
        throwsA(
          isA<SellerOrderException>().having(
            (error) => error.message,
            'message',
            contains('Backend đã xác nhận'),
          ),
        ),
      );
      expect(container.read(detailProvider).requireValue.status, 'PROCESSING');
      expect(container.read(sellerOrderActionProvider).needsReload, isTrue);
      expect(await notifier.readyToShip(oldOrder), isFalse);
      expect(repository.readyCalls, [6]);
      repository.onGetDetail = null;
      await notifier.reloadDetail(6);
      expect(
        container.read(detailProvider).requireValue.status,
        'READY_TO_SHIP',
      );
      expect(container.read(sellerOrderActionProvider).needsReload, isFalse);
    },
  );

  for (final code in [401, 403]) {
    test('Lỗi quyền HTTP $code không tự đổi trạng thái', () async {
      repository.onReady = (id) async =>
          throw SellerOrderException('Lỗi quyền $code', statusCode: code);
      await expectLater(
        notifier.readyToShip(repository.orders.single),
        throwsA(isA<SellerOrderException>()),
      );
      expect(container.read(detailProvider).requireValue.status, 'PROCESSING');
      expect(container.read(sellerOrderActionProvider).isBusy, isFalse);
    });
  }
}
