import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';

/// 6 ô nhập OTP: tự focus ô kế tiếp khi gõ, Backspace lùi về ô trước,
/// dán cả mã (vd. "123456") sẽ tự phân bổ vào các ô.
class OtpInput extends StatefulWidget {
  const OtpInput({
    super.key,
    this.length = 6,
    required this.onChanged,
    this.onCompleted,
    this.hasError = false,
  });

  final int length;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onCompleted;
  final bool hasError;

  @override
  State<OtpInput> createState() => OtpInputState();
}

class OtpInputState extends State<OtpInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _nodes;

  String get code => _controllers.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _nodes = List.generate(widget.length, (i) {
      final node = FocusNode(onKeyEvent: (node, event) => _onKey(i, event));
      node.addListener(() {
        // Chọn sẵn ký tự để gõ đè thay vì nối thêm.
        if (node.hasFocus) {
          final c = _controllers[i];
          c.selection = TextSelection(
            baseOffset: 0,
            extentOffset: c.text.length,
          );
        }
      });
      return node;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nodes.first.requestFocus();
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  /// Xoá toàn bộ và focus lại ô đầu (khi OTP sai).
  void clear() {
    for (final c in _controllers) {
      c.clear();
    }
    _nodes.first.requestFocus();
    widget.onChanged('');
  }

  KeyEventResult _onKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _controllers[index - 1].clear();
      _nodes[index - 1].requestFocus();
      _notify();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft && index > 0) {
      _nodes[index - 1].requestFocus();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
        index < widget.length - 1) {
      _nodes[index + 1].requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _onChanged(int index, String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 1) {
      // Dán mã: phân bổ từ ô hiện tại trở đi.
      var i = index;
      for (final ch in digits.split('')) {
        if (i >= widget.length) break;
        _controllers[i].text = ch;
        i++;
      }
      _nodes[(i).clamp(0, widget.length - 1)].requestFocus();
    } else {
      _controllers[index].text = digits;
      if (digits.isNotEmpty && index < widget.length - 1) {
        _nodes[index + 1].requestFocus();
      }
    }
    _notify();
  }

  void _notify() {
    final value = code;
    widget.onChanged(value);
    if (value.length == widget.length) {
      FocusScope.of(context).unfocus();
      widget.onCompleted?.call(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size =
            ((constraints.maxWidth - 8 * (widget.length - 1)) / widget.length)
                .clamp(36.0, 48.0);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              SizedBox(
                width: size,
                height: size + 6,
                child: TextField(
                  controller: _controllers[i],
                  focusNode: _nodes[i],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  autofillHints: i == 0
                      ? const [AutofillHints.oneTimeCode]
                      : null,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (v) => _onChanged(i, v),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: AppColors.title,
                  ),
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.zero,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(2),
                      borderSide: BorderSide(
                        color: widget.hasError
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(2),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
