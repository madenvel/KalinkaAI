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
    0xFFBFA85A,
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
    color: KalinkaColors.textSecondary,
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
    color: KalinkaColors.textSecondary,
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
    color: KalinkaColors.textSecondary,
  );

  static TextStyle aiCardLabel = GoogleFonts.ibmPlexMono(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.5,
    color: KalinkaColors.textSecondary,
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
    color: KalinkaColors.textSecondary,
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
    color: KalinkaColors.textPrimary,
  );

  static TextStyle aiCompletionText = GoogleFonts.playfairDisplay(
    fontSize: 12,
    color: KalinkaColors.textPrimary,
  );

  // AI prompt chips (zero-state)
  static TextStyle aiPromptChipText = GoogleFonts.ibmPlexMono(
    fontSize: 13,
    fontWeight: FontWeight.w300,
    color: KalinkaColors.textSecondary,
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
    color: KalinkaColors.textSecondary,
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
    color: KalinkaColors.frost,
  );

  static TextStyle emptyQueueSubtitle = GoogleFonts.ibmPlexMono(
    fontSize: 12,
    color: KalinkaColors.textSecondary,
  );

  // Confirm dialog
  static TextStyle dialogTitle = GoogleFonts.playfairDisplay(
    fontSize: 20,
    color: KalinkaColors.frost,
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
  static TextStyle lettermark = GoogleFonts.playfairDisplay(
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
