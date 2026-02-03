import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data_model/data_model.dart' show PlaybackState, PlayerStateType;
import '../providers/app_state_provider.dart' show playerStateProvider;
import '../providers/monotonic_clock_provider.dart' show monotonicClockProvider;

/// Expose app lifecycle as a provider.
final appLifecycleProvider =
    NotifierProvider<AppLifecycleNotifier, AppLifecycleState>(
      AppLifecycleNotifier.new,
    );

class AppLifecycleNotifier extends Notifier<AppLifecycleState> {
  AppLifecycleListener? _listener;

  @override
  AppLifecycleState build() {
    // Assume resumed initially (Flutter may deliver the real state soon after)
    state = AppLifecycleState.resumed;

    _listener = AppLifecycleListener(onStateChange: (s) => state = s);

    ref.onDispose(() => _listener?.dispose());
    return state;
  }
}

/// Public provider you watch in widgets.
/// - Uses `Stopwatch` (monotonic) to advance between accurate updates.
/// - Emits once per second only when app is RESUMED.
/// - On resume, emits immediately (catch-up) and restarts the 1s tick.
final playbackTimeMsProvider = NotifierProvider<PlaybackTimeMsNotifier, int>(
  PlaybackTimeMsNotifier.new,
);

class PlaybackTimeMsNotifier extends Notifier<int> {
  int getDeltaMs(PlaybackState playerState) {
    if (playerState.state == PlayerStateType.playing) {
      int delta =
          ref.read(monotonicClockProvider).elapsedMilliseconds -
          playerState.timestampNs;
      return delta;
    }
    return 0;
  }

  @override
  int build() {
    Timer? tick;

    bool isDisposed = false;
    final playerState = ref.watch(playerStateProvider);
    final baseTimeMs = playerState.position ?? 0;
    state = baseTimeMs + getDeltaMs(playerState);

    // Start/stop ticking based on lifecycle.
    ref.listen<AppLifecycleState>(appLifecycleProvider, (prev, next) {
      if (next == AppLifecycleState.resumed) {
        state = baseTimeMs + getDeltaMs(playerState);

        if (playerState.state == PlayerStateType.playing) {
          final msUntilNextSecond = 1000 - (state % 1000);
          tick = Timer(Duration(milliseconds: msUntilNextSecond), () {
            final lifecycle = ref.read(appLifecycleProvider);
            if (isDisposed || lifecycle != AppLifecycleState.resumed) {
              return;
            }

            state = baseTimeMs + getDeltaMs(playerState);
            tick = Timer.periodic(const Duration(seconds: 1), (_) {
              state = baseTimeMs + getDeltaMs(playerState);
            });
          });
        }
      } else {
        tick?.cancel();
        tick = null;
      }
    }, fireImmediately: true);

    ref.onDispose(() {
      tick?.cancel();
      tick = null;
      isDisposed = true;
    });

    return state;
  }
}
