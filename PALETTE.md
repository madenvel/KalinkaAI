# Kalinka Palette

High-contrast grayscale with **berry** & **brass** accents. Source of truth: `KalinkaColors` in [lib/theme/app_theme.dart](lib/theme/app_theme.dart).

Flutter colors are `0xAARRGGBB`. Below they're translated to CSS: opaque values as `#RRGGBB`, alpha values as `rgba()` (with the source alpha byte noted).

## Backgrounds

Six-step depth scale — each level sits above the previous. Use the shallowest level that creates visible separation from its parent.

| Token | Hex | Usage |
|---|---|---|
| `background` | `#080808` | Page canvas — near-black, behind all surfaces |
| `surfaceBase` | `#0E0E0E` | Header · tab bar · bottom sheets |
| `surfaceRaised` | `#151513` | Cards · queue rows · mini-player |
| `surfaceInput` | `#171715` | Input fields · search bar · chips |
| `surfaceElevated` | `#1C1C1A` | Pills (unselected) · toggle off · nested |
| `surfaceOverlay` | `#222220` | Hover · pressed · active row tint |

## Borders

Pure white alpha — clean neutral separation.

| Token | RGBA | Usage |
|---|---|---|
| `borderSubtle` | `rgba(255,255,255,0.07)` | Dividers · card edges · row separators |
| `borderDefault` | `#323235` | Controls · inputs · chips · sheet rules |

## Text

Near-white on near-black — maximum contrast.

| Token | Hex | Contrast | Usage |
|---|---|---|---|
| `textPrimary` | `#FAF5F0` | ~18:1 | Track titles · labels · values |
| `textSecondary` | `#A3A3A3` | ~7:1 | Subtitles · metadata · chip labels |
| `textMuted` | `#858585` | ~3.5:1 | Section chrome · drag handles · inactive icons |
| `textSectionLabel` | `#B0B0B0` | ~5:1 | Queue section headers |
| `frost` | `#EEEEEE` | — | Playfair Display headings only (titles) — not body/mono |

## Accent — Kalinka Berry

Primary interactive accent — deep natural red of guelder-rose berries. Active states, progress, selected indicators. Use sparingly — max 2 tinted surfaces at once.

| Token | Value | Usage |
|---|---|---|
| `accent` | `#C2394B` | Toggle on · progress · active dot |
| `accentTint` | `#D8556A` | Bright berry · labels on accent surfaces |
| `accentFaded` | `#250708` | Disabled buttons · inactive pills |
| `accentBright` | `#F59299` | Text/icons on `accentFaded` only |
| `accentSubtle` | `rgba(194,57,75,0.08)` | Now-playing row · active pill bg |
| `accentBorder` | `rgba(194,57,75,0.40)` | Focused inputs · selected cards |

## Accent — Warm Brass

Secondary signal for streaming/external content — gold-plated connector warmth.

| Token | Value | Usage |
|---|---|---|
| `gold` | `#CDC9BE` | Tinted ivory · streaming module · progress end (reads as warm white) |
| `goldSubtle` | `rgba(205,201,190,0.09)` | Streaming module tile bg |

**Progress gradient:** linear `accent → gold` (`#C2394B → #CDC9BE`).

## Semantic — Status

Three states only: online, pending, error. Leaf green for "online" — guelder-rose leaves, alive in winter.

| Token | Value | Usage |
|---|---|---|
| `statusOnline` | `#3D8A58` | Leaf green · connected · success |
| `statusPending` | `#C8943A` | Amber · staged · reconnecting |
| `statusOffline` | `#858585` | Offline |
| `statusOnlineSurface` | `rgba(61,138,88,0.10)` | Badge bg · done step |
| `statusPendingSurface` | `rgba(200,148,58,0.09)` | Pending banner bg |
| `statusOfflineSurface` | `rgba(200,68,68,0.07)` | Error badge bg · warning note |
| `statusPendingLight` | `#E8B86A` | Text/icons on `statusPendingSurface` only |

## Semantic — Actions

Destructive and confirmatory actions in interactive controls.

| Token | Hex | Usage |
|---|---|---|
| `actionDelete` | `#C84444` | Swipe-to-delete · remove button · destructive CTA |
| `actionConfirm` | `#5AAE78` | Confirm · apply · positive CTA |

## Typography

| Role | Family | Notes |
|---|---|---|
| Sans | `IBM Plex Sans` | UI / body |
| Mono | `IBM Plex Mono` | Monospace content |
| Display | `Playfair Display` | Headings / titles only |
