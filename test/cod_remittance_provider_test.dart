import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoppy/features/shipper_orders/models/cod_balance.dart';
import 'package:shoppy/features/shipper_orders/models/cod_transaction.dart';
import 'package:shoppy/features/shipper_orders/providers/cod_remittance_provider.dart';
import 'package:shoppy/features/shipper_orders/providers/shipper_cod_provider.dart';
import 'package:shoppy/features/shipper_orders/services/shipper_order_service.dart';

import 'helpers/cod_fakes.dart';

void main() {
  late FakeCodRepository repository;
  late ProviderContainer container;
  late CodRemittanceNotifier notifier;
  setUp(() {
    repository = FakeCodRepository();
    container = ProviderContainer(
      overrides: [shipperCodRepositoryProvider.overrideWithValue(repository)],
    );
    notifier = container.read(codRemittanceProvider.notifier);
  });
  tearDown(() {
    container.dispose();
    repository.service.close();
  });

  for (final input in [
    '',
    ' ',
    'abc',
    '-1000',
    '0',
    '999',
    '1,000',
    '1.000',
    '1000.5',
    '930001',
  ]) {
    test(
      'Chặn số tiền nhập "$input"',
      () => expect(validateCodRemittance(input, 930000), isNotNull),
    );
  }
  for (final input in ['1000', '500000', '930000', ' 1000 ']) {
    test(
      'Chấp nhận số tiền hợp lệ "$input"',
      () => expect(validateCodRemittance(input, 930000), isNull),
    );
  }
  test('Nộp toàn bộ: chỉ backend giả lập sửa tiền, FE tải lại số dư 0 và REMITTANCE', () async {
    container.listen(codBalanceProvider, (previous, next) {});
    container.listen(
      codTransactionsProvider(CodFilter.all),
      (previous, next) {},
    );
    await container.read(codBalanceProvider.future);
    await container.read(codTransactionsProvider(CodFilter.all).future);
    expect(await notifier.submit(930000, 'Cuối ca'), isTrue);
    final balance = await container.read(codBalanceProvider.future);
    expect(balance.currentBalance, 0);
    expect(balance.totalRemitted, 930000);
    expect(balance.totalCollected, 930000);
    final state = container.read(codRemittanceProvider);
    expect(state.transaction?.id, 2);
    expect(state.transaction?.amount, 930000);
    expect(state.transaction?.isRemittance, isTrue);
    expect(state.transaction?.status, 'COMPLETED');
    expect(
      (await container.read(codTransactionsProvider(CodFilter.all).future))
          .first
          .type,
      'REMITTANCE',
    );
    expect(repository.postCalls, [
      {'amount': 930000, 'note': 'Cuối ca'},
    ]);
    expect(await notifier.submit(930000, 'Cuối ca'), isFalse);
    expect(repository.postCalls, hasLength(1));
  });
  test('Nộp một phần và mở form mới để nộp phần còn lại', () async {
    await notifier.submit(500000, 'Đợt 1');
    expect(repository.backend.balances[16]!.currentBalance, 430000);
    notifier.startNew();
    expect(container.read(codRemittanceProvider).transaction, isNull);
    await notifier.submit(430000, 'Đợt 2');
    expect(repository.backend.balances[16]!.currentBalance, 0);
    expect(repository.postCalls, hasLength(2));
  });
  test('Số dư mới giảm trước POST thì chặn và không gửi yêu cầu', () async {
    repository.backend.balances[16] = const CodBalance(
      totalCollected: 930000,
      totalRemitted: 830000,
      currentBalance: 100000,
    );
    await expectLater(
      notifier.submit(500000, 'Cuối ca'),
      throwsA(isA<CodAmountException>()),
    );
    expect(repository.postCalls, isEmpty);
  });
  test('Nhấn liên tục chỉ có một POST', () async {
    final pending = Completer<void>();
    repository.onRemit = (amount, note) async {
      await pending.future;
      repository.backend.remit(16, amount, note);
    };
    final first = notifier.submit(500000, 'Cuối ca');
    expect(await notifier.submit(500000, 'Cuối ca'), isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(repository.postCalls, hasLength(1));
    pending.complete();
    await first;
    expect(repository.backend.balances[16]!.totalRemitted, 500000);
  });
  for (final code in [400, 401, 403, 422]) {
    test(
      'Backend từ chối $code giữ dữ liệu và cho thử lại sau khi sửa',
      () async {
        repository.onRemit = (amount, note) async =>
            throw ShipperOrderException('Từ chối', statusCode: code);
        await expectLater(
          notifier.submit(500000, 'Ghi chú giữ lại'),
          throwsA(isA<ShipperOrderException>()),
        );
        final state = container.read(codRemittanceProvider);
        expect(state.isBusy, isFalse);
        expect(state.needsCheck, isFalse);
        expect(state.amount, 500000);
        expect(state.note, 'Ghi chú giữ lại');
        expect(repository.backend.balances[16]!.currentBalance, 930000);
        repository.onRemit = null;
        expect(await notifier.submit(500000, 'Ghi chú giữ lại'), isTrue);
      },
    );
  }
  test('Lỗi status error dù HTTP 200 được coi là từ chối rõ ràng', () async {
    repository.onRemit = (amount, note) async =>
        throw const ShipperOrderException('Không hợp lệ', isRejected: true);
    await expectLater(
      notifier.submit(500000, 'Ca'),
      throwsA(isA<ShipperOrderException>()),
    );
    expect(container.read(codRemittanceProvider).needsCheck, isFalse);
  });
  test(
    'Response POST chưa xác nhận giao dịch thì đối chiếu và khóa gửi lại',
    () async {
      repository.onRemit = (amount, note) async =>
          throw const ShipperOrderException(
            'Chưa xác nhận được giao dịch nộp COD.',
          );
      await expectLater(
        notifier.submit(5000, 'Nộp về công ty'),
        throwsA(isA<ShipperOrderException>()),
      );
      final state = container.read(codRemittanceProvider);
      expect(state.completed, isFalse);
      expect(state.transaction, isNull);
      expect(state.needsCheck, isTrue);
      expect(repository.balanceCalls, greaterThanOrEqualTo(2));
      expect(repository.filterCalls.length, greaterThanOrEqualTo(2));
      expect(await notifier.submit(5000, 'Nộp về công ty'), isFalse);
      expect(repository.postCalls, hasLength(1));
    },
  );
  test('Timeout sau khi BE đã ghi: đối chiếu ID mới/tổng đã nộp, không gửi lại POST', () async {
    repository.onRemit = (amount, note) async {
      repository.backend.remit(16, amount, note);
      throw const ShipperOrderException('Timeout', isTimeout: true);
    };
    expect(await notifier.submit(500000, 'Ca tối'), isTrue);
    expect(
      container.read(codRemittanceProvider).message,
      contains('cùng số tiền'),
    );
    expect(repository.postCalls, hasLength(1));
    expect(repository.backend.balances[16]!.currentBalance, 430000);
    expect(container.read(codRemittanceProvider).transaction?.id, 2);
  });
  test(
    'Chưa thấy kết quả sau timeout vẫn khóa, đóng/mở lại không cho gửi trùng',
    () async {
      repository.onRemit = (amount, note) async =>
          throw const ShipperOrderException('Timeout', isTimeout: true);
      await expectLater(
        notifier.submit(500000, 'Ca tối'),
        throwsA(isA<ShipperOrderException>()),
      );
      expect(container.read(codRemittanceProvider).needsCheck, isTrue);
      notifier.startNew();
      expect(await notifier.submit(500000, 'Ca tối'), isFalse);
      expect(await notifier.checkResult(), isFalse);
      expect(repository.postCalls, hasLength(1));
      // Request cũ được backend xử lý muộn; lần kiểm tra sau mới nhìn thấy.
      repository.backend.remit(16, 500000, 'Ca tối');
      expect(await notifier.checkResult(), isTrue);
      expect(repository.postCalls, hasLength(1));
    },
  );
  test('GET kiểm tra lỗi vẫn giữ khóa đến khi đọc được kết quả', () async {
    repository.onRemit = (amount, note) async {
      repository.backend.remit(16, amount, note);
      repository.onBalance = () async =>
          throw const ShipperOrderException('Mất mạng');
      throw const ShipperOrderException('Timeout', isTimeout: true);
    };
    await expectLater(
      notifier.submit(500000, 'Cuối ca'),
      throwsA(isA<ShipperOrderException>()),
    );
    expect(container.read(codRemittanceProvider).needsCheck, isTrue);
    repository.onBalance = null;
    expect(await notifier.checkResult(), isTrue);
    expect(repository.postCalls, hasLength(1));
  });
  test(
    'Không nhầm giao dịch cũ cùng amount/note là kết quả POST mới',
    () async {
      repository.backend.remit(16, 100000, 'Cuối ca');
      repository.onRemit = (amount, note) async =>
          throw const ShipperOrderException('Timeout', isTimeout: true);
      await expectLater(
        notifier.submit(100000, 'Cuối ca'),
        throwsA(isA<ShipperOrderException>()),
      );
      expect(container.read(codRemittanceProvider).needsCheck, isTrue);
      expect(repository.backend.balances[16]!.totalRemitted, 100000);
    },
  );
  test('Dữ liệu COD của hai tài xế được backend giả lập tách riêng', () async {
    repository.backend.balances[17] = const CodBalance(
      totalCollected: 200000,
      totalRemitted: 0,
      currentBalance: 200000,
    );
    final other = FakeCodRepository(backend: repository.backend, shipperId: 17);
    addTearDown(other.service.close);
    await notifier.submit(500000, 'Ca 16');
    expect((await other.getBalance()).currentBalance, 200000);
    expect(await other.getTransactions(), isEmpty);
  });
}
