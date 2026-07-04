import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data_model/data_model.dart';
import 'kalinka_player_api_provider.dart';
import 'connection_settings_provider.dart';
import 'connection_state_provider.dart';
import 'indexer_status_provider.dart';
import 'app_state_provider.dart';
import 'selection_state_provider.dart';

const _searchHistoryKey = 'Kalinka.searchHistory';
const _maxHistoryItems = 10;
const _maxSessionHistory = 5;
const _minHistoryQueryLength = 3;
const _maxCachedQueries = 5;
const _cacheTtlMinutes = 5;
const _maxCompletions = 3;

// AI zero-state suggestion slots. Recent AI queries are curated into the
// leading slots; the rest fall back to canned suggestions. Bump
// [_aiHistorySlotCount] (and add matching [_aiLeadSuggestions]) to widen the
// row later — a "show more" affordance can then reveal the overflow.
const _aiSearchHistoryKey = 'Kalinka.aiSearchHistory';
const _maxAiHistoryItems = 10;
const _aiHistorySlotCount = 2;

/// How long AI results must sit on screen, untouched, before the query is
/// curated into the AI suggestion history.
const _aiHistoryCaptureDelay = Duration(seconds: 10);

/// A single server-defined section of the currently playing album,
/// together with its first 10 browse results.
class LibrarySection {
  final BrowseItem sectionItem;
  final BrowseItemsList browseResult;

  const LibrarySection({required this.sectionItem, required this.browseResult});
}

/// Cached search result with timestamp
class CachedSearchResult {
  final Map<SearchType, BrowseItemsList> results;
  final DateTime timestamp;

  CachedSearchResult(this.results, this.timestamp);

  bool get isExpired =>
      DateTime.now().difference(timestamp).inMinutes >= _cacheTtlMinutes;
}

class _CachedAiResult {
  final BrowseItemsList result;
  final DateTime timestamp;

  _CachedAiResult(this.result, this.timestamp);

  bool get isExpired =>
      DateTime.now().difference(timestamp).inMinutes >= _cacheTtlMinutes;
}

/// Search surface lifecycle phase
enum SearchPhase { inactive, activated, typing, results, cleared }

/// Scope filter pills (non-genre)
enum FilterPillType { favourites, myPlaylists }

/// Type-based filter for results screen
enum ResultsFilterType { all, artists, albums, tracks, playlists }

/// Canned AI suggestions filling the leading slots until enough real AI
/// history has been captured to replace them (slot i shows [i] until
/// history reaches that slot).
const _aiLeadSuggestions = [
  'something melancholic for tonight',
  'continue where I left off',
];

/// AI suggestions pinned after the history slots — always shown, never
/// displaced by history. Backend wiring is still pending for these, so they
/// don't yet return curated results.
const _aiPinnedSuggestions = ['new additions to the library'];

/// Search state containing expansion, query, and results
class SearchState {
  final bool isExpanded;
  final SearchPhase searchPhase;
  final bool keyboardVisible;
  final String query;
  final bool isLoading;
  final Map<SearchType, BrowseItemsList>? searchResults;
  final List<BrowseItemsList>? browseRecommendations;
  final List<LibrarySection>? librarySections;
  final Set<String> expandedLibrarySectionIds;
  final String? error;
  final Set<String> expandedAlbumIds;
  final Set<String> expandedArtistIds;
  final Set<String> expandedAlbumIdsWithinArtist;
  final Set<String> artistMoreAlbumsExpanded;
  final ResultsFilterType resultsFilter;
  final Set<String> albumMoreTracksExpanded;
  final List<String> sessionHistory;
  final List<String> completions;
  final String? aiCompletionSuggestion;
  final bool completionStripVisible;
  final List<String> aiPromptSuggestions;

  // ── Zero-state filter system ──────────────────────────────────────────────
  /// Active scope filter pill (null = "All")
  final FilterPillType? activeScopeFilter;

  /// Active genre filter pill ID (null = no genre filter)
  final String? activeGenreId;

  /// Recently favourited tracks shown in zero-state
  final List<BrowseItem> recentlyFavourited;

  /// Whether the "show more" in the recently favourited section is expanded
  final bool recentlyFavouritedExpanded;

  /// Genre pills available in the filter row (max 4)
  final List<Genre> genrePills;

  /// Whether the AI mode toggle in the search bar is active
  final bool isAiEnabled;

  /// Result of the most recent AI (natural-language) search. Mixed item types
  /// in a single ordered list — unlike [searchResults] which is split by type.
  final BrowseItemsList? aiSearchResults;

  /// IDs of AI result catalog sections whose full contents are shown.
  /// Sections not in this set are truncated to the default visible limit.
  final Set<String> aiExpandedSections;

  /// Favourites split by type, loaded while the Favourites scope pill is
  /// active. The query (when present) is passed as the `filter` argument to
  /// `favorite/list/{type}`. Null when the filter is inactive or not yet
  /// loaded.
  final Map<SearchType, BrowseItemsList>? scopedFavourites;

  /// User playlists loaded while the My Playlists scope pill is active.
  /// Playlist listing has no text filter, so typing does not refetch.
  final BrowseItemsList? scopedPlaylists;

  /// True while a scope-filtered list (favourites or playlists) is loading.
  final bool isScopedLoading;

  /// True while the zero-state surface data (genre pills + recently
  /// favourited) is loading. Combined with [isLoading] (Based on Now
  /// Playing) it drives the structured zero-state shimmer.
  final bool isZeroStateLoading;

  /// IDs of scoped favourite type sections the user expanded past the
  /// default visible limit.
  final Set<SearchType> scopedExpandedTypes;

