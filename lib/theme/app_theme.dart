import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Kalinka color palette — high-contrast grayscale with berry & brass accents
class KalinkaColors {
  KalinkaColors._();

  // ── Backgrounds ─────────────────────────────────────────────────────────
  // Six-step depth scale. Each level sits above the previous.
  // Never skip levels — use the shallowest level that creates
  // visible separation from the parent surface.

  static const background = Color(
    0xFF080808,
  ); // Page canvas — near-black, behind all surfaces
  static const surfaceBase = Color(
    0xFF111111,
  ); // Header · tab bar · bottom sheets
  static const surfaceRaised = Color(
    0xFF1A1A1C,
  ); // Cards · queue rows · mini-player
  static const surfaceInput = Color(
    0xFF1C1C1C,
  ); // Input fields · search bar · chips
  static const surfaceElevated = Color(
    0xFF222225,
  ); // Pills (unselected) · toggle off · nested
  static const surfaceOverlay = Color(
    0xFF282828,
  ); // Hover · pressed · active row tint

  // ── Borders ─────────────────────────────────────────────────────────────
  // Pure white alpha — clean neutral separation.

  static const borderSubtle = Color(
    0x11FFFFFF,
  ); // 0.07 alpha · Dividers · card edges · row separators
  static const borderDefault = Color(
    0xFF323235,
  ); // 0.13 alpha · Controls · inputs · chips · sheet rules

  // ── Text ────────────────────────────────────────────────────────────────
  // Pure near-white on near-black — maximum contrast.

  static const textPrimary = Color(
    0xFFF2F2F2,
  ); // ~18:1 on bg · Track titles · labels · values
  static const textSecondary = Color(
    0xFF919191,
  ); // ~7:1 on bg · Subtitles · metadata · chip labels
  static const textMuted = Color(
    0xFF858585,
  ); // ~3.5:1 on bg · Section chrome · drag handles · inactive icons
  static const textSectionLabel = Color(
    0xFFB0B0B0,
  ); // ~5:1 on bg · Queue section headers

  // Playfair Display headings only — "Looking for Kalinka", "nothing queued",
  // dialog titles. Pure off-white for high-contrast headings.
  // Do not use for body text or monospace content.
  static const frost = Color(0xFFEEEEEE);

  // ── Accent — Kalinka Berry ──────────────────────────────────────────────
  // Primary interactive accent — deep natural red of guelder-rose berries.
  // Active states, progress, selected indicators.
  // Do not use accent directly for body text — use accentTint for labels
  // on accent-tinted surfaces. Use sparingly — max 2 tinted surfaces at once.

  static const accent = Color(0xFFC2394B); // Toggle on · progress · active dot
  static const accentTint = Color(
    0xFFD8556A,
  ); // Bright berry · Labels on accent surfaces
  static const accentSubtle = Color(
    0x14C2394B,
  ); // 0.08 alpha · Now-playing row · active pill bg only
  static const accentBorder = Color(
    0x66C2394B,
  ); // 0.40 alpha · Focused inputs · selected cards

  // ── Accent — Warm Brass ──────────────────────────────────────────────────
  // Secondary signal for streaming/external content — gold-plated connector
  // warmth. Appears on module tiles and progress gradient terminus.

  static const gold = Color(
    0xFFF0D58A,
  ); // Brass · streaming module · progress end
  static const goldSubtle = Color(
    0x1FBFA85A,
  ); // 0.12 alpha · Streaming module tile bg

  // ── Progress gradient ────────────────────────────────────────────────────

  static const progressGradient = LinearGradient(colors: [accent, gold]);

  // ── Semantic — Status ───────────────────────────────────────────────────
  // Three states only: online, pending, error.
  // Leaf green for "online" — Kalinka guelder-rose leaves, alive in winter.

  static const statusOnline = Color(
    0xFF5AAE78,
  ); // Leaf green · Connected · success
  static const statusPending = Color(
    0xFFC8943A,
  ); // Amber · Staged · reconnecting
  static const statusOffline = Color(0xFF858585); // Offline

  static const statusOnlineSurface = Color(
    0x1A5AAE78,
  ); // 0.10 alpha · Badge bg · done step
  static const statusPendingSurface = Color(
    0x17C8943A,
  ); // 0.09 alpha · Pending banner bg
  static const statusOfflineSurface = Color(
    0x12C84444,
  ); // 0.07 alpha · Error badge bg · warning note

