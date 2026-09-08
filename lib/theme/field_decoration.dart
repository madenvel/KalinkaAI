import 'package:flutter/material.dart';

import 'app_theme.dart';

/// The look of a field in a sheet: filled, rounded, and berry-edged while it
/// holds the focus. Sheets ask for one line of text at a time, so they all
/// wear the same one.
InputDecoration kalinkaFieldDecoration({
  required String hint,
  Widget? prefixIcon,
}) => InputDecoration(
  hintText: hint,
  hintStyle: KalinkaTextStyles.trackRowSubtitle,
  prefixIcon: prefixIcon,
  counterText: '',
  filled: true,
  fillColor: KalinkaColors.surfaceElevated,
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: KalinkaColors.borderDefault),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: KalinkaColors.accent),
  ),
);
