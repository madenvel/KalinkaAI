/// The protocol half of the app-hosted renderer: one playback session, the
/// source queue, and state reporting — the same observable behaviour as the
/// native renderer (and the server repo's tests/sim_renderer.py, which is the
/// reference for the corner cases: FINISHED vs STOPPED, who advances the
/// queue, which states carry a valid position).
///
/// The engine outlives any single WebSocket connection: a link drop leaves
/// playback running and the session in place, to be reconciled at the next
/// Hello. It emits ready-made Envelopes (sans message_id, which is
/// per-connection); with no connection listening they are dropped, exactly as
/// a session with a dead link would drop them.
library;

import 'dart:async';

import 'package:fixnum/fixnum.dart';

import '../generated/kalinka/renderer/v1/renderer.pb.dart' as pb;
import 'renderer_backend.dart';

class _Session {
  final String id;
  final String ownerServerId;

  /// Level to restore when the session ends; volume policy is session-scoped.
  final int savedVolumePercent;
  bool fixedVolume = false;

  _Session(this.id, this.ownerServerId, {required this.savedVolumePercent});
}

class RendererEngine {
  final RendererAudioBackend _backend;
  late final StreamSubscription<BackendEvent> _backendSub;
  // Sync: a reply must hit the wire in the order the protocol promises
  // (SessionOpenResult before the snapshot), not a microtask later.
  final _messages = StreamController<pb.Envelope>.broadcast(sync: true);

  _Session? _session;
  pb.Source? _current;
  final List<pb.Source> _queued = [];
  pb.PlaybackState _lastState = pb.PlaybackState.PLAYBACK_STATE_STOPPED;
  int _volumePercent = 100;

  RendererEngine(this._backend) {
    _backendSub = _backend.events.listen(_onBackendEvent);
  }

  /// Protocol messages for whichever connection is up; unstamped message_id.
  Stream<pb.Envelope> get messages => _messages.stream;

  /// For Hello: the session this renderer is running, if any.
  String get activeSessionId => _session?.id ?? '';
  String get sessionOwnerServerId => _session?.ownerServerId ?? '';

  void dispose() {
    _backendSub.cancel();
    _backend.dispose();
    _messages.close();
  }

  // ---------------------------------------------------------------- sessions

  void openSession({
    required String sessionId,
    required String ownerServerId,
    String volumeMode = '',
    int? volumePercent,
  }) {
    final existing = _session;
    if (existing != null && existing.id != sessionId) {
      _emit(
        pb.Envelope()
          ..sessionOpenResult = (pb.SessionOpenResult()
            ..sessionId = sessionId
            ..accepted = false
            ..error = pb.SessionOpenResult_Error.ERROR_BUSY
            ..detail = 'another playback session is running'
            ..ownerServerId = existing.ownerServerId),
      );
      return;
    }
    final session =
        existing ??
        _Session(sessionId, ownerServerId, savedVolumePercent: _volumePercent);
    _session = session;
    session.fixedVolume = volumeMode == 'fixed';
    if (volumePercent != null) _applyVolume(volumePercent);
    _emit(
      pb.Envelope()
        ..sessionOpenResult = (pb.SessionOpenResult()
          ..sessionId = sessionId
          ..accepted = true),
    );
    _emitSnapshot();
  }

  /// SessionClose from the server: stop playing, undo the volume policy, ack.
  void closeSession(String sessionId) {
    if (_session?.id != sessionId) return;
    _endSession();
    _emit(
      pb.Envelope()
        ..sessionClosed = (pb.SessionClosed()
          ..sessionId = sessionId
          ..reason = pb.SessionClosed_Reason.REASON_ACK),
    );
  }

  /// The session is over with nobody to tell: this connection was replaced by
  /// another instance, or the app moved to a different server.
  void abandonSession() {
    if (_session == null) return;
    _endSession();
  }

  void _endSession() {
    final session = _session!;
    _session = null;
    _queued.clear();
    _current = null;
    _backend.stop();
    _lastState = pb.PlaybackState.PLAYBACK_STATE_STOPPED;
    _applyVolume(session.savedVolumePercent);
  }

  // ---------------------------------------------------------------- commands

