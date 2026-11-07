import 'package:flutter_riverpod/flutter_riverpod.dart';

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