  const SearchState({
    this.isExpanded = false,
    this.searchPhase = SearchPhase.inactive,
    this.keyboardVisible = false,
    this.query = '',
    this.isLoading = false,
    this.searchResults,
    this.browseRecommendations,
    this.librarySections,
    this.expandedLibrarySectionIds = const {},
    this.error,
    this.expandedAlbumIds = const {},
    this.expandedArtistIds = const {},
    this.expandedAlbumIdsWithinArtist = const {},
    this.artistMoreAlbumsExpanded = const {},
    this.resultsFilter = ResultsFilterType.all,
    this.albumMoreTracksExpanded = const {},
    this.sessionHistory = const [],
    this.completions = const [],
    this.aiCompletionSuggestion,
    this.completionStripVisible = false,
    this.aiPromptSuggestions = const [],
    this.activeScopeFilter,
    this.activeGenreId,
    this.recentlyFavourited = const [],
    this.recentlyFavouritedExpanded = false,
    this.genrePills = const [],
    this.isAiEnabled = true,
    this.aiSearchResults,
    this.aiExpandedSections = const {},
    this.scopedFavourites,
    this.scopedPlaylists,
    this.isScopedLoading = false,
    this.isZeroStateLoading = false,
    this.scopedExpandedTypes = const {},
  });

  /// Backward-compatible getter — true when search surface is active
  bool get searchActive => searchPhase != SearchPhase.inactive;

  /// Derived: mic visible when query is empty and search is active
  bool get micVisible => searchActive && query.isEmpty;

  /// Derived: clear (×) visible when query is non-empty
  bool get clearVisible => query.isNotEmpty;

  int get totalResultCount {
    if (searchResults == null) return 0;
    return searchResults!.values.fold(
      0,
      (sum, list) => sum + list.items.length,
    );
  }

  SearchState copyWith({
    bool? isExpanded,
    SearchPhase? searchPhase,
    bool? keyboardVisible,
    String? query,
    bool? isLoading,
    Map<SearchType, BrowseItemsList>? searchResults,
    List<BrowseItemsList>? browseRecommendations,
    List<LibrarySection>? librarySections,
    Set<String>? expandedLibrarySectionIds,
    String? error,
    Set<String>? expandedAlbumIds,
    Set<String>? expandedArtistIds,
    Set<String>? expandedAlbumIdsWithinArtist,
    Set<String>? artistMoreAlbumsExpanded,
    Set<String>? albumMoreTracksExpanded,
    ResultsFilterType? resultsFilter,
    List<String>? sessionHistory,
    List<String>? completions,
    String? aiCompletionSuggestion,
    bool? completionStripVisible,
    List<String>? aiPromptSuggestions,
    bool clearSearchResults = false,
    bool clearAiCompletion = false,
    bool clearError = false,
    FilterPillType? activeScopeFilter,
    bool clearActiveScopeFilter = false,
    String? activeGenreId,
    bool clearActiveGenreId = false,
    List<BrowseItem>? recentlyFavourited,
    bool? recentlyFavouritedExpanded,
    List<Genre>? genrePills,
    bool? isAiEnabled,
    BrowseItemsList? aiSearchResults,
    bool clearAiSearchResults = false,
    Set<String>? aiExpandedSections,
    Map<SearchType, BrowseItemsList>? scopedFavourites,
    bool clearScopedFavourites = false,
    BrowseItemsList? scopedPlaylists,
    bool clearScopedPlaylists = false,
    bool? isScopedLoading,
    bool? isZeroStateLoading,
    Set<SearchType>? scopedExpandedTypes,
  }) {
    return SearchState(
      isExpanded: isExpanded ?? this.isExpanded,
      searchPhase: searchPhase ?? this.searchPhase,
      keyboardVisible: keyboardVisible ?? this.keyboardVisible,
      query: query ?? this.query,
      isLoading: isLoading ?? this.isLoading,
      searchResults: clearSearchResults
          ? null
          : (searchResults ?? this.searchResults),
      browseRecommendations:
          browseRecommendations ?? this.browseRecommendations,
      librarySections: librarySections ?? this.librarySections,
      expandedLibrarySectionIds:
          expandedLibrarySectionIds ?? this.expandedLibrarySectionIds,
      error: clearError ? null : (error ?? this.error),
      expandedAlbumIds: expandedAlbumIds ?? this.expandedAlbumIds,
      expandedArtistIds: expandedArtistIds ?? this.expandedArtistIds,
      expandedAlbumIdsWithinArtist:
          expandedAlbumIdsWithinArtist ?? this.expandedAlbumIdsWithinArtist,
      artistMoreAlbumsExpanded:
          artistMoreAlbumsExpanded ?? this.artistMoreAlbumsExpanded,
      albumMoreTracksExpanded:
          albumMoreTracksExpanded ?? this.albumMoreTracksExpanded,
      resultsFilter: resultsFilter ?? this.resultsFilter,
      sessionHistory: sessionHistory ?? this.sessionHistory,
      completions: completions ?? this.completions,
      aiCompletionSuggestion: clearAiCompletion
          ? null
          : (aiCompletionSuggestion ?? this.aiCompletionSuggestion),
      completionStripVisible:
          completionStripVisible ?? this.completionStripVisible,
      aiPromptSuggestions: aiPromptSuggestions ?? this.aiPromptSuggestions,
      activeScopeFilter: clearActiveScopeFilter
          ? null
          : (activeScopeFilter ?? this.activeScopeFilter),
      activeGenreId: clearActiveGenreId
          ? null
          : (activeGenreId ?? this.activeGenreId),
      recentlyFavourited: recentlyFavourited ?? this.recentlyFavourited,
      recentlyFavouritedExpanded:
          recentlyFavouritedExpanded ?? this.recentlyFavouritedExpanded,
      genrePills: genrePills ?? this.genrePills,
      isAiEnabled: isAiEnabled ?? this.isAiEnabled,
      aiSearchResults: clearAiSearchResults
          ? null
          : (aiSearchResults ?? this.aiSearchResults),
      aiExpandedSections: aiExpandedSections ?? this.aiExpandedSections,
      scopedFavourites: clearScopedFavourites
          ? null
          : (scopedFavourites ?? this.scopedFavourites),
      scopedPlaylists: clearScopedPlaylists
          ? null
          : (scopedPlaylists ?? this.scopedPlaylists),
      isScopedLoading: isScopedLoading ?? this.isScopedLoading,
      isZeroStateLoading: isZeroStateLoading ?? this.isZeroStateLoading,
      scopedExpandedTypes: scopedExpandedTypes ?? this.scopedExpandedTypes,
    );
  }
}

