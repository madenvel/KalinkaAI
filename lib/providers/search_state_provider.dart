import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data_model/data_model.dart';
import 'kalinka_player_api_provider.dart';
import 'connection_settings_provider.dart';
import 'app_state_provider.dart';

const _searchHistoryKey = 'Kalinka.searchHistory';
const _maxHistoryItems = 10;
const _maxSessionHistory = 5;
const _maxCachedQueries = 5;
const _cacheTtlMinutes = 5;
const _maxCompletions = 3;

/// Cached search result with timestamp
class CachedSearchResult {
  final Map<SearchType, BrowseItemsList> results;
  final DateTime timestamp;

  CachedSearchResult(this.results, this.timestamp);

  bool get isExpired =>
      DateTime.now().difference(timestamp).inMinutes >= _cacheTtlMinutes;
}

/// Search surface lifecycle phase
enum SearchPhase { inactive, activated, typing, results, cleared }

/// Stub AI prompt suggestions for zero-state
const _stubAiPromptSuggestions = [
  'something melancholic for tonight',
  'new additions to the library',
  'continue where I left off',
];

/// Search state containing expansion, query, and results
class SearchState {
  final bool isExpanded;
  final SearchPhase searchPhase;
  final bool keyboardVisible;
  final String query;
  final bool isLoading;
  final Map<SearchType, BrowseItemsList>? searchResults;
  final List<BrowseItemsList>? browseRecommendations;
  final String? error;
  final String? expandedAlbumId;
  final String? artistPreviewId;
  final bool tracksExpanded;
  final String? expandedAlbumIdWithinArtist;
  final Set<String> artistMoreAlbumsExpanded;
  final Set<String> albumMoreTracksExpanded;
  final List<String> sessionHistory;
  final List<String> completions;
  final String? aiCompletionSuggestion;
  final bool completionStripVisible;
  final List<String> aiPromptSuggestions;

  const SearchState({
    this.isExpanded = false,
    this.searchPhase = SearchPhase.inactive,
    this.keyboardVisible = false,
    this.query = '',
    this.isLoading = false,
    this.searchResults,
    this.browseRecommendations,
    this.error,
    this.expandedAlbumId,
    this.artistPreviewId,
    this.tracksExpanded = false,
    this.expandedAlbumIdWithinArtist,
    this.artistMoreAlbumsExpanded = const {},
    this.albumMoreTracksExpanded = const {},
    this.sessionHistory = const [],
    this.completions = const [],
    this.aiCompletionSuggestion,
    this.completionStripVisible = false,
    this.aiPromptSuggestions = const [],
  });

  /// Backward-compatible getter — true when search surface is active
  bool get searchActive =>
      searchPhase != SearchPhase.inactive;

  /// Derived: mic visible when query is empty and search is active
  bool get micVisible => searchActive && query.isEmpty;

  /// Derived: clear (×) visible when query is non-empty
  bool get clearVisible => query.isNotEmpty;

  int get totalResultCount {
    if (searchResults == null) return 0;
    return searchResults!.values.fold(0, (sum, list) => sum + list.items.length);
  }

  SearchState copyWith({
    bool? isExpanded,
    SearchPhase? searchPhase,
    bool? keyboardVisible,
    String? query,
    bool? isLoading,
    Map<SearchType, BrowseItemsList>? searchResults,
    List<BrowseItemsList>? browseRecommendations,
    String? error,
    String? expandedAlbumId,
    String? artistPreviewId,
    bool? tracksExpanded,
    bool clearExpandedAlbum = false,
    bool clearArtistPreview = false,
    String? expandedAlbumIdWithinArtist,
    Set<String>? artistMoreAlbumsExpanded,
    Set<String>? albumMoreTracksExpanded,
    bool clearExpandedAlbumWithinArtist = false,
    List<String>? sessionHistory,
    List<String>? completions,
    String? aiCompletionSuggestion,
    bool? completionStripVisible,
    List<String>? aiPromptSuggestions,
    bool clearSearchResults = false,
    bool clearAiCompletion = false,
    bool clearError = false,
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
      error: clearError ? null : (error ?? this.error),
      expandedAlbumId:
          clearExpandedAlbum ? null : (expandedAlbumId ?? this.expandedAlbumId),
      artistPreviewId:
          clearArtistPreview ? null : (artistPreviewId ?? this.artistPreviewId),
      tracksExpanded: tracksExpanded ?? this.tracksExpanded,
      expandedAlbumIdWithinArtist: clearExpandedAlbumWithinArtist
          ? null
          : (expandedAlbumIdWithinArtist ?? this.expandedAlbumIdWithinArtist),
      artistMoreAlbumsExpanded:
          artistMoreAlbumsExpanded ?? this.artistMoreAlbumsExpanded,
      albumMoreTracksExpanded:
          albumMoreTracksExpanded ?? this.albumMoreTracksExpanded,
      sessionHistory: sessionHistory ?? this.sessionHistory,
      completions: completions ?? this.completions,
      aiCompletionSuggestion: clearAiCompletion
          ? null
          : (aiCompletionSuggestion ?? this.aiCompletionSuggestion),
      completionStripVisible:
          completionStripVisible ?? this.completionStripVisible,
      aiPromptSuggestions: aiPromptSuggestions ?? this.aiPromptSuggestions,
    );
  }
}

