import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data_model/data_model.dart';
import 'connection_settings_provider.dart';
import 'kalinka_player_api_provider.dart';

/// Persistent history of submitted search prompts (most-recent first).
const _historyKey = 'Kalinka.chatSearchHistory';
const _maxHistoryItems = 5;
const _minHistoryQueryLength = 2;

/// Minimum time the "working…" state stays up, even if results resolve
/// instantly — the request may be slow, so the UI must always read as busy
/// rather than flickering a frame of loading.
const _minLoadingDuration = Duration(milliseconds: 650);

/// How many suggestions the zero state asks the server for.
const _suggestionCount = 4;

/// Static fallback prompts for the zero state, shown until the server's
/// context-aware suggestions arrive (or when the fetch fails). Phrased the
/// way the retrieval stack handles well — concrete genre/instrument words,
/// no negation ("no vocals" retrieves vocals).
const _fallbackSuggestions = <SearchSuggestion>[
  SearchSuggestion(query: 'something melancholic for a late night'),
  SearchSuggestion(query: 'upbeat indie for a morning run'),
  SearchSuggestion(query: 'calm piano for deep focus'),
  SearchSuggestion(query: 'smooth jazz for a cozy evening'),
];

/// The two views of the Find Music workspace; Results sits one back-layer
/// above Catalogs (there are no tabs).
enum FindMusicView { catalogs, results }

/// The Catalogs view is either at its root (search invitation + catalog cards)
/// or on one selected catalog page. Navigation is exactly one level deep — a
/// page never opens another page; albums/artists/playlists unroll inline.
class CatalogPage {
  /// Stable browse id of the open catalog category; null on the root screen.
  final String? id;

  /// Category title, e.g. "Popular Albums" (shown in Playfair on the page).
  final String? title;

  /// Owning provider, e.g. "Jamendo" — shown with its source badge as the
  /// page's attribution line.
  final String? provider;

  /// Category description, e.g. "Most played this month" — the page subtitle.
  final String? description;

  /// Server-rendered card art path — reused as the page's header backdrop.
  final String? artPath;

  const CatalogPage.root()
    : id = null,
      title = null,
      provider = null,
      description = null,
      artPath = null;

  const CatalogPage.category({
    required this.id,
    required this.title,
    this.provider,
    this.description,
    this.artPath,
  });

  bool get isRoot => id == null;
}

/// State for the Find Music workspace: two views (Catalogs / Results) with
/// independently preserved content, plus the persisted zero-state data.
/// Results holds a single current query — a new search replaces it.
class SearchSessionState {
  /// Whether the full-screen Find Music surface is open.
  final bool isOpen;

  /// The visible view. Switching is pure state — no back-stack.
  final FindMusicView activeView;

  /// Results is disabled until the first search is submitted; true thereafter
  /// for the life of the workspace.
  final bool resultsAvailable;

  // ── Results view (single query) ─────────────────────────────────────────────
  final String searchQuery;

  /// AI search result — top-level items are per-source sections, never merged
  /// into a single ranked list. Null until the current query resolves.
  final BrowseItemsList? searchResults;
  final bool searchLoading;
  final String? searchError;

  /// Section ids expanded past their default visible limit in the results.
  final Set<String> expandedSections;

  // ── Catalogs view ───────────────────────────────────────────────────────────
  /// Root screen, or the one open catalog page. Its item data is fetched by the
  /// page view via `browseDetailProvider(id)` (cached across view switches).
  final CatalogPage catalogPage;

  // ── Zero-state data (persisted history + fetched favourites) ───────────────
  final List<String> history;
  final List<BrowseItem> recentFavourites;
  final bool zeroStateLoading;

  /// Context-aware suggestions fetched from `/ai_search/suggestions` —
  /// matched to the listener's time of day and validated against the
  /// library. Empty until the first successful fetch.
  final List<SearchSuggestion> aiSuggestions;

  const SearchSessionState({
    this.isOpen = false,
    this.activeView = FindMusicView.catalogs,
    this.resultsAvailable = false,
    this.searchQuery = '',
    this.searchResults,
    this.searchLoading = false,
    this.searchError,
    this.expandedSections = const {},
    this.catalogPage = const CatalogPage.root(),
    this.history = const [],
    this.recentFavourites = const [],
    this.zeroStateLoading = false,
    this.aiSuggestions = const [],
  });

  /// Prompts shown in the search overlay: the server's context-aware
  /// suggestions once fetched, static examples until then.
  List<SearchSuggestion> get suggestions =>
      aiSuggestions.isEmpty ? _fallbackSuggestions : aiSuggestions;

