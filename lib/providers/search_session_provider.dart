import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data_model/data_model.dart';
import 'connection_settings_provider.dart';
import 'kalinka_player_api_provider.dart';

/// Persistent history of submitted search prompts (most-recent first).
const _historyKey = 'Kalinka.chatSearchHistory';
const _maxHistoryItems = 12;
const _minHistoryQueryLength = 2;

/// Visible query blocks kept in the session: one expanded + up to two folded.
/// Older blocks scroll out of the session view (but their queries still land
/// in history on exit).
const _maxVisibleBlocks = 3;

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

/// One query and its results in the chat-style search session.
class SearchQueryBlock {
  final String id;
  final String query;

  /// True while the request is in flight (or held under the minimum loading
  /// duration). Drives the working animation under the bubble.
  final bool loading;

  /// AI search result — top-level items are per-source sections, never merged
  /// into a single ranked list. Null until resolved.
  final BrowseItemsList? results;
  final String? error;

  /// Section ids expanded past their default visible limit within this block.
  final Set<String> expandedSections;

  const SearchQueryBlock({
    required this.id,
    required this.query,
    this.loading = true,
    this.results,
    this.error,
    this.expandedSections = const {},
  });

  /// Total result items across all sections (for the folded summary line).
  int get resultCount {
    final r = results;
    if (r == null) return 0;
    return r.items.fold<int>(0, (sum, s) => sum + (s.sections?.length ?? 0));
  }

  SearchQueryBlock copyWith({
    bool? loading,
    BrowseItemsList? results,
    String? error,
    bool clearError = false,
    Set<String>? expandedSections,
  }) {
    return SearchQueryBlock(
      id: id,
      query: query,
      loading: loading ?? this.loading,
      results: results ?? this.results,
      error: clearError ? null : (error ?? this.error),
      expandedSections: expandedSections ?? this.expandedSections,
    );
  }
}

/// Ephemeral state for the bottom-docked, chat-style search session.
class SearchSessionState {
  /// Whether the full-screen search surface is open.
  final bool isOpen;

  /// Query blocks in chat order — oldest first, the newest at the bottom.
  final List<SearchQueryBlock> blocks;

  /// Id of the currently expanded block. Exactly one block is expanded at a
  /// time; the rest render as folded single-line summaries.
  final String expandedBlockId;

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
    this.blocks = const [],
    this.expandedBlockId = '',
    this.history = const [],
    this.recentFavourites = const [],
    this.zeroStateLoading = false,
    this.aiSuggestions = const [],
  });

  /// True when the session has no query blocks — the zero state is shown.
  bool get isZeroState => blocks.isEmpty;

  /// Prompts shown in the zero state: the server's context-aware suggestions
  /// once fetched, static examples until then.
  List<SearchSuggestion> get suggestions =>
      aiSuggestions.isEmpty ? _fallbackSuggestions : aiSuggestions;

  SearchSessionState copyWith({
    bool? isOpen,
    List<SearchQueryBlock>? blocks,
    String? expandedBlockId,
    List<String>? history,
    List<BrowseItem>? recentFavourites,
    bool? zeroStateLoading,
    List<SearchSuggestion>? aiSuggestions,
  }) {
    return SearchSessionState(
      isOpen: isOpen ?? this.isOpen,
      blocks: blocks ?? this.blocks,
      expandedBlockId: expandedBlockId ?? this.expandedBlockId,
      history: history ?? this.history,
      recentFavourites: recentFavourites ?? this.recentFavourites,
      zeroStateLoading: zeroStateLoading ?? this.zeroStateLoading,
      aiSuggestions: aiSuggestions ?? this.aiSuggestions,
    );
  }
}

class SearchSessionNotifier extends Notifier<SearchSessionState> {
  late SharedPreferences _prefs;
  int _blockCounter = 0;

  /// Every query submitted this session, oldest first. Kept separate from the
  /// visible [SearchSessionState.blocks] (capped at [_maxVisibleBlocks]) so
  /// queries that scroll out of view are still folded into history on exit.
  final List<String> _sessionQueries = [];

