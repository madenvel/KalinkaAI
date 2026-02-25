import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Text input field for settings.
///
/// Dark surface background, small font. Supports wide (145px) and full-width variants.
/// Shows accent-colored border on focus.
class SettingsTextInput extends StatelessWidget {
  final String value;
  final String? hintText;
  final ValueChanged<String> onChanged;
  final double? width;
  final bool obscureText;

  const SettingsTextInput({
    super.key,
    required this.value,
    this.hintText,
    required this.onChanged,
    this.width,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        decoration: BoxDecoration(
          color: KalinkaColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: KalinkaColors.borderDefault),
        ),
        child: TextField(
          controller: TextEditingController(text: value)
            ..selection = TextSelection.collapsed(offset: value.length),
          obscureText: obscureText,
          style: KalinkaTextStyles.searchBarInput.copyWith(fontSize: 12),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: KalinkaTextStyles.searchPlaceholder.copyWith(
              fontSize: 12,
              color: KalinkaColors.textSecondary,
            ),
            border: InputBorder.none,
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: BorderSide(
                color: KalinkaColors.accent.withValues(alpha: 0.45),
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 7,
            ),
            isDense: true,
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
