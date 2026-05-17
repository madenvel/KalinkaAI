import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Password/masked input with eye toggle button.
///
/// Same commit semantics as [SettingsTextInput]: the typed value is held
/// locally and only propagated to [onChanged] on focus loss, submit, or
/// dispose. Re-staging on every keystroke would steal focus and the user
/// would lose every character after the first.
class SettingsPasswordInput extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final double? width;

  const SettingsPasswordInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.width,
  });

  @override
  State<SettingsPasswordInput> createState() => _SettingsPasswordInputState();
}

class _SettingsPasswordInputState extends State<SettingsPasswordInput> {
  bool _obscured = true;
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant SettingsPasswordInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value &&
        !_focusNode.hasFocus &&
        _controller.text != widget.value) {
      _controller.text = widget.value;
      _controller.selection = TextSelection.collapsed(
        offset: widget.value.length,
      );
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

  void _commitIfChanged() {
    if (_controller.text != widget.value) {
      widget.onChanged(_controller.text);
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
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                obscureText: _obscured,
                style: KalinkaTextStyles.searchBarInput.copyWith(
                  fontSize: KalinkaTypography.baseSize + 2,
                ),
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  isDense: true,
                ),
                onSubmitted: (_) => _commitIfChanged(),
                onEditingComplete: _commitIfChanged,
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _obscured = !_obscured),
              child: Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: KalinkaColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: KalinkaColors.borderDefault),
                ),
                child: Icon(
                  _obscured ? Icons.visibility_off : Icons.visibility,
                  size: 13,
                  color: KalinkaColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
