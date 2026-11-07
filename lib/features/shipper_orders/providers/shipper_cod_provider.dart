import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cod_balance.dart';
import '../models/cod_transaction.dart';
import '../repositories/shipper_cod_repository.dart';

import 'shipper_orders_provider.dart';

// Màn COD sẽ watch hai provider này. autoDispose giúp lần mở mới lấy dữ liệu mới;
// xác nhận giao hàng sẽ invalidate cả hai nếu backend có thể đã ghi nhận COD.
// Không cộng số dư hoặc tự tạo giao dịch ở frontend.
final shipperCodBalanceProvider = FutureProvider.autoDispose<dynamic>(
  (ref) => ref.watch(shipperOrderRepositoryProvider).getCodBalance(),
  retry: (count, error) => null,
);
final shipperCodTransactionsProvider = FutureProvider.autoDispose<dynamic>(
  (ref) => ref.watch(shipperOrderRepositoryProvider).getCodTransactions(),
  retry: (count, error) => null,
);

final shipperCodRepositoryProvider = Provider<ShipperCodRepository>(
  (ref) => ShipperCodRepository(ref.watch(shipperOrderServiceProvider)),
);

final codBalanceProvider = FutureProvider.autoDispose<CodBalance>(
  (ref) => ref.watch(shipperCodRepositoryProvider).getBalance(),
  retry: (count, error) => null,
);

// Mỗi bộ lọc có state riêng: response bộ lọc cũ không ghi đè bộ lọc mới.
final codTransactionsProvider = FutureProvider.autoDispose
    .family<List<CodTransaction>, CodFilter>(
      (ref, filter) => ref
          .watch(shipperCodRepositoryProvider)
          .getTransactions(filter: filter),
      retry: (count, error) => null,
    );
