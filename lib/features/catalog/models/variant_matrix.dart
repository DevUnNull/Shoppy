import 'variant.dart';

class VariantGroup {
  const VariantGroup({required this.name, required this.options});

  final String name;
  final List<String> options;
}

/// Chuyển danh sách biến thể phẳng ("Đen / 42", "Trắng / 43"…) thành các nhóm
/// phân loại kiểu Shopee (Màu sắc, Kích cỡ) và tính các lựa chọn khả dụng.
class VariantMatrix {
  VariantMatrix._(this.variants, this.groups, this._optionsByVariant);

  factory VariantMatrix.from(List<Variant> variants) {
    final active = variants.where((v) => v.isActive).toList();
    final split = {for (final v in active) v.id: _split(v.name)};
    final partCounts = split.values.map((p) => p.length).toSet();
    final uniform = partCounts.length == 1 && partCounts.first > 1;

    final Map<int, List<String>> optionsByVariant = uniform
        ? split
        : {
            for (final v in active)
              v.id: [v.name.isEmpty ? 'Mặc định' : v.name],
          };
    final groupCount = uniform ? partCounts.first : 1;

    final groups = <VariantGroup>[];
    for (var g = 0; g < groupCount; g++) {
      final options = <String>[];
      for (final v in active) {
        final option = optionsByVariant[v.id]![g];
        if (!options.contains(option)) options.add(option);
      }
      groups.add(
        VariantGroup(
          name: _guessGroupName(options, g, groupCount),
          options: options,
        ),
      );
    }
    return VariantMatrix._(active, groups, optionsByVariant);
  }

  final List<Variant> variants;
  final List<VariantGroup> groups;
  final Map<int, List<String>> _optionsByVariant;

  /// Sản phẩm chỉ có 1 biến thể mặc định -> không cần hiển thị bộ chọn.
  bool get isTrivial =>
      variants.length <= 1 &&
      (variants.isEmpty ||
          variants.first.name.isEmpty ||
          variants.first.name.toLowerCase() == 'mặc định');

  List<String?> emptySelection() => List<String?>.filled(groups.length, null);

  /// Các biến thể khớp với lựa chọn hiện tại (null = chưa chọn nhóm đó).
  List<Variant> matching(List<String?> selection) => variants.where((v) {
    final opts = _optionsByVariant[v.id]!;
    for (var g = 0; g < groups.length; g++) {
      if (selection[g] != null && selection[g] != opts[g]) return false;
    }
    return true;
  }).toList();

  /// Option có thể chọn được không (còn ít nhất 1 biến thể còn hàng
  /// khi kết hợp với các nhóm khác đã chọn).
  bool isOptionAvailable(int group, String option, List<String?> selection) {
    final probe = [...selection]..[group] = option;
    return matching(probe).any((v) => v.isAvailable);
  }

  /// Biến thể đã chọn đầy đủ tất cả nhóm.
  Variant? resolve(List<String?> selection) {
    if (selection.any((s) => s == null)) return null;
    final result = matching(selection);
    return result.isEmpty ? null : result.first;
  }

  /// Chọn sẵn khi chỉ có 1 option khả dụng ở mỗi nhóm (vd. biến thể mặc định).
  List<String?> initialSelection() {
    final selection = emptySelection();
    for (var g = 0; g < groups.length; g++) {
      final available = groups[g].options
          .where((o) => isOptionAvailable(g, o, selection))
          .toList();
      if (groups[g].options.length == 1 && available.length == 1) {
        selection[g] = available.first;
      }
    }
    return selection;
  }

  static final _separator = RegExp(r'\s+-\s+|\s*[/,|;]\s*');

  static List<String> _split(String name) => name
      .split(_separator)
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();

  static const _colorWords = [
    'đen',
    'trắng',
    'đỏ',
    'xanh',
    'vàng',
    'hồng',
    'xám',
    'ghi',
    'nâu',
    'tím',
    'cam',
    'be',
    'bạc',
    'kem',
    'black',
    'white',
    'red',
    'blue',
    'green',
    'pink',
    'gray',
    'grey',
    'gold',
    'silver',
  ];
  static final _sizePattern = RegExp(
    r'^(xxs|xs|s|m|l|xl|xxl|xxxl|\d{1,3}(\.\d)?|\d+\s?(gb|tb|ml|l|cm|mm|kg|g))$',
    caseSensitive: false,
  );

  static String _guessGroupName(List<String> options, int index, int count) {
    final lower = options.map((o) => o.toLowerCase()).toList();
    if (lower.every((o) => _colorWords.any((c) => o.split(' ').contains(c)))) {
      return 'Màu sắc';
    }
    if (lower.every(_sizePattern.hasMatch)) return 'Kích cỡ';
    return count == 1 ? 'Phân loại' : 'Phân loại ${index + 1}';
  }
}
