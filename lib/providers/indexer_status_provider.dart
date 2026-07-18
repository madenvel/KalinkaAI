import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data_model/data_model.dart';
import 'connection_settings_provider.dart';
import 'kalinka_player_api_provider.dart';

/// Library-pipeline stages surfaced to the user, in pipeline order. The
/// server reports finer-grained stages (`clap_audio` / `clap_text`); both
/// embedding stages fold into [preparingAi].
enum IndexerDisplayStage {
  indexing('Indexing'),
  enrichment('Enrichment'),
  preparingAi('Preparing AI search');

  final String label;
  const IndexerDisplayStage(this.label);
}

/// Pipeline progress published as its own provider so the 5s poll loop does
/// not churn the wider search state. Widgets that render the progress banner
/// watch this provider directly; everything else is unaffected by ticks.
class IndexerStatusState {
  /// Earliest pipeline stage that still has outstanding work — the one the
  /// banner names. Stages overlap on the server (enrichment starts while the
  /// scan is still finding files), but showing the earliest keeps the label
  /// from jumping back and forth. Null when the whole pipeline is idle.
  final IndexerDisplayStage? stage;

  /// Progress (0-100) of [stage], monotonically non-decreasing while the
  /// stage is displayed: raw numbers can dip when new work is queued
  /// mid-run. Resets when the displayed stage changes.
  final double? progressPct;

  const IndexerStatusState({this.stage, this.progressPct});
}

class IndexerStatusNotifier extends Notifier<IndexerStatusState> {
  Timer? _pollTimer;

  /// Bumped by [stop] so a refresh whose request is in flight when the
  /// search surface closes cannot re-arm the timer afterwards.
  int _generation = 0;
  static const _activePollInterval = Duration(seconds: 5);

  /// Idle cadence: keeps the banner able to appear if pipeline work starts
  /// while the search surface stays open (a scheduled rescan, a manual
  /// re-index) at negligible request cost.
  static const _idlePollInterval = Duration(seconds: 30);

  @override
  IndexerStatusState build() {
    ref.onDispose(() => _pollTimer?.cancel());
    return const IndexerStatusState();
  }

  /// Kick off (or refresh) the polling loop. Safe to call repeatedly.
  /// Runs until [stop]: every 5s while the pipeline works, every 30s while
  /// it is idle. A failed poll keeps the last state — the pipeline is
  /// likely still running, and the retry self-heals.
  Future<void> refresh() async {
    _pollTimer?.cancel();
    final generation = ++_generation;
    final settings = ref.read(connectionSettingsProvider);
    if (!settings.isSet) return;
    try {
      final api = ref.read(kalinkaProxyProvider);
      final status = await api.getIndexerStatus();
      if (generation != _generation) return; // stopped while in flight
      _apply(status);
    } catch (_) {
      if (generation != _generation) return;
      // Non-critical (server briefly unreachable) — keep the last state
      // rather than flashing "done", and let the next poll correct it.
    }
    _pollTimer = Timer(
      state.stage != null ? _activePollInterval : _idlePollInterval,
      refresh,
    );
  }

  void stop() {
    _generation++;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _apply(IndexerStatus status) {
    for (final stage in IndexerDisplayStage.values) {
      var total = 0;
      var outstanding = 0;
      for (final stages in status.modules.values) {
        for (final entry in stages.entries) {
          if (_displayStageFor(entry.key) != stage) continue;
          total += entry.value.total;
          outstanding += entry.value.pending + entry.value.inProgress;
        }
      }
      if (outstanding == 0) continue;

      final raw = 100.0 * (total - outstanding) / total;
      // Monotonic within a stage; a stage change starts fresh.
      final prev = state.stage == stage ? state.progressPct : null;
      state = IndexerStatusState(
        stage: stage,
        progressPct: prev == null ? raw : math.max(prev, raw),
      );
      return;
    }
    state = const IndexerStatusState();
  }

  IndexerDisplayStage _displayStageFor(String serverStage) {
    switch (serverStage) {
      case 'indexing':
        return IndexerDisplayStage.indexing;
      case 'enrichment':
        return IndexerDisplayStage.enrichment;
      default: // clap_audio, clap_text and any future embedding stage
        return IndexerDisplayStage.preparingAi;
    }
  }
}

final indexerStatusProvider =
    NotifierProvider<IndexerStatusNotifier, IndexerStatusState>(
  IndexerStatusNotifier.new,
);
