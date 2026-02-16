import 'package:flutter/material.dart';

/// Hi-Fi grayscale Material 3 theme
class AppTheme {
  static ThemeData dark() {
    const charcoal = Color(0xFF1C1C1E);
    const surface = Color(0xFF2C2C2E);
    const outline = Color(0xFF48484A);
    const textPrimary = Color(0xFFE5E5E7);
    const textSecondary = Color(0xFF98989A);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        surface: charcoal,
        surfaceContainerHighest: surface,
        onSurface: textPrimary,
        onSurfaceVariant: textSecondary,
        outline: outline,
        outlineVariant: outline,
        primary: textPrimary,
        onPrimary: charcoal,
      ),
      scaffoldBackgroundColor: charcoal,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      textTheme: const TextTheme(
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: textPrimary,
          letterSpacing: -0.2,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: textSecondary,
          letterSpacing: -0.1,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: textSecondary,
          letterSpacing: -0.1,
        ),
      ),
      iconTheme: const IconThemeData(color: textPrimary, size: 24),
      dividerTheme: const DividerThemeData(
        color: outline,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
