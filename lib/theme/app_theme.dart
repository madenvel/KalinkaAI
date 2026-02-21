import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Kalinka color palette — viburnum-inspired dark theme
class KalinkaColors {
  KalinkaColors._();

  // Background hierarchy
  static const background = Color(0xFF0A0A0D);
  static const headerSurface = Color(0xFF111116);
  static const miniPlayerSurface = Color(0xFF16161B);
  static const inputSurface = Color(0xFF1C1C22);

  // Accent colors
  static const accent = Color(0xFFC23B5C);
  static const accentTint = Color(0xFFD4647A);
  static const gold = Color(0xFFE8C87A);

  // Text
  static const textPrimary = Color(0xFFE5E5E7);
  static const textSecondary = Color(0xFF98989A);

  // Borders
  static const borderDefault = Color(0x12FFFFFF); // rgba(255,255,255,0.07)
  static const borderElevated = Color(0x21FFFFFF); // rgba(255,255,255,0.13)

  // Secondary surfaces
  static const pillSurface = Color(0xFF222228);

  // Semantic
  static const deleteRed = Color(0xFFE53935);
  static const confirmGreen = Color(0xFF4ADE80);

  // Status colors
  static const textMuted = Color(0xFF48485A);
  static const amber = Color(0xFFF59E0B);
  static const amberLight = Color(0xFFFCD34D);
  static const statusGreen = Color(0xFF4ADE80);
  static const statusRed = Color(0xFFEF4444);

  // Gradient for progress bars
  static const progressGradient = LinearGradient(colors: [accent, gold]);
}

/// Kalinka text styles using IBM Plex Mono and Playfair Display
class KalinkaTextStyles {
  KalinkaTextStyles._();

  // Queue items
  static TextStyle queueItemTitle = GoogleFonts.ibmPlexMono(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: KalinkaColors.textPrimary,
  );

  static TextStyle queueItemArtist = GoogleFonts.ibmPlexMono(
    fontSize: 10,
    color: KalinkaColors.textSecondary,
  );

  static TextStyle queueItemIndex = GoogleFonts.ibmPlexMono(
    fontSize: 12,
    color: KalinkaColors.textSecondary,
  );

  static TextStyle queueItemDuration = GoogleFonts.ibmPlexMono(
    fontSize: 11,
    color: KalinkaColors.textSecondary,
  );

  // Mini player
  static TextStyle miniPlayerTitle = GoogleFonts.ibmPlexMono(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: KalinkaColors.textPrimary,
  );

  static TextStyle miniPlayerArtist = GoogleFonts.ibmPlexMono(
    fontSize: 10,
    color: KalinkaColors.textSecondary,
  );

  // Expanded player
  static TextStyle expandedTitle = GoogleFonts.playfairDisplay(
    fontSize: 26,
    fontStyle: FontStyle.italic,
    color: KalinkaColors.textPrimary,
  );

  static TextStyle expandedArtist = GoogleFonts.ibmPlexMono(
    fontSize: 12,
    color: KalinkaColors.textSecondary,
  );

  // Labels
  static TextStyle nowPlayingLabel = GoogleFonts.ibmPlexMono(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 2.0,
    color: KalinkaColors.textSecondary,
  );

  static TextStyle formatBadge = GoogleFonts.ibmPlexMono(
    fontSize: 9,
    fontWeight: FontWeight.w500,
    color: KalinkaColors.accent,
  );

