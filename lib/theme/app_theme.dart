import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Kalinka color palette — viburnum-inspired dark theme
class KalinkaColors {
  KalinkaColors._();

  // ── Backgrounds ─────────────────────────────────────────────────────────
  // Six-step depth scale. Each level sits above the previous.
  // Never skip levels — use the shallowest level that creates
  // visible separation from the parent surface.

  static const background = Color(
    0xFF0A0A0D,
  ); // Page canvas — behind all surfaces
  static const surfaceBase = Color(
    0xFF111116,
  ); // Header · tab bar · bottom sheets
  static const surfaceRaised = Color(
    0xFF16161B,
  ); // Cards · queue rows · mini-player
  static const surfaceInput = Color(
    0xFF1C1C22,
  ); // Input fields · search bar · chips
  static const surfaceElevated = Color(
    0xFF222228,
  ); // Pills (unselected) · toggle off · nested
  static const surfaceOverlay = Color(
    0xFF2A2A32,
  ); // Hover · pressed · active row tint

  // ── Borders ─────────────────────────────────────────────────────────────
  // Always white-alpha — never solid. Works against any surface level.

  static const borderSubtle = Color(
    0x1EFFFFFF,
  ); // 0.12 · Dividers · card edges · row separators
  static const borderDefault = Color(
    0x33FFFFFF,
  ); // 0.20 · Controls · inputs · chips · sheet rules

  // ── Text ────────────────────────────────────────────────────────────────
  // Three legibility tiers. All pass WCAG AA on background and surfaceBase.
  // textSecondary and textMuted must be verified on surfaceRaised and above
  // before use at sizes below 14px.

  static const textPrimary = Color(
    0xFFEEECEA,
  ); // 15.8:1 on bg · Track titles · labels · values
  static const textSecondary = Color(
    0xFFBABABC,
  ); // 7.0:1 on bg · Subtitles · metadata · chip labels
  static const textMuted = Color(
    0xFF888899,
  ); // 5.0:1 on bg · Section chrome · drag handles · inactive icons

  // ── Accent — Rose/Crimson ───────────────────────────────────────────────
  // Primary interactive accent. Active states, progress, selected indicators.
  // Do not use accent directly for body text — use accentTint for labels
  // on accent-tinted surfaces.

  static const accent = Color(
    0xFFC23B5C,
  ); // 5.2:1 on bg · Toggle on · progress · active dot
  static const accentTint = Color(
    0xFFD4647A,
  ); // 5.6:1 on surfaceInput · Labels on accent surfaces
  static const accentSubtle = Color(
    0x26C23B5C,
  ); // 0.15 alpha · Selected pill bg · focus tint
  static const accentBorder = Color(
    0x59C23B5C,
  ); // 0.35 alpha · Selected pill border · focus ring

  // ── Accent — Gold ────────────────────────────────────────────────────────
  // Material signal for streaming/external content. Not an interactive accent.
  // Appears on Qobuz module tile and progress gradient terminus only.

  static const gold = Color(
    0xFFE8C87A,
  ); // 8.1:1 on bg · Streaming module · progress end
  static const goldSubtle = Color(
    0x1FE8C87A,
  ); // 0.12 alpha · Streaming module tile bg

  // ── Progress gradient ────────────────────────────────────────────────────

  static const progressGradient = LinearGradient(colors: [accent, gold]);

  // ── Semantic — Status ───────────────────────────────────────────────────
  // Three states only: success/online, warning/pending, error/offline.
  // Each has a pure value (for dots, text, icons) and a surface tint
  // (for badge backgrounds and banner fills).
  // Do not repurpose these colours outside their semantic role.

  static const statusOnline = Color(
    0xFF4ADE80,
  ); // 6.4:1 on surfaceInput · Connected · success
  static const statusPending = Color(
    0xFFF59E0B,
  ); // 5.2:1 on surfaceInput · Staged · reconnecting
  static const statusError = Color(
    0xFFEF4444,
  ); // 4.5:1 on surfaceInput · Offline · failed

  static const statusOnlineSurface = Color(
    0x1A4ADE80,
  ); // 0.10 alpha · Badge bg · done step
  static const statusPendingSurface = Color(
    0x17F59E0B,
  ); // 0.09 alpha · Pending banner bg
  static const statusErrorSurface = Color(
    0x12EF4444,
  ); // 0.07 alpha · Error badge bg · warning note

  // Brighter amber for text on amber-tinted surfaces where the base
  // amber doesn't meet contrast against the tinted bg.
  static const statusPendingLight = Color(
    0xFFFCD34D,
  ); // Use for text/icons on statusPendingSurface only

  // ── Semantic — Actions ──────────────────────────────────────────────────
  // Destructive and confirmatory actions. Separate from status colours
  // because they appear in interactive controls (buttons, swipe actions)
  // rather than passive indicators.

