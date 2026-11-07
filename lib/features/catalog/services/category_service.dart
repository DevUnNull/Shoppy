import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/json_utils.dart';
import '../models/category.dart';

class CategoryService {
  CategoryService(this._client);

  final ApiClient _client;

  /// `GET /categories` — cây danh mục (gốc + children).
  Future<List<Category>> getCategoryTree() async {
    final data = await _client.get('/categories');
    return asMapList(data)
        .where((c) => asString(c['status'], 'ACTIVE') == 'ACTIVE')
        .map(Category.fromJson)
        .toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  }

  /// `GET /categories/{id}`
  Future<Category> getCategory(int id) async {
    final data = await _client.get('/categories/$id');
    if (data is! Map) throw const ApiException('Không tìm thấy danh mục.');
    return Category.fromJson(asMap(data));
  }
}