  static TextStyle sourceBadgeDot = GoogleFonts.ibmPlexMono(
    fontSize: 7.5,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  static TextStyle sectionHeader = GoogleFonts.ibmPlexMono(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0,
    color: KalinkaColors.textSecondary,
  );

  // Search
  static TextStyle searchPlaceholder = GoogleFonts.ibmPlexMono(
    fontSize: 13,
    color: KalinkaColors.textSecondary,
  );

  static TextStyle aiBadge = GoogleFonts.ibmPlexMono(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: KalinkaColors.accent,
  );

  static TextStyle aiPlaylistName = GoogleFonts.playfairDisplay(
    fontSize: 16,
    fontStyle: FontStyle.italic,
    color: KalinkaColors.textPrimary,
  );

  static TextStyle searchTab = GoogleFonts.ibmPlexMono(
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  // Search results
  static TextStyle resultCountHint = GoogleFonts.ibmPlexMono(
    fontSize: 9,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.5,
    color: KalinkaColors.textSecondary,
  );

  static TextStyle sectionLabel = GoogleFonts.ibmPlexMono(
    fontSize: 9,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.5,
    color: KalinkaColors.textSecondary,
  );

  static TextStyle trackRowTitle = GoogleFonts.ibmPlexMono(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: KalinkaColors.textPrimary,
  );

  static TextStyle trackRowSubtitle = GoogleFonts.ibmPlexMono(
    fontSize: 10,
    color: KalinkaColors.textSecondary,
  );

  static TextStyle cardTitle = GoogleFonts.ibmPlexMono(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: KalinkaColors.textPrimary,
  );

  static TextStyle tagPill = GoogleFonts.ibmPlexMono(
    fontSize: 8.5,
    fontWeight: FontWeight.w500,
    color: KalinkaColors.textSecondary,
  );

  static TextStyle showMoreLabel = GoogleFonts.ibmPlexMono(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: KalinkaColors.accent,
  );

  static TextStyle aiCardLabel = GoogleFonts.ibmPlexMono(
    fontSize: 9,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.5,
    color: KalinkaColors.accent,
  );

  static TextStyle aiTrackChip = GoogleFonts.ibmPlexMono(
    fontSize: 11,
    color: KalinkaColors.textPrimary,
  );

  static TextStyle aiTrackChipDuration = GoogleFonts.ibmPlexMono(
    fontSize: 9,
    color: KalinkaColors.textSecondary,
  );

  static TextStyle browseButtonLabel = GoogleFonts.ibmPlexMono(
    fontSize: 9,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0,
    color: KalinkaColors.accent,
  );

  static TextStyle cancelButton = GoogleFonts.ibmPlexMono(
    fontSize: 12,
    color: KalinkaColors.textSecondary,
  );

  static TextStyle searchBarInput = GoogleFonts.ibmPlexMono(
    fontSize: 13,
    color: KalinkaColors.textPrimary,
  );

  // Completion strip
  static TextStyle completionText = GoogleFonts.ibmPlexMono(
    fontSize: 13,
    color: KalinkaColors.textPrimary,
  );

  static TextStyle completionMatchHighlight = GoogleFonts.ibmPlexMono(
    fontSize: 13,
    color: KalinkaColors.accent,
  );

  static TextStyle aiCompletionText = GoogleFonts.playfairDisplay(
    fontSize: 12,
    fontStyle: FontStyle.italic,
    color: KalinkaColors.textPrimary,
  );

  // AI prompt chips (zero-state)
  static TextStyle aiPromptChipText = GoogleFonts.playfairDisplay(
    fontSize: 12,
    fontStyle: FontStyle.italic,
    color: KalinkaColors.textPrimary,
  );

  // Clear all link
  static TextStyle clearAllLink = GoogleFonts.ibmPlexMono(
    fontSize: 10,
    color: KalinkaColors.textSecondary,
  );

  static TextStyle batchBarLabel = GoogleFonts.ibmPlexMono(
    fontSize: 9,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.5,
    color: KalinkaColors.textSecondary,
  );

  // Time
  static TextStyle timeLabel = GoogleFonts.ibmPlexMono(
    fontSize: 11,
    color: KalinkaColors.textSecondary,
  );

  // Queue management tray
  static TextStyle trayTitle = GoogleFonts.ibmPlexMono(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
    color: KalinkaColors.textSecondary,
  );

  static TextStyle traySectionLabel = GoogleFonts.ibmPlexMono(
    fontSize: 8,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.8,
    color: KalinkaColors.textSecondary,
  );

  static TextStyle trayRowLabel = GoogleFonts.ibmPlexMono(
    fontSize: 13,
    letterSpacing: -0.1,
    color: KalinkaColors.textPrimary,
  );

  static TextStyle trayRowSublabel = GoogleFonts.ibmPlexMono(
    fontSize: 10,
    color: KalinkaColors.textSecondary,
  );

  // Queue section headers
  static TextStyle trackCountBadge = GoogleFonts.ibmPlexMono(
    fontSize: 9,
    color: KalinkaColors.textSecondary,
  );

  static TextStyle shuffleBadgeText = GoogleFonts.ibmPlexMono(
    fontSize: 9,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    color: KalinkaColors.gold,
  );

  static TextStyle clearPlayedButton = GoogleFonts.ibmPlexMono(
    fontSize: 9,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0,
    color: KalinkaColors.textSecondary,
  );

  // Empty queue state
  static TextStyle emptyQueueTitle = GoogleFonts.playfairDisplay(
    fontSize: 22,
    fontStyle: FontStyle.italic,
    color: KalinkaColors.textSecondary,
  );

  static TextStyle emptyQueueSubtitle = GoogleFonts.ibmPlexMono(
    fontSize: 10,
    letterSpacing: 0.6,
    color: KalinkaColors.textSecondary,
  );

  // Confirm dialog
  static TextStyle dialogTitle = GoogleFonts.playfairDisplay(
    fontSize: 20,
    color: KalinkaColors.textPrimary,
  );

  static TextStyle dialogBody = GoogleFonts.ibmPlexMono(
    fontSize: 11,
    height: 1.6,
    color: KalinkaColors.textSecondary,
  );

  static TextStyle dialogButton = GoogleFonts.ibmPlexMono(
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );

  // Lettermark
  static TextStyle lettermark = GoogleFonts.instrumentSerif(
    fontSize: 22,
    fontStyle: FontStyle.italic,
    color: KalinkaColors.textPrimary,
  );

  // Server chip
  static TextStyle serverChipLabel = GoogleFonts.ibmPlexMono(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: KalinkaColors.textPrimary,
  );

  // Connection banners
  static TextStyle bannerText = GoogleFonts.ibmPlexMono(
    fontSize: 10,
    color: KalinkaColors.amberLight,
  );

  // Muted section header (settings, server sheet)
  static TextStyle sectionHeaderMuted = GoogleFonts.ibmPlexMono(
    fontSize: 9,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.8,
    color: KalinkaColors.textMuted,
  );
}

/// App-wide Material theme
class AppTheme {
  static ThemeData dark() {
    final baseTextTheme = GoogleFonts.ibmPlexMonoTextTheme(
      ThemeData.dark().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        surface: KalinkaColors.background,
        surfaceContainerHighest: KalinkaColors.inputSurface,
        onSurface: KalinkaColors.textPrimary,
        onSurfaceVariant: KalinkaColors.textSecondary,
        outline: KalinkaColors.borderDefault,
        outlineVariant: KalinkaColors.borderElevated,
        primary: KalinkaColors.accent,
        onPrimary: KalinkaColors.textPrimary,
        secondary: KalinkaColors.gold,
        onSecondary: KalinkaColors.background,
      ),
      scaffoldBackgroundColor: KalinkaColors.background,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      textTheme: baseTextTheme.copyWith(
        titleMedium: GoogleFonts.ibmPlexMono(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: KalinkaColors.textPrimary,
          letterSpacing: -0.2,
        ),
        bodyMedium: GoogleFonts.ibmPlexMono(
          fontSize: 14,
          color: KalinkaColors.textSecondary,
          letterSpacing: -0.1,
        ),
        bodySmall: GoogleFonts.ibmPlexMono(
          fontSize: 12,
          color: KalinkaColors.textSecondary,
          letterSpacing: -0.1,
        ),
      ),
      iconTheme: const IconThemeData(
        color: KalinkaColors.textPrimary,
        size: 24,
      ),
      dividerTheme: const DividerThemeData(
        color: KalinkaColors.borderDefault,
        thickness: 1,
        space: 1,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: KalinkaColors.accent,
        inactiveTrackColor: KalinkaColors.borderElevated,
        thumbColor: Colors.white,
        overlayColor: KalinkaColors.accent.withValues(alpha: 0.2),
        trackHeight: 3,
      ),
    );
  }
}
