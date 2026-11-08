import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cod_balance.dart';
import '../models/cod_transaction.dart';
import '../services/shipper_order_service.dart';
import 'shipper_cod_provider.dart';

class CodAmountException implements Exception {
  const CodAmountException(this.message);
  final String message;
  @override
  String toString() => message;
}

class CodRemittanceState {
  const CodRemittanceState({
    this.isBusy = false,
    this.needsCheck = false,
    this.completed = false,
    this.amount,
    this.note = '',
    this.message = '',
    this.transaction,
  });
  final bool isBusy, needsCheck, completed;
  final int? amount;
  final String note, message;
  final CodTransaction? transaction;
}

class _PendingRemittance {
  const _PendingRemittance(
    this.amount,
    this.note,
    this.balance,
    this.transactionIds,
  );
  final int amount;
  final String note;
  final CodBalance balance;
  final Set<int> transactionIds;
}

// Khóa dùng chung trong phiên, kể cả khi đóng rồi mở lại form.
final codRemittanceProvider =
    NotifierProvider<CodRemittanceNotifier, CodRemittanceState>(
      CodRemittanceNotifier.new,
    );

class CodRemittanceNotifier extends Notifier<CodRemittanceState> {
  _PendingRemittance? _pending;
  @override
  CodRemittanceState build() {
    ref.watch(shipperCodRepositoryProvider);
    _pending = null;
    return const CodRemittanceState();
  }

  void startNew() {
    if (state.isBusy || state.needsCheck) return;
    _pending = null;
    state = const CodRemittanceState();
  }

  Future<bool> submit(int amount, String note) async {
    final currentRef = ref;
    if (state.isBusy || state.needsCheck || state.completed) return false;
    state = CodRemittanceState(isBusy: true, amount: amount, note: note);
    var sent = false;
    try {
      final repository = ref.read(shipperCodRepositoryProvider);
      final balance = await repository.getBalance();
      if (!currentRef.mounted) return false;
      final error = validateCodRemittance('$amount', balance.currentBalance);
      if (error != null) throw CodAmountException(error);
      final transactions = await repository.getTransactions();
      if (!currentRef.mounted) return false;
      _pending = _PendingRemittance(
        amount,
        note,
        balance,
        transactions.map((item) => item.id).toSet(),
      );
      late final CodTransaction transaction;
      try {
        sent = true;
        transaction = await repository.remit(amount, note);
      } catch (error) {
        if (!currentRef.mounted) return false;
        // Lỗi từ chối rõ ràng cho phép sửa/thử lại. Lỗi mạng, timeout, 5xx
        // hoặc phản hồi không đọc được có thể xảy ra sau khi BE đã ghi tiền.
        final code = error is ShipperOrderException ? error.statusCode : null;
        if ([400, 401, 403, 404, 422, 429].contains(code) ||
            (error is ShipperOrderException && error.isRejected)) {
          _pending = null;
          rethrow;
        }
        state = CodRemittanceState(
          isBusy: true,
          needsCheck: true,
          amount: amount,
          note: note,
          message: 'Chưa xác định được kết quả nộp tiền. Đang kiểm tra số dư và lịch sử.',
        );
        try {
          await _checkPending(currentRef);
        } catch (checkError) {
          if (!currentRef.mounted) return false;
          state = CodRemittanceState(
            isBusy: true,
            needsCheck: true,
            amount: amount,
            note: note,
            message: 'Chưa kiểm tra được kết quả. $checkError',
          );
        }
        if (!currentRef.mounted) return false;
        if (state.completed) return true;
        throw ShipperOrderException(state.message);
      }
      if (!currentRef.mounted) return false;
      _pending = null;
      state = CodRemittanceState(
        completed: true,
        amount: amount,
        note: note,
        message: 'Nộp tiền COD thành công',
        transaction: transaction,
      );
      return true;
    } finally {
      if (currentRef.mounted) {
        _unlock();
        // Không chỉnh số dư tại chỗ: các màn hình phải đọc lại backend.
        if (sent) {
          _refreshData();
        } else {
          ref.invalidate(codBalanceProvider);
        }
      }
    }
  }

  Future<void> _checkPending(Ref currentRef) async {
    final pending = _pending;
    if (pending == null) return;
    final repository = currentRef.read(shipperCodRepositoryProvider);
    final balance = await repository.getBalance();
    if (!currentRef.mounted) return;
    final transactions = await repository.getTransactions();
    if (!currentRef.mounted) return;
    final matching = transactions
        .where(
          (item) =>
              !pending.transactionIds.contains(item.id) &&
              item.isRemittance &&
              item.status == 'COMPLETED' &&
              item.amount == pending.amount &&
              (item.note ?? '').trim() == pending.note.trim(),
        )
        .toList();
    final recorded =
        matching.length == 1 &&
        balance.totalRemitted >= pending.balance.totalRemitted + pending.amount;
    if (recorded) {
      _pending = null;
      state = CodRemittanceState(
        isBusy: true,
        completed: true,
        amount: pending.amount,
        note: pending.note,
        message: 'Đã có giao dịch nộp cùng số tiền và ghi chú trong lịch sử. Không gửi lại yêu cầu.',
        transaction: matching.single,
      );
    } else {
      // Không thấy giao dịch chưa đủ để kết luận POST cũ chắc chắn thất bại.
      state = CodRemittanceState(
        isBusy: true,
        needsCheck: true,
        amount: pending.amount,
        note: pending.note,
        message: 'Chưa xác định chắc chắn kết quả lần nộp trước. Hãy kiểm tra lịch sử hoặc xác nhận với hãng; ứng dụng chưa gửi lại yêu cầu.',
      );
    }
  }

  Future<bool> checkResult() async {
    final currentRef = ref;
    if (state.isBusy || !state.needsCheck) return false;
    state = CodRemittanceState(
      isBusy: true,
      needsCheck: true,
      amount: state.amount,
      note: state.note,
      message: state.message,
      transaction: state.transaction,
    );
    try {
      await _checkPending(currentRef);
      if (!currentRef.mounted) return false;
      return state.completed;
    } finally {
      if (currentRef.mounted) {
        _unlock();
        _refreshData();
      }
    }
  }

  void _unlock() {
    state = CodRemittanceState(
      needsCheck: state.needsCheck,
      completed: state.completed,
      amount: state.amount,
      note: state.note,
      message: state.message,
      transaction: state.transaction,
    );
  }

  void _refreshData() {
    ref.invalidate(codBalanceProvider);
    ref.invalidate(codTransactionsProvider);
    ref.invalidate(shipperCodBalanceProvider);
    ref.invalidate(shipperCodTransactionsProvider);
  }
}
