# Changelog

Curated, user-facing notes per release. Add a `## <version>` section (matching
the `pubspec.yaml` semver, no build suffix) before tagging — the release
pipeline pulls the matching section into the GitHub Release body.

## 0.5.2

### Added
- Retry a track that failed to play: the play button now sends play again
  instead of turning into a dead warning icon.
- Tracks the player couldn't play stay marked in the queue for the rest of the
  session, and the now-playing header says so — the mark clears once the track
  plays.

### Changed
- Every confirmation dialog now shares one presentation: bottom-anchored, and
  on tablets it stays inside the panel it belongs to and follows window
  resizes.

### Fixed
- Server discovery on Windows: a virtual network adapter refusing to join the
  multicast group aborted the whole scan, so the app jumped straight to manual
  address entry.
- The server update banner now re-checks after connecting to a different
  server instead of describing the one connected first.
- The playback error dialog now goes away when the error does — for example
  when another client skips the failing track.

## 0.5.1

### Changed
- Find Music: the search entry now stands out on the Discover screen, and the
  suggestion overlay reads more clearly — icons on every row and less prompt
  text while you type.
- Android now ships a single universal APK instead of per-ABI builds.

### Fixed
- Crash when clearing the playback queue.
- Duplicate entries when scanning for servers on the local network.

## 0.5.0

### Added
- Find Music: hybrid browse/search replacing the tabbed flow — explore source
  catalogs through art-backed category pages with breadcrumb navigation and
  infinite scrolling, or ask the AI and return to your results at any time.
- Redesigned AI search entry with an animated overlay, curated history and
  suggestion slots.
- Server updates from the app: an update banner in Settings → Server with a
  confirm dialog and install progress overlay.
- Windows x64 desktop build with an Inno Setup installer.
- Permanent latest-download links: every release also publishes version-less
  alias assets.

### Changed
- Catalog cards redesigned as 3:1 banners with framed art and source
  attribution.
- Faster catalog browsing: banner blur pre-baked, flatter banner heights on
  wide screens, brighter loading shimmer.
- Initial setup wizard now only runs when the server requests it.
- Haptic feedback disabled on desktop and web.
- Upgraded to Flutter 3.44 and Riverpod 3.4.

### Fixed
- Now-playing highlight for singles and loose tracks in the artist expansion.
- Spurious connection banner while browsing Find Music; catalog cards refresh
  once per session.

## 0.3.0

### Added
- AI-first Discover screen replacing the old top-bar search.
- Source attribution across the app: AI sections tinted by their source badge
  colour, and a "My Files" badge on local now-playing tracks.
- AI search on by default, with curated query history in the suggestion slots
  and expanded completion stubs (moods, genres, instruments).

### Changed
- Polished search result rows, Discover cards, the mini-player and navigation.
- Settings field descriptions now render inline markdown (links, italic, bold).
- Tablet: bottom sheets anchor to their panel and the discovery overlay
  survives window resizes.

### Fixed
- Mini-player play/pause button no longer dead; reuses the shared transport button.
- Now-playing prev/next disabled at the queue ends.
- Long full-width button labels truncate with an ellipsis.
- Loading shimmer matches the AI results layout.
