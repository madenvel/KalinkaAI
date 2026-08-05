import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data_model/data_model.dart' show RendererInfo;
import 'connection_settings_provider.dart';
import 'connection_state_provider.dart';
import 'kalinka_player_api_provider.dart';

/// Renderers the server knows about, plus which one playback runs on.
///
/// There is no push channel for this — `/renderer/list` is polled on connect
/// and re-read whenever the picker opens, which is the only moment a stale
/// list would be visible.
class RendererListState {
  final List<RendererInfo> renderers;

  /// True while a list fetch is in flight.
  final bool loading;

  /// False on a server that predates the `/renderer/*` endpoints. Keeps the
  /// switcher hidden and stops the provider retrying against a 404.
  final bool supported;

  const RendererListState({
    this.renderers = const [],
    this.loading = false,
    this.supported = true,
  });

  /// The renderer playback is on, or null when nothing is connected.
  RendererInfo? get active {
    for (final r in renderers) {
      if (r.active) return r;
    }
    return null;
  }

  /// Whether the renderer switcher has anything to show.
  bool get hasRenderers => supported && renderers.isNotEmpty;

  RendererListState copyWith({
    List<RendererInfo>? renderers,
    bool? loading,
    bool? supported,
  }) => RendererListState(
    renderers: renderers ?? this.renderers,
    loading: loading ?? this.loading,
    supported: supported ?? this.supported,
  );
}

class RendererListNotifier extends Notifier<RendererListState> {
  /// Bumped per fetch so a slow response can't overwrite a newer one.
  int _generation = 0;

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
          state = const RendererListState();
        case ConnectionStatus.connecting:
        case ConnectionStatus.reconnecting:
        case ConnectionStatus.offline:
          break;
      }
    });
    if (ref.read(connectionStateProvider) == ConnectionStatus.connected) {
      Future.microtask(refresh);
    }
    return const RendererListState();
  }

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
      state = RendererListState(renderers: renderers);
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
          RendererInfo(
            rendererId: r.rendererId,
            friendlyName: r.friendlyName,
            status: r.status,
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
