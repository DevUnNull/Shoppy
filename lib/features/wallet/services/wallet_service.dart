import '../../../core/network/api_client.dart';
import '../../../core/network/json_utils.dart';
import '../../../core/network/page_result.dart';
import '../models/wallet_transaction.dart';

/// Kết quả nạp ví: backend có thể cộng tiền ngay, hoặc trả về link
/// cổng thanh toán để người dùng hoàn tất.
class DepositResult {
  const DepositResult({this.newBalance, this.paymentUrl});

  final double? newBalance;
  final String? paymentUrl;
}

/// Mức nạp tối thiểu (đã xác minh: "Số tiền nạp tối thiểu là 10,000 VNĐ").
const minDepositAmount = 10000;

class WalletService {
  WalletService(this._client);

  final ApiClient _client;

  /// `POST /users/wallet/deposit` — body `{amount}`.
  Future<DepositResult> deposit(int amount) async {
    final data = await _client.post(
      '/users/wallet/deposit',
      body: {'amount': amount},
    );
    if (data is String && data.startsWith('http')) {
      return DepositResult(paymentUrl: data);
    }
    final map = asMap(data);
    return DepositResult(
      newBalance: asDoubleOrNull(map['balance'] ?? map['newBalance']),
      paymentUrl: asStringOrNull(
        map['paymentUrl'] ?? map['payUrl'] ?? map['url'],
      ),
    );
  }

  /// `GET /users/wallet/transactions?page=&size=`
  Future<PageResult<WalletTransaction>> getTransactions({
    int page = 0,
    int size = 20,
  }) async {
    final data = await _client.get(
      '/users/wallet/transactions',
      query: {'page': page, 'size': size},
    );
    return PageResult.fromJson(data, WalletTransaction.fromJson);
  }
}
