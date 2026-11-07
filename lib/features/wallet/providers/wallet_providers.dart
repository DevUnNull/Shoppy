import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_providers.dart';
import '../models/wallet_transaction.dart';
import '../services/wallet_service.dart';

final walletServiceProvider = Provider<WalletService>(
  (ref) => WalletService(ref.watch(apiClientProvider)),
);

class TransactionsState {
  const TransactionsState({
    this.items = const [],
    this.page = -1,
    this.hasNext = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
  });

  final List<WalletTransaction> items;
  final int page;
  final bool hasNext;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;

  List<WalletTransaction> filtered(TransactionFilter filter) =>
      switch (filter) {
        TransactionFilter.all => items,
        TransactionFilter.credit => items.where((t) => t.isCredit).toList(),
        TransactionFilter.debit => items.where((t) => !t.isCredit).toList(),
      };
}

/// Lịch sử biến động số dư, tải thêm khi cuộn.
final transactionsProvider =
    NotifierProvider.autoDispose<TransactionsNotifier, TransactionsState>(
      TransactionsNotifier.new,
    );

class TransactionsNotifier extends Notifier<TransactionsState> {
  int _requestId = 0;

  @override
  TransactionsState build() {
    Future.microtask(refresh);
    return const TransactionsState(isLoading: true);
  }

  Future<void> refresh() async {
    final id = ++_requestId;
    state = const TransactionsState(isLoading: true);
    try {
      final result = await ref.read(walletServiceProvider).getTransactions();
      if (!ref.mounted || id != _requestId) return;
      state = TransactionsState(
        items: result.content,
        page: 0,
        hasNext: result.hasNext,
      );
    } catch (e) {
      if (!ref.mounted || id != _requestId) return;
      state = TransactionsState(error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasNext) return;
    final id = _requestId;
    final current = state;
    state = TransactionsState(
      items: current.items,
      page: current.page,
      hasNext: current.hasNext,
      isLoadingMore: true,
    );
    try {
      final result = await ref
          .read(walletServiceProvider)
          .getTransactions(page: current.page + 1);
      if (!ref.mounted || id != _requestId) return;
      final seen = current.items.map((t) => t.id).toSet();
      state = TransactionsState(
        items: [
          ...current.items,
          ...result.content.where((t) => seen.add(t.id)),
        ],
        page: current.page + 1,
        hasNext: result.hasNext,
      );
    } catch (_) {
      if (!ref.mounted || id != _requestId) return;
      state = TransactionsState(
        items: current.items,
        page: current.page,
        hasNext: current.hasNext,
      );
    }
  }
}
