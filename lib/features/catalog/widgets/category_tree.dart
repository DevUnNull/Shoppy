import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/category.dart';

/// Cây danh mục đa cấp với checkbox (chọn cha = chọn toàn bộ con).
class CategoryTree extends StatefulWidget {
  const CategoryTree({
    super.key,
    required this.categories,
    required this.selected,
    required this.onChanged,
  });

  final List<Category> categories;
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  @override
  State<CategoryTree> createState() => _CategoryTreeState();
}

class _CategoryTreeState extends State<CategoryTree> {
  final _expanded = <int>{};

  @override
  void initState() {
    super.initState();
    // Mở sẵn nhánh đang được chọn.
    for (final category in widget.categories) {
      if (category.selfAndDescendantIds.any(widget.selected.contains)) {
        _expanded.add(category.id);
      }
    }
  }

  /// true = chọn hết, false = chưa chọn, null = chọn một phần.
  bool? _checkState(Category category) {
    final ids = category.selfAndDescendantIds;
    final count = ids.where(widget.selected.contains).length;
    if (count == 0) return false;
    if (count == ids.length) return true;
    return null;
  }

  void _toggle(Category category) {
    final next = {...widget.selected};
    final ids = category.selfAndDescendantIds;
    if (_checkState(category) == true) {
      next.removeAll(ids);
    } else {
      next.addAll(ids);
    }
    _syncParents(next);
    widget.onChanged(next);
  }

  /// Cha chỉ được tính là "đã chọn" khi tất cả con đều được chọn.
  void _syncParents(Set<int> selection) {
    void visit(Category node) {
      for (final child in node.children) {
        visit(child);
      }
      if (node.children.isEmpty) return;
      final allChildren = node.children.every(
        (c) => c.selfAndDescendantIds.every(selection.contains),
      );
      allChildren ? selection.add(node.id) : selection.remove(node.id);
    }

    widget.categories.forEach(visit);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final c in widget.categories) ..._buildNode(c, 0)],
    );
  }

  List<Widget> _buildNode(Category category, int depth) {
    final hasChildren = category.children.isNotEmpty;
    final expanded = _expanded.contains(category.id);
    final state = _checkState(category);
    return [
      InkWell(
        onTap: () => _toggle(category),
        child: Padding(
          padding: EdgeInsets.only(left: depth * 20.0),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                height: 36,
                child: Checkbox(
                  tristate: true,
                  value: state,
                  onChanged: (_) => _toggle(category),
                  side: const BorderSide(color: AppColors.border),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              Expanded(
                child: Text(
                  category.name,
                  style: TextStyle(
                    fontSize: 14,
                    color: state == false ? AppColors.title : AppColors.primary,
                    fontWeight: depth == 0 ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ),
              if (hasChildren)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  tooltip: expanded ? 'Thu gọn' : 'Mở rộng',
                  onPressed: () => setState(
                    () => expanded
                        ? _expanded.remove(category.id)
                        : _expanded.add(category.id),
                  ),
                  icon: Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.caption,
                  ),
                ),
            ],
          ),
        ),
      ),
      if (hasChildren && expanded)
        for (final child in category.children) ..._buildNode(child, depth + 1),
    ];
  }
}