  SearchSessionState copyWith({
    bool? isOpen,
    FindMusicView? activeView,
    bool? resultsAvailable,
    String? searchQuery,
    BrowseItemsList? searchResults,
    bool clearResults = false,
    bool? searchLoading,
    String? searchError,
    bool clearError = false,
    Set<String>? expandedSections,
    CatalogPage? catalogPage,
    List<String>? history,
    List<BrowseItem>? recentFavourites,
    bool? zeroStateLoading,
    List<SearchSuggestion>? aiSuggestions,
  }) {
    return SearchSessionState(
      isOpen: isOpen ?? this.isOpen,
      activeView: activeView ?? this.activeView,
      resultsAvailable: resultsAvailable ?? this.resultsAvailable,
      searchQuery: searchQuery ?? this.searchQuery,
      searchResults: clearResults
          ? null
          : (searchResults ?? this.searchResults),
      searchLoading: searchLoading ?? this.searchLoading,
      searchError: clearError ? null : (searchError ?? this.searchError),
      expandedSections: expandedSections ?? this.expandedSections,
      catalogPage: catalogPage ?? this.catalogPage,
      history: history ?? this.history,
      recentFavourites: recentFavourites ?? this.recentFavourites,
      zeroStateLoading: zeroStateLoading ?? this.zeroStateLoading,
      aiSuggestions: aiSuggestions ?? this.aiSuggestions,
    );
  }
}

class SearchSessionNotifier extends Notifier<SearchSessionState> {
  late SharedPreferences _prefs;

  /// Bumped on each [submit]; a resolving query whose generation no longer
  /// matches has been superseded and drops its result.
  int _queryGen = 0;

  bool _disposed = false;

  @override
  SearchSessionState build() {
    _prefs = ref.read(sharedPrefsProvider);
    ref.onDispose(() => _disposed = true);
    return SearchSessionState(history: _loadHistory());
  }

  // ── Open / close ───────────────────────────────────────────────────────────

  /// Open Find Music on the Catalogs root and refresh its data.
  void open() {
    if (state.isOpen) return;
    state = state.copyWith(isOpen: true, history: _loadHistory());
    _loadRecentFavourites();
    _loadSuggestions();
  }

  /// Close Find Music and discard the ephemeral workspace (results + catalog
  /// page). History is written live on each [submit], so nothing to fold here.
  void close() {
    if (!state.isOpen) return;
    state = state.copyWith(
      isOpen: false,
      activeView: FindMusicView.catalogs,
      resultsAvailable: false,
      searchQuery: '',
      clearResults: true,
      searchLoading: false,
      clearError: true,
      expandedSections: const {},
      catalogPage: const CatalogPage.root(),
      history: _loadHistory(),
    );
  }

  // ── Views ────────────────────────────────────────────────────────────────

  /// Switch view (pure state, no back-stack). Results is inert until a search
  /// has run. Reselecting Catalogs while on a page returns to its root.
  void selectView(FindMusicView view) {
    if (view == FindMusicView.results && !state.resultsAvailable) return;
    if (view == FindMusicView.catalogs &&
        state.activeView == FindMusicView.catalogs &&
        !state.catalogPage.isRoot) {
      state = state.copyWith(catalogPage: const CatalogPage.root());
      return;
    }
    if (view == state.activeView) return;
    state = state.copyWith(activeView: view);
  }

  // ── Catalog navigation (deterministic — never through the AI router) ───────

  /// Open a catalog category page directly by its stable browse id. Not
  /// recorded in search history — this is navigation, not a search.
  void openCatalog({
    required String id,
    required String title,
    String? provider,
    String? description,
    String? artPath,
  }) {
    state = state.copyWith(
      activeView: FindMusicView.catalogs,
      catalogPage: CatalogPage.category(
        id: id,
        title: title,
        provider: provider,
        description: description,
        artPath: artPath,
      ),
    );
  }

  /// Return from a catalog page to the Catalogs root (the search screen).
  void backToCatalogsRoot() {
    if (state.catalogPage.isRoot) return;
    state = state.copyWith(catalogPage: const CatalogPage.root());
  }

  // ── Submitting queries (AI search) ─────────────────────────────────────────

  /// Submit [rawQuery] through the AI router. No-op for blank input. Enables +
  /// selects Results and replaces the current query. This is the only path that
  /// fires a search — there is no search-as-you-type, and catalog taps bypass it.
  void submit(String rawQuery) {
    final query = rawQuery.trim();
    if (query.isEmpty) return;

    // Dedup + move-to-front, so a repeated query jumps to the top of Recent
    // searches. Catalog navigation never reaches here, so it stays out of it.
    _appendHistory(query);
    final gen = ++_queryGen;
    state = state.copyWith(
      activeView: FindMusicView.results,
      resultsAvailable: true,
      searchQuery: query,
      clearResults: true,
      searchLoading: true,
      clearError: true,
      expandedSections: const {},
      history: _loadHistory(),
    );
    _runQuery(query, gen);
  }

