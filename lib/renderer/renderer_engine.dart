/// Session, queue, and state machine for the app-hosted renderer.
///
/// Outlives WebSocket connections so a session can survive reconnects.
library;

import 'dart:async';

import 'package:fixnum/fixnum.dart';

import '../generated/kalinka/renderer/v1/renderer.pb.dart' as pb;
import 'renderer_backend.dart';

class _Session {
  final String id;
  final String ownerServerId;
  final int? volumeToRestore;

  _Session(this.id, this.ownerServerId, {this.volumeToRestore});

  bool get forceFixedOutput => volumeToRestore != null;
}

/// An envelope addressed to one connection.
class RendererOutbound {
  final Object connection;
  final pb.Envelope envelope;

  const RendererOutbound(this.connection, this.envelope);
}

class RendererEngine {
  final RendererAudioBackend _backend;

  /// How long a session survives without a route to its owner.
  final Duration ownerGrace;

  late final StreamSubscription<BackendEvent> _backendSub;
  // Sync: a reply must hit the wire in the order the protocol promises
  // (SessionOpenResult before the snapshot), not a microtask later.
  final _messages = StreamController<RendererOutbound>.broadcast(sync: true);

  _Session? _session;
  // Owner routes, oldest to newest.
  final List<Object> _attached = [];
  Timer? _graceTimer;
  pb.Source? _current;
  final List<pb.Source> _queued = [];
  pb.PlaybackState _lastState = pb.PlaybackState.PLAYBACK_STATE_STOPPED;
  pb.AudioFormat? _format;
  pb.ErrorInfo? _lastError;
  int _nextGeneration = 0;
  int? _activeGeneration;
  int _volumePercent = 100;

  RendererEngine(
    this._backend, {
    this.ownerGrace = const Duration(seconds: 60),
  }) {
    _backendSub = _backend.events.listen(_onBackendEvent);
  }

  /// Targeted protocol messages without a per-connection message_id.
  Stream<RendererOutbound> get messages => _messages.stream;

  /// For Hello: the session this renderer is running, if any.
  String get activeSessionId => _session?.id ?? '';
  String get sessionOwnerServerId => _session?.ownerServerId ?? '';

  void dispose() {
    _graceTimer?.cancel();
    _backendSub.cancel();
    _backend.dispose();
    _messages.close();
  }

  // ---------------------------------------------------------------- sessions

  /// Reattach a welcomed connection if it belongs to the session owner.
  void attachConnection(Object connection, String serverId) {
    final session = _session;
    if (session == null ||
        serverId.isEmpty ||
        session.ownerServerId != serverId) {
      return;
    }
    _attached.remove(connection);
    _attached.add(connection);
    _graceTimer?.cancel();
    _graceTimer = null;
    _emitSnapshot(target: connection);
  }

  /// Start the grace period when the last owner route disconnects.
  void detachConnection(Object connection) {
    if (!_attached.remove(connection)) return;
    if (_session == null || _attached.isNotEmpty) return;
    _graceTimer?.cancel();
    _graceTimer = Timer(ownerGrace, () {
      _graceTimer = null;
      if (_session != null && _attached.isEmpty) _endSession();
    });
  }

