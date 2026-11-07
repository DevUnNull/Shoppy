import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoppy/features/shipper_orders/models/cod_balance.dart';
import 'package:shoppy/features/shipper_orders/models/cod_transaction.dart';
import 'package:shoppy/features/shipper_orders/providers/shipper_cod_provider.dart';
import 'package:shoppy/features/shipper_orders/screens/cod_remittance_screen.dart';
import 'package:shoppy/features/shipper_orders/screens/shipper_cod_screen.dart';
import 'package:shoppy/features/shipper_orders/services/shipper_order_service.dart';
import 'package:shoppy/features/shipper_orders/widgets/cod_transaction_tile.dart';
import 'package:shoppy/features/shipper_orders/widgets/shipper_order_widgets.dart';

import 'helpers/cod_fakes.dart';

Future<void> openCod(
  WidgetTester tester,
  FakeCodRepository repository, {
  bool form = false,
}) async {
  addTearDown(repository.service.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [shipperCodRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        home: form ? const CodRemittanceScreen() : const ShipperCodScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> fillCod(
  WidgetTester tester, {
  String amount = '500000',
  String note = 'Cuối ca',
}) async {
  await tester.enterText(find.byKey(const ValueKey('cod-amount')), amount);
  await tester.enterText(find.byKey(const ValueKey('cod-note')), note);
  await tester.ensureVisible(find.widgetWithText(FilledButton, 'Nộp tiền'));
  await tester.tap(find.widgetWithText(FilledButton, 'Nộp tiền'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Hiện đúng 3 số dư VNĐ và giao dịch thu tiền với mã đơn, ghi chú',
    (tester) async {
      await openCod(tester, FakeCodRepository());
      expect(find.text('Tiền thu hộ COD'), findsOneWidget);
      expect(find.text(shipperMoney(930000)), findsOneWidget);
      expect(
        find.text('Tổng tiền đã thu: ${shipperMoney(930000)}'),
        findsOneWidget,
      );
      expect(find.text('Tổng tiền đã nộp: ${shipperMoney(0)}'), findsOneWidget);
      expect(find.text('+${shipperMoney(930000)}'), findsOneWidget);
      expect(find.text('Đơn #6'), findsOneWidget);
      expect(find.text('Thu tiền mặt COD đơn hàng #6'), findsOneWidget);
    },
  );
  testWidgets('Bộ lọc hoạt động, không giữ danh sách cũ khi chuyển nhanh', (
    tester,
  ) async {
    final repository = FakeCodRepository();
    repository.backend.remit(16, 500000, 'Nộp cuối ca');
    final old = Completer<List<CodTransaction>>();
    repository.onTransactions = (filter) async {
      if (filter == CodFilter.collection) return old.future;
      return repository.backend.transactions[16]!
          .where(
            (item) => filter == CodFilter.all || item.type == filter.apiValue,
          )
          .toList();
    };
    await openCod(tester, repository);
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Thu tiền'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Thu tiền'));
    await tester.pump();
    expect(find.byType(CodTransactionTile), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Nộp tiền'));
    await tester.pumpAndSettle();
    old.complete(
      repository.backend.transactions[16]!
          .where((item) => item.type == 'COLLECTION')
          .toList(),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CodTransactionTile), findsOneWidget);
    expect(
      tester
          .widget<CodTransactionTile>(find.byType(CodTransactionTile))
          .transaction
          .type,
      'REMITTANCE',
    );
    expect(find.text('−${shipperMoney(500000)}'), findsOneWidget);
    expect(
      repository.filterCalls,
      containsAll([CodFilter.collection, CodFilter.remittance]),
    );
  });
  testWidgets('Kéo làm mới số dư và lịch sử, lịch sử trống hiển thị rõ', (
    tester,
  ) async {
    final repository = FakeCodRepository();
    repository.backend.transactions[16] = [];
    await openCod(tester, repository);
    expect(find.text('Chưa có giao dịch COD.'), findsOneWidget);
    final beforeBalance = repository.balanceCalls,
        beforeTransactions = repository.filterCalls.length;
    repository.backend.remit(16, 500000, 'Nộp mới');
    await tester.drag(find.byType(ListView), const Offset(0, 350));
    await tester.pumpAndSettle();
    expect(repository.balanceCalls, greaterThan(beforeBalance));
    expect(repository.filterCalls.length, greaterThan(beforeTransactions));
    expect(find.text(shipperMoney(430000)), findsOneWidget);
    expect(find.text('Nộp mới'), findsOneWidget);
  });
  for (final input in ['', 'abc', '-1000', '999', '930001', '1,000']) {
    testWidgets('Form chặn "$input", lỗi dưới ô tiền và không mở xác nhận', (
      tester,
    ) async {
      final repository = FakeCodRepository();
      await openCod(tester, repository, form: true);
      await fillCod(tester, amount: input);
      expect(find.text(validateCodRemittance(input, 930000)!), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(repository.postCalls, isEmpty);
    });
  }
  testWidgets('Số dư dưới 1000 khóa nút và giải thích', (tester) async {
    final repository = FakeCodRepository();
    repository.backend.balances[16] = const CodBalance(
      totalCollected: 500,
      totalRemitted: 0,
      currentBalance: 500,
    );
    await openCod(tester, repository, form: true);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Nộp tiền'))
          .onPressed,
      isNull,
    );
    expect(
      find.text('Số dư chưa đủ mức nộp tối thiểu 1.000 VNĐ.'),
      findsOneWidget,
    );
  });
  testWidgets('Số dư giảm trước hộp thoại được phát hiện, không gửi POST', (
    tester,
  ) async {
    final repository = FakeCodRepository();
    await openCod(tester, repository, form: true);
    repository.backend.balances[16] = const CodBalance(
      totalCollected: 930000,
      totalRemitted: 830000,
      currentBalance: 100000,
    );
    await fillCod(tester);
    expect(
      find.text('Số tiền nộp vượt quá số dư COD đang giữ.'),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsNothing);
    expect(repository.postCalls, isEmpty);
  });
  testWidgets('Quay lại hộp thoại không gửi API và giữ số tiền/ghi chú', (
    tester,
  ) async {
    final repository = FakeCodRepository();
    await openCod(tester, repository, form: true);
    await fillCod(tester);
    expect(find.text('Số tiền: ${shipperMoney(500000)}'), findsOneWidget);
    expect(find.text('Ghi chú: Cuối ca'), findsOneWidget);
    await tester.tap(find.text('Quay lại'));
    await tester.pumpAndSettle();
    expect(repository.postCalls, isEmpty);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('cod-amount')))
          .controller!
          .text,
      '500000',
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('cod-note')))
          .controller!
          .text,
      'Cuối ca',
    );
  });
  testWidgets(
    'Nộp toàn bộ thành công quay về, số dư 0 và xuất hiện REMITTANCE',
    (tester) async {
      final repository = FakeCodRepository();
      await openCod(tester, repository);
      await tester.tap(find.widgetWithText(FilledButton, 'Nộp tiền COD'));
      await tester.pumpAndSettle();
      await fillCod(tester, amount: '930000');
      expect(find.text('Nộp về công ty vận chuyển của bạn'), findsOneWidget);
      await tester.tap(find.text('Xác nhận nộp'));
      await tester.pumpAndSettle();
      expect(find.text('Tiền thu hộ COD'), findsOneWidget);
      expect(find.text('Nộp tiền COD thành công'), findsOneWidget);
      expect(find.text('Giao dịch nộp COD #2 đã hoàn tất.'), findsOneWidget);
      expect(find.text(shipperMoney(0)), findsOneWidget);
      expect(find.text('−${shipperMoney(930000)}'), findsOneWidget);
      expect(repository.postCalls, [
        {'amount': 930000, 'note': 'Cuối ca'},
      ]);
    },
  );
  testWidgets('Nhấn xác nhận liên tục chỉ gửi một POST, nút khóa khi gửi', (
    tester,
  ) async {
    final pending = Completer<void>();
    final repository = FakeCodRepository()
      ..onRemit = (amount, note) => pending.future;
    await openCod(tester, repository);
    await tester.tap(find.widgetWithText(FilledButton, 'Nộp tiền COD'));
    await tester.pumpAndSettle();
    await fillCod(tester);
    await tester.tap(find.text('Xác nhận nộp'));
    await tester.tap(find.text('Xác nhận nộp'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 400));
    expect(repository.postCalls, hasLength(1));
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Đang xử lý…'),
          )
          .onPressed,
      isNull,
    );
    repository.backend.remit(16, 500000, 'Cuối ca');
    pending.complete();
    await tester.pumpAndSettle();
    expect(repository.postCalls, hasLength(1));
  });
  testWidgets(
    '403 giữ form và dữ liệu nhập, hiển thị lỗi rõ, không đổi số dư',
    (tester) async {
      final repository = FakeCodRepository()
        ..onRemit = (amount, note) async => throw const ShipperOrderException(
          'Không đủ quyền SHIPPER',
          statusCode: 403,
        );
      await openCod(tester, repository, form: true);
      await fillCod(tester);
      await tester.tap(find.text('Xác nhận nộp'));
      await tester.pumpAndSettle();
      expect(find.text('Không đủ quyền SHIPPER'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('cod-amount')))
            .controller!
            .text,
        '500000',
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('cod-note')))
            .controller!
            .text,
        'Cuối ca',
      );
      expect(repository.backend.balances[16]!.currentBalance, 930000);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Nộp tiền'))
            .onPressed,
        isNotNull,
      );
    },
  );
  testWidgets('Timeout chưa rõ kết quả: khóa gửi lại qua cả đóng/mở form', (
    tester,
  ) async {
    final repository = FakeCodRepository()
      ..onRemit = (amount, note) async =>
          throw const ShipperOrderException('Timeout', isTimeout: true);
    await openCod(tester, repository);
    await tester.tap(find.widgetWithText(FilledButton, 'Nộp tiền COD'));
    await tester.pumpAndSettle();
    await fillCod(tester);
    await tester.tap(find.text('Xác nhận nộp'));
    await tester.pumpAndSettle();
    expect(find.text('Kiểm tra lại kết quả'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Nộp tiền'))
          .onPressed,
      isNull,
    );
    await tester.ensureVisible(find.text('Xem lịch sử'));
    await tester.tap(find.text('Xem lịch sử'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Kiểm tra lần nộp trước'));
    await tester.tap(find.text('Kiểm tra lần nộp trước'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('cod-amount')))
          .controller!
          .text,
      '500000',
    );
    repository.backend.remit(16, 500000, 'Cuối ca');
    await tester.ensureVisible(find.text('Kiểm tra lại kết quả'));
    await tester.tap(find.text('Kiểm tra lại kết quả'));
    await tester.pumpAndSettle();
    expect(find.text('Tiền thu hộ COD'), findsOneWidget);
    expect(find.text(shipperMoney(430000)), findsOneWidget);
    expect(repository.postCalls, hasLength(1));
  });
}
