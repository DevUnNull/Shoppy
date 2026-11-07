import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoppy/features/shipper_orders/providers/shipper_orders_provider.dart';
import 'package:shoppy/features/shipper_orders/screens/shipper_order_detail_screen.dart';
import 'package:shoppy/features/shipper_orders/screens/shipper_orders_screen.dart';
import 'package:shoppy/features/shipper_orders/services/shipper_order_service.dart';
import 'package:shoppy/features/shipper_orders/widgets/shipper_order_widgets.dart';

import 'helpers/shipper_order_fakes.dart';

const deliveryText = 'Xác nhận giao thành công';
FakeShipperOrderRepository deliveryRepo({
  String status = 'SHIPPING',
  String payment = 'COD',
  int driverId = 100,
}) => FakeShipperOrderRepository(
  backend: FakeShipperBackend([
    makeShipperOrder(status: status, payment: payment, driverId: driverId),
  ]),
);

Future<void> openDelivery(
  WidgetTester tester,
  FakeShipperOrderRepository repository, {
  bool list = false,
}) async {
  addTearDown(repository.service.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [shipperOrderRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        home: list
            ? const ShipperOrdersScreen()
            : const ShipperOrderDetailScreen(orderId: 6),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> confirmDelivery(WidgetTester tester, {bool cod = true}) async {
  await tester.tap(find.text(deliveryText));
  await tester.pumpAndSettle();
  if (cod) {
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
  }
  await tester.tap(find.text('Xác nhận'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Chỉ đơn SHIPPING thuộc tài xế hiện tại có nút giao thành công', (
    tester,
  ) async {
    await openDelivery(tester, deliveryRepo());
    expect(find.text(deliveryText), findsOneWidget);
  });
  for (final status in [
    'PENDING',
    'PROCESSING',
    'READY_TO_SHIP',
    'DELIVERED',
    'CANCELLED',
  ]) {
    testWidgets('Không hiển thị nút giao với $status', (tester) async {
      final repository = deliveryRepo(status: status);
      await openDelivery(tester, repository);
      expect(find.text(deliveryText), findsNothing);
      expect(repository.deliveredCalls, isEmpty);
    });
  }
  testWidgets('Không hiển thị nút cho đơn của tài xế khác cùng hãng', (
    tester,
  ) async {
    final repository = deliveryRepo(driverId: 200);
    await openDelivery(tester, repository);
    expect(find.text(deliveryText), findsNothing);
    expect(repository.deliveredCalls, isEmpty);
  });
  testWidgets('COD đúng số tiền, chưa tích thu đủ thì nút xác nhận bị khóa', (
    tester,
  ) async {
    final repository = deliveryRepo();
    await openDelivery(tester, repository);
    await tester.tap(find.text(deliveryText));
    await tester.pumpAndSettle();
    expect(find.text('Xác nhận đã giao hàng cho người nhận?'), findsOneWidget);
    expect(
      find.text('Số tiền COD cần thu: ${shipperMoney(930000)}'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Xác nhận'))
          .onPressed,
      isNull,
    );
    expect(repository.deliveredCalls, isEmpty);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Xác nhận'))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Quay lại'));
    await tester.pumpAndSettle();
    expect(repository.deliveredCalls, isEmpty);
  });
  for (final payment in ['COD', 'WALLET']) {
    testWidgets('Quay lại hộp thoại $payment không gửi PUT hay ghi tiền', (
      tester,
    ) async {
      final repository = deliveryRepo(payment: payment);
      await openDelivery(tester, repository);
      await tester.tap(find.text(deliveryText));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quay lại'));
      await tester.pumpAndSettle();
      expect(repository.deliveredCalls, isEmpty);
      expect(repository.backend.collections, isEmpty);
    });
  }
  testWidgets('Giao COD thành công cập nhật DELIVERED, tracking, ẩn nút', (
    tester,
  ) async {
    final repository = deliveryRepo();
    await openDelivery(tester, repository);
    await confirmDelivery(tester);
    expect(repository.deliveredCalls, [6]);
    expect(find.text('Đã giao'), findsOneWidget);
    expect(find.text('Giao hàng thành công'), findsWidgets);
    expect(find.text(deliveryText), findsNothing);
    expect(repository.backend.collections, hasLength(1));
    expect(tester.takeException(), isNull);
  });
  testWidgets('WALLET nhắc không thu tiền, không checkbox và không tăng COD', (
    tester,
  ) async {
    final repository = deliveryRepo(payment: 'WALLET');
    await openDelivery(tester, repository);
    await tester.tap(find.text(deliveryText));
    await tester.pumpAndSettle();
    expect(
      find.text('Khách đã thanh toán qua ví — Không thu tiền'),
      findsOneWidget,
    );
    expect(find.byType(CheckboxListTile), findsNothing);
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(find.text('Đã giao'), findsOneWidget);
    expect(repository.backend.collections, isEmpty);
    expect(repository.backend.codBalances[100] ?? 0, 0);
  });
  testWidgets('Nhấn liên tục chỉ gửi một PUT, hiện loading và khóa nút', (
    tester,
  ) async {
    final pending = Completer<void>();
    final repository = deliveryRepo()..onDelivered = (id) => pending.future;
    await openDelivery(tester, repository);
    await tester.tap(find.text(deliveryText));
    await tester.tap(find.text(deliveryText), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.text('Xác nhận'));
    await tester.tap(find.text('Xác nhận'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 400));
    expect(repository.deliveredCalls, [6]);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Đang xử lý…'),
          )
          .onPressed,
      isNull,
    );
    repository.backend.completeDelivery(6, 100, 1);
    pending.complete();
    await tester.pumpAndSettle();
    expect(repository.deliveredCalls, [6]);
    expect(repository.backend.collections, hasLength(1));
  });
  testWidgets('API lỗi giữ SHIPPING và cho phép thử lại, không ghi tiền', (
    tester,
  ) async {
    final repository = deliveryRepo()
      ..onDelivered = (id) async =>
          throw const ShipperOrderException('Backend từ chối giao');
    await openDelivery(tester, repository);
    await confirmDelivery(tester);
    expect(find.text('Backend từ chối giao'), findsOneWidget);
    expect(find.text('Đang giao'), findsOneWidget);
    expect(find.text(deliveryText), findsOneWidget);
    expect(repository.backend.collections, isEmpty);
  });
  testWidgets('Đơn đã giao ở nơi khác thì tải lại và không gửi PUT lần nữa', (
    tester,
  ) async {
    final repository = deliveryRepo();
    await openDelivery(tester, repository);
    await tester.tap(find.text(deliveryText));
    await tester.pumpAndSettle();
    repository.backend.completeDelivery(6, 100, 1);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(find.text('Đã giao'), findsOneWidget);
    expect(repository.deliveredCalls, isEmpty);
    expect(repository.backend.collections, hasLength(1));
  });
  testWidgets(
    'Timeout GET lỗi giữ thông tin, phải kiểm tra trước khi gửi tiếp',
    (tester) async {
      final repository = deliveryRepo();
      repository.onDelivered = (id) async {
        repository.onDetail = (id) async =>
            throw const ShipperOrderException('Mất mạng');
        throw const ShipperOrderException('Timeout', isTimeout: true);
      };
      await openDelivery(tester, repository);
      await confirmDelivery(tester);
      expect(find.text('Kiểm tra lại trạng thái'), findsOneWidget);
      expect(find.text(deliveryText), findsNothing);
      expect(find.text('Nguyễn Văn A'), findsOneWidget);
      repository.onDetail = null;
      repository.onDelivered = null;
      await tester.tap(find.text('Kiểm tra lại trạng thái'));
      await tester.pumpAndSettle();
      expect(find.text(deliveryText), findsOneWidget);
      expect(repository.deliveredCalls, [6]);
    },
  );
  testWidgets('Quay về: xóa khỏi Đang giao, xuất hiện trong lịch sử chỉ xem', (
    tester,
  ) async {
    final repository = deliveryRepo();
    await openDelivery(tester, repository, list: true);
    await tester.tap(find.widgetWithText(Tab, 'Đang giao'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đơn #6'));
    await tester.pumpAndSettle();
    await confirmDelivery(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Bạn chưa có đơn đang giao.'), findsOneWidget);
    await tester.tap(find.widgetWithText(Tab, 'Đã giao'));
    await tester.pumpAndSettle();
    expect(find.text('Lịch sử giao hàng'), findsOneWidget);
    expect(find.text('Đơn #6'), findsOneWidget);
    expect(repository.deliveryStatuses, contains('DELIVERED'));
    await tester.tap(find.text('Đơn #6'));
    await tester.pumpAndSettle();
    expect(find.text(deliveryText), findsNothing);
    expect(repository.deliveredCalls, [6]);
  });
  testWidgets('Hộp thoại COD trên màn hình nhỏ không tràn', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openDelivery(tester, deliveryRepo());
    await tester.tap(find.text(deliveryText));
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsOneWidget);
    expect(find.text('Quay lại').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Quay lại'));
    await tester.pumpAndSettle();
  });
}
