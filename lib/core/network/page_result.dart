import 'json_utils.dart';

/// Kết quả phân trang chuẩn của backend Shoppy (Spring Page rút gọn).
class PageResult<T> {
  const PageResult({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.hasNext,
  });

  final List<T> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool hasNext;

  factory PageResult.fromJson(
    dynamic json,
    T Function(Map<String, dynamic>) parseItem,
  ) {
    final map = asMap(json);
    final items = asMapList(map['content']).map(parseItem).toList();
    final page = asInt(map['page']);
    final totalPages = asInt(map['totalPages']);
    return PageResult(
      content: items,
      page: page,
      size: asInt(map['size'], items.length),
      totalElements: asInt(map['totalElements'], items.length),
      totalPages: totalPages,
      hasNext: map['hasNext'] is bool
          ? map['hasNext'] as bool
          : page + 1 < totalPages,
    );
  }
}
