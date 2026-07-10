# Changelog

Curated, user-facing notes per release. Add a `## <version>` section (matching
the `pubspec.yaml` semver, no build suffix) before tagging — the release
pipeline pulls the matching section into the GitHub Release body.

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
