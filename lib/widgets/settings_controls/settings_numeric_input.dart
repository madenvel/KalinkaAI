import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Numeric input with optional constraints. 80px wide, right-aligned.
/// Shows accent-colored border on focus.
class SettingsNumericInput extends StatelessWidget {
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
          controller: TextEditingController(text: value.toString()),
          keyboardType: TextInputType.number,
          textAlign: TextAlign.right,
          style: KalinkaTextStyles.searchBarInput.copyWith(fontSize: 12),
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
          onChanged: (text) {
            final parsed = num.tryParse(text);
            if (parsed != null) onChanged(parsed);
          },
        ),
      ),
    );
  }
}
