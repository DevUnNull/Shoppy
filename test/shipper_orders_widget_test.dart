import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoppy/features/shipper_orders/models/shipper_order.dart';
import 'package:shoppy/features/shipper_orders/providers/shipper_orders_provider.dart';
import 'package:shoppy/features/shipper_orders/screens/shipper_order_detail_screen.dart';
import 'package:shoppy/features/shipper_orders/screens/shipper_orders_screen.dart';
import 'package:shoppy/features/shipper_orders/services/shipper_order_service.dart';
import 'package:shoppy/features/shipper_orders/widgets/pickup_location.dart';
import 'package:shoppy/features/shipper_orders/widgets/shipper_order_card.dart';
import 'package:shoppy/features/shipper_orders/widgets/shipper_order_widgets.dart';

import 'helpers/shipper_order_fakes.dart';

Future<void> openShipper(
  WidgetTester tester,
  FakeShipperOrderRepository repository, {
  bool detail = false,
}) async {
  addTearDown(repository.service.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [shipperOrderRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        home: detail
            ? const ShipperOrderDetailScreen(orderId: 6)
            : const ShipperOrdersScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

FakeShipperOrderRepository repoWith(List<ShipperOrder> orders) =>
    FakeShipperOrderRepository(backend: FakeShipperBackend(orders));

void main() {
  testWidgets(
    'Danh sách hiển thị đúng tên người nhận, địa chỉ, COD và nút nhận',
    (tester) async {
      final repository = repoWith([makeShipperOrder()]);
      await openShipper(tester, repository);
      expect(find.text('Đơn chờ nhận'), findsOneWidget);
      expect(find.text('Đơn #6'), findsOneWidget);
      expect(find.text('Nguyễn Văn A'), findsOneWidget);
      expect(find.textContaining('123 Đường Nguyễn Huệ'), findsOneWidget);
      expect(find.text(shipperMoney(930000)), findsOneWidget);
      expect(find.text('Nhận đơn'), findsOneWidget);
      expect(find.text('Mở vị trí lấy hàng'), findsOneWidget);
    },
  );
  testWidgets('WALLET không hiển thị số tiền COD phải thu', (tester) async {
    await openShipper(tester, repoWith([makeShipperOrder(payment: 'WALLET')]));
    expect(find.text('Đã thanh toán qua ví — Không thu tiền'), findsOneWidget);
    expect(find.text('COD · Số tiền cần thu'), findsNothing);
    expect(find.text(shipperMoney(930000)), findsNothing);
  });
  testWidgets(
    'Danh sách trống và my-deliveries rỗng không lỗi bố cục, kéo làm mới được',
    (tester) async {
      final repository = repoWith([]);
      await openShipper(tester, repository);
      expect(find.text('Chưa có đơn chờ nhận.'), findsOneWidget);
      repository.backend.orders[6] = makeShipperOrder();
      await tester.drag(find.byType(ListView), const Offset(0, 350));
      await tester.pumpAndSettle();
      expect(find.byType(ShipperOrderCard), findsOneWidget);
      await tester.tap(find.widgetWithText(Tab, 'Đang giao'));
      await tester.pumpAndSettle();
      expect(find.text('Bạn chưa có đơn đang giao.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Loading và lỗi danh sách có nút thử lại', (tester) async {
    final pending = Completer<List<ShipperOrder>>();
    final repository = repoWith([])..onAvailable = () => pending.future;
    addTearDown(repository.service.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shipperOrderRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: ShipperOrdersScreen()),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.completeError(const ShipperOrderException('Mất mạng'));
    await tester.pumpAndSettle();
    expect(find.text('Mất mạng'), findsOneWidget);
    repository.onAvailable = null;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có đơn chờ nhận.'), findsOneWidget);
  });
  testWidgets('Nhấn thẻ mở đúng orderId, có người nhận và sản phẩm chi tiết', (
    tester,
  ) async {
    final repository = repoWith([makeShipperOrder(id: 9)]);
    await openShipper(tester, repository);
    await tester.tap(find.text('Đơn #9'));
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết đơn giao #9'), findsOneWidget);
    expect(repository.detailCalls.last, 9);
    expect(find.text('0912345678'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Giày sneaker trắng'), 300);
    expect(find.text('Phân loại: Mặc định'), findsOneWidget);
    expect(find.text('Số lượng: 2'), findsOneWidget);
  });
  for (final detail in [false, true]) {
    testWidgets(
      'Quay lại hộp thoại từ ${detail ? 'chi tiết' : 'danh sách'} không gửi PUT',
      (tester) async {
        final repository = repoWith([makeShipperOrder()]);
        await openShipper(tester, repository, detail: detail);
        await tester.tap(find.text('Nhận đơn'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Quay lại'));
        await tester.pumpAndSettle();
        expect(repository.assignCalls, isEmpty);
        expect(find.text('Nhận đơn'), findsOneWidget);
      },
    );
    testWidgets(
      'Nhận từ ${detail ? 'chi tiết' : 'danh sách'} cập nhật trạng thái và hai danh sách',
      (tester) async {
        final repository = repoWith([makeShipperOrder()]);
        await openShipper(tester, repository);
        if (detail) {
          await tester.tap(find.text('Đơn #6'));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('Nhận đơn'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Xác nhận nhận đơn'));
        await tester.pumpAndSettle();
        expect(repository.assignCalls, [6]);
        expect(find.text('Nhận đơn thành công'), findsOneWidget);
        expect(find.text('Nhận đơn'), findsNothing);
        if (detail) {
          expect(find.text('Đang giao'), findsWidgets);
          await tester.pageBack();
          await tester.pumpAndSettle();
        }
        expect(find.text('Chưa có đơn chờ nhận.'), findsOneWidget);
        await tester.tap(find.widgetWithText(Tab, 'Đang giao'));
        await tester.pumpAndSettle();
        expect(find.text('Đơn #6'), findsOneWidget);
        expect(find.text('Nhận đơn'), findsNothing);
      },
    );
  }
  testWidgets('Nhấn nhận và xác nhận liên tục chỉ gửi một PUT', (tester) async {
    final pending = Completer<void>();
    final repository = repoWith([makeShipperOrder()])
      ..onAssign = (id) => pending.future;
    await openShipper(tester, repository);
    await tester.tap(find.text('Nhận đơn'));
    await tester.tap(find.text('Nhận đơn'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Xác nhận nhận đơn'));
    await tester.tap(find.text('Xác nhận nhận đơn'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 400));
    expect(repository.assignCalls, [6]);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Đang xử lý…'),
          )
          .onPressed,
      isNull,
    );
    repository.backend.orders[6] = makeShipperOrder(
      status: 'SHIPPING',
      driverId: 100,
    );
    pending.complete();
    await tester.pumpAndSettle();
    expect(repository.assignCalls, [6]);
  });
  testWidgets('Lỗi nhận đơn không tự chuyển trạng thái và có thể thử lại', (
    tester,
  ) async {
    final repository = repoWith([makeShipperOrder()])
      ..onAssign = (id) async =>
          throw const ShipperOrderException('Backend từ chối nhận đơn');
    await openShipper(tester, repository, detail: true);
    await tester.tap(find.text('Nhận đơn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận nhận đơn'));
    await tester.pumpAndSettle();
    expect(find.text('Backend từ chối nhận đơn'), findsOneWidget);
    expect(find.text('Chờ lấy hàng'), findsOneWidget);
    expect(find.text('Nhận đơn'), findsOneWidget);
  });
  testWidgets('Đơn khác hãng bị từ chối chi tiết và không có nút nhận', (
    tester,
  ) async {
    final repository = repoWith([makeShipperOrder(companyId: 2)]);
    await openShipper(tester, repository);
    expect(find.byType(ShipperOrderCard), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await openShipper(tester, repository, detail: true);
    expect(find.text('Không có quyền xem đơn khác hãng'), findsOneWidget);
    expect(find.text('Nhận đơn'), findsNothing);
  });
  testWidgets('Quay lại từ chi tiết không giữ đơn đã đổi trạng thái', (
    tester,
  ) async {
    final repository = repoWith([makeShipperOrder()]);
    await openShipper(tester, repository);
    await tester.tap(find.text('Đơn #6'));
    await tester.pumpAndSettle();
    repository.backend.orders[6] = makeShipperOrder(status: 'CANCELLED');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Chưa có đơn chờ nhận.'), findsOneWidget);
  });
  testWidgets(
    'Chuyển tab khi response cũ còn chờ không hiển thị nhầm dữ liệu',
    (tester) async {
      final old = Completer<List<ShipperOrder>>();
      final repository = repoWith([])..onAvailable = () => old.future;
      addTearDown(repository.service.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shipperOrderRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(home: ShipperOrdersScreen()),
        ),
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(Tab, 'Đang giao'));
      await tester.pumpAndSettle();
      old.complete([makeShipperOrder()]);
      await tester.pumpAndSettle();
      expect(find.text('Đơn đang giao'), findsOneWidget);
      expect(find.text('Bạn chưa có đơn đang giao.'), findsOneWidget);
      expect(find.byType(ShipperOrderCard), findsNothing);
    },
  );
  testWidgets('Địa chỉ dài và nhiều sản phẩm không tràn ở màn hình nhỏ', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final json = shipperOrderJson();
    json['recipientName'] =
        'Nguyễn Thị Minh Anh có tên người nhận rất dài để kiểm tra bố cục';
    json['shippingAddress'] = List.filled(
      8,
      'Đường Nguyễn Huệ, TP.HCM',
    ).join(', ');
    json['items'] = List.generate(
      20,
      (index) => {
        'productNameSnapshot': 'Sản phẩm $index',
        'variantNameSnapshot': 'Mặc định',
        'quantity': 2,
      },
    );
    final repository = repoWith([ShipperOrder.fromJson(json)]);
    await openShipper(tester, repository);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Đơn #6'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Sản phẩm 19'), 300);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Mở đúng link Maps API trả về, có xử lý mở thất bại', (
    tester,
  ) async {
    Uri? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PickupLocation(
            address: pickupUrl,
            openUrl: (uri) async {
              opened = uri;
              return false;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mở vị trí lấy hàng'));
    await tester.pumpAndSettle();
    expect(opened.toString(), pickupUrl);
    expect(
      find.text('Không mở được bản đồ. Bạn có thể sao chép địa chỉ lấy hàng.'),
      findsOneWidget,
    );
    expect(pickupMapUri('javascript:alert(1)'), isNull);
    expect(pickupMapUri('123 Nguyễn Huệ'), isNull);
    expect(pickupMapUri(null), isNull);
  });
}
