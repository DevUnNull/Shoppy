import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoppy/features/seller_orders/models/seller_order_status.dart';
import 'package:shoppy/features/seller_orders/models/seller_orders_page.dart';
import 'package:shoppy/features/seller_orders/providers/seller_orders_provider.dart';
import 'package:shoppy/features/seller_orders/services/seller_order_service.dart';
import 'package:shoppy/features/seller_orders/widgets/seller_order_card.dart';
import 'package:shoppy/main.dart';

import 'helpers/seller_order_fakes.dart';

Future<void> openApp(
  WidgetTester tester,
  FakeSellerOrderRepository repository,
) async {
  addTearDown(repository.service.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sellerOrderRepositoryProvider.overrideWithValue(repository)],
      child: const MyApp(),
    ),
  );
}

void main() {
  testWidgets('Hiển thị loading trang đầu, tiêu đề và đủ 6 tab', (
    tester,
  ) async {
    final pending = Completer<SellerOrdersPage>();
    final repository = FakeSellerOrderRepository()
      ..onGetOrders = (status, page) => pending.future;
    await openApp(tester, repository);
    await tester.pump();
    expect(find.text('Đơn hàng Shop'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Chờ lấy hàng'), findsOneWidget);
    expect(repository.listCalls, ['PENDING:0']);
    pending.complete(
      const SellerOrdersPage(orders: [], page: 0, hasNext: false),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chưa có đơn chờ xác nhận.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mỗi tab gọi đúng status và trang 0', (tester) async {
    final repository = FakeSellerOrderRepository();
    await openApp(tester, repository);
    await tester.pumpAndSettle();
    for (final status in SellerOrderStatus.values.skip(1)) {
      await tester.ensureVisible(find.text(status.label));
      await tester.tap(find.text(status.label));
      await tester.pumpAndSettle();
      expect(repository.listCalls.last, '${status.value}:0');
      expect(
        find.text('Chưa có đơn ${status.label.toLowerCase()}.'),
        findsOneWidget,
      );
    }
  });

  testWidgets('Tên dài ở màn hình hẹp không tràn, mở đúng ID chi tiết', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeSellerOrderRepository(
      orders: [
        makeOrder(
          id: 9,
          name: 'Nguyễn Thị Hoàng Minh Anh tên người nhận rất dài để kiểm tra bố cục trên màn hình nhỏ',
        ),
      ],
    );
    await openApp(tester, repository);
    await tester.pumpAndSettle();
    expect(find.text('Đơn #9'), findsOneWidget);
    expect(find.text(formatOrderMoney(930000)), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(SellerOrderCard));
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết đơn #9'), findsOneWidget);
    expect(repository.detailCalls.last, 9);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Quay lại từ chi tiết tải mới: đơn đã đổi trạng thái sang đúng tab',
    (tester) async {
      final repository = FakeSellerOrderRepository(orders: [makeOrder()]);
      await openApp(tester, repository);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SellerOrderCard));
      await tester.pumpAndSettle();
      // Giả lập backend cập nhật trạng thái khi người dùng đang xem chi tiết.
      repository.orders = [makeOrder(status: 'PROCESSING')];
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Chưa có đơn chờ xác nhận.'), findsOneWidget);
      expect(
        repository.listCalls.where((call) => call == 'PENDING:0').length,
        2,
      );
      await tester.tap(find.text('Đang chuẩn bị'));
      await tester.pumpAndSettle();
      expect(find.byType(SellerOrderCard), findsOneWidget);
      expect(find.text('Đơn #6'), findsOneWidget);
      expect(repository.listCalls.last, 'PROCESSING:0');
    },
  );

  testWidgets('Tên người nhận lấy từ API chi tiết, có thử lại khi lỗi', (
    tester,
  ) async {
    var fail = true;
    final repository = FakeSellerOrderRepository(orders: [makeOrder()])
      ..onGetDetail = (id) async {
        if (fail) {
          throw const SellerOrderException('Không có quyền xem chi tiết');
        }
        return makeOrder(name: 'Nguyễn Văn A');
      };
    await openApp(tester, repository);
    await tester.pumpAndSettle();
    expect(find.textContaining('Không tải được người nhận.'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Thử lại tên người nhận'));
    await tester.pumpAndSettle();
    expect(find.text('Nguyễn Văn A'), findsOneWidget);
    expect(repository.detailCalls, [6, 6]);
  });

  testWidgets('Lỗi trang đầu có nút thử lại và tải được sau đó', (
    tester,
  ) async {
    final repository = FakeSellerOrderRepository()
      ..onGetOrders = (status, page) async =>
          throw const SellerOrderException('Token không hợp lệ');
    await openApp(tester, repository);
    await tester.pumpAndSettle();
    expect(find.text('Token không hợp lệ'), findsOneWidget);
    repository.onGetOrders = null;
    repository.orders = [makeOrder(name: 'Nguyễn Văn A')];
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.byType(SellerOrderCard), findsOneWidget);
    expect(find.text('Token không hợp lệ'), findsNothing);
  });

  testWidgets('Danh sách trống vẫn kéo xuống làm mới được', (tester) async {
    final repository = FakeSellerOrderRepository();
    await openApp(tester, repository);
    await tester.pumpAndSettle();
    repository.orders = [makeOrder(name: 'Nguyễn Văn A')];
    await tester.drag(find.byType(ListView), const Offset(0, 350));
    await tester.pumpAndSettle();
    expect(repository.listCalls, ['PENDING:0', 'PENDING:0']);
    expect(find.byType(SellerOrderCard), findsOneWidget);
  });

  testWidgets('Cuộn cuối tải trang tiếp, có loading và giữ đơn cũ khi lỗi', (
    tester,
  ) async {
    final nextPage = Completer<SellerOrdersPage>();
    final orders = List.generate(
      10,
      (index) => makeOrder(id: index + 1, name: 'Người nhận $index'),
    );
    final repository = FakeSellerOrderRepository(orders: orders)
      ..onGetOrders = (status, page) async => page == 0
          ? SellerOrdersPage(orders: orders, page: 0, hasNext: true)
          : nextPage.future;
    await openApp(tester, repository);
    await tester.pumpAndSettle();
    final list = tester.widget<ListView>(find.byType(ListView));
    list.controller!.jumpTo(list.controller!.position.maxScrollExtent);
    await tester.pump();
    await tester.pump();
    expect(repository.listCalls, ['PENDING:0', 'PENDING:1']);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    nextPage.completeError(
      const SellerOrderException('Mất kết nối khi tải thêm'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mất kết nối khi tải thêm'), findsOneWidget);
    expect(find.byType(SellerOrderCard), findsWidgets);
    expect(repository.listCalls.length, 2);
    repository.onGetOrders = (status, page) async => SellerOrdersPage(
      orders: [
        makeOrder(id: 10, name: 'Bản cập nhật'),
        makeOrder(id: 11, name: 'Người nhận mới'),
      ],
      page: 1,
      hasNext: false,
    );
    await tester.ensureVisible(find.text('Thử lại'));
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(SellerOrderCard).first);
    final state = ProviderScope.containerOf(context).read(sellerOrdersProvider);
    expect(state.orders.length, 11);
    expect(state.orders.map((order) => order.id).toSet().length, 11);
    expect(state.loadMoreError, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
