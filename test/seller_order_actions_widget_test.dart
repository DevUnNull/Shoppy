import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoppy/features/seller_orders/models/seller_order_status.dart';
import 'package:shoppy/features/seller_orders/providers/seller_orders_provider.dart';
import 'package:shoppy/features/seller_orders/screens/seller_order_detail_screen.dart';
import 'package:shoppy/features/seller_orders/services/seller_order_service.dart';
import 'package:shoppy/features/seller_orders/widgets/seller_order_card.dart';
import 'package:shoppy/main.dart';

import 'helpers/seller_order_fakes.dart';

const packText = 'Xác nhận đóng gói hoàn tất';
const cancelText = 'Hủy đơn do hết hàng';

Future<void> openDetail(
  WidgetTester tester,
  FakeSellerOrderRepository repository,
) async {
  addTearDown(repository.service.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sellerOrderRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: SellerOrderDetailScreen(orderId: 6)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final status in SellerOrderStatus.values) {
    testWidgets('Hai nút chỉ hiển thị với PROCESSING: ${status.value}', (
      tester,
    ) async {
      final repository = FakeSellerOrderRepository(
        orders: [makeOrder(status: status.value)],
      );
      await openDetail(tester, repository);
      expect(
        find.text(packText),
        status.value == 'PROCESSING' ? findsOneWidget : findsNothing,
      );
      expect(
        find.text(cancelText),
        status.value == 'PROCESSING' ? findsOneWidget : findsNothing,
      );
      expect(repository.readyCalls, isEmpty);
      expect(repository.cancelCalls, isEmpty);
    });
  }

  for (final cancel in [false, true]) {
    testWidgets(
      'Quay lại trong hộp thoại ${cancel ? 'hủy' : 'đóng gói'} không gửi PUT',
      (tester) async {
        final repository = FakeSellerOrderRepository(
          orders: [makeOrder(status: 'PROCESSING')],
        );
        await openDetail(tester, repository);
        await tester.tap(find.text(cancel ? cancelText : packText));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.tap(find.text('Quay lại'));
        await tester.pumpAndSettle();
        expect(repository.readyCalls, isEmpty);
        expect(repository.cancelCalls, isEmpty);
        expect(find.text(packText), findsOneWidget);
      },
    );
  }

  testWidgets(
    'Đóng gói thành công tải lại trạng thái/hành trình và ẩn hai nút',
    (tester) async {
      final repository = FakeSellerOrderRepository(
        orders: [makeOrder(status: 'PROCESSING')],
      );
      await openDetail(tester, repository);
      await tester.tap(find.text(packText));
      await tester.pumpAndSettle();
      expect(find.text('Bạn đã đóng gói xong đơn hàng này?'), findsOneWidget);
      await tester.tap(find.text('Xác nhận'));
      await tester.pumpAndSettle();
      expect(repository.readyCalls, [6]);
      expect(find.text('Chờ lấy hàng'), findsOneWidget);
      expect(find.text(packText), findsNothing);
      expect(find.text(cancelText), findsNothing);
      await tester.scrollUntilVisible(find.text('Shop đã đóng gói xong'), 300);
      expect(find.text('Shop đã đóng gói xong'), findsOneWidget);
    },
  );

  testWidgets(
    'Hủy đơn WALLET có lý do điền sẵn/chỉnh sửa được, không thay đổi số tiền',
    (tester) async {
      final repository = FakeSellerOrderRepository(
        orders: [makeOrder(status: 'PROCESSING', paymentMethod: 'WALLET')],
      );
      await openDetail(tester, repository);
      await tester.tap(find.text(cancelText));
      await tester.pumpAndSettle();
      final field = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(field.controller!.text, 'Shop hết hàng');
      await tester.enterText(
        find.byType(TextFormField),
        'Shop hết hàng size M',
      );
      await tester.tap(find.text('Xác nhận hủy'));
      await tester.pumpAndSettle();
      expect(repository.cancelCalls, [
        {'id': 6, 'reason': 'Shop hết hàng size M'},
      ]);
      expect(find.text('Đã hủy'), findsOneWidget);
      expect(find.text(packText), findsNothing);
      expect(find.text(cancelText), findsNothing);
      expect(repository.orders.single.grandTotal, 930000);
      await tester.scrollUntilVisible(
        find.text('Shop đã hủy đơn do hết hàng'),
        300,
      );
      expect(find.text('Shop đã hủy đơn do hết hàng'), findsOneWidget);
    },
  );

  testWidgets(
    'Nhấn nhanh nút và xác nhận chỉ mở một hộp thoại, gửi một PUT, khóa cả hai nút',
    (tester) async {
      final pending = Completer<void>();
      final repository = FakeSellerOrderRepository(
        orders: [makeOrder(status: 'PROCESSING')],
      )..onReady = (id) => pending.future;
      await openDetail(tester, repository);
      await tester.tap(find.text(packText));
      await tester.tap(find.text(packText), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Xác nhận'));
      // Lần nhấn thứ hai có thể bị bỏ qua vì hộp thoại đang đóng.
      await tester.tap(find.text('Xác nhận'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 400));
      expect(repository.readyCalls, [6]);
      expect(repository.cancelCalls, isEmpty);
      final packButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, packText),
      );
      final cancelButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, cancelText),
      );
      expect(packButton.onPressed, isNull);
      expect(cancelButton.onPressed, isNull);
      repository.orders = [
        changedOrder(repository.orders.single, 'READY_TO_SHIP'),
      ];
      pending.complete();
      await tester.pumpAndSettle();
      expect(repository.readyCalls, [6]);
      expect(find.text('Chi tiết đơn #6'), findsOneWidget);
    },
  );

  testWidgets(
    'Nhấn xác nhận hủy liên tục chỉ gửi một yêu cầu với lý do mặc định',
    (tester) async {
      final pending = Completer<void>();
      final repository = FakeSellerOrderRepository(
        orders: [makeOrder(status: 'PROCESSING')],
      )..onCancel = (id, reason) => pending.future;
      await openDetail(tester, repository);
      await tester.tap(find.text(cancelText));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận hủy'));
      await tester.tap(find.text('Xác nhận hủy'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 400));
      expect(repository.cancelCalls, [
        {'id': 6, 'reason': 'Shop hết hàng'},
      ]);
      expect(repository.readyCalls, isEmpty);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, packText))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, cancelText),
            )
            .onPressed,
        isNull,
      );
      repository.orders = [changedOrder(repository.orders.single, 'CANCELLED')];
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Đã hủy'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Đơn PROCESSING và hộp thoại hủy không tràn trên màn hình nhỏ', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeSellerOrderRepository(
      orders: [makeOrder(status: 'PROCESSING')],
    );
    await openDetail(tester, repository);
    expect(find.text(packText).hitTestable(), findsOneWidget);
    expect(find.text(cancelText).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text(cancelText));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('Xác nhận hủy').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Quay lại'));
    await tester.pumpAndSettle();
  });

  for (final cancel in [false, true]) {
    testWidgets(
      'PUT ${cancel ? 'hủy' : 'đóng gói'} thất bại giữ PROCESSING và cho thử lại',
      (tester) async {
        final repository = FakeSellerOrderRepository(
          orders: [makeOrder(status: 'PROCESSING')],
        );
        if (cancel) {
          repository.onCancel = (id, reason) async =>
              throw const SellerOrderException('Backend từ chối thao tác');
        } else {
          repository.onReady = (id) async =>
              throw const SellerOrderException('Backend từ chối thao tác');
        }
        await openDetail(tester, repository);
        await tester.tap(find.text(cancel ? cancelText : packText));
        await tester.pumpAndSettle();
        await tester.tap(find.text(cancel ? 'Xác nhận hủy' : 'Xác nhận'));
        await tester.pumpAndSettle();
        expect(find.text('Backend từ chối thao tác'), findsOneWidget);
        expect(find.text('Đang chuẩn bị'), findsOneWidget);
        expect(find.text(packText), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, packText))
              .onPressed,
          isNotNull,
        );
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, cancelText),
              )
              .onPressed,
          isNotNull,
        );
      },
    );
  }

  testWidgets('Đơn đã đổi nơi khác: hiển thị lỗi, tải lại và ẩn nút', (
    tester,
  ) async {
    final repository = FakeSellerOrderRepository(
      orders: [makeOrder(status: 'PROCESSING')],
    );
    await openDetail(tester, repository);
    await tester.tap(find.text(packText));
    await tester.pumpAndSettle();
    repository.orders = [changedOrder(repository.orders.single, 'SHIPPING')];
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(find.text('Đơn không còn ở trạng thái PROCESSING'), findsOneWidget);
    expect(find.text('Đang giao'), findsOneWidget);
    expect(find.text(packText), findsNothing);
  });

  testWidgets('PUT thành công GET lỗi giữ thông tin và có nút tải lại', (
    tester,
  ) async {
    final repository = FakeSellerOrderRepository(
      orders: [makeOrder(status: 'PROCESSING', name: 'Nguyễn Văn A')],
    );
    await openDetail(tester, repository);
    repository.onGetDetail = (id) async =>
        throw const SellerOrderException('Mất mạng');
    await tester.tap(find.text(packText));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(find.text('Nguyễn Văn A'), findsOneWidget);
    expect(find.text('Tải lại chi tiết'), findsOneWidget);
    expect(find.text(packText), findsNothing);
    expect(find.text(cancelText), findsNothing);
    repository.onGetDetail = null;
    await tester.tap(find.text('Tải lại chi tiết'));
    await tester.pumpAndSettle();
    expect(find.text('Chờ lấy hàng'), findsOneWidget);
    expect(repository.readyCalls, [6]);
    expect(tester.takeException(), isNull);
  });

  for (final cancel in [false, true]) {
    testWidgets(
      'Thao tác ${cancel ? 'hủy' : 'đóng gói'} xong quay lại danh sách đúng tab mới',
      (tester) async {
        final repository = FakeSellerOrderRepository(
          orders: [makeOrder(status: 'PROCESSING', name: 'Nguyễn Văn A')],
        );
        addTearDown(repository.service.close);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sellerOrderRepositoryProvider.overrideWithValue(repository),
            ],
            child: const MyApp(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Đang chuẩn bị'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(SellerOrderCard));
        await tester.pumpAndSettle();
        await tester.tap(find.text(cancel ? cancelText : packText));
        await tester.pumpAndSettle();
        await tester.tap(find.text(cancel ? 'Xác nhận hủy' : 'Xác nhận'));
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('Chưa có đơn đang chuẩn bị.'), findsOneWidget);
        final target = find.text(cancel ? 'Đã hủy' : 'Chờ lấy hàng');
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(find.text('Đơn #6'), findsOneWidget);
        expect(
          repository.listCalls.last,
          '${cancel ? 'CANCELLED' : 'READY_TO_SHIP'}:0',
        );
      },
    );
  }
}
