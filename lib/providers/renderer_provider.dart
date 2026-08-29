import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data_model/data_model.dart' show RendererInfo;
import '../data_model/playqueue_events.dart';
import 'connection_settings_provider.dart';
import 'connection_state_provider.dart';
import 'kalinka_player_api_provider.dart';
import 'wire_event_provider.dart';

/// Renderers the server knows about, plus which one playback runs on.
///
/// Kept current by the queue socket: the replay reports the topology with the
/// queue state and renderers_changed / current_renderer_changed push every
/// change. `/renderer/list` remains as the fallback for servers that predate
/// the events — polled on connect and when the picker opens.
class RendererListState {
  final List<RendererInfo> renderers;

  /// True while a list fetch is in flight.
  final bool loading;

  /// False on a server that predates the `/renderer/*` endpoints. Keeps the
  /// switcher hidden and stops the provider retrying against a 404.
  final bool supported;

  /// True once a list has actually been read from this server. Distinguishes
  /// "no renderer available" from "not asked yet" (startup, server switch),
  /// which must not flash the failure state.
  final bool loaded;

  const RendererListState({
    this.renderers = const [],
    this.loading = false,
    this.supported = true,
    this.loaded = false,
  });

  /// The renderer playback is on, or null when nothing is connected.
  RendererInfo? get active {
    for (final r in renderers) {
      if (r.active) return r;
    }
    return null;
  }

  /// Whether the switcher widgets have anything trustworthy to show — the
  /// server speaks `/renderer/*` and a list has been read. An empty list
  /// still shows: that is the crossed-icon "no renderer available" state.
  bool get switcherVisible => supported && loaded;

  RendererListState copyWith({
    List<RendererInfo>? renderers,
    bool? loading,
    bool? supported,
    bool? loaded,
  }) => RendererListState(
    renderers: renderers ?? this.renderers,
    loading: loading ?? this.loading,
    supported: supported ?? this.supported,
    loaded: loaded ?? this.loaded,
  );
}

class RendererListNotifier extends Notifier<RendererListState> {
  /// Bumped per fetch and per pushed event so a slow response can't overwrite
  /// a newer picture.
  int _generation = 0;

  /// Last pushed (active, selected) pair; rows arrive unflagged, the marker
  /// is a separate fact.
  String? _currentId;
  String? _selectedId;

  @override
  RendererListState build() {
    ref.listen<ConnectionStatus>(connectionStateProvider, (previous, next) {
      if (next == previous) return;
      switch (next) {
        case ConnectionStatus.connected:
          refresh();
        case ConnectionStatus.none:
          // Server unset — drop the previous server's renderers instead of
          // offering them against the next one.
          _generation++;
          _currentId = null;
          _selectedId = null;
          state = const RendererListState();
        case ConnectionStatus.connecting:
        case ConnectionStatus.reconnecting:
        case ConnectionStatus.offline:
          break;
      }
    });
    ref.listen(playQueueEventBusProvider, (previous, next) {
      next.whenData(_onEvent);
    });
    if (ref.read(connectionStateProvider) == ConnectionStatus.connected) {
      Future.microtask(refresh);
    }
    return const RendererListState();
  }

  void _onEvent(PlayQueueEvent event) {
    switch (event) {
      case RenderersChangedEvent(:final renderers):
        _generation++;
        state = RendererListState(renderers: _flagged(renderers), loaded: true);
      case CurrentRendererChangedEvent(
        :final rendererId,
        :final selectedRendererId,
      ):
        _generation++;
        _currentId = rendererId;
        _selectedId = selectedRendererId;
        state = state.copyWith(
          renderers: _flagged(state.renderers),
          loading: false,
        );
      case ReplayPlayQueueEvent(state: final replay):
        // Null renderers = a server from before the events; the REST poll
        // stays the source there.
        final rows = replay.renderers;
        if (rows == null) return;
        _generation++;
        _currentId = replay.currentRendererId;
        _selectedId = replay.selectedRendererId;
        state = RendererListState(renderers: _flagged(rows), loaded: true);
      default:
        break;
    }
  }

  List<RendererInfo> _flagged(List<RendererInfo> rows) => [
    for (final r in rows)
      r.copyWith(
        active: r.rendererId == _currentId,
        selected: r.rendererId == _selectedId,
      ),
  ];

  /// True once this response no longer owns the state — a newer fetch started,
  /// or the container went away while the request was in flight.
  bool _stale(int generation) => !ref.mounted || generation != _generation;

  Future<void> refresh() async {
    // The microtask in build() can outlive a short-lived container.
    if (!ref.mounted) return;
    if (!ref.read(connectionSettingsProvider).isSet) return;
    final generation = ++_generation;
    state = state.copyWith(loading: true);
    try {
      final renderers = await ref.read(kalinkaProxyProvider).listRenderers();
      if (_stale(generation)) return;
      // REST rows carry the flags; keep the pushed-event bookkeeping in step
      // so a later current-only event reflags this list correctly.
      _currentId = renderers
          .where((r) => r.active)
          .map((r) => r.rendererId)
          .firstOrNull;
      _selectedId = renderers
          .where((r) => r.selected)
          .map((r) => r.rendererId)
          .firstOrNull;
      state = RendererListState(renderers: renderers, loaded: true);
    } on RenderersUnsupportedException {
      if (_stale(generation)) return;
      state = const RendererListState(supported: false);
    } catch (_) {
      if (_stale(generation)) return;
      // Transient (server briefly unreachable): keep the last list rather
      // than making the switcher vanish mid-session.
      state = state.copyWith(loading: false);
    }
  }

  /// Pin playback to [rendererId], which must be connected — the server keeps
  /// a pin on an offline renderer but leaves playback where it is, so the
  /// picker only offers connected ones. Marks it active straight away so the
  /// tick moves with the tap, then reconciles against what the server reports.
  Future<void> select(String rendererId) async {
    state = state.copyWith(
      renderers: [
        for (final r in state.renderers)
          r.copyWith(
            active: r.rendererId == rendererId,
            selected: r.rendererId == rendererId,
          ),
      ],
    );
    try {
      await ref.read(kalinkaProxyProvider).setActiveRenderer(rendererId);
    } finally {
      await refresh();
    }
  }
}

final rendererListProvider =
    NotifierProvider<RendererListNotifier, RendererListState>(
      RendererListNotifier.new,
    );