/// Notifier managing search state, history, and caching
class SearchStateNotifier extends Notifier<SearchState> {
  late SharedPreferences _prefs;
  final Map<String, CachedSearchResult> _cache = {};
  final Map<String, _CachedAiResult> _aiCache = {};
  Timer? _debounceTimer;
  Timer? _completionHideTimer;
  Timer? _aiHistoryTimer;
  String? _recommendationsForTrackId;

  @override
  SearchState build() {
    _prefs = ref.read(sharedPrefsProvider);
    _setupAutoCollapse();
    _setupCacheInvalidation();
    ref.onDispose(() {
      _debounceTimer?.cancel();
      _completionHideTimer?.cancel();
      _aiHistoryTimer?.cancel();
    });
    return const SearchState();
  }

  void _setupAutoCollapse() {
    ref.listen(queueExpansionProvider, (previous, next) {
      if (next && state.isExpanded) {
        collapse();
      }
    });
  }

  void _setupCacheInvalidation() {
    ref.listen(connectionSettingsProvider, (previous, next) {
      if (previous?.host != next.host || previous?.port != next.port) {
        // Switching servers invalidates everything: the in-memory caches AND
        // the results already painted on screen, which belong to the old
        // server. A server switch doesn't dip the connection state out of
        // ``connected`` (the socket rebuilds in place), so the reconnect
        // listener below never fires — wipe the visible state and re-fetch
        // here instead, or stale items linger with no resolvable content.
        _cache.clear();
        _aiCache.clear();
        _recommendationsForTrackId = null;
        state = state.copyWith(
          clearSearchResults: true,
          clearAiSearchResults: true,
          aiExpandedSections: const {},
          clearScopedFavourites: true,
          clearScopedPlaylists: true,
          recentlyFavourited: const [],
          genrePills: const [],
          librarySections: const [],
          browseRecommendations: const [],
          clearError: true,
        );
        _refreshAfterReconnect();
      }
    });

    // Reconnect-busting: any transition into ``connected`` from a
    // non-connected state means there was a disconnect (server
    // restart, network blip, app foregrounding after a long pause).
    // The indexer may have advanced or rewound during that window —
    // earlier AI-search snapshots could reflect a partial index that
    // no longer matches reality. Drop the cache so the next query
    // reaches the server.
    ref.listen(connectionStateProvider, (previous, next) {
      if (next == ConnectionStatus.connected &&
          previous != ConnectionStatus.connected) {
        _cache.clear();
        _aiCache.clear();
        _refreshAfterReconnect();
      }
    });
  }

  /// Re-fetch whatever the search surface is currently showing after a
  /// reconnect. Clearing the caches above only helps the *next* query — the
  /// data already painted on screen is a pre-outage snapshot (or a stuck
  /// error/skeleton from a fetch that failed mid-outage) and must be pulled
  /// again so the user isn't left looking at stale results.
  void _refreshAfterReconnect() {
    switch (state.searchPhase) {
      case SearchPhase.inactive:
        return; // surface closed — nothing visible to refresh
      case SearchPhase.typing:
      case SearchPhase.results:
        // Active query on screen. performSearch routes to the scoped / AI /
        // typed loader as appropriate and now reaches the server (the cache
        // was just cleared).
        if (state.query.trim().isNotEmpty) performSearch();
      case SearchPhase.activated:
      case SearchPhase.cleared:
        // Zero-state — refresh each independently-loaded section.
        final scope = state.activeScopeFilter;
        if (scope == FilterPillType.favourites) {
          _loadScopedFavourites(state.query.trim());
        } else if (scope == FilterPillType.myPlaylists) {
          _loadScopedPlaylists();
        } else {
          // "All" / genre view shows the "Based on Now Playing" rows.
          _recommendationsForTrackId = null; // force reload despite same track
          _loadBrowseRecommendations();
        }
        // Genre pills + recently-favourited back the always-visible filter
        // row and the All/genre teaser, so refresh them in every zero-state.
        _loadZeroStateData();
        ref.read(indexerStatusProvider.notifier).refresh();
    }
  }

  void toggle() {
    state = state.copyWith(isExpanded: !state.isExpanded);
    if (state.isExpanded && state.query.isEmpty && _recommendationsAreStale()) {
      _loadBrowseRecommendations();
    }
  }

  void expand() {
    state = state.copyWith(isExpanded: true);
    if (state.query.isEmpty && _recommendationsAreStale()) {
      _loadBrowseRecommendations();
    }
  }

  void collapse() {
    state = state.copyWith(isExpanded: false);
  }

  /// Activate search — enter zero-state (State 2 or 3 depending on history)
  void activateSearch() {
    state = state.copyWith(
      searchPhase: SearchPhase.activated,
      aiPromptSuggestions: _buildAiSuggestions(),
    );
    if (_recommendationsAreStale()) {
      _loadBrowseRecommendations();
    }
    _loadZeroStateData();
    ref.read(indexerStatusProvider.notifier).refresh();
  }

  /// Deactivate search — exit to inactive (State 7), preserve histories
  void deactivateSearch() {
    _debounceTimer?.cancel();
    _completionHideTimer?.cancel();
    _aiHistoryTimer?.cancel();
    ref.read(indexerStatusProvider.notifier).stop();
    ref.read(selectionStateProvider.notifier).exitSelectionMode();
    // Save any session history queries into all-time history
    for (final q in state.sessionHistory) {
      _addToHistory(q);
    }
    state = state.copyWith(
      searchPhase: SearchPhase.inactive,
      query: '',
      clearSearchResults: true,
      clearAiSearchResults: true,
      aiExpandedSections: const {},
      clearError: true,
      expandedAlbumIds: const {},
      expandedArtistIds: const {},
      expandedAlbumIdsWithinArtist: const {},
      artistMoreAlbumsExpanded: const {},
      albumMoreTracksExpanded: const {},
      resultsFilter: ResultsFilterType.all,
      sessionHistory: const [],
      completions: const [],
      clearAiCompletion: true,
      completionStripVisible: false,
      aiPromptSuggestions: const [],
      clearActiveScopeFilter: true,
      clearActiveGenreId: true,
      recentlyFavouritedExpanded: false,
      clearScopedFavourites: true,
      clearScopedPlaylists: true,
      isScopedLoading: false,
      scopedExpandedTypes: const {},
    );
  }

