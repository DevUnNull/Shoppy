import '../../../core/network/json_utils.dart';

/// Danh mục đa cấp — khớp `GET /categories` và `GET /categories/{id}`.
class Category {
  const Category({
    required this.id,
    required this.name,
    this.slug,
    this.description,
    this.parentId,
    this.parentName,
    this.displayOrder = 0,
    this.children = const [],
  });

  final int id;
  final String name;
  final String? slug;
  final String? description;
  final int? parentId;
  final String? parentName;
  final int displayOrder;
  final List<Category> children;

  bool get isRoot => parentId == null;

  /// ID của chính nó và toàn bộ danh mục con cháu (để lọc sản phẩm).
  Set<int> get selfAndDescendantIds => {
    id,
    for (final child in children) ...child.selfAndDescendantIds,
  };

  factory Category.fromJson(Map<String, dynamic> json) {
    final children =
        asMapList(json['children'])
            .where((c) => asString(c['status'], 'ACTIVE') == 'ACTIVE')
            .map(Category.fromJson)
            .toList()
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return Category(
      id: asInt(json['id']),
      name: asString(json['name']),
      slug: asStringOrNull(json['slug']),
      description: asStringOrNull(json['description']),
      parentId: asIntOrNull(json['parentId']),
      parentName: asStringOrNull(json['parentName']),
      displayOrder: asInt(json['displayOrder']),
      children: children,
    );
  }
}
