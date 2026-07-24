import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/catalog_cards_provider.dart';
import '../../providers/indexer_status_provider.dart';
import '../../providers/search_session_provider.dart';
import '../../providers/selection_state_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/haptics.dart';
import '../indexer_status_banner.dart';
import '../mini_player.dart';
import '../selection_overlay.dart';
import '../server_chip.dart';
import 'catalog_page_view.dart';
import 'results_view.dart';
import 'search_composer.dart';
import 'search_zero_state.dart';

/// The search header uses the shared top-bar surface + shadow but drops the
/// hairline bottom rule: the bar and the content below it read as one surface.
const BoxDecoration _kSearchHeaderDecoration = BoxDecoration(
  color: KalinkaColors.surfaceBase,
  boxShadow: [
    BoxShadow(color: Color(0x80000000), offset: Offset(0, 4), blurRadius: 24),
  ],
);

/// Full-screen search session surface. The search bar sits in a header strip
/// at the top — back button on its left, connection dot on its right — with
/// the scrollable content (zero state, then query blocks, newest on top)
/// below it.
///
/// The bar does not take focus when the session opens; it focuses only when
/// tapped.
class SearchSessionView extends ConsumerStatefulWidget {
  /// Opens the server sheet — the connection dot's tap target.
  final VoidCallback? onServerTap;

  const SearchSessionView({super.key, this.onServerTap});

  @override
  ConsumerState<SearchSessionView> createState() => _SearchSessionViewState();
}

