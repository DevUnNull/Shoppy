import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product.dart';
import 'catalog_providers.dart';

const productPageSize = 24;

class ProductListState {
  const ProductListState({
    this.items = const [],
    this.page = -1,
    this.totalElements = 0,
    this.hasNext = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.loadMoreError,
  });

  final List<Product> items;
  final int page;
  final int totalElements;
  final bool hasNext;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final String? loadMoreError;

  bool get isEmpty => !isLoading && error == null && items.isEmpty;

  ProductListState copyWith({
    List<Product>? items,
    int? page,
    int? totalElements,
    bool? hasNext,
    bool? isLoadingMore,
    String? loadMoreError,
    bool clearLoadMoreError = false,
  }) => ProductListState(
    items: items ?? this.items,
    page: page ?? this.page,
    totalElements: totalElements ?? this.totalElements,
    hasNext: hasNext ?? this.hasNext,
    isLoading: isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    error: error,
    loadMoreError: clearLoadMoreError
        ? null
        : (loadMoreError ?? this.loadMoreError),
  );
}

/// Danh sách sản phẩm phân trang + Infinite Scroll, khoá theo từ khoá tìm kiếm
/// (`''` = trang chủ, tất cả sản phẩm).
final productListProvider = NotifierProvider.autoDispose
    .family<ProductListNotifier, ProductListState, String>(
      ProductListNotifier.new,
    );

class ProductListNotifier extends Notifier<ProductListState> {
  ProductListNotifier(this.keyword);

  final String keyword;
  int _requestId = 0;

  @override
  ProductListState build() {
    Future.microtask(refresh);
    return const ProductListState(isLoading: true);
  }

  Future<void> refresh() async {
    final requestId = ++_requestId;
    state = const ProductListState(isLoading: true);
    try {
      final result = await ref
          .read(productServiceProvider)
          .getProducts(search: keyword, page: 0, size: productPageSize);
      if (!ref.mounted || requestId != _requestId) return;
      state = ProductListState(
        items: result.content,
        page: 0,
        totalElements: result.totalElements,
        hasNext: result.hasNext,
      );
    } catch (e) {
      if (!ref.mounted || requestId != _requestId) return;
      state = ProductListState(error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading ||
        state.isLoadingMore ||
        !state.hasNext ||
        state.error != null) {
      return;
    }
    final requestId = _requestId;
    final nextPage = state.page + 1;
    state = state.copyWith(isLoadingMore: true, clearLoadMoreError: true);
    try {
      final result = await ref
          .read(productServiceProvider)
          .getProducts(search: keyword, page: nextPage, size: productPageSize);
      if (!ref.mounted || requestId != _requestId) return;
      // Khử trùng lặp theo ID nếu dữ liệu thay đổi giữa các trang.
      final seen = state.items.map((p) => p.id).toSet();
      state = state.copyWith(
        items: [...state.items, ...result.content.where((p) => seen.add(p.id))],
        page: nextPage,
        totalElements: result.totalElements,
        hasNext: result.hasNext,
        isLoadingMore: false,
      );
    } catch (e) {
      if (!ref.mounted || requestId != _requestId) return;
      state = state.copyWith(isLoadingMore: false, loadMoreError: e.toString());
    }
  }
}

/// Gợi ý từ khoá trending dưới thanh tìm kiếm, rút từ tên sản phẩm trang chủ.
final trendingKeywordsProvider = Provider.autoDispose<List<String>>((ref) {
  final items = ref.watch(productListProvider('').select((s) => s.items));
  final keywords = <String>{};
  for (final product in items) {
    final words = product.name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final phrase = words.take(2).join(' ');
    // Khử trùng không phân biệt hoa/thường ("Giày Sneaker" ~ "Giày sneaker").
    final duplicate = keywords.any(
      (k) => k.toLowerCase() == phrase.toLowerCase(),
    );
    if (phrase.length >= 3 && !duplicate) keywords.add(phrase);
    if (keywords.length >= 6) break;
  }
  return keywords.isEmpty
      ? const ['Giày sneaker', 'Điện thoại', 'Bình giữ nhiệt', 'Áo thun']
      : keywords.toList();
});