  static const actionDelete = Color(
    0xFFEF4444,
  ); // Swipe-to-delete · remove button · destructive CTA
  static const actionConfirm = Color(
    0xFF4ADE80,
  ); // Confirm · apply · positive CTA
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
    fontSize: 30,
    color: KalinkaColors.textPrimary,
  );

  static TextStyle expandedArtist = GoogleFonts.playfairDisplay(
    fontSize: 16,
    color: KalinkaColors.textPrimary,
  );

  static TextStyle expandedAlbum = GoogleFonts.playfairDisplay(
    fontSize: 13,
    color: KalinkaColors.textSecondary,
  );

  static TextStyle expandedAttribution = GoogleFonts.ibmPlexMono(
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
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: KalinkaColors.accentTint,
  );

  static TextStyle sourceBadgeLetter = GoogleFonts.ibmPlexMono(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1,
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
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: KalinkaColors.accentTint,
  );

  static TextStyle aiPlaylistName = GoogleFonts.playfairDisplay(
    fontSize: 16,
    color: KalinkaColors.textPrimary,
  );

  static TextStyle searchTab = GoogleFonts.ibmPlexMono(
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  // Search results
  static TextStyle resultCountHint = GoogleFonts.ibmPlexMono(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.5,
    color: KalinkaColors.textSecondary,
  );

  static TextStyle sectionLabel = GoogleFonts.ibmPlexMono(
    fontSize: 11,
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
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: KalinkaColors.textSecondary,
  );

  static TextStyle showMoreLabel = GoogleFonts.ibmPlexMono(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: KalinkaColors.accentTint,
  );

  static TextStyle aiCardLabel = GoogleFonts.ibmPlexMono(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.5,
    color: KalinkaColors.accentTint,
  );

  static TextStyle aiTrackChip = GoogleFonts.ibmPlexMono(
    fontSize: 11,
    color: KalinkaColors.textPrimary,
  );

  static TextStyle aiTrackChipDuration = GoogleFonts.ibmPlexMono(
    fontSize: 11,
    color: KalinkaColors.textSecondary,
  );

  static TextStyle browseButtonLabel = GoogleFonts.ibmPlexMono(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0,
    color: KalinkaColors.accentTint,
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
    color: KalinkaColors.accentTint,
  );

  static TextStyle aiCompletionText = GoogleFonts.playfairDisplay(
    fontSize: 12,
    color: KalinkaColors.textPrimary,
  );

  // AI prompt chips (zero-state)
  static TextStyle aiPromptChipText = GoogleFonts.ibmPlexMono(
    fontSize: 13,
    fontWeight: FontWeight.w300,
    color: KalinkaColors.accentTint,
  );

  // Clear all link
  static TextStyle clearAllLink = GoogleFonts.ibmPlexMono(
    fontSize: 10,
    color: KalinkaColors.textSecondary,
  );

  static TextStyle batchBarLabel = GoogleFonts.ibmPlexMono(
    fontSize: 11,
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
    fontSize: 11,
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
    fontSize: 11,
    color: KalinkaColors.textSecondary,
  );

  static TextStyle shuffleBadgeText = GoogleFonts.ibmPlexMono(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    color: KalinkaColors.gold,
  );

  static TextStyle clearPlayedButton = GoogleFonts.ibmPlexMono(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0,
    color: KalinkaColors.textSecondary,
  );

  // Empty queue state
  static TextStyle emptyQueueTitle = GoogleFonts.playfairDisplay(
    fontSize: 22,
    color: KalinkaColors.textPrimary,
  );

  static TextStyle emptyQueueSubtitle = GoogleFonts.ibmPlexMono(
    fontSize: 12,
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
    color: KalinkaColors.statusPendingLight,
  );

  // Action toast notifications
  static TextStyle toastText = GoogleFonts.ibmPlexMono(
    fontSize: 11,
    color: KalinkaColors.textPrimary,
  );

  // Status section header (frozen queue label, server sheet).
  // Uses textSecondary (6.9:1) instead of textMuted (2.2:1) because this
  // text communicates meaningful state, not a disabled/decorative element.
  static TextStyle sectionHeaderMuted = GoogleFonts.ibmPlexMono(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.8,
    color: KalinkaColors.textSecondary,
  );

  // ── Search zero-state v15 ─────────────────────────────────────────────────

  /// Recent search chip label
  static TextStyle recentChipLabel = GoogleFonts.ibmPlexMono(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: KalinkaColors.textSecondary,
  );

  /// Filter pill label — inactive state
  static TextStyle filterPillInactive = GoogleFonts.ibmPlexMono(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: KalinkaColors.textSecondary,
  );

  /// Filter pill label — active state
  static TextStyle filterPillActive = GoogleFonts.ibmPlexMono(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: KalinkaColors.accentTint,
  );

  /// "Clear all" button in the chip row
  static TextStyle clearAllChips = GoogleFonts.ibmPlexMono(
    fontSize: 11,
    fontWeight: FontWeight.w400,
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
    );
  }
}