  bool _disposed = false;

  @override
  SearchSessionState build() {
    _prefs = ref.read(sharedPrefsProvider);
    ref.onDispose(() => _disposed = true);
    return SearchSessionState(history: _loadHistory());
  }

  // ── Open / close ───────────────────────────────────────────────────────────

  /// Open the search surface at the zero state and refresh its data.
  void open() {
    if (state.isOpen) return;
    state = state.copyWith(isOpen: true, history: _loadHistory());
    _loadRecentFavourites();
    _loadSuggestions();
  }

  /// Close the surface: fold every session query into persistent history,
  /// then discard the ephemeral session (blocks + results).
  void close() {
    if (!state.isOpen && state.blocks.isEmpty) return;
    // Oldest first, so the newest lands at the front of history.
    for (final query in _sessionQueries) {
      _appendHistory(query);
    }
    _sessionQueries.clear();
    state = state.copyWith(
      isOpen: false,
      blocks: const [],
      expandedBlockId: '',
      history: _loadHistory(),
    );
  }

  // ── Submitting queries ─────────────────────────────────────────────────────

  /// Submit [rawQuery] as a new query block. No-op for blank input. This is the
  /// only path that fires a network request — there is no search-as-you-type.
  void submit(String rawQuery) {
    final query = rawQuery.trim();
    if (query.isEmpty) return;

    final id = 'q${_blockCounter++}';
    final block = SearchQueryBlock(id: id, query: query);
    _sessionQueries.add(query);

    // Newest block appends at the bottom (chat order); keep only the most
    // recent few, dropping the oldest off the top.
    final blocks = [...state.blocks, block];
    if (blocks.length > _maxVisibleBlocks) {
      blocks.removeRange(0, blocks.length - _maxVisibleBlocks);
    }
    state = state.copyWith(blocks: blocks, expandedBlockId: id);
    _runQuery(id, query);
  }

  Future<void> _runQuery(String id, String query) async {
    final settings = ref.read(connectionSettingsProvider);
    if (!settings.isSet) {
      _updateBlock(
        id,
        (b) => b.copyWith(loading: false, error: 'No server connected'),
      );
      return;
    }

    final start = DateTime.now();
    try {
      final api = ref.read(kalinkaProxyProvider);
      final result = await api.aiSearch(query);
      await _holdMinimumLoading(start);
      if (_disposed) return;
      _updateBlock(
        id,
        (b) => b.copyWith(loading: false, results: result, clearError: true),
      );
    } catch (e) {
      await _holdMinimumLoading(start);
      if (_disposed) return;
      _updateBlock(
        id,
        (b) => b.copyWith(loading: false, error: 'Search failed: $e'),
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

  // ── Block folding / section expansion ──────────────────────────────────────

  /// Expand a folded block, collapsing whichever block was expanded. Only one
  /// block is ever expanded at a time.
  void expandBlock(String id) {
    if (state.expandedBlockId == id) return;
    if (!state.blocks.any((b) => b.id == id)) return;
    state = state.copyWith(expandedBlockId: id);
  }

  /// Toggle "show more" for a section within a block.
  void toggleSection(String blockId, String sectionId) {
    _updateBlock(blockId, (b) {
      final next = Set<String>.from(b.expandedSections);
      if (!next.remove(sectionId)) next.add(sectionId);
      return b.copyWith(expandedSections: next);
    });
  }

  void _updateBlock(
    String id,
    SearchQueryBlock Function(SearchQueryBlock) update,
  ) {
    final index = state.blocks.indexWhere((b) => b.id == id);
    if (index < 0) return;
    final blocks = [...state.blocks];
    blocks[index] = update(blocks[index]);
    state = state.copyWith(blocks: blocks);
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
      // A fresh modifiable list — callers append/remove in place.
      return List<String>.from((jsonDecode(json) as List).cast<String>());
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
