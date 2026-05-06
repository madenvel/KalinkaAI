import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data_model/data_model.dart';
import 'connection_settings_provider.dart';
import 'kalinka_player_api_provider.dart';

/// Embedding-index coverage published as its own provider so the 5s poll
/// loop does not churn the much wider [searchStateProvider]. Widgets that
/// render the progress banner watch this provider directly; everything
/// else in the search surface is unaffected by ticks.
class IndexerStatusState {
  final IndexerStatus? status;

  /// Monotonically non-decreasing progress (0-100). The server's raw
  /// coverage can dip when new work is queued; we display the max observed
  /// value within a session and only reset it when the index completes or
  /// empties.
  final double? progressPct;

  const IndexerStatusState({this.status, this.progressPct});

  IndexerStatusState copyWith({
    IndexerStatus? status,
    double? progressPct,
    bool clearProgressPct = false,
  }) {
    return IndexerStatusState(
      status: status ?? this.status,
      progressPct:
          clearProgressPct ? null : (progressPct ?? this.progressPct),
    );
  }
}

class IndexerStatusNotifier extends Notifier<IndexerStatusState> {
  Timer? _pollTimer;
  static const _pollInterval = Duration(seconds: 5);

  @override
  IndexerStatusState build() {
    ref.onDispose(() => _pollTimer?.cancel());
    return const IndexerStatusState();
  }

  /// Kick off (or refresh) the polling loop. Safe to call repeatedly.
  Future<void> refresh() async {
    _pollTimer?.cancel();
    final settings = ref.read(connectionSettingsProvider);
    if (!settings.isSet) return;
    try {
      final api = ref.read(kalinkaProxyProvider);
      final status = await api.getIndexerStatus();

      if (status.isEmpty || status.isComplete) {
        state = state.copyWith(status: status, clearProgressPct: true);
      } else {
        final raw = status.overallCoveragePct;
        final prev = state.progressPct;
        final next = raw == null
            ? prev
            : (prev == null ? raw : math.max(prev, raw));
        state = state.copyWith(status: status, progressPct: next);
        _pollTimer = Timer(_pollInterval, refresh);
      }
    } catch (_) {
      // Non-critical — banner simply won't show.
    }
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }
}

final indexerStatusProvider =
    NotifierProvider<IndexerStatusNotifier, IndexerStatusState>(
  IndexerStatusNotifier.new,
);