/// Notifier managing search state, history, and caching
class SearchStateNotifier extends Notifier<SearchState> {
  late SharedPreferences _prefs;
  final Map<String, CachedSearchResult> _cache = {};
  Timer? _debounceTimer;
  Timer? _completionHideTimer;

  @override
  SearchState build() {
    _prefs = ref.read(sharedPrefsProvider);
    _setupAutoCollapse();
    _setupCacheInvalidation();
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
        _cache.clear();
      }
    });
  }

  void toggle() {
    state = state.copyWith(isExpanded: !state.isExpanded);
    if (state.isExpanded &&
        state.query.isEmpty &&
        state.browseRecommendations == null) {
      _loadBrowseRecommendations();
    }
  }

  void expand() {
    state = state.copyWith(isExpanded: true);
    if (state.query.isEmpty && state.browseRecommendations == null) {
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
      aiPromptSuggestions: _stubAiPromptSuggestions,
    );
    if (state.browseRecommendations == null) {
      _loadBrowseRecommendations();
    }
  }

  /// Deactivate search — exit to inactive (State 7), preserve histories
  void deactivateSearch() {
    _debounceTimer?.cancel();
    _completionHideTimer?.cancel();
    // Save any session history queries into all-time history
    for (final q in state.sessionHistory) {
      _addToHistory(q);
    }
    state = state.copyWith(
      searchPhase: SearchPhase.inactive,
      query: '',
      clearSearchResults: true,
      clearError: true,
      clearExpandedAlbum: true,
      clearArtistPreview: true,
      tracksExpanded: false,
      clearExpandedAlbumWithinArtist: true,
      artistMoreAlbumsExpanded: const {},
      albumMoreTracksExpanded: const {},
      sessionHistory: const [],
      completions: const [],
      clearAiCompletion: true,
      completionStripVisible: false,
      aiPromptSuggestions: const [],
    );
  }

  /// Clear query mid-session (State 6) — user tapped ×
  /// Saves current query to session history, clears query, stays in search mode
  void clearQueryMidSession() {
    _debounceTimer?.cancel();
    _completionHideTimer?.cancel();
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
      clearError: true,
      sessionHistory: updated,
      completions: const [],
      clearAiCompletion: true,
      completionStripVisible: false,
      clearExpandedAlbum: true,
      clearArtistPreview: true,
      tracksExpanded: false,
      clearExpandedAlbumWithinArtist: true,
      artistMoreAlbumsExpanded: const {},
      albumMoreTracksExpanded: const {},
    );
  }

  void setKeyboardVisible(bool visible) {
    state = state.copyWith(keyboardVisible: visible);
  }

  void setQuery(String query) {
    _debounceTimer?.cancel();
    _completionHideTimer?.cancel();

    final trimmed = query.trim();

    if (trimmed.isEmpty) {
      // Query cleared by typing — if we had results, go to cleared state
      if (state.searchPhase == SearchPhase.typing ||
          state.searchPhase == SearchPhase.results) {
        state = state.copyWith(
          query: query,
          clearError: true,
          completionStripVisible: false,
          completions: const [],
          clearAiCompletion: true,
        );
      } else {
        state = state.copyWith(query: query, clearError: true);
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
    final cached = _cache[trimmed];
    if (cached != null && !cached.isExpired) {
      state = state.copyWith(
        searchResults: cached.results,
        isLoading: false,
        searchPhase: SearchPhase.results,
      );
      return;
    }

    // Debounce search
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      performSearch();
    });
  }

  Future<void> performSearch() async {
    _debounceTimer?.cancel();
    if (state.query.trim().isEmpty) return;

    final query = state.query.trim();

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
      'sad': 'sad and slow, something for a rainy day',
      'jazz': 'jazz standards for a late-night mood',
      'rock': 'rock classics with raw energy',
      'chill': 'chill ambient for deep focus',
      'dance': 'dance tracks to lift the energy',
      'piano': 'piano pieces, gentle and introspective',
      'night': 'late night, atmospheric and moody',
    };
    for (final entry in stubs.entries) {
      if (entry.key.startsWith(partial.toLowerCase()) ||
          partial.toLowerCase().startsWith(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  Future<void> _loadBrowseRecommendations() async {
    final currentTrack = ref.read(playerStateProvider).currentTrack;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final api = ref.read(kalinkaProxyProvider);
      final recommendations = <BrowseItemsList>[];

      if (currentTrack != null) {
        if (currentTrack.id.isNotEmpty) {
          try {
            final trackBrowse = await api.browse(currentTrack.id);
            recommendations.add(trackBrowse);
            await Future.delayed(const Duration(milliseconds: 300));
          } catch (e) {
            // Continue on error
          }
        }

        if (currentTrack.album?.id != null &&
            currentTrack.album!.id.isNotEmpty) {
          try {
            final albumBrowse = await api.browse(currentTrack.album!.id);
            recommendations.add(albumBrowse);
            await Future.delayed(const Duration(milliseconds: 300));
          } catch (e) {
            // Continue on error
          }
        }

        if (currentTrack.performer?.id != null &&
            currentTrack.performer!.id.isNotEmpty) {
          try {
            final artistBrowse = await api.browse(currentTrack.performer!.id);
            recommendations.add(artistBrowse);
          } catch (e) {
            // Continue on error
          }
        }
      } else {
        try {
          final rootBrowse = await api.browse('root');
          recommendations.add(rootBrowse);
        } catch (e) {
          // Continue on error
        }
      }

      state = state.copyWith(
        browseRecommendations: recommendations,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load recommendations: $e',
      );
    }
  }

  void expandAlbum(String albumId) {
    state = state.copyWith(
      expandedAlbumId: albumId,
      clearArtistPreview: true,
    );
  }

  void collapseAlbum() {
    state = state.copyWith(clearExpandedAlbum: true);
  }

  void previewArtist(String artistId) {
    state = state.copyWith(
      artistPreviewId: artistId,
      clearExpandedAlbum: true,
      clearExpandedAlbumWithinArtist: true,
      artistMoreAlbumsExpanded: const {},
      albumMoreTracksExpanded: const {},
    );
  }

  void collapseArtistPreview() {
    state = state.copyWith(
      clearArtistPreview: true,
      clearExpandedAlbumWithinArtist: true,
    );
  }

  void expandAlbumWithinArtist(String albumId) {
    state = state.copyWith(expandedAlbumIdWithinArtist: albumId);
  }

  void collapseAlbumWithinArtist() {
    state = state.copyWith(clearExpandedAlbumWithinArtist: true);
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

  void toggleTracksExpanded() {
    state = state.copyWith(tracksExpanded: !state.tracksExpanded);
  }

  void resetExpansions() {
    state = state.copyWith(
      clearExpandedAlbum: true,
      clearArtistPreview: true,
      tracksExpanded: false,
      clearExpandedAlbumWithinArtist: true,
      artistMoreAlbumsExpanded: const {},
      albumMoreTracksExpanded: const {},
    );
  }

  void clearSearch() {
    _debounceTimer?.cancel();
    _completionHideTimer?.cancel();
    state = state.copyWith(
      query: '',
      clearSearchResults: true,
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
    final history = getSearchHistory();
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
}

final searchStateProvider = NotifierProvider<SearchStateNotifier, SearchState>(
  SearchStateNotifier.new,
);