class _SearchSessionViewState extends ConsumerState<SearchSessionView>
    with
        IndexerPollHolder,
        SingleTickerProviderStateMixin,
        WidgetsBindingObserver {
  final _composerController = TextEditingController();
  final _composerFocus = FocusNode();

  // Whether the animated search overlay is up. Driven by _openSearch /
  // _closeSearch (not by raw focus), so dismissing the keyboard alone keeps
  // the overlay open, like Material's search view.
  bool _focused = false;

  // Live composer text, mirrored here to filter the suggestion list. This
  // never fires a query — search still runs only on submit.
  String _typed = '';

  // Drives the open/close transition: scrim dim, the card rising from the
  // resting entry and stretching, and the staggered suggestions.
  late final AnimationController _overlayCtrl;

  // The resting search entry's screen rect, measured on open so the overlay
  // card can rise out of exactly where the entry sat.
  final _entryKey = GlobalKey();
  Rect? _originRect;

  // Tracks the keyboard so its dismissal (e.g. the hardware back that hides it)
  // also closes the overlay — one back drops both.
  bool _keyboardUp = false;

  // Rotates the example hint: each mount of the search surface advances one
  // step through the suggestion list.
  static int _hintRotation = 0;
  final int _hintIndex = _hintRotation++;

  // Hit-box height for the back button and connection dot, centred in the bar
  // (whose height is the shared kKalinkaTopBarHeight).
  static const double _kBarMinHeight = 46;

  @override
  void initState() {
    super.initState();
    _overlayCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 230),
    );
    _composerController.addListener(_onTextChange);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _composerController.removeListener(_onTextChange);
    _overlayCtrl.dispose();
    _composerController.dispose();
    _composerFocus.dispose();
    // Torn down with the overlay still up (session closed externally) would
    // otherwise leave the shared flag stuck true and the mini-player hidden.
    // Clear it after this frame — a synchronous write could land mid-build of
    // whatever removed this surface.
    if (_focused) {
      final notifier = ref.read(searchEntryModeProvider.notifier);
      WidgetsBinding.instance.addPostFrameCallback((_) => notifier.set(false));
    }
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // While the overlay is up, the hardware back first dismisses the keyboard
    // (Android consumes it before our PopScope). Treat that dismissal as the
    // close gesture so a single back drops both the keyboard and the overlay.
    if (!_focused) {
      _keyboardUp = false;
      return;
    }
    final view = View.maybeOf(context);
    if (view == null) return;
    final up = view.viewInsets.bottom > 100;
    if (_keyboardUp && !up) _closeSearch();
    _keyboardUp = up;
  }

  void _onTextChange() {
    final text = _composerController.text;
    if (text != _typed && mounted) setState(() => _typed = text);
  }

  /// Lift the search overlay out of the resting entry: measure where the entry
  /// sits, fade the scrim in, and forward the transition while the field takes
  /// focus.
  void _openSearch({bool measure = true}) {
    if (_focused) return;
    // Measure the entry in THIS surface's local space (not global): on tablet
    // the search surface is only the right panel, and the overlay positions
    // itself within it, so the origin must be panel-relative. When opened from
    // the Results pencil (no entry on screen), skip it and rise from the top.
    final selfBox = context.findRenderObject() as RenderBox?;
    final entryBox = _entryKey.currentContext?.findRenderObject() as RenderBox?;
    _originRect =
        (measure &&
            selfBox != null &&
            selfBox.attached &&
            entryBox != null &&
            entryBox.hasSize)
        ? selfBox.globalToLocal(entryBox.localToGlobal(Offset.zero)) &
              entryBox.size
        : null;
    _keyboardUp = false;
    // Flips searchEntryModeProvider → the mini-player starts sliding down.
    ref.read(searchEntryModeProvider.notifier).set(true);
    setState(() => _focused = true);
    _overlayCtrl.forward(from: 0);
    // Hold the keyboard until the mini-player has cleared: raising focus is
    // what triggers the IME, so defer it by the bar's slide-down duration.
    Future.delayed(kMiniPlayerHideDuration, () {
      if (mounted && _focused) _composerFocus.requestFocus();
    });
  }

  /// Reverse the overlay away. [animate] false when a query is being submitted
  /// (the screen swaps to results, so there is nothing to animate back to).
  void _closeSearch({bool animate = true}) {
    // Re-entrant: the back arrow / scrim tap unfocuses, which fires
    // didChangeMetrics → here again. Ignore once a close is already running.
    if (!_focused || _overlayCtrl.status == AnimationStatus.reverse) return;
    _composerFocus.unfocus();
    _composerController.clear();
    if (!animate) {
      _overlayCtrl.value = 0;
      ref.read(searchEntryModeProvider.notifier).set(false);
      if (mounted) setState(() => _focused = false);
      return;
    }
    _overlayCtrl.reverse().whenComplete(() {
      if (!mounted) return;
      ref.read(searchEntryModeProvider.notifier).set(false);
      setState(() => _focused = false);
    });
  }

  void _submit(String text) {
    ref.read(searchSessionProvider.notifier).submit(text);
    // Submitting swaps to the results screen, so drop the overlay without a
    // reverse animation.
    if (_focused) _closeSearch(animate: false);
  }

  /// Submit from a zero-state tile (history / suggestion run arrow).
  void _submitFromTile(String text) {
    ref.read(searchSessionProvider.notifier).submit(text);
    if (_focused) _closeSearch(animate: false);
  }

  /// Insert a suggestion into the composer for editing (does not send).
  void _insert(String text) {
    _composerController.text = text;
    _composerController.selection = TextSelection.collapsed(
      offset: text.length,
    );
    _composerFocus.requestFocus();
  }

  /// The Results pencil: reopen the overlay pre-filled with the current query
  /// (no on-screen entry to rise from, so skip the measurement).
  void _editSearch() {
    final query = ref.read(searchSessionProvider).searchQuery;
    _composerController.text = query;
    _composerController.selection = TextSelection.collapsed(
      offset: query.length,
    );
    _openSearch(measure: false);
  }

  /// Open a catalog page directly from a card tap — deterministic browse, never
  /// the AI router, and never recorded in search history.
  void _openCatalog(CatalogCardPlan plan, String provider) {
    ref
        .read(searchSessionProvider.notifier)
        .openCatalog(id: plan.id, title: plan.title, provider: provider);
  }

  /// One back press unwinds one layer (MD §11): the open overlay closes; a
  /// catalog page returns to the Catalogs root; otherwise Find Music closes to
  /// playback. Tab switches never enter this stack. Shared by the header arrow
  /// and the system back gesture.
  void _handleBack() {
    if (_focused) {
      _closeSearch();
      return;
    }
    final session = ref.read(searchSessionProvider);
    if (session.activeTab == FindMusicTab.catalogs &&
        !session.catalogPage.isRoot) {
      ref.read(searchSessionProvider.notifier).backToCatalogsRoot();
      return;
    }
    ref.read(searchSessionProvider.notifier).close();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(searchSessionProvider);

    // The shared tiles long-press into multi-select; surface the same batch
    // bar the old search feed used so the selection can be acted on.
    final selectionActive = ref.watch(
      selectionStateProvider.select((s) => s.isActive),
    );

    // Find Music owns its back handling: the route must not pop while any
    // in-screen layer can still unwind (the parent screen's PopScope leaves it
    // alone).
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: ColoredBox(
        color: KalinkaColors.background,
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(session),
                const _IndexerBannerSlot(),
                // Both tabs stay mounted (IndexedStack) so scroll and inline
                // expansion survive tab switches without a refetch.
                Expanded(
                  child: IndexedStack(
                    index: session.activeTab == FindMusicTab.results ? 1 : 0,
                    children: [
                      _buildCatalogsTab(session),
                      session.resultsAvailable
                          ? ResultsView(onEdit: _editSearch)
                          : const SizedBox.shrink(),
                    ],
                  ),
                ),
              ],
            ),
            // The animated search overlay floats above the header too, so its
            // dim scrim covers the top bar and tabs — the in-field arrow is the
            // only back affordance while it is up.
            if (_focused) _buildSearchOverlay(session),
            if (selectionActive)
              const Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: MultiSelectBottomBar(),
              ),
          ],
        ),
      ),
    );
  }

  /// The Catalogs tab: its root (search invitation + cards) or the one open
  /// catalog page.
  Widget _buildCatalogsTab(SearchSessionState session) {
    if (!session.catalogPage.isRoot) {
      return CatalogPageView(
        page: session.catalogPage,
        onBackToCatalogs: () =>
            ref.read(searchSessionProvider.notifier).backToCatalogsRoot(),
      );
    }
    return _buildCatalogsRoot(session);
  }

  /// Top strip: back · Catalogs/Results tabs · connection dot. Solid, same
  /// framing as the main screen's top bar. Results is disabled until the first
  /// search runs; tab switches never touch the back stack.
  Widget _buildHeader(SearchSessionState session) {
    return Container(
      decoration: _kSearchHeaderDecoration,
      child: SafeArea(
        bottom: false,
        // Shared height so this bar lines up with the queue and settings bars.
        child: SizedBox(
          height: kKalinkaTopBarHeight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 3, 6, 3),
            child: Row(
              children: [
                // Back — unwinds one layer per tap, same as the system back
                // gesture (_handleBack).
                Semantics(
                  label: 'Back',
                  button: true,
                  child: GestureDetector(
                    onTap: () {
                      KalinkaHaptics.lightImpact();
                      _handleBack();
                    },
                    behavior: HitTestBehavior.opaque,
                    child: const SizedBox(
                      width: 42,
                      height: _kBarMinHeight,
                      child: Icon(
                        Icons.arrow_back,
                        size: 22,
                        color: KalinkaColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Center(
                    child: _FindMusicTabs(
                      activeTab: session.activeTab,
                      resultsEnabled: session.resultsAvailable,
                      onSelect: (tab) =>
                          ref.read(searchSessionProvider.notifier).selectTab(tab),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                SizedBox(
                  height: _kBarMinHeight,
                  width: 42,
                  child: Center(
                    child: ServerChip(compact: true, onTap: widget.onServerTap),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The Catalogs root: one scroll holding the Playfair question, its
  /// description, the resting search entry, then the "OR EXPLORE CATALOGS"
  /// divider, catalog cards and favourites. Tapping the entry lifts the overlay.
  Widget _buildCatalogsRoot(SearchSessionState session) {
    return SearchZeroState(
      onOpenCatalog: _openCatalog,
      leading: [
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 10),
          child: Text(
            'What shall we play?',
            style: KalinkaFonts.display(
              fontSize: KalinkaTypography.baseSize + 11,
              fontWeight: FontWeight.w600,
              color: KalinkaColors.textPrimary,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Text(
            'Describe a mood, activity, genre, or anything else you would '
            'like to hear.',
            style: KalinkaTextStyles.trackRowSubtitle,
          ),
        ),
        _SearchEntryButton(
          key: _entryKey,
          hint: _hintText(session),
          onTap: _openSearch,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  /// Rotating example hint — a different real suggestion each time the surface
  /// mounts, teaching the query language.
  String _hintText(SearchSessionState session) {
    final suggestions = session.suggestions;
    if (suggestions.isEmpty) return 'Ask for music…';
    return 'Try “${suggestions[_hintIndex % suggestions.length].query}”';
  }

  /// The focused search view: a dim scrim over the search surface (top bar
  /// included) and a card that rises out of the resting entry, stretches, and
  /// reveals the staggered suggestions. Back arrow / hardware back reverse it.
  ///
  /// All geometry is in this surface's own coordinate space (see the local
  /// origin measured in [_openSearch]) — on tablet the surface is only the
  /// right half, so the overlay stays inside it and unrolls exactly as on
  /// phone rather than sweeping across the whole screen.
  Widget _buildSearchOverlay(SearchSessionState session) {
    final topInset = MediaQuery.paddingOf(context).top;
    final targetTop = topInset + 6;

    return LayoutBuilder(
      builder: (context, constraints) {
        final surfaceWidth = constraints.maxWidth;
        final origin =
            _originRect ??
            Rect.fromLTWH(16, targetTop + 120, surfaceWidth - 32, 56);
        return AnimatedBuilder(
          animation: _overlayCtrl,
          builder: (context, _) {
            final t = Curves.easeOutCubic.transform(_overlayCtrl.value);
            // The card slides up from the entry and its left/right ease to the
            // surface margins (they already sit at 16, so mostly vertical).
            final top = lerpDouble(origin.top, targetTop, t)!;
            final left = lerpDouble(origin.left, 16, t)!;
            final right = lerpDouble(surfaceWidth - origin.right, 16, t)!;
            // The panel unfurls (height grows) so the card stretches as it
            // opens.
            final panelReveal = Curves.easeOutCubic.transform(
              ((_overlayCtrl.value - 0.15) / 0.85).clamp(0.0, 1.0),
            );
            // Cap the suggestion list to the room left between the card top and
            // the keyboard (the surface itself is not resized by the IME), so
            // it scrolls internally instead of running off-screen. ~96 leaves
            // the composer row + divider + card margins above it.
            final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
            final listMaxHeight =
                (constraints.maxHeight - targetTop - keyboardInset - 96).clamp(
                  80.0,
                  double.infinity,
                );

            return Stack(
              children: [
                // Dim scrim — almost opaque at rest — over the whole screen. Tap to
                // dismiss.
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _closeSearch,
                    behavior: HitTestBehavior.opaque,
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.92 * t),
                    ),
                  ),
                ),
                Positioned(
                  top: top,
                  left: left,
                  right: right,
                  child: TextFieldTapRegion(
                    child: Material(
                      type: MaterialType.transparency,
                      child: Container(
                        decoration: BoxDecoration(
                          color: KalinkaColors.surfaceInput,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: KalinkaColors.borderDefault,
                            width: 1,
                          ),
                          // Elevation so the card lifts off the fading scrim.
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0xB3000000),
                              offset: Offset(0, 12),
                              blurRadius: 40,
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SearchComposer(
                              controller: _composerController,
                              focusNode: _composerFocus,
                              onSubmit: _submit,
                              // No placeholder once activated — the resting
                              // entry already showed the example prompt.
                              hint: '',
                              onBack: _closeSearch,
                            ),
                            // The suggestion panel grows top-down; rows fade/slide
                            // in staggered inside it.
                            ClipRect(
                              child: Align(
                                alignment: Alignment.topCenter,
                                heightFactor: panelReveal,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      height: 1,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                      ),
                                      color: KalinkaColors.borderSubtle,
                                    ),
                                    ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxHeight: listMaxHeight,
                                      ),
                                      child: SearchSuggestionsList(
                                        query: _typed,
                                        onInsert: _insert,
                                        onSubmit: _submitFromTile,
                                        reveal: _overlayCtrl,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

}

/// The Catalogs / Results tab pair in the header. Results is inert (dimmed, no
/// tap) until a search has run. The active tab carries an accent underline.
class _FindMusicTabs extends StatelessWidget {
  final FindMusicTab activeTab;
  final bool resultsEnabled;
  final ValueChanged<FindMusicTab> onSelect;

  const _FindMusicTabs({
    required this.activeTab,
    required this.resultsEnabled,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Tab(
          label: 'Catalogs',
          active: activeTab == FindMusicTab.catalogs,
          enabled: true,
          onTap: () => onSelect(FindMusicTab.catalogs),
        ),
        const SizedBox(width: 4),
        _Tab(
          label: 'Results',
          active: activeTab == FindMusicTab.results,
          enabled: resultsEnabled,
          onTap: () => onSelect(FindMusicTab.results),
        ),
      ],
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.active,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = !enabled
        ? KalinkaColors.textMuted.withValues(alpha: 0.4)
        : active
        ? KalinkaColors.textPrimary
        : KalinkaColors.textSecondary;

    return Semantics(
      button: true,
      selected: active,
      enabled: enabled,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: enabled
              ? () {
                  KalinkaHaptics.lightImpact();
                  onTap();
                }
              : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: active ? KalinkaColors.accent : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Text(
              label,
              style: KalinkaFonts.sans(
                fontSize: KalinkaTypography.baseSize + 1,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The resting search entry in the Discover scroll: looks like the field
/// (sparkle + hint) but is a button — tapping it lifts the animated overlay.
/// Its screen rect is measured on open so the overlay card rises from here.
class _SearchEntryButton extends StatelessWidget {
  final String hint;
  final VoidCallback onTap;

  const _SearchEntryButton({
    super.key,
    required this.hint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Search',
      hint: 'Ask for music in plain language',
      button: true,
      child: Material(
        color: KalinkaColors.surfaceInput,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            KalinkaHaptics.lightImpact();
            onTap();
          },
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: KalinkaColors.borderDefault, width: 1),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 26,
                  child: Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: KalinkaColors.gold,
                  ),
                ),
                Expanded(
                  child: Text(
                    hint,
                    style: KalinkaTextStyles.searchPlaceholder,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Subtle pipeline progress strip under the header: stage name + crimson
/// 2px line while the library is indexing / enriching / embedding; gone when
/// the pipeline is idle. Its own consumer so the 5s poll ticks rebuild only
/// this strip, not the whole search surface.
class _IndexerBannerSlot extends ConsumerWidget {
  const _IndexerBannerSlot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(indexerStatusProvider);
    final caption = status.caption;
    if (caption == null) return const SizedBox.shrink();
    return IndexerStatusBanner(
      caption: caption,
      progressPct: status.progressPct,
    );
  }
}

