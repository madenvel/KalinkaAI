# Changelog

Curated, user-facing notes per release. Add a `## <version>` section (matching
the `pubspec.yaml` semver, no build suffix) before tagging — the release
pipeline pulls the matching section into the GitHub Release body.

Do not hard-wrap the notes: GitHub renders a newline inside a release body as
a line break, so a wrapped sentence arrives broken. One line per bullet or
paragraph, however long; blank lines separate paragraphs.

## 0.6.1

### Added
- The web player now runs the same first-run setup wizard as the app, minus the server-discovery step the browser doesn't need.

### Changed
- A server on several networks now shows up once in discovery, under its own name instead of once per network interface, and the app connects over the fastest reachable route. Older servers list exactly as before.
- Playback through the browser output now rides out brief connection drops and server address changes: the server picks its session back up when it returns, and playback left without a server stops on its own after a minute instead of running unattended.

### Fixed
- Skipping tracks quickly in the browser no longer marks the interrupted track as failed.
- The guided tour no longer starts in the web player.
- The "This browser" output no longer disappears while the setup wizard is running.
- Setup wizard steps share the same half-width column on tablets instead of each picking its own width.

## 0.6.0

### Added
- Choose where the music plays. The cast icon in the mini player and in Now Playing lists the outputs on your network — a machine wired to your DAC, another room, this device — and moves playback to the one you pick. Each output has its own settings behind a gear, applied without a restart.
- Play through the browser. Open the web player and it offers itself as an output, listed as "This browser".
- Test the sound from the output's own settings, and from the setup wizard, without restarting anything.
- Hand volume and power to an amplifier or receiver, per output, so the hardware you actually listen through takes the volume commands.
- Rescan for servers from the discovery screen instead of restarting the app when one doesn't show up.

Outputs appear once the server supports them; against an older server the app behaves exactly as it did before.

### Changed
- First-run setup is rebuilt around outputs and asks less: the questions come from the server, so each source and device asks only for what it needs. The server-name step is gone.
- The phone Now Playing header puts minimise on the left and the output on the right, and the output reads as one control — icon, state and name.
- The guided tour now runs on tablets too, and points out the output switcher.
- A search that never answers now gives up after ten seconds and says so, instead of spinning.

### Fixed
- An intermittent crash on startup and when reconnecting.
- The restart progress screen no longer stretches across a wide window.

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