  // ── Filter pill methods ───────────────────────────────────────────────────

  void toggleAiMode() {
    final newAi = !state.isAiEnabled;
    // Mode changed — the on-screen query no longer belongs to the AI history.
    _aiHistoryTimer?.cancel();
    // Drop the other mode's results so the feed switches cleanly between
    // typed-split and AI-merged rendering.
    state = state.copyWith(
      isAiEnabled: newAi,
      clearSearchResults: newAi,
      clearAiSearchResults: !newAi,
    );
    // Refresh indexer coverage whenever the user opts into AI mode so the
    // banner under the search bar reflects current progress, not a snapshot
    // taken when the search surface was first opened.
    if (newAi) {
      ref.read(indexerStatusProvider.notifier).refresh();
    }
    final hasQuery = state.query.trim().isNotEmpty;
    if (hasQuery &&
        (state.searchPhase == SearchPhase.results ||
            state.searchPhase == SearchPhase.typing)) {
      performSearch();
    }
  }

  /// Toggle a scope filter pill (Favourites, My Playlists).
  /// Tapping the active filter deactivates it (returns to "All").
  ///
  /// Activating a scope pill snaps the surface back to the zero-state/scope
  /// view (dropping any in-flight global search results) and kicks off the
  /// scoped load. Deactivating re-runs the global search if a query is
  /// still in the box.
  void toggleScopeFilter(FilterPillType type) {
    _debounceTimer?.cancel();
    if (state.activeScopeFilter == type) {
      state = state.copyWith(
        clearActiveScopeFilter: true,
        clearScopedFavourites: true,
        clearScopedPlaylists: true,
        isScopedLoading: false,
        scopedExpandedTypes: const {},
      );
      if (state.query.trim().isNotEmpty) {
        performSearch();
      }
    } else {
      state = state.copyWith(
        activeScopeFilter: type,
        clearActiveGenreId: true,
        clearScopedFavourites: true,
        clearScopedPlaylists: true,
        clearSearchResults: true,
        clearAiSearchResults: true,
        aiExpandedSections: const {},
        scopedExpandedTypes: const {},
        searchPhase: SearchPhase.activated,
        completionStripVisible: false,
        completions: const [],
        clearAiCompletion: true,
      );
      if (type == FilterPillType.favourites) {
        _loadScopedFavourites(state.query.trim());
      } else if (type == FilterPillType.myPlaylists) {
        _loadScopedPlaylists();
      }
    }
  }

  /// Fetch favourites for all four types, optionally filtered by [filter].
  /// The `favorite/list/{type}` endpoint accepts a `filter` query arg for
  /// simple text matching; callers pass the current search text so typing
  /// narrows the scoped favourites view instead of triggering a global
  /// search.
  Future<void> _loadScopedFavourites(String filter) async {
    final settings = ref.read(connectionSettingsProvider);
    if (!settings.isSet) return;
    final api = ref.read(kalinkaProxyProvider);
    state = state.copyWith(isScopedLoading: true, clearError: true);
    try {
      final (artists, albums, tracks, playlists) = await (
        api.getFavorite(SearchType.artist, filter: filter, limit: 30),
        api.getFavorite(SearchType.album, filter: filter, limit: 30),
        api.getFavorite(SearchType.track, filter: filter, limit: 30),
        api.getFavorite(SearchType.playlist, filter: filter, limit: 30),
      ).wait;
      // Drop the result if the user has since changed scope or typed more.
      if (state.activeScopeFilter != FilterPillType.favourites) return;
      if (state.query.trim() != filter) return;
      state = state.copyWith(
        scopedFavourites: {
          SearchType.artist: artists,
          SearchType.album: albums,
          SearchType.track: tracks,
          SearchType.playlist: playlists,
        },
        isScopedLoading: false,
      );
    } catch (e) {
      if (state.activeScopeFilter != FilterPillType.favourites) return;
      state = state.copyWith(
        isScopedLoading: false,
        error: 'Failed to load favourites: $e',
      );
    }
  }

  /// Fetch the user's playlists. Playlist listing has no text filter, so
  /// this is called once when the My Playlists pill is activated.
  Future<void> _loadScopedPlaylists() async {
    final settings = ref.read(connectionSettingsProvider);
    if (!settings.isSet) return;
    final api = ref.read(kalinkaProxyProvider);
    state = state.copyWith(isScopedLoading: true, clearError: true);
    try {
      final result = await api.playlistUserList(0, 50);
      if (state.activeScopeFilter != FilterPillType.myPlaylists) return;
      state = state.copyWith(
        scopedPlaylists: result,
        isScopedLoading: false,
      );
    } catch (e) {
      if (state.activeScopeFilter != FilterPillType.myPlaylists) return;
      state = state.copyWith(
        isScopedLoading: false,
        error: 'Failed to load playlists: $e',
      );
    }
  }

  void toggleScopedTypeExpanded(SearchType type) {
    final updated = Set<SearchType>.from(state.scopedExpandedTypes);
    if (updated.contains(type)) {
      updated.remove(type);
    } else {
      updated.add(type);
    }
    state = state.copyWith(scopedExpandedTypes: updated);
  }

  /// Toggle a genre filter pill.
  /// Tapping the active genre deactivates it.
  void toggleGenreFilter(String genreId) {
    if (state.activeGenreId == genreId) {
      state = state.copyWith(clearActiveGenreId: true);
    } else {
      // Genre + Favourites can co-exist; genre clears other scope filters
      state = state.copyWith(
        activeGenreId: genreId,
        clearActiveScopeFilter:
            state.activeScopeFilter == FilterPillType.favourites ? false : true,
        activeScopeFilter: state.activeScopeFilter == FilterPillType.favourites
            ? FilterPillType.favourites
            : null,
      );
    }
  }