  // Brighter amber for text on amber-tinted surfaces where the base
  // amber doesn't meet contrast against the tinted bg.
  static const statusPendingLight = Color(
    0xFFE8B86A,
  ); // Use for text/icons on statusPendingSurface only

  // ── Semantic — Actions ──────────────────────────────────────────────────
  // Destructive and confirmatory actions. Separate from status colours
  // because they appear in interactive controls (buttons, swipe actions)
  // rather than passive indicators.

  static const actionDelete = Color(
    0xFFC84444,
  ); // Swipe-to-delete · remove button · destructive CTA
  static const actionConfirm = Color(
    0xFF5AAE78,
  ); // Confirm · apply · positive CTA (leaf green matches statusOnline)
}

class KalinkaFonts {
  KalinkaFonts._();

  // Swap these family names to update typography app-wide.
  static const sansFamily = 'IBM Plex Sans';
  static const monoFamily = 'IBM Plex Mono';
  static const displayFamily = 'Playfair Display';

  static TextStyle sans({
    TextStyle? textStyle,
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
  }) {
    return _style(
      sansFamily,
      textStyle: textStyle,
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  static TextStyle mono({
    TextStyle? textStyle,
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
  }) {
    return _style(
      monoFamily,
      textStyle: textStyle,
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  static TextStyle display({
    TextStyle? textStyle,
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
  }) {
    return _style(
      displayFamily,
      textStyle: textStyle,
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  static TextTheme monoTextTheme([TextTheme? textTheme]) {
    return GoogleFonts.getTextTheme(monoFamily, textTheme);
  }

  static TextTheme sansTextTheme([TextTheme? textTheme]) {
    return GoogleFonts.getTextTheme(sansFamily, textTheme);
  }

  static TextStyle _style(
    String fontFamily, {
    TextStyle? textStyle,
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.getFont(
      fontFamily,
      textStyle: textStyle,
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      height: height,
    );
  }
}

/// Centralized typography scale.
class KalinkaTypography {
  KalinkaTypography._();

  // Smallest size used in the app theme; all other sizes are offsets from this.
  static const double baseSize = 10;
}

/// Kalinka text styles using centralized font roles.
class KalinkaTextStyles {
  KalinkaTextStyles._();

  // Queue items
  static TextStyle queueItemTitle = KalinkaFonts.sans(
    fontSize: KalinkaTypography.baseSize + 4,
    fontWeight: FontWeight.w400,
    color: KalinkaColors.textPrimary,
  );

  static TextStyle queueItemArtist = KalinkaFonts.sans(
    fontSize: KalinkaTypography.baseSize + 1,
    color: KalinkaColors.textSecondary,
  );

  static TextStyle queueItemIndex = KalinkaFonts.mono(
    fontSize: KalinkaTypography.baseSize + 2,
    color: KalinkaColors.textSecondary,
  );

  static TextStyle queueItemDuration = KalinkaFonts.mono(
    fontSize: KalinkaTypography.baseSize + 1,
    color: KalinkaColors.textSecondary,
  );

  // Mini player
  static TextStyle miniPlayerTitle = KalinkaFonts.sans(
    fontSize: KalinkaTypography.baseSize + 4,
    fontWeight: FontWeight.w500,
    color: KalinkaColors.textPrimary,
  );

  static TextStyle miniPlayerArtist = KalinkaFonts.sans(
    fontSize: KalinkaTypography.baseSize + 1,
    color: KalinkaColors.textSecondary,
  );

  // Expanded player
  static TextStyle expandedTitle = KalinkaFonts.display(
    fontSize: KalinkaTypography.baseSize + 20,
    color: KalinkaColors.textPrimary,
  );

  static TextStyle expandedArtist = KalinkaFonts.sans(
    fontSize: KalinkaTypography.baseSize + 7,
    color: KalinkaColors.textPrimary,
  );

  static TextStyle expandedAlbum = KalinkaFonts.sans(
    fontSize: KalinkaTypography.baseSize + 4,
    color: KalinkaColors.textSecondary,
  );

  static TextStyle expandedAttribution = KalinkaFonts.mono(
    fontSize: KalinkaTypography.baseSize + 2,
    color: KalinkaColors.textSecondary,
  );

  // Labels
  static TextStyle nowPlayingLabel = KalinkaFonts.mono(
    fontSize: KalinkaTypography.baseSize + 0,
    fontWeight: FontWeight.w600,
    letterSpacing: 2.0,
    color: KalinkaColors.textSecondary,
  );

  static TextStyle formatBadge = KalinkaFonts.mono(
    fontSize: KalinkaTypography.baseSize + 1,
    fontWeight: FontWeight.w500,
    color: KalinkaColors.textSecondary,
  );

  static TextStyle sourceBadgeLetter = KalinkaFonts.mono(
    fontSize: KalinkaTypography.baseSize + 1,
    fontWeight: FontWeight.w500,
    height: 1,
  );

  static TextStyle sectionHeader = KalinkaFonts.mono(
    fontSize: KalinkaTypography.baseSize + 1,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0,
    color: KalinkaColors.textSecondary,
  );

  // Search
  static TextStyle searchPlaceholder = KalinkaFonts.mono(
    fontSize: KalinkaTypography.baseSize + 3,
    color: KalinkaColors.textSecondary,
  );

  static TextStyle aiBadge = KalinkaFonts.mono(
    fontSize: KalinkaTypography.baseSize + 1,
    fontWeight: FontWeight.w700,
    color: KalinkaColors.textSecondary,
  );

  static TextStyle aiPlaylistName = KalinkaFonts.display(
    fontSize: KalinkaTypography.baseSize + 6,
    color: KalinkaColors.textPrimary,
  );

  static TextStyle searchTab = KalinkaFonts.sans(
    fontSize: KalinkaTypography.baseSize + 3,
    fontWeight: FontWeight.w500,
  );

  // Search results
  static TextStyle resultCountHint = KalinkaFonts.mono(
    fontSize: KalinkaTypography.baseSize + 1,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.5,
    color: KalinkaColors.textSecondary,
  );

  static TextStyle sectionLabel = KalinkaFonts.mono(
    fontSize: KalinkaTypography.baseSize + 1,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.5,
    color: KalinkaColors.textSectionLabel,
  );

  static TextStyle trackRowTitle = KalinkaFonts.sans(
    fontSize: KalinkaTypography.baseSize + 4,
    fontWeight: FontWeight.w400,
    color: KalinkaColors.textPrimary,
  );

  static TextStyle trackRowSubtitle = KalinkaFonts.sans(
    fontSize: KalinkaTypography.baseSize + 1,
    color: KalinkaColors.textSecondary,
  );

  static TextStyle cardTitle = KalinkaFonts.sans(
    fontSize: KalinkaTypography.baseSize + 5,
    fontWeight: FontWeight.w500,
    color: KalinkaColors.textPrimary,
  );

  static TextStyle tagPill = KalinkaFonts.sans(
    fontSize: KalinkaTypography.baseSize + 2,
    fontWeight: FontWeight.w500,
    color: KalinkaColors.textSecondary,
  );

  static TextStyle showMoreLabel = KalinkaFonts.sans(
    fontSize: KalinkaTypography.baseSize + 2,
    fontWeight: FontWeight.w600,
    color: KalinkaColors.textSecondary,
  );

  static TextStyle aiCardLabel = KalinkaFonts.mono(
    fontSize: KalinkaTypography.baseSize + 1,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.5,
    color: KalinkaColors.textSecondary,
  );

  static TextStyle aiTrackChip = KalinkaFonts.sans(
    fontSize: KalinkaTypography.baseSize + 2,
    color: KalinkaColors.textPrimary,
  );

  static TextStyle aiTrackChipDuration = KalinkaFonts.mono(
    fontSize: KalinkaTypography.baseSize + 1,
    color: KalinkaColors.textSecondary,
  );

  static TextStyle browseButtonLabel = KalinkaFonts.sans(
    fontSize: KalinkaTypography.baseSize + 2,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0,
    color: KalinkaColors.textSecondary,
  );

  static TextStyle cancelButton = KalinkaFonts.sans(
    fontSize: KalinkaTypography.baseSize + 3,
    color: KalinkaColors.textSecondary,
  );

  static TextStyle searchBarInput = KalinkaFonts.mono(
    fontSize: KalinkaTypography.baseSize + 3,
    color: KalinkaColors.textPrimary,
  );

  // Completion strip
  static TextStyle completionText = KalinkaFonts.mono(
    fontSize: KalinkaTypography.baseSize + 3,
    color: KalinkaColors.textPrimary,
  );

  static TextStyle completionMatchHighlight = KalinkaFonts.mono(
    fontSize: KalinkaTypography.baseSize + 3,
    color: KalinkaColors.textPrimary,
  );

  static TextStyle aiCompletionText = KalinkaFonts.sans(
    fontSize: KalinkaTypography.baseSize + 3,
    color: KalinkaColors.textPrimary,
  );

  // AI prompt chips (zero-state)
  static TextStyle aiPromptChipText = KalinkaFonts.sans(
    fontSize: KalinkaTypography.baseSize + 4,
    fontWeight: FontWeight.w300,
    color: KalinkaColors.textSectionLabel,
  );

  // Clear all link
  static TextStyle clearAllLink = KalinkaFonts.sans(
    fontSize: KalinkaTypography.baseSize + 1,
    color: KalinkaColors.textSecondary,
  );

  static TextStyle batchBarLabel = KalinkaFonts.mono(
    fontSize: KalinkaTypography.baseSize + 1,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.5,
    color: KalinkaColors.textSecondary,
  );

  // Time
  static TextStyle timeLabel = KalinkaFonts.mono(
    fontSize: KalinkaTypography.baseSize + 1,
    color: KalinkaColors.textSecondary,
  );

  // Queue management tray
  static TextStyle trayTitle = KalinkaFonts.mono(
    fontSize: KalinkaTypography.baseSize + 1,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
    color: KalinkaColors.textSecondary,
  );

  static TextStyle traySectionLabel = KalinkaFonts.mono(
    fontSize: KalinkaTypography.baseSize + 1,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.8,
    color: KalinkaColors.textSecondary,
  );

  static TextStyle trayRowLabel = KalinkaFonts.sans(
    fontSize: KalinkaTypography.baseSize + 4,
    letterSpacing: -0.1,
    color: KalinkaColors.textPrimary,
  );

  static TextStyle trayRowSublabel = KalinkaFonts.sans(
    fontSize: KalinkaTypography.baseSize + 1,
    color: KalinkaColors.textSecondary,
  );

  // Queue section headers
  static TextStyle trackCountBadge = KalinkaFonts.mono(
    fontSize: KalinkaTypography.baseSize + 1,
    color: KalinkaColors.textSecondary,
  );

  static TextStyle shuffleBadgeText = KalinkaFonts.mono(
    fontSize: KalinkaTypography.baseSize + 1,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    color: KalinkaColors.textSecondary,
  );

  // Empty queue state
  static TextStyle emptyQueueTitle = KalinkaFonts.display(
    fontSize: KalinkaTypography.baseSize + 12,
    color: KalinkaColors.frost,
  );

  static TextStyle emptyQueueSubtitle = KalinkaFonts.sans(
    fontSize: KalinkaTypography.baseSize + 3,
    color: KalinkaColors.textSecondary,
  );

  // Confirm dialog
  static TextStyle dialogTitle = KalinkaFonts.display(
    fontSize: KalinkaTypography.baseSize + 10,
    color: KalinkaColors.frost,
  );

  static TextStyle dialogBody = KalinkaFonts.sans(
    fontSize: KalinkaTypography.baseSize + 2,
    height: 1.6,
    color: KalinkaColors.textSecondary,
  );

  static TextStyle dialogButton = KalinkaFonts.sans(
    fontSize: KalinkaTypography.baseSize + 4,
    fontWeight: FontWeight.w500,
  );

  // Lettermark
  static TextStyle lettermark = KalinkaFonts.display(
    fontSize: KalinkaTypography.baseSize + 12,
    fontStyle: FontStyle.italic,
    color: KalinkaColors.textPrimary,
  );

  // Server chip
  static TextStyle serverChipLabel = KalinkaFonts.mono(
    fontSize: KalinkaTypography.baseSize + 1,
    fontWeight: FontWeight.w500,
    color: KalinkaColors.textPrimary,
  );

  // Connection banners
  static TextStyle bannerText = KalinkaFonts.sans(
    fontSize: KalinkaTypography.baseSize + 3,
    color: KalinkaColors.statusPendingLight,
  );

  // Action toast notifications
  static TextStyle toastText = KalinkaFonts.sans(
    fontSize: KalinkaTypography.baseSize + 2,
    color: KalinkaColors.textPrimary,
  );

  // Status section header (frozen queue label, server sheet).
  // Uses textSecondary (6.9:1) instead of textMuted (2.2:1) because this
  // text communicates meaningful state, not a disabled/decorative element.
  static TextStyle sectionHeaderMuted = KalinkaFonts.mono(
    fontSize: KalinkaTypography.baseSize + 1,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.8,
    color: KalinkaColors.textSecondary,
  );

  // ── Search zero-state v15 ─────────────────────────────────────────────────

  /// Recent search chip label
  static TextStyle recentChipLabel = KalinkaFonts.sans(
    fontSize: KalinkaTypography.baseSize + 3,
    fontWeight: FontWeight.w400,
    color: KalinkaColors.textSecondary,
  );

  /// Filter pill label — inactive state
  static TextStyle filterPillInactive = KalinkaFonts.sans(
    fontSize: KalinkaTypography.baseSize + 2,
    fontWeight: FontWeight.w400,
    color: KalinkaColors.textSecondary,
  );

  /// Filter pill label — active state
  static TextStyle filterPillActive = KalinkaFonts.sans(
    fontSize: KalinkaTypography.baseSize + 2,
    fontWeight: FontWeight.w500,
    color: KalinkaColors.accentTint,
  );

  /// "Clear all" button in the chip row
  static TextStyle clearAllChips = KalinkaFonts.sans(
    fontSize: KalinkaTypography.baseSize + 2,
    fontWeight: FontWeight.w400,
    color: KalinkaColors.textMuted,
  );
}

/// App-wide Material theme
class AppTheme {
  static ThemeData dark() {
    final baseTextTheme = KalinkaFonts.sansTextTheme(
      ThemeData.dark().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        surface: KalinkaColors.background,
        surfaceContainerHighest: KalinkaColors.surfaceInput,
        onSurface: KalinkaColors.textPrimary,
        onSurfaceVariant: KalinkaColors.textSecondary,
        outline: KalinkaColors.borderSubtle,
        outlineVariant: KalinkaColors.borderDefault,
        primary: KalinkaColors.accent,
        onPrimary: KalinkaColors.textPrimary,
        secondary: KalinkaColors.gold,
        onSecondary: KalinkaColors.background,
      ),
      scaffoldBackgroundColor: KalinkaColors.background,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      textTheme: baseTextTheme.copyWith(
        titleMedium: KalinkaFonts.sans(
          fontSize: KalinkaTypography.baseSize + 6,
          fontWeight: FontWeight.w500,
          color: KalinkaColors.textPrimary,
          letterSpacing: -0.2,
        ),
        bodyMedium: KalinkaFonts.sans(
          fontSize: KalinkaTypography.baseSize + 5,
          color: KalinkaColors.textSecondary,
          letterSpacing: -0.1,
        ),
        bodySmall: KalinkaFonts.sans(
          fontSize: KalinkaTypography.baseSize + 3,
          color: KalinkaColors.textSecondary,
          letterSpacing: -0.1,
        ),
      ),
      iconTheme: const IconThemeData(
        color: KalinkaColors.textPrimary,
        size: 24,
      ),
      dividerTheme: const DividerThemeData(
        color: KalinkaColors.borderSubtle,
        thickness: 1,
        space: 1,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: KalinkaColors.accent,
        inactiveTrackColor: KalinkaColors.borderDefault,
        thumbColor: Colors.white,
        overlayColor: KalinkaColors.accent.withValues(alpha: 0.2),
        trackHeight: 3,
      ),
      chipTheme: ChipThemeData(
        color: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return Colors.white.withValues(alpha: 0.13);
          }
          return const Color(0x0DFFFFFF);
        }),
        selectedColor: const Color(0x0DFFFFFF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: const BorderSide(color: Color(0x17FFFFFF), width: 1),
        labelStyle: KalinkaTextStyles.filterPillInactive,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }
}
