import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';

/// Bộ chọn số lượng `[-] [ n ] [+]`, giới hạn trong [1, max].
class QuantitySelector extends StatefulWidget {
  const QuantitySelector({
    super.key,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  State<QuantitySelector> createState() => _QuantitySelectorState();
}

class _QuantitySelectorState extends State<QuantitySelector> {
  late final _controller = TextEditingController(text: '${widget.value}');
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit(_controller.text);
    });
  }

  @override
  void didUpdateWidget(covariant QuantitySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != '${widget.value}' && !_focus.hasFocus) {
      _controller.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit(String raw) {
    final upper = widget.max < 1 ? 1 : widget.max;
    final parsed = (int.tryParse(raw) ?? widget.value).clamp(1, upper);
    _controller.text = '$parsed';
    if (parsed != widget.value) widget.onChanged(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.max < 1;
    return Container(
      height: 32,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black.withValues(alpha: 0.09)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _button(
            Icons.remove,
            !disabled && widget.value > 1,
            () => widget.onChanged(widget.value - 1),
          ),
          Container(
            width: 50,
            decoration: BoxDecoration(
              border: Border.symmetric(
                vertical: BorderSide(
                  color: Colors.black.withValues(alpha: 0.09),
                ),
              ),
            ),
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              enabled: !disabled,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onSubmitted: _commit,
              style: const TextStyle(fontSize: 15, color: AppColors.primary),
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          _button(
            Icons.add,
            !disabled && widget.value < widget.max,
            () => widget.onChanged(widget.value + 1),
          ),
        ],
      ),
    );
  }

  Widget _button(IconData icon, bool enabled, VoidCallback onTap) => InkWell(
    onTap: enabled ? onTap : null,
    child: SizedBox(
      width: 32,
      height: 32,
      child: Icon(
        icon,
        size: 16,
        color: enabled ? AppColors.body : AppColors.border,
      ),
    ),
  );
}
