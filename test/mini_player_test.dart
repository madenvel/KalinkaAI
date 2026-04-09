import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalinka/data_model/data_model.dart';
import 'package:kalinka/data_model/playqueue_events.dart';
import 'package:kalinka/providers/app_state_provider.dart';
import 'package:kalinka/providers/connection_state_provider.dart';
import 'package:kalinka/providers/playback_time_provider.dart';
import 'package:kalinka/providers/search_state_provider.dart';
import 'package:kalinka/providers/url_resolver.dart';
import 'package:kalinka/widgets/gradient_progress_line.dart';
import 'package:kalinka/widgets/mini_player.dart';

// ── Fake notifiers ────────────────────────────────────────────────────────────
// Each extends the real notifier and overrides build() to return a fixed value,
// avoiding any network/timer setup from the real implementations.

class _SettableQueueNotifier extends PlayQueueStateStore {
  _SettableQueueNotifier(this._initialState);
  final PlayQueueState _initialState;

  @override
  PlayQueueState build() => _initialState;

  void emit(PlayQueueState s) => state = s;
}

class _FakeConnectionNotifier extends ConnectionStateNotifier {
  _FakeConnectionNotifier(this._status);
  final ConnectionStatus _status;

  @override
  ConnectionStatus build() => _status;
}

class _FakeSearchNotifier extends SearchStateNotifier {
  @override
  SearchState build() => const SearchState();
}

