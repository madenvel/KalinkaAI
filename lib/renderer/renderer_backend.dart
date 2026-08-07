/// The audio half of the app-hosted renderer: plays one source at a time.
///
/// Queue semantics (what a set_source displaces, when the next queued source
/// starts) are protocol behaviour and live in RendererEngine; a backend only
/// loads, plays and reports. Implementations: HtmlAudioBackend on web.
library;

import 'dart:async';

abstract interface class RendererAudioBackend {
  /// Load [uri] and start playing it, replacing whatever was loaded.
  /// [startOffsetMs] begins the source partway in; positions reported stay
  /// absolute in the stream.
  void play({required String uri, required int startOffsetMs});

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
  const BackendEvent();
}

/// Audio is audibly progressing (initial start, after a stall or a seek).
class BackendPlaying extends BackendEvent {
  const BackendPlaying();
}

/// Playback halted to buffer; a [BackendPlaying] follows when it recovers.
class BackendStalled extends BackendEvent {
  const BackendStalled();
}

/// Paused outside the protocol — browser media keys, or a seek that settled
/// while paused. The engine's own pause command does not need this.
class BackendPaused extends BackendEvent {
  const BackendPaused();
}

/// The loaded source ran to its end.
class BackendEnded extends BackendEvent {
  const BackendEnded();
}

/// The loaded source cannot play (on).
class BackendFailed extends BackendEvent {
  final BackendErrorKind kind;
  final String message;
  const BackendFailed(this.kind, this.message);
}
