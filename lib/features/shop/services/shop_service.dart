import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/json_utils.dart';
import '../../../core/network/page_result.dart';
import '../../catalog/models/product.dart';
import '../../catalog/services/product_service.dart';
import '../models/shop.dart';

class ShopService {
  ShopService(this._client);

  final ApiClient _client;

  /// `GET /shops/{id}` — thông tin công khai của shop.
  Future<Shop> getShop(int id) async {
    final data = await _client.get('/shops/$id');
    if (data is! Map) throw const ApiException('Không tìm thấy shop.');
    return Shop.fromJson(asMap(data));
  }

  /// `GET /shops/{id}/products?page=&size=`
  Future<PageResult<Product>> getShopProducts(
    int shopId, {
    int page = 0,
    int size = 24,
  }) async {
    final data = await _client.get(
      '/shops/$shopId/products',
      query: {'page': page, 'size': size},
    );
    return PageResult.fromJson(data, Product.fromJson);
  }

  /// Tải toàn bộ sản phẩm của shop để sort phía client.
  Future<List<Product>> getAllShopProducts(int shopId) =>
      collectPages((page) => getShopProducts(shopId, page: page, size: 100));
}
