/// Audio backend for one source at a time. Queue behavior lives in the engine.
library;

import 'dart:async';

abstract interface class RendererAudioBackend {
  /// Load [uri] and start playing it, replacing whatever was loaded.
  /// [startOffsetMs] begins the source partway in; positions reported stay
  /// absolute in the stream.
  void play({
    required String uri,
    required int startOffsetMs,
    required int generation,
  });

  void pause();

  void resume();

  /// Tear down; nothing is loaded afterwards.
  void stop();

  void seek(int positionMs);

  /// Software gain, 0.0–1.0.
  void setVolume(double fraction);

  int get positionMs;

  bool get isPaused;

  Stream<BackendEvent> get events;

  void dispose();
}

enum BackendErrorKind { network, decode, internal }

sealed class BackendEvent {
  /// Identifies the [play] call this event belongs to. Events from a replaced
  /// media element can arrive late; the engine must ignore an old generation.
  final int generation;

  const BackendEvent(this.generation);
}

/// Audio is audibly progressing (initial start, after a stall or a seek).
class BackendPlaying extends BackendEvent {
  const BackendPlaying(super.generation);
}

/// Playback halted to buffer; a [BackendPlaying] follows when it recovers.
class BackendStalled extends BackendEvent {
  const BackendStalled(super.generation);
}

/// Paused outside the protocol — browser media keys, or a seek that settled
/// while paused. The engine's own pause command does not need this.
class BackendPaused extends BackendEvent {
  const BackendPaused(super.generation);
}

/// The loaded source ran to its end.
class BackendEnded extends BackendEvent {
  const BackendEnded(super.generation);
}

/// What the browser's own output runs at. HTMLMediaElement never exposes the
/// format it decoded, so a browser renderer has this to report and no stream
/// format. Emitted only when the browser will say — never invented.
class BackendDeviceFormat extends BackendEvent {
  final int sampleRateHz;
  final int channels;
  final int bitsPerSample;
  final String sampleFormat;

  const BackendDeviceFormat(
    super.generation, {
    required this.sampleRateHz,
    required this.channels,
    required this.bitsPerSample,
    required this.sampleFormat,
  });
}

/// How long the loaded source runs. Separate from the device, which is known
/// for a live stream whose length never will be.
class BackendDuration extends BackendEvent {
  final int durationMs;

  const BackendDuration(super.generation, {required this.durationMs});
}

/// The loaded source cannot play.
class BackendFailed extends BackendEvent {
  final BackendErrorKind kind;
  final String message;
  const BackendFailed(super.generation, this.kind, this.message);
}
