import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Numeric input with optional constraints. 80px wide, right-aligned.
/// Shows accent-colored border on focus.
///
/// Commit semantics mirror [SettingsTextInput]: the parsed value is held
/// locally while the field has focus and only propagated on blur, submit,
/// or dispose. Staging on every keystroke would re-render the parent on
/// each character and steal focus mid-edit.
class SettingsNumericInput extends StatefulWidget {
  final num value;
  final ValueChanged<num> onChanged;
  final double width;

  const SettingsNumericInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.width = 80,
  });

  @override
  State<SettingsNumericInput> createState() => _SettingsNumericInputState();
}

class _SettingsNumericInputState extends State<SettingsNumericInput> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  // Track the value we last reported to the parent so we don't re-emit
  // an unchanged value on a focus-blur after the user typed and then
  // erased back to where they started.
  late num _committedValue;

  @override
  void initState() {
    super.initState();
    _committedValue = widget.value;
    _controller = TextEditingController(text: widget.value.toString());
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant SettingsNumericInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && !_focusNode.hasFocus) {
      _committedValue = widget.value;
      final text = widget.value.toString();
      if (_controller.text != text) {
        _controller.text = text;
        _controller.selection = TextSelection.collapsed(offset: text.length);
      }
    }
  }

  @override
  void dispose() {
    _commitIfChanged();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) _commitIfChanged();
  }

  /// Parse + emit only if the text is a valid number and differs from
  /// what the parent currently holds. Invalid text (mid-typing "1.")
  /// is left alone — the user might continue typing — and silently
  /// reverts on blur because we restore the text from
  /// [_committedValue].
  void _commitIfChanged() {
    final parsed = num.tryParse(_controller.text);
    if (parsed == null) {
      // Restore display so the user isn't left looking at an unparseable
      // string after blurring.
      final restored = _committedValue.toString();
      if (_controller.text != restored) {
        _controller.text = restored;
        _controller.selection = TextSelection.collapsed(
          offset: restored.length,
        );
      }
      return;
    }
    if (parsed != _committedValue) {
      _committedValue = parsed;
      widget.onChanged(parsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: Container(
        decoration: BoxDecoration(
          color: KalinkaColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: KalinkaColors.borderDefault),
        ),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.right,
          textInputAction: TextInputAction.done,
          style: KalinkaTextStyles.searchBarInput.copyWith(
            fontSize: KalinkaTypography.baseSize + 2,
          ),
          decoration: InputDecoration(
            border: InputBorder.none,
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: const BorderSide(color: Color(0x55FFFFFF)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 7,
            ),
            isDense: true,
          ),
          onSubmitted: (_) => _commitIfChanged(),
          onEditingComplete: _commitIfChanged,
        ),
      ),
    );
  }
}