  Future<void> _runQuery(String query, int gen) async {
    final settings = ref.read(connectionSettingsProvider);
    if (!settings.isSet) {
      if (gen == _queryGen && !_disposed) {
        state = state.copyWith(
          searchLoading: false,
          searchError: 'No server connected',
        );
      }
      return;
    }

    final start = DateTime.now();
    try {
      final api = ref.read(kalinkaProxyProvider);
      final result = await api.aiSearch(query);
      await _holdMinimumLoading(start);
      if (_disposed || gen != _queryGen) return;
      state = state.copyWith(
        searchLoading: false,
        searchResults: result,
        clearError: true,
      );
    } catch (e) {
      await _holdMinimumLoading(start);
      if (_disposed || gen != _queryGen) return;
      state = state.copyWith(
        searchLoading: false,
        searchError: 'Search failed: $e',
      );
    }
  }

  Future<void> _holdMinimumLoading(DateTime start) async {
    final elapsed = DateTime.now().difference(start);
    final remaining = _minLoadingDuration - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }
  }

  /// Toggle "show more" for a results section.
  void toggleSection(String sectionId) {
    final next = Set<String>.from(state.expandedSections);
    if (!next.remove(sectionId)) next.add(sectionId);
    state = state.copyWith(expandedSections: next);
  }

  // ── Zero-state data ────────────────────────────────────────────────────────

  /// Fetch context-aware suggestions for the zero state. The proxy sends the
  /// device's real UTC offset so "morning" is the listener's morning. Any
  /// failure keeps what is already shown (the static fallback or the last
  /// successful fetch).
  Future<void> _loadSuggestions() async {
    final settings = ref.read(connectionSettingsProvider);
    if (!settings.isSet) return;
    try {
      final api = ref.read(kalinkaProxyProvider);
      final result = await api.searchSuggestions(count: _suggestionCount);
      if (_disposed || result.suggestions.isEmpty) return;
      state = state.copyWith(aiSuggestions: result.suggestions);
    } catch (_) {
      // Zero state must render regardless — the fallback stays.
    }
  }

  Future<void> _loadRecentFavourites() async {
    final settings = ref.read(connectionSettingsProvider);
    if (!settings.isSet) return;
    final api = ref.read(kalinkaProxyProvider);
    state = state.copyWith(zeroStateLoading: true);
    try {
      final (tracks, albums, artists, playlists) = await (
        api.getFavorite(SearchType.track, limit: 5),
        api.getFavorite(SearchType.album, limit: 5),
        api.getFavorite(SearchType.artist, limit: 5),
        api.getFavorite(SearchType.playlist, limit: 5),
      ).wait;
      if (_disposed) return;

      final all = [
        ...tracks.items,
        ...albums.items,
        ...artists.items,
        ...playlists.items,
      ];
      // Newest first; entries without a timestamp sink to the bottom.
      all.sort((a, b) {
        if (a.timestamp == 0 && b.timestamp == 0) return 0;
        if (a.timestamp == 0) return 1;
        if (b.timestamp == 0) return -1;
        return b.timestamp.compareTo(a.timestamp);
      });

      state = state.copyWith(
        recentFavourites: all.take(6).toList(),
        zeroStateLoading: false,
      );
    } catch (_) {
      state = state.copyWith(zeroStateLoading: false);
    }
  }

  // ── Persistent history ─────────────────────────────────────────────────────

  List<String> _loadHistory() {
    final json = _prefs.getString(_historyKey);
    if (json == null) return <String>[];
    try {
      // A fresh modifiable list — callers append/remove in place. Clamp on
      // load too, so a store written under an older (larger) cap shrinks
      // immediately rather than on the next append.
      final items = List<String>.from(
        (jsonDecode(json) as List).cast<String>(),
      );
      if (items.length > _maxHistoryItems) {
        items.removeRange(_maxHistoryItems, items.length);
      }
      return items;
    } catch (_) {
      return <String>[];
    }
  }

  void _appendHistory(String rawQuery) {
    final query = rawQuery.trim();
    if (query.length < _minHistoryQueryLength) return;
    final lower = query.toLowerCase();
    final history = _loadHistory()
      ..removeWhere((h) => h.toLowerCase() == lower);
    history.insert(0, query);
    if (history.length > _maxHistoryItems) {
      history.removeRange(_maxHistoryItems, history.length);
    }
    _prefs.setString(_historyKey, jsonEncode(history));
  }

  void removeHistoryItem(String query) {
    final history = _loadHistory()..remove(query);
    _prefs.setString(_historyKey, jsonEncode(history));
    state = state.copyWith(history: history);
  }

  void clearHistory() {
    _prefs.remove(_historyKey);
    state = state.copyWith(history: const []);
  }
}

final searchSessionProvider =
    NotifierProvider<SearchSessionNotifier, SearchSessionState>(
      SearchSessionNotifier.new,
    );

/// True while the animated search overlay (the focused entry + keyboard) is up.
/// The main screen watches it to drop the mini-player out of the way so the
/// keyboard and suggestions own the bottom of the screen.
class SearchEntryModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) {
    if (state != value) state = value;
  }
}

final searchEntryModeProvider = NotifierProvider<SearchEntryModeNotifier, bool>(
  SearchEntryModeNotifier.new,
);
