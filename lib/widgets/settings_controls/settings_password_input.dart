import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Password/masked input with eye toggle button.
class SettingsPasswordInput extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final double width;

  const SettingsPasswordInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.width = 145,
  });

  @override
  State<SettingsPasswordInput> createState() => _SettingsPasswordInputState();
}

class _SettingsPasswordInputState extends State<SettingsPasswordInput> {
  bool _obscured = true;

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
                controller: TextEditingController(text: widget.value)
                  ..selection = TextSelection.collapsed(
                    offset: widget.value.length,
                  ),
                obscureText: _obscured,
                style: KalinkaTextStyles.searchBarInput.copyWith(fontSize: 12),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  isDense: true,
                ),
                onChanged: widget.onChanged,
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
