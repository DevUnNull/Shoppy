import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_providers.dart';
import '../models/shop.dart';

abstract interface class ShopRepository {
  Future<Shop> getMyShop();
}

final myShopRepositoryProvider = Provider<ShopRepository>(
  (ref) => ShopApiService(ref.watch(apiClientProvider)),
);

class ShopApiService implements ShopRepository {
  ShopApiService(this._client);

  final ApiClient _client;

  @override
  Future<Shop> getMyShop() async {
    final data = await _client.get('/shops/me');
    if (data is! Map) {
      throw const ApiException('Phản hồi thông tin shop không hợp lệ.');
    }
    return Shop.fromJson(Map<String, dynamic>.from(data));
  }
}
