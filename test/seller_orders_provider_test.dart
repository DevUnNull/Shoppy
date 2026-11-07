import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoppy/features/seller_orders/models/seller_order_status.dart';
import 'package:shoppy/features/seller_orders/models/seller_orders_page.dart';
import 'package:shoppy/features/seller_orders/providers/seller_orders_provider.dart';
import 'package:shoppy/features/seller_orders/services/seller_order_service.dart';

import 'helpers/seller_order_fakes.dart';

void main() {
  late FakeSellerOrderRepository repository;
  late ProviderContainer container;
  late SellerOrdersNotifier notifier;

  setUp(() {
    repository = FakeSellerOrderRepository();
    container = ProviderContainer(
      overrides: [sellerOrderRepositoryProvider.overrideWithValue(repository)],
    );
    container.listen(sellerOrdersProvider, (previous, next) {});
    notifier = container.read(sellerOrdersProvider.notifier);
  });

  tearDown(() {
    container.dispose();
    repository.service.close();
  });

  test('Tab cũ trả về muộn không ghi đè tab mới', () async {
    final pending = Completer<SellerOrdersPage>();
    final processing = Completer<SellerOrdersPage>();
    repository.onGetOrders = (status, page) =>
        status == 'PENDING' ? pending.future : processing.future;
    final first = notifier.selectStatus(SellerOrderStatus.pending);
    final second = notifier.selectStatus(SellerOrderStatus.processing);
    expect(container.read(sellerOrdersProvider).orders, isEmpty);
    processing.complete(
      SellerOrdersPage(
        orders: [makeOrder(id: 2, status: 'PROCESSING')],
        page: 0,
        hasNext: false,
      ),
    );
    await second;
    pending.complete(
      SellerOrdersPage(orders: [makeOrder(id: 1)], page: 0, hasNext: false),
    );
    await first;
    final state = container.read(sellerOrdersProvider);
    expect(state.status, SellerOrderStatus.processing);
    expect(state.orders.single.id, 2);
    expect(repository.listCalls, ['PENDING:0', 'PROCESSING:0']);
  });

  test('Lỗi của tab cũ cũng không ghi đè dữ liệu tab mới', () async {
    final old = Completer<SellerOrdersPage>();
    repository.onGetOrders = (status, page) async {
      if (status == 'PENDING') return old.future;
      return SellerOrdersPage(
        orders: [makeOrder(status: 'SHIPPING')],
        page: 0,
        hasNext: false,
      );
    };
    final first = notifier.selectStatus(SellerOrderStatus.pending);
    await notifier.selectStatus(SellerOrderStatus.shipping);
    old.completeError(const SellerOrderException('Lỗi tab cũ'));
    await first;
    expect(container.read(sellerOrdersProvider).error, isEmpty);
    expect(
      container.read(sellerOrdersProvider).orders.single.status,
      'SHIPPING',
    );
  });

  test('Nối trang, loại trùng ID và giữ đúng trạng thái tab', () async {
    repository.onGetOrders = (status, page) async => SellerOrdersPage(
      orders: page == 0
          ? [makeOrder(id: 1), makeOrder(id: 1), makeOrder(id: 2)]
          : [
              makeOrder(id: 2, name: 'Tên cập nhật'),
              makeOrder(id: 3),
              makeOrder(id: 99, status: 'CANCELLED'),
            ],
      page: page,
      hasNext: page == 0,
    );
    await notifier.refresh();
    await notifier.loadMore();
    final state = container.read(sellerOrdersProvider);
    expect(state.orders.map((order) => order.id), [1, 2, 3]);
    expect(state.orders[1].recipientName, 'Tên cập nhật');
    expect(state.page, 1);
    expect(state.hasNext, isFalse);
    await notifier.loadMore();
    expect(repository.listCalls, ['PENDING:0', 'PENDING:1']);
  });

  test('Chặn tải thêm nhiều lần cùng lúc', () async {
    final nextPage = Completer<SellerOrdersPage>();
    repository.onGetOrders = (status, page) async => page == 0
        ? SellerOrdersPage(orders: [makeOrder()], page: 0, hasNext: true)
        : nextPage.future;
    await notifier.refresh();
    final first = notifier.loadMore();
    await notifier.loadMore();
    expect(container.read(sellerOrdersProvider).isLoadingMore, isTrue);
    expect(repository.listCalls, ['PENDING:0', 'PENDING:1']);
    nextPage.complete(
      SellerOrdersPage(orders: [makeOrder(id: 7)], page: 1, hasNext: false),
    );
    await first;
    expect(container.read(sellerOrdersProvider).orders.length, 2);
  });

  test('Làm mới bắt đầu từ page 0 và bỏ response tải thêm cũ', () async {
    final nextPage = Completer<SellerOrdersPage>();
    var refreshCount = 0;
    repository.onGetOrders = (status, page) async {
      if (page == 1) return nextPage.future;
      refreshCount++;
      return SellerOrdersPage(
        orders: [makeOrder(id: refreshCount)],
        page: 0,
        hasNext: refreshCount == 1,
      );
    };
    await notifier.refresh();
    final loadMore = notifier.loadMore();
    await notifier.refresh();
    nextPage.complete(
      SellerOrdersPage(orders: [makeOrder(id: 99)], page: 1, hasNext: false),
    );
    await loadMore;
    expect(container.read(sellerOrdersProvider).orders.single.id, 2);
    expect(container.read(sellerOrdersProvider).page, 0);
    expect(repository.listCalls, ['PENDING:0', 'PENDING:1', 'PENDING:0']);
  });

  test('Lỗi tải thêm giữ trang cũ, thử lại đúng trang bị lỗi', () async {
    var fail = true;
    repository.onGetOrders = (status, page) async {
      if (page == 1 && fail) throw const SellerOrderException('Mất mạng');
      return SellerOrdersPage(
        orders: [makeOrder(id: page + 1)],
        page: page,
        hasNext: page == 0,
      );
    };
    await notifier.refresh();
    await notifier.loadMore();
    expect(container.read(sellerOrdersProvider).orders.single.id, 1);
    expect(container.read(sellerOrdersProvider).page, 0);
    expect(container.read(sellerOrdersProvider).loadMoreError, 'Mất mạng');
    fail = false;
    await notifier.loadMore();
    expect(
      container.read(sellerOrdersProvider).orders.map((order) => order.id),
      [1, 2],
    );
    expect(container.read(sellerOrdersProvider).loadMoreError, isEmpty);
    expect(repository.listCalls, ['PENDING:0', 'PENDING:1', 'PENDING:1']);
  });

  test('Đổi tab sau khi phân trang xóa dữ liệu và tải từ page 0', () async {
    repository.orders = List.generate(12, (index) => makeOrder(id: index));
    await notifier.refresh();
    await notifier.loadMore();
    await notifier.selectStatus(SellerOrderStatus.readyToShip);
    expect(container.read(sellerOrdersProvider).orders, isEmpty);
    expect(container.read(sellerOrdersProvider).page, 0);
    expect(repository.listCalls.last, 'READY_TO_SHIP:0');
  });

  test('Lỗi trang đầu có thể thử lại', () async {
    repository.onGetOrders = (status, page) async =>
        throw const SellerOrderException('Token hết hạn');
    await notifier.refresh();
    expect(container.read(sellerOrdersProvider).error, 'Token hết hạn');
    expect(container.read(sellerOrdersProvider).isLoading, isFalse);
    repository.onGetOrders = null;
    repository.orders = [makeOrder()];
    await notifier.refresh();
    expect(container.read(sellerOrdersProvider).error, isEmpty);
    expect(container.read(sellerOrdersProvider).orders.single.id, 6);
  });
}