  void handleCommand(String sessionId, pb.Command command) {
    final session = _session;
    if (session == null || session.id != sessionId) {
      _emit(
        pb.Envelope()
          ..commandRejected = (pb.CommandRejected()
            ..sessionId = sessionId
            ..command = _controlKind(command)
            ..atUnixMs = _now()
            ..detail = 'not the session this renderer is running'),
      );
      return;
    }
    switch (command.whichOp()) {
      case pb.Command_Op.setSource:
        _queued.clear();
        _start(command.setSource.source);
      case pb.Command_Op.enqueueSource:
        final source = command.enqueueSource.source;
        _current == null ? _start(source) : _queued.add(source);
      case pb.Command_Op.removeSource:
        _remove(command.removeSource.sourceToken);
      case pb.Command_Op.clearQueue:
        _queued.clear();
        if (_current != null) {
          _current = null;
          _backend.stop();
          _emitState(pb.PlaybackState.PLAYBACK_STATE_FINISHED, null);
        }
      case pb.Command_Op.pause:
        if (_current != null) {
          _backend.pause();
          _emitState(
            pb.PlaybackState.PLAYBACK_STATE_PAUSED,
            _current!.sourceToken,
          );
        }
      case pb.Command_Op.resume:
        if (_current != null) {
          _backend.resume();
          _emitState(
            pb.PlaybackState.PLAYBACK_STATE_PLAYING,
            _current!.sourceToken,
          );
        }
      case pb.Command_Op.stop:
        _queued.clear();
        final hadCurrent = _current != null;
        _current = null;
        _backend.stop();
        if (hadCurrent) {
          _emitState(pb.PlaybackState.PLAYBACK_STATE_STOPPED, null);
        }
      case pb.Command_Op.setVolume:
        if (!session.fixedVolume) {
          _applyVolume(command.setVolume.percent.clamp(0, 100));
        }
        // Restated even when fixed, so the server never holds a level the
        // renderer refused.
        _emitVolume();
      case pb.Command_Op.requestSnapshot:
        _emitSnapshot();
      case pb.Command_Op.seek:
        if (_current != null) {
          final position = command.seek.positionMs.toInt();
          _backend.seek(position);
          // Re-buffering; PLAYING (or PAUSED) follows from the backend.
          _emitState(
            pb.PlaybackState.PLAYBACK_STATE_PREPARING,
            _current!.sourceToken,
            positionMs: position,
          );
        }
      case pb.Command_Op.notSet:
        break;
    }
  }

  void _remove(String token) {
    if (_current?.sourceToken == token) {
      _current = null;
      if (_queued.isNotEmpty) {
        _start(_queued.removeAt(0));
      } else {
        _backend.stop();
        _emitState(pb.PlaybackState.PLAYBACK_STATE_FINISHED, token);
      }
    } else {
      _queued.removeWhere((source) => source.sourceToken == token);
    }
  }

  void _start(pb.Source source) {
    final previous = _current?.sourceToken;
    _current = source;
    _backend.play(uri: source.uri, startOffsetMs: source.startOffsetMs.toInt());
    final changed = pb.SourceChanged()
      ..sourceToken = source.sourceToken
      ..atUnixMs = _now();
    if (previous != null) changed.previousSourceToken = previous;
    _emit(pb.Envelope()..sourceChanged = changed);
    _emitState(
      pb.PlaybackState.PLAYBACK_STATE_PREPARING,
      source.sourceToken,
      positionMs: source.startOffsetMs.toInt(),
    );
  }

  // ---------------------------------------------------------- backend events

  void _onBackendEvent(BackendEvent event) {
    final token = _current?.sourceToken;
    switch (event) {
      case BackendPlaying():
        if (token != null &&
            _lastState != pb.PlaybackState.PLAYBACK_STATE_PLAYING) {
          _emitState(pb.PlaybackState.PLAYBACK_STATE_PLAYING, token);
        }
      case BackendStalled():
        if (token != null &&
            _lastState == pb.PlaybackState.PLAYBACK_STATE_PLAYING) {
          _emitState(pb.PlaybackState.PLAYBACK_STATE_PREPARING, token);
        }
      case BackendPaused():
        if (token != null &&
            _lastState != pb.PlaybackState.PLAYBACK_STATE_PAUSED) {
          _emitState(pb.PlaybackState.PLAYBACK_STATE_PAUSED, token);
        }
      case BackendEnded():
        if (token == null) return;
        if (_queued.isNotEmpty) {
          _start(_queued.removeAt(0)); // reads _current as the previous source
        } else {
          _current = null;
          _emitState(pb.PlaybackState.PLAYBACK_STATE_FINISHED, token);
        }
      case BackendFailed(:final kind, :final message):
        _current = null;
        _backend.stop();
        final state = pb.PlaybackStateChanged()
          ..state = pb.PlaybackState.PLAYBACK_STATE_ERROR
          ..positionMs = Int64(_backend.positionMs)
          ..positionValid = false
          ..atUnixMs = _now()
          ..error = (pb.ErrorInfo()
            ..source = _errorSource(kind)
            ..message = message);
        if (token != null) state.sourceToken = token;
        _lastState = pb.PlaybackState.PLAYBACK_STATE_ERROR;
        _emit(pb.Envelope()..playbackStateChanged = state);
    }
  }

