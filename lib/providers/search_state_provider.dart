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
const _maxCachedQueries = 5;
const _cacheTtlMinutes = 5;

/// Cached search result with timestamp
class CachedSearchResult {
  final Map<SearchType, BrowseItemsList> results;
  final DateTime timestamp;

  CachedSearchResult(this.results, this.timestamp);

  bool get isExpired =>
      DateTime.now().difference(timestamp).inMinutes >= _cacheTtlMinutes;
}

/// Interaction mode for the + button
enum InteractionMode { contextMenu, instantAppend }

/// Search state containing expansion, query, and results
class SearchState {
  final bool isExpanded;
  final bool searchActive;
  final bool keyboardVisible;
  final String query;
  final bool isLoading;
  final Map<SearchType, BrowseItemsList>? searchResults;
  final List<BrowseItemsList>? browseRecommendations;
  final String? error;
  final String? expandedAlbumId;
  final String? artistPreviewId;
  final bool tracksExpanded;
  final InteractionMode interactionMode;
  final String? expandedAlbumIdWithinArtist;
  final Set<String> artistMoreAlbumsExpanded;
  final Set<String> albumMoreTracksExpanded;

  const SearchState({
    this.isExpanded = false,
    this.searchActive = false,
    this.keyboardVisible = false,
    this.query = '',
    this.isLoading = false,
    this.searchResults,
    this.browseRecommendations,
    this.error,
    this.expandedAlbumId,
    this.artistPreviewId,
    this.tracksExpanded = false,
    this.interactionMode = InteractionMode.instantAppend,
    this.expandedAlbumIdWithinArtist,
    this.artistMoreAlbumsExpanded = const {},
    this.albumMoreTracksExpanded = const {},
  });

  int get totalResultCount {
    if (searchResults == null) return 0;
    return searchResults!.values.fold(0, (sum, list) => sum + list.items.length);
  }

  SearchState copyWith({
    bool? isExpanded,
    bool? searchActive,
    bool? keyboardVisible,
    String? query,
    bool? isLoading,
    Map<SearchType, BrowseItemsList>? searchResults,
    List<BrowseItemsList>? browseRecommendations,
    String? error,
    String? expandedAlbumId,
    String? artistPreviewId,
    bool? tracksExpanded,
    InteractionMode? interactionMode,
    bool clearExpandedAlbum = false,
    bool clearArtistPreview = false,
    String? expandedAlbumIdWithinArtist,
    Set<String>? artistMoreAlbumsExpanded,
    Set<String>? albumMoreTracksExpanded,
    bool clearExpandedAlbumWithinArtist = false,
  }) {
    return SearchState(
      isExpanded: isExpanded ?? this.isExpanded,
      searchActive: searchActive ?? this.searchActive,
      keyboardVisible: keyboardVisible ?? this.keyboardVisible,
      query: query ?? this.query,
      isLoading: isLoading ?? this.isLoading,
      searchResults: searchResults ?? this.searchResults,
      browseRecommendations:
          browseRecommendations ?? this.browseRecommendations,
      error: error ?? this.error,
      expandedAlbumId:
          clearExpandedAlbum ? null : (expandedAlbumId ?? this.expandedAlbumId),
      artistPreviewId:
          clearArtistPreview ? null : (artistPreviewId ?? this.artistPreviewId),
      tracksExpanded: tracksExpanded ?? this.tracksExpanded,
      interactionMode: interactionMode ?? this.interactionMode,
      expandedAlbumIdWithinArtist: clearExpandedAlbumWithinArtist
          ? null
          : (expandedAlbumIdWithinArtist ?? this.expandedAlbumIdWithinArtist),
      artistMoreAlbumsExpanded:
          artistMoreAlbumsExpanded ?? this.artistMoreAlbumsExpanded,
      albumMoreTracksExpanded:
          albumMoreTracksExpanded ?? this.albumMoreTracksExpanded,
    );
  }
}

/// Notifier managing search state, history, and caching
class SearchStateNotifier extends Notifier<SearchState> {
  late SharedPreferences _prefs;
  final Map<String, CachedSearchResult> _cache = {};
  Timer? _debounceTimer;

  @override
  SearchState build() {
    _prefs = ref.read(sharedPrefsProvider);
    _setupAutoCollapse();
    _setupCacheInvalidation();
    return const SearchState();
  }

  void _setupAutoCollapse() {
    // Auto-collapse when queue expands
    ref.listen(queueExpansionProvider, (previous, next) {
      if (next && state.isExpanded) {
        collapse();
      }
    });
  }

  void _setupCacheInvalidation() {
    // Clear cache when connection settings change
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

  void activateSearch() {
    state = state.copyWith(searchActive: true);
    if (state.query.isEmpty && state.browseRecommendations == null) {
      _loadBrowseRecommendations();
    }
  }

  void deactivateSearch() {
    _debounceTimer?.cancel();
    state = state.copyWith(
      searchActive: false,
      query: '',
      searchResults: null,
      error: null,
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
    state = state.copyWith(query: query, error: null);
    _debounceTimer?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    // If cached results exist, show them immediately
    final cached = _cache[trimmed];
    if (cached != null && !cached.isExpired) {
      state = state.copyWith(searchResults: cached.results, isLoading: false);
      return;
    }
    // Otherwise, debounce a search
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
      state = state.copyWith(searchResults: cached.results, isLoading: false);
      _addToHistory(query);
      return;
    }

    state = state.copyWith(isLoading: true, error: null, searchResults: null);

    try {
      final api = ref.read(kalinkaProxyProvider);

      // Perform 4 parallel searches
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
        // Remove oldest entry
        final oldestKey = _cache.keys.first;
        _cache.remove(oldestKey);
      }

      state = state.copyWith(searchResults: resultMap, isLoading: false);

      _addToHistory(query);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Search failed: $e');
    }
  }

  Future<void> _loadBrowseRecommendations() async {
    final currentTrack = ref.read(playerStateProvider).currentTrack;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final api = ref.read(kalinkaProxyProvider);
      final recommendations = <BrowseItemsList>[];

      if (currentTrack != null) {
        // Sequential calls with 300ms stagger for track, album, artist
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
        // No track playing, browse root
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

  void cycleInteractionMode() {
    final next = state.interactionMode == InteractionMode.instantAppend
        ? InteractionMode.contextMenu
        : InteractionMode.instantAppend;
    state = state.copyWith(interactionMode: next);
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
    state = state.copyWith(query: '', searchResults: null, error: null);
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
    history.remove(query); // Remove if already exists
    history.insert(0, query); // Add to front
    if (history.length > _maxHistoryItems) {
      history.removeRange(_maxHistoryItems, history.length);
    }
    _prefs.setString(_searchHistoryKey, jsonEncode(history));
  }

  void clearHistory() {
    _prefs.remove(_searchHistoryKey);
  }
}

final searchStateProvider = NotifierProvider<SearchStateNotifier, SearchState>(
  SearchStateNotifier.new,
);