  void toggleRecentlyFavouritedExpanded() {
    state = state.copyWith(
      recentlyFavouritedExpanded: !state.recentlyFavouritedExpanded,
    );
  }

  /// Load data needed for the zero-state: genre pills and recently favourited.
  Future<void> _loadZeroStateData() async {
    final settings = ref.read(connectionSettingsProvider);
    if (!settings.isSet) return;
    final api = ref.read(kalinkaProxyProvider);
    state = state.copyWith(isZeroStateLoading: true);
    try {
      final (genres, tracks, albums, artists, playlists) = await (
        api.getGenres(null),
        api.getFavorite(SearchType.track, limit: 5),
        api.getFavorite(SearchType.album, limit: 5),
        api.getFavorite(SearchType.artist, limit: 5),
        api.getFavorite(SearchType.playlist, limit: 5),
      ).wait;

      // Merge all items from each type
      final all = [
        ...tracks.items,
        ...albums.items,
        ...artists.items,
        ...playlists.items,
      ];

      // Filter out items older than 30 days (when timestamp is available)
      final cutoffSeconds =
          DateTime.now().millisecondsSinceEpoch ~/ 1000 - 30 * 24 * 3600;
      final filtered = all.where((item) {
        if (item.timestamp == 0) return true;
        return item.timestamp >= cutoffSeconds;
      }).toList();

      // Sort by timestamp descending; items with timestamp == 0 go last
      filtered.sort((a, b) {
        if (a.timestamp == 0 && b.timestamp == 0) return 0;
        if (a.timestamp == 0) return 1;
        if (b.timestamp == 0) return -1;
        return b.timestamp.compareTo(a.timestamp);
      });

      state = state.copyWith(
        genrePills: genres.items.take(4).toList(),
        recentlyFavourited: filtered,
        isZeroStateLoading: false,
      );
    } catch (_) {
      // Non-critical — zero state still works without this data
      state = state.copyWith(isZeroStateLoading: false);
    }
  }

  /// Clear query mid-session (State 6) — user tapped ×
  /// Saves current query to session history, clears query, stays in search mode
  void clearQueryMidSession() {
    _debounceTimer?.cancel();
    _completionHideTimer?.cancel();
    _aiHistoryTimer?.cancel();
    final currentQuery = state.query.trim();
    final updated = List<String>.from(state.sessionHistory);
    if (currentQuery.isNotEmpty) {
      updated.remove(currentQuery);
      updated.insert(0, currentQuery);
      if (updated.length > _maxSessionHistory) {
        updated.removeRange(_maxSessionHistory, updated.length);
      }
    }
    state = state.copyWith(
      searchPhase: SearchPhase.activated,
      query: '',
      clearSearchResults: true,
      clearAiSearchResults: true,
      aiExpandedSections: const {},
      clearError: true,
      sessionHistory: updated,
      completions: const [],
      clearAiCompletion: true,
      completionStripVisible: false,
      expandedAlbumIds: const {},
      expandedArtistIds: const {},
      expandedAlbumIdsWithinArtist: const {},
      artistMoreAlbumsExpanded: const {},
      albumMoreTracksExpanded: const {},
      resultsFilter: ResultsFilterType.all,
      // Re-surface any AI queries curated earlier this session.
      aiPromptSuggestions: _buildAiSuggestions(),
    );
    // If scope-filtered, reload the scoped view without a filter so it
    // shows the full set again after the ×.
    if (state.activeScopeFilter == FilterPillType.favourites) {
      _loadScopedFavourites('');
    }
  }

  void setKeyboardVisible(bool visible) {
    state = state.copyWith(keyboardVisible: visible);
  }