  // ----------------------------------------------------------------- output

  void _emitState(pb.PlaybackState state, String? token, {int? positionMs}) {
    _lastState = state;
    final message = pb.PlaybackStateChanged()
      ..state = state
      ..positionMs = Int64(positionMs ?? _backend.positionMs)
      ..positionValid =
          state == pb.PlaybackState.PLAYBACK_STATE_PLAYING ||
          state == pb.PlaybackState.PLAYBACK_STATE_PAUSED
      ..atUnixMs = _now();
    if (token != null) message.sourceToken = token;
    _emit(pb.Envelope()..playbackStateChanged = message);
  }

  void _emitVolume() {
    _emit(
      pb.Envelope()
        ..volumeChanged = (pb.VolumeChanged()
          ..volume = _volumeState()
          ..external = false),
    );
  }

  void _emitSnapshot() {
    final snapshot = pb.StateSnapshot()
      ..playbackState = _lastState
      ..positionMs = Int64(_backend.positionMs)
      ..positionValid =
          _lastState == pb.PlaybackState.PLAYBACK_STATE_PLAYING ||
          _lastState == pb.PlaybackState.PLAYBACK_STATE_PAUSED
      ..capturedAtUnixMs = _now()
      ..volume = _volumeState()
      ..queuedSourceTokens.addAll([for (final s in _queued) s.sourceToken]);
    final current = _current;
    if (current != null) snapshot.currentSource = current;
    _emit(pb.Envelope()..stateSnapshot = snapshot);
  }

  void _emit(pb.Envelope envelope) {
    if (_messages.isClosed) return;
    // Lifecycle replies and rejections carry their own session_id and may
    // outlive the session (the ack goes out after it ends). State is
    // addressed to the session; without one it has nowhere to go — dropped,
    // as it is when no connection is listening.
    final selfAddressed = switch (envelope.whichPayload()) {
      pb.Envelope_Payload.sessionOpenResult ||
      pb.Envelope_Payload.sessionClosed ||
      pb.Envelope_Payload.commandRejected => true,
      _ => false,
    };
    if (!selfAddressed) {
      final session = _session;
      if (session == null) return;
      envelope.sessionId = session.id;
    }
    _messages.add(envelope);
  }

  void _applyVolume(int percent) {
    _volumePercent = percent;
    _backend.setVolume(percent / 100);
  }

  pb.VolumeState _volumeState() => pb.VolumeState()
    ..supported = !(_session?.fixedVolume ?? false)
    ..current = _volumePercent
    ..max = 100
    ..backend = pb.VolumeBackend.VOLUME_BACKEND_SOFTWARE;

  static Int64 _now() => Int64(DateTime.now().millisecondsSinceEpoch);

  static pb.ErrorSource _errorSource(BackendErrorKind kind) => switch (kind) {
    BackendErrorKind.network => pb.ErrorSource.ERROR_SOURCE_HTTP_STREAM,
    BackendErrorKind.decode => pb.ErrorSource.ERROR_SOURCE_DECODER,
    BackendErrorKind.internal => pb.ErrorSource.ERROR_SOURCE_RENDERER_INTERNAL,
  };

  static pb.ControlKind _controlKind(pb.Command command) => switch (command
      .whichOp()) {
    pb.Command_Op.setSource => pb.ControlKind.CONTROL_KIND_SET_SOURCE,
    pb.Command_Op.enqueueSource => pb.ControlKind.CONTROL_KIND_ENQUEUE_SOURCE,
    pb.Command_Op.removeSource => pb.ControlKind.CONTROL_KIND_REMOVE_SOURCE,
    pb.Command_Op.clearQueue => pb.ControlKind.CONTROL_KIND_CLEAR_QUEUE,
    pb.Command_Op.resume => pb.ControlKind.CONTROL_KIND_RESUME,
    pb.Command_Op.pause => pb.ControlKind.CONTROL_KIND_PAUSE,
    pb.Command_Op.stop => pb.ControlKind.CONTROL_KIND_STOP,
    pb.Command_Op.setVolume => pb.ControlKind.CONTROL_KIND_SET_VOLUME,
    pb.Command_Op.requestSnapshot =>
      pb.ControlKind.CONTROL_KIND_REQUEST_SNAPSHOT,
    pb.Command_Op.seek => pb.ControlKind.CONTROL_KIND_SEEK,
    pb.Command_Op.notSet => pb.ControlKind.CONTROL_KIND_UNSPECIFIED,
  };
}
