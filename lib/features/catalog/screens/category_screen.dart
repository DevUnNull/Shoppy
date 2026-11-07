import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/breakpoints.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/widgets/shoppy_header.dart';
import '../models/category.dart';
import '../models/product_sort.dart';
import '../providers/catalog_providers.dart';
import '../widgets/category_tree.dart';
import '../widgets/paged_product_section.dart';
import '../widgets/product_sliver_grid.dart';

/// Màn Duyệt theo Danh mục: cây danh mục bên trái, sort bar + grid bên phải.
class CategoryScreen extends ConsumerStatefulWidget {
  const CategoryScreen({super.key, this.initialCategoryId});

  final int? initialCategoryId;

  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends ConsumerState<CategoryScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _scroll = ScrollController();
  Set<int>? _selected; // null = chưa khởi tạo từ initialCategoryId
  ProductSort _sort = ProductSort.popular;
  int _page = 0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Set<int> _initialSelection(List<Category> tree) {
    final id = widget.initialCategoryId;
    if (id == null) return {};
    Category? find(List<Category> nodes) {
      for (final node in nodes) {
        if (node.id == id) return node;
        final found = find(node.children);
        if (found != null) return found;
      }
      return null;
    }

    return find(tree)?.selfAndDescendantIds ?? {id};
  }

  void _update({Set<int>? selected, ProductSort? sort, int? page}) {
    setState(() {
      if (selected != null) _selected = selected;
      if (sort != null) _sort = sort;
      _page = page ?? 0;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final treeAsync = ref.watch(categoryTreeProvider);
    final productsAsync = ref.watch(allProductsProvider);
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.desktop;

    final tree = treeAsync.value;
    if (tree != null) _selected ??= _initialSelection(tree);
    final selected = _selected ?? const <int>{};

    final filtered = productsAsync.whenData(
      (all) => applyCatalogQuery(all, categoryIds: selected, sort: _sort),
    );

    final sidebar = _Sidebar(
      treeAsync: treeAsync,
      selected: selected,
      onChanged: (value) {
        _update(selected: value);
      },
      onRetry: () => ref.invalidate(categoryTreeProvider),
    );

    final content = CustomScrollView(
      controller: _scroll,
      slivers: [
        SliverToBoxAdapter(
          child: _Heading(
            tree: tree ?? const [],
            selected: selected,
            total: filtered.value?.length,
            onOpenFilter: wide
                ? null
                : () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ),
        if (filtered.hasError && filtered.value == null)
          SliverToBoxAdapter(
            child: ErrorStateView(
              message: filtered.error.toString(),
              onRetry: () => ref.invalidate(allProductsProvider),
            ),
          )
        else
          ...pagedProductSlivers(
            products: filtered.value,
            sort: _sort,
            page: _page,
            onSortChanged: (sort) => _update(sort: sort),
            onPageChanged: (page) => _update(page: page),
            empty: filteredEmpty(
              onClear: selected.isEmpty ? null : () => _update(selected: {}),
            ),
          ),
      ],
    );

    return Scaffold(
      key: _scaffoldKey,
      endDrawer: wide
          ? null
          : Drawer(
              shape: const RoundedRectangleBorder(),
              child: SafeArea(child: SingleChildScrollView(child: sidebar)),
            ),
      body: Column(
        children: [
          const ShoppyHeader(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final gutter = centeredGutter(constraints.maxWidth);
                return Padding(
                  padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 0),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 220,
                              child: SingleChildScrollView(child: sidebar),
                            ),
                            const SizedBox(width: 16),
                            Expanded(child: content),
                          ],
                        )
                      : content,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.treeAsync,
    required this.selected,
    required this.onChanged,
    required this.onRetry,
  });

  final AsyncValue<List<Category>> treeAsync;
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.list, size: 20, color: AppColors.title),
              SizedBox(width: 8),
              Text(
                'Tất cả danh mục',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ],
          ),
          const Divider(height: 24),
          const Row(
            children: [
              Icon(Icons.filter_alt_outlined, size: 18, color: AppColors.title),
              SizedBox(width: 8),
              Text(
                'BỘ LỌC TÌM KIẾM',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Theo danh mục', style: TextStyle(color: AppColors.body)),
          const SizedBox(height: 4),
          treeAsync.when(
            loading: () => Column(
              children: List.generate(
                6,
                (_) => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Skeleton(height: 16),
                ),
              ),
            ),
            error: (error, _) =>
                ErrorStateView(message: error.toString(), onRetry: onRetry),
            data: (tree) => CategoryTree(
              categories: tree,
              selected: selected,
              onChanged: onChanged,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: selected.isEmpty ? null : () => onChanged({}),
            child: const Text('XOÁ TẤT CẢ'),
          ),
        ],
      ),
    );
  }
}

class _Heading extends ConsumerWidget {
  const _Heading({
    required this.tree,
    required this.selected,
    required this.total,
    required this.onOpenFilter,
  });

  final List<Category> tree;
  final Set<int> selected;
  final int? total;
  final VoidCallback? onOpenFilter;

  /// Danh mục duy nhất đang được chọn trọn vẹn (để hiển thị mô tả).
  Category? get _single {
    final roots = <Category>[];
    void visit(Category node) {
      if (node.selfAndDescendantIds.every(selected.contains)) {
        roots.add(node);
      } else {
        node.children.forEach(visit);
      }
    }

    tree.forEach(visit);
    final covered = roots.expand((c) => c.selfAndDescendantIds).toSet();
    return roots.length == 1 && covered.length == selected.length
        ? roots.first
        : null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final single = _single;
    // `GET /categories/{id}` để lấy mô tả chi tiết của danh mục đang xem.
    final detail = single == null
        ? null
        : ref.watch(categoryDetailProvider(single.id));
    final title =
        single?.name ??
        (selected.isEmpty
            ? 'Tất cả sản phẩm'
            : 'Đã chọn ${selected.length} danh mục');
    final description = detail?.value?.description ?? single?.description;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: AppColors.title,
                  ),
                ),
                if (description != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      description,
                      style: const TextStyle(color: AppColors.caption),
                    ),
                  ),
                if (total != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '$total sản phẩm',
                      style: const TextStyle(
                        color: AppColors.caption,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (onOpenFilter != null)
            OutlinedButton.icon(
              onPressed: onOpenFilter,
              icon: const Icon(Icons.filter_alt_outlined, size: 18),
              label: Text(
                selected.isEmpty ? 'Lọc' : 'Lọc (${selected.length})',
              ),
            ),
        ],
      ),
    );
  }
}