class _FakePlaybackTimeNotifier extends PlaybackTimeMsNotifier {
  @override
  int build() => 0;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

// Return type is intentionally inferred — Riverpod's Override type is sealed
// and its concrete form is resolved by the package internally.
_buildOverrides({
  required PlayQueueState queueState,
  ConnectionStatus connectionStatus = ConnectionStatus.connected,
}) =>
    [
      playQueueStateStoreProvider
          .overrideWith(() => _SettableQueueNotifier(queueState)),
      connectionStateProvider
          .overrideWith(() => _FakeConnectionNotifier(connectionStatus)),
      searchStateProvider.overrideWith(() => _FakeSearchNotifier()),
      playbackTimeMsProvider.overrideWith(() => _FakePlaybackTimeNotifier()),
      urlResolverProvider.overrideWithValue(UrlResolver('')),
    ];

PlayQueueState _queueWithState({
  PlayerStateType? state,
  String? message,
}) =>
    PlayQueueState(
      playbackState: PlaybackState(state: state, message: message),
      trackList: const [],
      playbackMode: PlaybackMode.empty,
      seq: 0,
    );


Future<void> pumpMiniPlayer(
  WidgetTester tester, {
  PlayQueueState? queueState,
  ConnectionStatus connectionStatus = ConnectionStatus.connected,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: _buildOverrides(
        queueState: queueState ?? PlayQueueState.empty,
        connectionStatus: connectionStatus,
      ),
      child: const MaterialApp(home: Scaffold(body: MiniPlayer())),
    ),
  );
  await tester.pump();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('play button icons', () {
    testWidgets('shows pause icon when playing', (tester) async {
      await pumpMiniPlayer(
        tester,
        queueState: _queueWithState(state: PlayerStateType.playing),
      );

      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
      expect(find.byIcon(Icons.warning_rounded), findsNothing);
    });

    testWidgets('shows play icon when paused', (tester) async {
      await pumpMiniPlayer(
        tester,
        queueState: _queueWithState(state: PlayerStateType.paused),
      );

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsNothing);
    });

    testWidgets('shows play icon when stopped', (tester) async {
      await pumpMiniPlayer(
        tester,
        queueState: _queueWithState(state: PlayerStateType.stopped),
      );

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('shows CircularProgressIndicator when buffering', (tester) async {
      await pumpMiniPlayer(
        tester,
        queueState: _queueWithState(state: PlayerStateType.buffering),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
      expect(find.byIcon(Icons.pause_rounded), findsNothing);
    });

    testWidgets('shows warning icon when error', (tester) async {
      await pumpMiniPlayer(
        tester,
        queueState:
            _queueWithState(state: PlayerStateType.error, message: 'Oops'),
      );

      expect(find.byIcon(Icons.warning_rounded), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
      expect(find.byIcon(Icons.pause_rounded), findsNothing);
    });
  });

  group('error popup', () {
    testWidgets('shows AlertDialog on transition to error', (tester) async {
      final container = ProviderContainer(
        overrides: _buildOverrides(queueState: PlayQueueState.empty),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: MiniPlayer())),
        ),
      );
      await tester.pump();

      expect(find.byType(AlertDialog), findsNothing);

      (container.read(playQueueStateStoreProvider.notifier)
              as _SettableQueueNotifier)
          .emit(_queueWithState(
        state: PlayerStateType.error,
        message: 'Unsupported codec',
      ));
      await tester.pump();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Unsupported codec'), findsOneWidget);
    });

    testWidgets('does not show dialog when already in error on first build',
        (tester) async {
      // Starting in error state is not a transition — no dialog.
      final container = ProviderContainer(
        overrides: _buildOverrides(
          queueState: _queueWithState(
            state: PlayerStateType.error,
            message: 'Codec error',
          ),
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: MiniPlayer())),
        ),
      );
      await tester.pump();

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('shows new dialog when error message changes', (tester) async {
      final container = ProviderContainer(
        overrides: _buildOverrides(
          queueState: _queueWithState(
            state: PlayerStateType.error,
            message: 'First error',
          ),
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: MiniPlayer())),
        ),
      );
      await tester.pump();

      // No dialog for the initial state — not a transition.
      expect(find.byType(AlertDialog), findsNothing);

      // A second distinct error fires a dialog.
      (container.read(playQueueStateStoreProvider.notifier)
              as _SettableQueueNotifier)
          .emit(_queueWithState(
        state: PlayerStateType.error,
        message: 'Second error',
      ));
      await tester.pump();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Second error'), findsOneWidget);
    });
  });

  group('offline dimming', () {
    testWidgets('content is dimmed when reconnecting', (tester) async {
      await pumpMiniPlayer(
        tester,
        connectionStatus: ConnectionStatus.reconnecting,
      );

      final opacities = tester
          .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
          .map((w) => w.opacity)
          .toList();
      expect(opacities.contains(0.45), isTrue);
    });

    testWidgets('content is dimmed when offline', (tester) async {
      await pumpMiniPlayer(
        tester,
        connectionStatus: ConnectionStatus.offline,
      );

      final opacities = tester
          .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
          .map((w) => w.opacity)
          .toList();
      expect(opacities.contains(0.45), isTrue);
    });

    testWidgets('content is fully visible when connected', (tester) async {
      await pumpMiniPlayer(
        tester,
        connectionStatus: ConnectionStatus.connected,
      );

      final opacities = tester
          .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
          .map((w) => w.opacity)
          .toList();
      expect(opacities.contains(0.45), isFalse);
    });
  });

  group('empty queue behaviour', () {
    testWidgets('shows "No track" when queue is empty and stopped',
        (tester) async {
      await pumpMiniPlayer(
        tester,
        queueState: PlayQueueState(
          playbackState: PlaybackState(state: PlayerStateType.stopped),
          trackList: const [],
          playbackMode: PlaybackMode.empty,
          seq: 0,
        ),
      );

      expect(find.text('No track'), findsOneWidget);
      expect(tester.getSize(find.byType(MiniPlayer)).height, greaterThan(0));
    });

    testWidgets(
        'does not show stale track when queue is cleared but playbackState.currentTrack is still set',
        (tester) async {
      // Simulate the server state after a queue clear: trackList is empty but
      // PlaybackState.currentTrack still holds the old track because copyWith
      // never clears fields to null.
      final staleTrack = Track(
        id: 'stale-id',
        title: 'Stale Track',
        duration: 180,
        performer: Artist(id: 'a1', name: 'Stale Artist'),
      );
      await pumpMiniPlayer(
        tester,
        queueState: PlayQueueState(
          playbackState: PlaybackState(
            state: PlayerStateType.stopped,
            currentTrack: staleTrack,
            index: 0,
          ),
          trackList: const [],
          playbackMode: PlaybackMode.empty,
          seq: 1,
        ),
      );

      expect(find.text('Stale Track'), findsNothing);
      expect(find.text('Stale Artist'), findsNothing);
      expect(find.text('No track'), findsOneWidget);
    });

    testWidgets('shows "No track" after playing track is removed from queue',
        (tester) async {
      final track = Track(id: 'tid', title: 'Now Playing', duration: 200);
      final container = ProviderContainer(
        overrides: _buildOverrides(
          queueState: PlayQueueState(
            playbackState: PlaybackState(
              state: PlayerStateType.playing,
              currentTrack: track,
              index: 0,
            ),
            trackList: [track],
            playbackMode: PlaybackMode.empty,
            seq: 0,
          ),
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: MiniPlayer())),
        ),
      );
      await tester.pump();

      expect(find.text('Now Playing'), findsOneWidget);

      // Simulate the server clearing the queue: empty trackList + stopped state,
      // stale currentTrack still present in playbackState.
      (container.read(playQueueStateStoreProvider.notifier)
              as _SettableQueueNotifier)
          .emit(PlayQueueState(
        playbackState: PlaybackState(
          state: PlayerStateType.stopped,
          currentTrack: track, // stale — never cleared by copyWith
          index: 0,
        ),
        trackList: const [],
        playbackMode: PlaybackMode.empty,
        seq: 1,
      ));
      await tester.pump();

      expect(find.text('Now Playing'), findsNothing);
      expect(find.text('No track'), findsOneWidget);
    });
  });

  group('progress line mode', () {
    testWidgets('uses normal mode when connected', (tester) async {
      await pumpMiniPlayer(
        tester,
        connectionStatus: ConnectionStatus.connected,
      );

      final line = tester.widget<GradientProgressLine>(
        find.byType(GradientProgressLine),
      );
      expect(line.mode, GradientProgressLineMode.normal);
    });

    testWidgets('uses reconnecting mode when reconnecting', (tester) async {
      await pumpMiniPlayer(
        tester,
        connectionStatus: ConnectionStatus.reconnecting,
      );

      final line = tester.widget<GradientProgressLine>(
        find.byType(GradientProgressLine),
      );
      expect(line.mode, GradientProgressLineMode.reconnecting);
    });

    testWidgets('uses offline mode when offline', (tester) async {
      await pumpMiniPlayer(
        tester,
        connectionStatus: ConnectionStatus.offline,
      );

      final line = tester.widget<GradientProgressLine>(
        find.byType(GradientProgressLine),
      );
      expect(line.mode, GradientProgressLineMode.offline);
    });
  });
}
