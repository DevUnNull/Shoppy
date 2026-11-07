import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/json_utils.dart';
import '../../../core/network/page_result.dart';
import '../models/product.dart';
import '../models/variant.dart';

class ProductService {
  ProductService(this._client);

  final ApiClient _client;

  /// `GET /products/getAll?search=&page=&size=` (page bắt đầu từ 0).
  Future<PageResult<Product>> getProducts({
    String? search,
    int page = 0,
    int size = 24,
  }) async {
    final keyword = search?.trim();
    final data = await _client.get(
      '/products/getAll',
      query: {
        if (keyword != null && keyword.isNotEmpty) 'search': keyword,
        'page': page,
        'size': size,
      },
    );
    return PageResult.fromJson(data, Product.fromJson);
  }

  /// Backend chưa hỗ trợ lọc theo danh mục / sort, nên các màn Danh mục & Shop
  /// tải toàn bộ (theo lô lớn) rồi lọc/sắp xếp phía client.
  Future<List<Product>> getAllProducts({
    int batchSize = 100,
    int maxPages = 20,
  }) => collectPages(
    (page) => getProducts(page: page, size: batchSize),
    maxPages: maxPages,
  );

  /// `GET /products/{id}`
  Future<ProductDetail> getProductDetail(int id) async {
    final data = await _client.get('/products/$id');
    if (data is! Map) throw const ApiException('Không tìm thấy sản phẩm.');
    return ProductDetail.fromJson(asMap(data));
  }

  /// `GET /products/{id}/variants`
  Future<List<Variant>> getVariants(int id) async {
    final data = await _client.get('/products/$id/variants');
    return asMapList(data).map(Variant.fromJson).toList();
  }
}

/// Gọi lần lượt từng trang cho đến khi hết `hasNext` (dùng chung với ShopService).
Future<List<T>> collectPages<T>(
  Future<PageResult<T>> Function(int page) fetch, {
  int maxPages = 20,
}) async {
  final items = <T>[];
  for (var page = 0; page < maxPages; page++) {
    final result = await fetch(page);
    items.addAll(result.content);
    if (!result.hasNext || result.content.isEmpty) break;
  }
  return items;
}