  void openSession({
    required Object connection,
    required String sessionId,
    required String ownerServerId,
    bool forceFixedOutput = false,
  }) {
    final existing = _session;
    // A repeated open is idempotent only for the owner.
    if (existing != null &&
        (existing.id != sessionId || existing.ownerServerId != ownerServerId)) {
      _emitTo(
        connection,
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

    if (existing != null) {
      _attached.remove(connection);
      _attached.add(connection);
      _graceTimer?.cancel();
      _graceTimer = null;
      _emitTo(
        connection,
        pb.Envelope()
          ..sessionOpenResult = (pb.SessionOpenResult()
            ..sessionId = sessionId
            ..accepted = true),
      );
      _emitSnapshot(target: connection);
      return;
    }

    final session = _Session(
      sessionId,
      ownerServerId,
      volumeToRestore: forceFixedOutput ? _volumePercent : null,
    );
    if (forceFixedOutput) _applyVolume(100);

    _session = session;
    _attached.add(connection);
    _emitTo(
      connection,
      pb.Envelope()
        ..sessionOpenResult = (pb.SessionOpenResult()
          ..sessionId = sessionId
          ..accepted = true),
    );
    _emitSnapshot(target: connection);
  }

  /// Close only from a connection attached to the session owner.
  void closeSession(
    String sessionId, {
    required Object connection,
    required String requesterServerId,
  }) {
    final session = _session;
    if (session == null ||
        session.id != sessionId ||
        session.ownerServerId != requesterServerId ||
        !_attached.contains(connection)) {
      return;
    }
    _endSession();
    _emitTo(
      connection,
      pb.Envelope()
        ..sessionClosed = (pb.SessionClosed()
          ..sessionId = sessionId
          ..reason = pb.SessionClosed_Reason.REASON_ACK),
    );
  }

  void abandonSession() {
    if (_session == null) return;
    _endSession();
  }

  void _endSession() {
    final volumeToRestore = _session?.volumeToRestore;
    _session = null;
    _graceTimer?.cancel();
    _graceTimer = null;
    _attached.clear();
    _queued.clear();
    _current = null;
    _activeGeneration = null;
    _format = null;
    _lastError = null;
    _backend.stop();
    if (volumeToRestore != null) _applyVolume(volumeToRestore);
    _lastState = pb.PlaybackState.PLAYBACK_STATE_STOPPED;
  }

  // ---------------------------------------------------------------- commands

  void handleCommand({
    required Object connection,
    required String requesterServerId,
    required String sessionId,
    required pb.Command command,
  }) {
    final session = _session;
    if (session == null ||
        session.id != sessionId ||
        session.ownerServerId != requesterServerId ||
        !_attached.contains(connection)) {
      _emitTo(
        connection,
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
          _activeGeneration = null;
          _format = null;
          _lastError = null;
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
        _activeGeneration = null;
        _format = null;
        _lastError = null;
        _backend.stop();
        if (hadCurrent) {
          _emitState(pb.PlaybackState.PLAYBACK_STATE_STOPPED, null);
        }
      case pb.Command_Op.setVolume:
        if (!session.forceFixedOutput) {
          _applyVolume(command.setVolume.percent.clamp(0, 100));
        }
        // Restated even when fixed, so the server never holds a level the
        // renderer refused.
        _emitVolume();
      case pb.Command_Op.requestSnapshot:
        _emitSnapshot(target: connection);
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
        _start(_queued.removeAt(0), previousToken: token);
      } else {
        _activeGeneration = null;
        _format = null;
        _lastError = null;
        _backend.stop();
        _emitState(pb.PlaybackState.PLAYBACK_STATE_FINISHED, token);
      }
    } else {
      _queued.removeWhere((source) => source.sourceToken == token);
    }
  }

  void _start(pb.Source source, {String? previousToken}) {
    final previous = previousToken ?? _current?.sourceToken;
    _current = source;
    _format = null;
    _lastError = null;
    final generation = ++_nextGeneration;
    _activeGeneration = generation;
    _backend.play(
      uri: source.uri,
      startOffsetMs: source.startOffsetMs.toInt(),
      generation: generation,
    );
    final changed = pb.SourceChanged()
      ..sourceToken = source.sourceToken
      ..atUnixMs = _now();
    if (previous != null) changed.previousSourceToken = previous;
    _emitSession(pb.Envelope()..sourceChanged = changed);
    _emitState(
      pb.PlaybackState.PLAYBACK_STATE_PREPARING,
      source.sourceToken,
      positionMs: source.startOffsetMs.toInt(),
    );
  }

  // ---------------------------------------------------------- backend events

  void _onBackendEvent(BackendEvent event) {
    if (event.generation != _activeGeneration) return;
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
      case BackendAudioFormat(
        :final sampleRateHz,
        :final channels,
        :final bitsPerSample,
        :final sampleFormat,
        :final durationMs,
      ):
        if (token == null || sampleRateHz <= 0 || durationMs < 0) return;
        final format = pb.AudioFormat()
          ..sampleRateHz = sampleRateHz
          ..channels = channels
          ..bitsPerSample = bitsPerSample
          ..sampleFormat = sampleFormat
          ..durationMs = Int64(durationMs);
        _format = format;
        // No message of its own any more, so restate the state it belongs to.
        // Never an error state: replaying one would restate the failure.
        if (_lastState != pb.PlaybackState.PLAYBACK_STATE_UNSPECIFIED &&
            _lastState != pb.PlaybackState.PLAYBACK_STATE_ERROR) {
          _emitState(_lastState, token);
        }
      case BackendEnded():
        if (token == null) return;
        if (_queued.isNotEmpty) {
          _start(_queued.removeAt(0), previousToken: token);
        } else {
          _current = null;
          _activeGeneration = null;
          _emitState(pb.PlaybackState.PLAYBACK_STATE_FINISHED, token);
        }
      case BackendFailed(:final kind, :final message):
        final positionMs = _backend.positionMs;
        _current = null;
        _activeGeneration = null;
        _backend.stop();
        final error = pb.ErrorInfo()
          ..source = _errorSource(kind)
          ..message = message;
        if (token != null) error.sourceToken = token;
        final state = pb.PlaybackStateChanged()
          ..state = pb.PlaybackState.PLAYBACK_STATE_ERROR
          ..positionMs = Int64(positionMs)
          ..positionValid = false
          ..atUnixMs = _now()
          ..error = error;
        if (token != null) state.sourceToken = token;
        _lastState = pb.PlaybackState.PLAYBACK_STATE_ERROR;
        _lastError = error;
        _emitSession(pb.Envelope()..playbackStateChanged = state);
    }
  }

  // ----------------------------------------------------------------- output

  void _emitState(pb.PlaybackState state, String? token, {int? positionMs}) {
    _lastState = state;
    _lastError = null;
    final message = pb.PlaybackStateChanged()
      ..state = state
      ..positionMs = Int64(positionMs ?? _backend.positionMs)
      ..positionValid =
          state == pb.PlaybackState.PLAYBACK_STATE_PLAYING ||
          state == pb.PlaybackState.PLAYBACK_STATE_PAUSED
      ..atUnixMs = _now();
    if (token != null) message.sourceToken = token;
    final format = _format;
    if (format != null) message.format = format;
    _emitSession(pb.Envelope()..playbackStateChanged = message);
  }

  void _emitVolume() {
    _emitSession(
      pb.Envelope()
        ..volumeChanged = (pb.VolumeChanged()
          ..volume = _volumeState()
          ..external = false),
    );
  }

  void _emitSnapshot({Object? target}) {
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
    final format = _format;
    if (format != null) snapshot.format = format;
    final error = _lastError;
    if (error != null) snapshot.error = error;
    _emitSession(pb.Envelope()..stateSnapshot = snapshot, target: target);
  }

  void _emitSession(pb.Envelope envelope, {Object? target}) {
    final session = _session;
    if (session == null) return;
    envelope.sessionId = session.id;
    target ??= _attached.isEmpty ? null : _attached.last;
    _emitTo(target, envelope);
  }

  void _emitTo(Object? target, pb.Envelope envelope) {
    if (target == null || _messages.isClosed) return;
    _messages.add(RendererOutbound(target, envelope));
  }

  void _applyVolume(int percent) {
    _volumePercent = percent;
    _backend.setVolume(percent / 100);
  }

  pb.VolumeState _volumeState() => pb.VolumeState()
    ..supported = !(_session?.forceFixedOutput ?? false)
    ..current = _volumePercent
    ..max = 100
    ..backend = (_session?.forceFixedOutput ?? false)
        ? pb.VolumeBackend.VOLUME_BACKEND_NONE
        : pb.VolumeBackend.VOLUME_BACKEND_SOFTWARE;

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