  void setQuery(String query) {
    _debounceTimer?.cancel();
    _completionHideTimer?.cancel();
    // Any new keystroke means the user is starting another search — the
    // previous AI result no longer qualifies as "settled".
    _aiHistoryTimer?.cancel();

    final trimmed = query.trim();

    // Scoped typing: favourites filters via the API `filter` arg; my
    // playlists ignore the query entirely. In both cases we stay in the
    // zero-state/scoped view and never transition to the global results
    // phase.
    final scope = state.activeScopeFilter;
    if (scope != null) {
      state = state.copyWith(
        query: query,
        clearError: true,
        completionStripVisible: false,
        completions: const [],
        clearAiCompletion: true,
      );
      if (scope == FilterPillType.favourites) {
        _debounceTimer = Timer(const Duration(milliseconds: 300), () {
          _loadScopedFavourites(trimmed);
        });
      }
      return;
    }

    if (trimmed.isEmpty) {
      // Query cleared by typing — drop to zero-state so the recent chips
      // and discover sections come back, instead of leaving stale results
      // (or a typing skeleton) sitting under an empty bar.
      if (state.searchPhase == SearchPhase.typing ||
          state.searchPhase == SearchPhase.results) {
        state = state.copyWith(
          searchPhase: SearchPhase.activated,
          query: query,
          clearSearchResults: true,
          clearAiSearchResults: true,
          aiExpandedSections: const {},
          clearError: true,
          completionStripVisible: false,
          completions: const [],
          clearAiCompletion: true,
          expandedAlbumIds: const {},
          expandedArtistIds: const {},
          expandedAlbumIdsWithinArtist: const {},
          artistMoreAlbumsExpanded: const {},
          albumMoreTracksExpanded: const {},
          resultsFilter: ResultsFilterType.all,
        );
      } else {
        state = state.copyWith(
          query: query,
          clearError: true,
        );
      }
      return;
    }

    // Generate completions from cached data
    final completions = _generateCompletions(trimmed);

    state = state.copyWith(
      searchPhase: SearchPhase.typing,
      query: query,
      clearError: true,
      completionStripVisible: true,
      completions: completions,
      aiCompletionSuggestion: _generateAiCompletion(trimmed),
    );

    // Hide completion strip after 600ms of inactivity
    _completionHideTimer = Timer(const Duration(milliseconds: 600), () {
      if (state.searchPhase == SearchPhase.typing ||
          state.searchPhase == SearchPhase.results) {
        state = state.copyWith(completionStripVisible: false);
      }
    });

    // Check cache for immediate results
    if (state.isAiEnabled) {
      final cached = _aiCache[trimmed];
      if (cached != null && !cached.isExpired) {
        // Stale-while-revalidate: paint cached results immediately,
        // then let the debounce schedule a background re-fetch.
        // ``_performAiSearch`` notices the cached result is already
        // on screen and suppresses the loading flash.
        state = state.copyWith(
          aiSearchResults: cached.result,
          clearSearchResults: true,
          isLoading: false,
          searchPhase: SearchPhase.results,
        );
      }
    } else {
      final cached = _cache[trimmed];
      if (cached != null && !cached.isExpired) {
        state = state.copyWith(
          searchResults: cached.results,
          isLoading: false,
          searchPhase: SearchPhase.results,
        );
        return;
      }
    }

    // Debounce search
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      performSearch();
    });
  }

  Future<void> performSearch() async {
    _debounceTimer?.cancel();

    // Scope filter takes precedence — route to the scoped loader. The
    // empty-query guard is skipped because favourites supports listing
    // without a filter.
    final scope = state.activeScopeFilter;
    if (scope == FilterPillType.favourites) {
      await _loadScopedFavourites(state.query.trim());
      return;
    }
    if (scope == FilterPillType.myPlaylists) {
      // Playlists are listed once on activation; typing is a no-op.
      return;
    }

    if (state.query.trim().isEmpty) return;

    final query = state.query.trim();

    if (state.isAiEnabled) {
      await _performAiSearch(query);
      return;
    }

    // Check cache first
    final cached = _cache[query];
    if (cached != null && !cached.isExpired) {
      state = state.copyWith(
        searchResults: cached.results,
        isLoading: false,
        searchPhase: SearchPhase.results,
        completionStripVisible: false,
      );
      _addToHistory(query);
      return;
    }

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSearchResults: true,
    );

    try {
      final api = ref.read(kalinkaProxyProvider);

      final results = await Future.wait([
        api.search(SearchType.track, query),
        api.search(SearchType.album, query),
        api.search(SearchType.artist, query),
        api.search(SearchType.playlist, query),
      ]);

      final resultMap = {
        SearchType.track: results[0],
        SearchType.album: results[1],
        SearchType.artist: results[2],
        SearchType.playlist: results[3],
      };

      // Cache the results
      _cache[query] = CachedSearchResult(resultMap, DateTime.now());
      if (_cache.length > _maxCachedQueries) {
        final oldestKey = _cache.keys.first;
        _cache.remove(oldestKey);
      }

      state = state.copyWith(
        searchResults: resultMap,
        isLoading: false,
        searchPhase: SearchPhase.results,
        completionStripVisible: false,
      );

      _addToHistory(query);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Search failed: $e');
    }
  }

  Future<void> _performAiSearch(String query) async {
    final cached = _aiCache[query];
    final hasCached = cached != null && !cached.isExpired;

    if (hasCached) {
      // Cached snapshot already drawn by ``setQuery`` (or just below
      // if we got here via ``reExecuteQuery``). Re-assert it without
      // a loading flash, then fall through to revalidate against the
      // server. The fresh result will quietly replace the cached one
      // if the underlying data has changed (post-restart, indexer
      // progress, etc.).
      state = state.copyWith(
        aiSearchResults: cached.result,
        clearSearchResults: true,
        isLoading: false,
        searchPhase: SearchPhase.results,
        completionStripVisible: false,
      );
      _scheduleAiHistoryCapture(query);
    } else {
      state = state.copyWith(
        isLoading: true,
        clearError: true,
        clearSearchResults: true,
        clearAiSearchResults: true,
        aiExpandedSections: const {},
      );
    }

    try {
      final api = ref.read(kalinkaProxyProvider);
      final result = await api.aiSearch(query);

      _aiCache[query] = _CachedAiResult(result, DateTime.now());
      if (_aiCache.length > _maxCachedQueries) {
        _aiCache.remove(_aiCache.keys.first);
      }

      // Drop the response if the user navigated away or toggled off
      // AI mode while the revalidate was in flight. The cache update
      // above is still useful next time around.
      if (state.query.trim() != query || !state.isAiEnabled) return;

      state = state.copyWith(
        aiSearchResults: result,
        isLoading: false,
        searchPhase: SearchPhase.results,
        completionStripVisible: false,
      );

      _scheduleAiHistoryCapture(query);
    } catch (e) {
      // Background revalidate failed but the user already has the
      // cached snapshot on screen — leave it. Only surface an error
      // when there was nothing to fall back to.
      if (hasCached) return;
      state = state.copyWith(isLoading: false, error: 'AI search failed: $e');
    }
  }

  /// Re-execute a query from history — go direct to results
  void reExecuteQuery(String query) {
    setQuery(query);
    performSearch();
  }

  /// Generate completions from cached search data
  List<String> _generateCompletions(String partial) {
    final lower = partial.toLowerCase();
    final matches = <String>{};

    // Search through cached results for artist and album names
    for (final cached in _cache.values) {
      if (cached.isExpired) continue;

      // Artist names
      final artists = cached.results[SearchType.artist]?.items ?? [];
      for (final item in artists) {
        final name = item.name ?? item.artist?.name;
        if (name != null && name.toLowerCase().startsWith(lower)) {
          matches.add(name);
        }
      }

      // Album titles
      final albums = cached.results[SearchType.album]?.items ?? [];
      for (final item in albums) {
        final title = item.name ?? item.album?.title;
        if (title != null && title.toLowerCase().startsWith(lower)) {
          matches.add(title);
        }
      }
    }

    // Also check browse recommendations
    if (state.browseRecommendations != null) {
      for (final browseList in state.browseRecommendations!) {
        for (final item in browseList.items) {
          final name = item.name;
          if (name != null && name.toLowerCase().startsWith(lower)) {
            matches.add(name);
          }
        }
      }
    }

    return matches.take(_maxCompletions).toList();
  }

  /// Generate a stub AI completion
  String? _generateAiCompletion(String partial) {
    // Stub: generate a natural-language completion based on partial query
    final stubs = {
      // Moods
      'sad': 'sad and slow, something for a rainy day',
      'happy': 'happy and upbeat to brighten the morning',
      'chill': 'chill ambient for deep focus',
      'calm': 'calm and soothing to wind down',
      'angry': 'angry and aggressive to blow off steam',
      'romantic': 'romantic and warm for a quiet evening',
      'nostalgic': 'nostalgic throwbacks that feel like home',
      'dreamy': 'dreamy and ethereal, drifting away',
      'energetic': 'energetic and driving to keep moving',
      'melancholy': 'melancholy and tender, bittersweet',
      'uplifting': 'uplifting anthems to lift the mood',
      'moody': 'moody and atmospheric, low and slow',
      'night': 'late night, atmospheric and moody',
      'morning': 'easy morning songs to start the day',
      // Genres
      'jazz': 'jazz standards for a late-night mood',
      'rock': 'rock classics with raw energy',
      'metal': 'heavy metal with relentless riffs',
      'punk': 'fast and loud punk with attitude',
      'indie': 'indie favourites, lo-fi and heartfelt',
      'pop': 'catchy pop hooks for any time of day',
      'hip hop': 'hip hop with sharp flows and deep grooves',
      'rap': 'rap with sharp flows and heavy bass',
      'electronic': 'electronic textures for late-night focus',
      'techno': 'driving techno for the dance floor',
      'house': 'deep house grooves to keep moving',
      'dance': 'dance tracks to lift the energy',
      'ambient': 'ambient soundscapes for deep focus',
      'classical': 'classical pieces, sweeping and timeless',
      'folk': 'folk songs, acoustic and storytelling',
      'country': 'country tunes with heart and twang',
      'blues': 'soulful blues, slow and aching',
      'soul': 'soul and groove, warm and rich',
      'funk': 'funk grooves with a tight rhythm section',
      'reggae': 'laid-back reggae with a sunny groove',
      'rnb': 'smooth R&B for a slow evening',
      'r&b': 'smooth R&B for a slow evening',
      'lofi': 'lo-fi beats to relax and study to',
      'disco': 'disco grooves to light up the floor',
      // Instruments
      'piano': 'piano pieces, gentle and introspective',
      'guitar': 'guitar-driven songs, raw and expressive',
      'acoustic': 'acoustic and unplugged, stripped back',
      'violin': 'violin melodies, soaring and emotive',
      'saxophone': 'smoky saxophone for a late-night mood',
      'drums': 'drum-heavy tracks with a powerful pulse',
      'synth': 'synth-soaked textures, retro and bright',
      'strings': 'lush strings, cinematic and sweeping',
      'bass': 'bass-forward grooves you can feel',
      'cello': 'cello pieces, deep and contemplative',
      'flute': 'flute melodies, light and airy',
      'organ': 'organ tones, rich and resonant',
    };
    for (final entry in stubs.entries) {
      if (entry.key.startsWith(partial.toLowerCase()) ||
          partial.toLowerCase().startsWith(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  String? _currentRecommendationsTargetId() {
    final playback = ref.read(playerStateProvider);
    // `currentTrack` is sticky: it survives stop/queue-clear, so gate on the
    // actual playback state and a non-empty queue.
    final isActive =
        playback.state == PlayerStateType.playing ||
        playback.state == PlayerStateType.paused ||
        playback.state == PlayerStateType.buffering;
    final hasQueue = ref.read(playQueueProvider).isNotEmpty;
    if (!isActive || !hasQueue) return null;

    final currentTrack = playback.currentTrack;
    return (currentTrack?.album?.id.isNotEmpty == true)
        ? currentTrack!.album!.id
        : (currentTrack?.id.isNotEmpty == true ? currentTrack!.id : null);
  }

  bool _recommendationsAreStale() {
    final targetId = _currentRecommendationsTargetId();
    return state.browseRecommendations == null ||
        _recommendationsForTrackId != targetId;
  }

  Future<void> _loadBrowseRecommendations() async {
    final settings = ref.read(connectionSettingsProvider);
    if (!settings.isSet) return;

    state = state.copyWith(isLoading: true, clearError: true);

    // Null when nothing is actively playing (stopped / empty queue).
    final targetId = _currentRecommendationsTargetId();
    _recommendationsForTrackId = targetId;

    try {
      final api = ref.read(kalinkaProxyProvider);

      if (targetId == null) {
        state = state.copyWith(librarySections: const [], isLoading: false);
        return;
      }

      // Fetch metadata to get server-defined sections
      final metadata = await api.getMetadata(targetId);
      final sections = metadata.sections;

      if (sections == null || sections.isEmpty) {
        state = state.copyWith(librarySections: const [], isLoading: false);
        return;
      }

      // Fetch first 10 items for each browsable section in parallel
      final browsableSections = sections.where((s) => s.canBrowse).toList();
      final browseResults = await Future.wait(
        browsableSections.map((s) => api.browse(s.id, limit: 10)),
        eagerError: false,
      );

      final librarySections = <LibrarySection>[];
      for (int i = 0; i < browsableSections.length; i++) {
        librarySections.add(
          LibrarySection(
            sectionItem: browsableSections[i],
            browseResult: browseResults[i],
          ),
        );
      }

      state = state.copyWith(
        librarySections: librarySections,
        browseRecommendations: librarySections
            .map((s) => s.browseResult)
            .toList(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load recommendations: $e',
      );
    }
  }

  void toggleAlbumExpanded(String albumId) {
    final updated = Set<String>.from(state.expandedAlbumIds);
    if (updated.contains(albumId)) {
      updated.remove(albumId);
    } else {
      updated.add(albumId);
    }
    state = state.copyWith(expandedAlbumIds: updated);
  }

  void toggleArtistExpanded(String artistId) {
    final updated = Set<String>.from(state.expandedArtistIds);
    if (updated.contains(artistId)) {
      updated.remove(artistId);
    } else {
      updated.add(artistId);
    }
    state = state.copyWith(expandedArtistIds: updated);
  }

  void toggleAlbumWithinArtistExpanded(String albumId) {
    final updated = Set<String>.from(state.expandedAlbumIdsWithinArtist);
    if (updated.contains(albumId)) {
      updated.remove(albumId);
    } else {
      updated.add(albumId);
    }
    state = state.copyWith(expandedAlbumIdsWithinArtist: updated);
  }

  void setResultsFilter(ResultsFilterType type) {
    state = state.copyWith(
      resultsFilter: type,
      expandedAlbumIds: const {},
      expandedArtistIds: const {},
      expandedAlbumIdsWithinArtist: const {},
      artistMoreAlbumsExpanded: const {},
      albumMoreTracksExpanded: const {},
    );
  }

  void revealAiSection(String sectionId) {
    final updated = Set<String>.from(state.aiExpandedSections);
    // Toggle: "Show N more" expands, "Show fewer" collapses.
    if (!updated.remove(sectionId)) updated.add(sectionId);
    state = state.copyWith(aiExpandedSections: updated);
  }

  void revealArtistMoreAlbums(String artistId) {
    final updated = Set<String>.from(state.artistMoreAlbumsExpanded);
    updated.add(artistId);
    state = state.copyWith(artistMoreAlbumsExpanded: updated);
  }

  void revealAlbumMoreTracks(String albumId) {
    final updated = Set<String>.from(state.albumMoreTracksExpanded);
    updated.add(albumId);
    state = state.copyWith(albumMoreTracksExpanded: updated);
  }

  void toggleLibrarySectionExpanded(String sectionId) {
    final updated = Set<String>.from(state.expandedLibrarySectionIds);
    if (updated.contains(sectionId)) {
      updated.remove(sectionId);
    } else {
      updated.add(sectionId);
    }
    state = state.copyWith(expandedLibrarySectionIds: updated);
  }

  void resetExpansions() {
    state = state.copyWith(
      expandedAlbumIds: const {},
      expandedArtistIds: const {},
      expandedAlbumIdsWithinArtist: const {},
      artistMoreAlbumsExpanded: const {},
      albumMoreTracksExpanded: const {},
      resultsFilter: ResultsFilterType.all,
    );
  }

  void clearSearch() {
    _debounceTimer?.cancel();
    _completionHideTimer?.cancel();
    state = state.copyWith(
      query: '',
      clearSearchResults: true,
      clearAiSearchResults: true,
      aiExpandedSections: const {},
      clearError: true,
      completions: const [],
      clearAiCompletion: true,
      completionStripVisible: false,
    );
    _loadBrowseRecommendations();
  }

  List<String> getSearchHistory() {
    final json = _prefs.getString(_searchHistoryKey);
    if (json == null) return [];
    try {
      final list = jsonDecode(json) as List;
      return list.cast<String>();
    } catch (e) {
      return [];
    }
  }

  void _addToHistory(String query) {
    // Recent chips are the short-term memory for direct (non-AI) searches.
    // AI queries are curated separately via [_scheduleAiHistoryCapture].
    if (state.isAiEnabled) return;
    if (query.length < _minHistoryQueryLength) return;
    final lower = query.toLowerCase();
    final history = getSearchHistory();
    // Remove any existing entries that are a prefix of the new query —
    // these are typing artifacts (e.g. "ja" when saving "jarre").
    history.removeWhere((h) => h != query && lower.startsWith(h.toLowerCase()));
    history.remove(query);
    history.insert(0, query);
    if (history.length > _maxHistoryItems) {
      history.removeRange(_maxHistoryItems, history.length);
    }
    _prefs.setString(_searchHistoryKey, jsonEncode(history));
  }

  /// Remove a single history item
  void removeHistoryItem(String query) {
    final history = getSearchHistory();
    history.remove(query);
    _prefs.setString(_searchHistoryKey, jsonEncode(history));
  }

  void clearHistory() {
    _prefs.remove(_searchHistoryKey);
  }

  // ── AI suggestion history ─────────────────────────────────────────────────

  /// Curated AI queries, most-recent-first. Backs the leading AI suggestion
  /// slots; see [_buildAiSuggestions].
  List<String> getAiSearchHistory() {
    final json = _prefs.getString(_aiSearchHistoryKey);
    if (json == null) return [];
    try {
      return (jsonDecode(json) as List).cast<String>();
    } catch (_) {
      return [];
    }
  }

  /// AI zero-state suggestions: the leading [_aiHistorySlotCount] slots take
  /// captured AI history (newest first), falling back to [_aiLeadSuggestions]
  /// until history fills them, then the always-on [_aiPinnedSuggestions].
  List<String> _buildAiSuggestions() {
    final history = getAiSearchHistory();
    final slots = <String>[];
    for (var i = 0; i < _aiHistorySlotCount; i++) {
      if (i < history.length) {
        slots.add(history[i]);
      } else if (i < _aiLeadSuggestions.length) {
        slots.add(_aiLeadSuggestions[i]);
      }
    }
    return [...slots, ..._aiPinnedSuggestions];
  }

  /// Once AI results have sat untouched for [_aiHistoryCaptureDelay], fold the
  /// query into the AI suggestion history. Cancelled by any new search, a mode
  /// toggle, or leaving the surface.
  void _scheduleAiHistoryCapture(String query) {
    _aiHistoryTimer?.cancel();
    _aiHistoryTimer = Timer(_aiHistoryCaptureDelay, () {
      if (state.isAiEnabled &&
          state.searchPhase == SearchPhase.results &&
          state.query.trim() == query) {
        _captureAiHistory(query);
      }
    });
  }

  void _captureAiHistory(String query) {
    if (query.length < _minHistoryQueryLength) return;
    final lower = query.toLowerCase();
    final history = getAiSearchHistory()
      ..removeWhere((h) => h.toLowerCase() == lower);
    history.insert(0, query);
    if (history.length > _maxAiHistoryItems) {
      history.removeRange(_maxAiHistoryItems, history.length);
    }
    _prefs.setString(_aiSearchHistoryKey, jsonEncode(history));
  }
}

final searchStateProvider = NotifierProvider<SearchStateNotifier, SearchState>(
  SearchStateNotifier.new,
);
