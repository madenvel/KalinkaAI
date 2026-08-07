// The app-hosted renderer against the wire protocol, mirroring the semantics
// of the server repo's tests/sim_renderer.py: who advances the queue, FINISHED
// vs STOPPED, which states carry a valid position, session-scoped volume.

import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalinka/generated/kalinka/renderer/v1/renderer.pb.dart' as pb;
import 'package:kalinka/renderer/renderer_backend.dart';
import 'package:kalinka/renderer/renderer_connection.dart';
import 'package:kalinka/renderer/renderer_engine.dart';
import 'package:kalinka/renderer/renderer_identity.dart';

class FakeBackend implements RendererAudioBackend {
  final _events = StreamController<BackendEvent>.broadcast(sync: true);
  final calls = <String>[];

  @override
  int positionMs = 0;

  @override
  bool isPaused = false;

  String? uri;
  double? volume;

  @override
  Stream<BackendEvent> get events => _events.stream;

  @override
  void play({required String uri, required int startOffsetMs}) {
    this.uri = uri;
    isPaused = false;
    calls.add('play $uri@$startOffsetMs');
  }

  @override
  void pause() {
    isPaused = true;
    calls.add('pause');
  }

  @override
  void resume() {
    isPaused = false;
    calls.add('resume');
  }

  @override
  void stop() {
    uri = null;
    calls.add('stop');
  }

  @override
  void seek(int positionMs) => calls.add('seek $positionMs');

  @override
  void setVolume(double fraction) {
    volume = fraction;
    calls.add('volume $fraction');
  }

  @override
  void dispose() => _events.close();

  void emit(BackendEvent event) => _events.add(event);
}

const identity = RendererIdentity(
  rendererId: 'r-1',
  instanceId: 'i-1',
  friendlyName: 'Chrome on Linux',
  softwareVersion: '1.2.3',
  os: 'web',
);

/// Engine + one connection over in-memory sync streams: everything a test
/// injects or asserts happens in the same event-loop turn.
class Harness {
  final backend = FakeBackend();
  late final engine = RendererEngine(backend);
  final sent = <pb.Envelope>[];
  final _incoming = StreamController<dynamic>(sync: true);
  late final RendererConnection connection;
  int _inId = 0;

  Harness() {
    connection = RendererConnection(
      incoming: _incoming.stream,
      send: (frame) => sent.add(pb.Envelope.fromBuffer(frame)),
      engine: engine,
      identity: identity,
    );
  }

  void deliver(pb.Envelope envelope) {
    envelope.messageId = Int64(++_inId);
    _incoming.add(envelope.writeToBuffer());
  }

  void welcome({String serverId = 'core-1'}) =>
      deliver(pb.Envelope()..welcome = (pb.Welcome()..serverId = serverId));

  void openSession(
    String sessionId, {
    String volumeMode = '',
    int? volumePercent,
  }) {
    final open = pb.SessionOpen()
      ..sessionId = sessionId
      ..volumeMode = volumeMode;
    if (volumePercent != null) open.volumePercent = volumePercent;
    deliver(pb.Envelope()..sessionOpen = open);
  }

  void command(pb.Command op, {String sessionId = 's1'}) => deliver(
    pb.Envelope()
      ..sessionId = sessionId
      ..command = op,
  );

  void setSource(
    String token, {
    String uri = 'http://media/a',
    int offset = 0,
  }) => command(
    pb.Command()
      ..setSource = (pb.SetSource()..source = _source(token, uri, offset)),
  );

  void enqueue(String token, {String uri = 'http://media/b'}) => command(
    pb.Command()
      ..enqueueSource = (pb.EnqueueSource()..source = _source(token, uri, 0)),
  );

  static pb.Source _source(String token, String uri, int offset) => pb.Source()
    ..uri = uri
    ..mimeType = 'audio/flac'
    ..sourceToken = token
    ..startOffsetMs = Int64(offset);

  /// Sent envelopes after the handshake Hello.
  List<pb.Envelope> get replies => sent.sublist(1);

  pb.Envelope get last => sent.last;

  /// Starts a session with a source already playing — the common fixture.
  void playing(String token) {
    welcome();
    openSession('s1');
    setSource(token);
    backend.emit(const BackendPlaying());
    sent.clear();
    backend.calls.clear();
  }
}

void main() {
  test('hello leads, carries identity and protocol version 1', () {
    final h = Harness();
    final hello = h.sent.first.hello;
    expect(h.sent.first.messageId.toInt(), 1);
    expect(hello.protocolVersions.min, 1);
    expect(hello.protocolVersions.max, 1);
    expect(hello.rendererId, 'r-1');
    expect(hello.instanceId, 'i-1');
    expect(hello.friendlyName, 'Chrome on Linux');
    expect(hello.kind, pb.RendererKind.RENDERER_KIND_WEB);
    expect(hello.platform.os, 'web');
    expect(hello.activeSessionId, isEmpty);
  });

  test('message ids are monotonic per connection', () {
    final h = Harness();
    h.welcome();
    h.openSession('s1');
    expect(
      [for (final e in h.sent) e.messageId.toInt()],
      [for (var i = 1; i <= h.sent.length; i++) i],
    );
  });

  test('session open is accepted, then the snapshot follows', () {
    final h = Harness();
    h.welcome();
    h.openSession('s1');
    final result = h.replies[0];
    expect(result.sessionOpenResult.sessionId, 's1');
    expect(result.sessionOpenResult.accepted, isTrue);
    // Lifecycle replies carry their own session_id, not the envelope's.
    expect(result.sessionId, isEmpty);
    final snapshot = h.replies[1];
    expect(snapshot.sessionId, 's1');
    expect(
      snapshot.stateSnapshot.playbackState,
      pb.PlaybackState.PLAYBACK_STATE_STOPPED,
    );
    expect(snapshot.stateSnapshot.positionValid, isFalse);
    expect(snapshot.stateSnapshot.volume.current, 100);
    expect(
      snapshot.stateSnapshot.volume.backend,
      pb.VolumeBackend.VOLUME_BACKEND_SOFTWARE,
    );
  });

  test('a second session is refused busy, naming the owner', () {
    final h = Harness();
    h.welcome(serverId: 'core-1');
    h.openSession('s1');
    h.openSession('s2');
    final result = h.last.sessionOpenResult;
    expect(result.sessionId, 's2');
    expect(result.accepted, isFalse);
    expect(result.error, pb.SessionOpenResult_Error.ERROR_BUSY);
    expect(result.ownerServerId, 'core-1');
    expect(h.engine.activeSessionId, 's1');
  });

  test('set_source starts playback and reports the start sequence', () {
    final h = Harness();
    h.welcome();
    h.openSession('s1');
    h.sent.clear();
    h.setSource('t1', uri: 'http://media/a', offset: 1500);
    expect(h.backend.calls, ['play http://media/a@1500']);
    expect(h.sent[0].sourceChanged.sourceToken, 't1');
    expect(h.sent[0].sourceChanged.hasPreviousSourceToken(), isFalse);
    final preparing = h.sent[1].playbackStateChanged;
    expect(preparing.state, pb.PlaybackState.PLAYBACK_STATE_PREPARING);
    expect(preparing.positionMs.toInt(), 1500);
    expect(preparing.positionValid, isFalse);

    h.backend.positionMs = 1500;
    h.backend.emit(const BackendPlaying());
    final playing = h.last.playbackStateChanged;
    expect(playing.state, pb.PlaybackState.PLAYBACK_STATE_PLAYING);
    expect(playing.positionValid, isTrue);
    expect(playing.sourceToken, 't1');
  });

  test('set_source displaces the current source and the queue', () {
    final h = Harness()..playing('t1');
    h.enqueue('t2');
    h.setSource('t3', uri: 'http://media/c');
    expect(h.backend.uri, 'http://media/c');
    expect(h.sent.first.sourceChanged.previousSourceToken, 't1');
    // t2 is gone: when t3 ends, playback finishes.
    h.sent.clear();
    h.backend.emit(const BackendEnded());
    expect(
      h.last.playbackStateChanged.state,
      pb.PlaybackState.PLAYBACK_STATE_FINISHED,
    );
  });

  test('enqueue onto an idle session starts it', () {
    final h = Harness();
    h.welcome();
    h.openSession('s1');
    h.sent.clear();
    h.enqueue('t1');
    expect(h.backend.calls, ['play http://media/b@0']);
    expect(h.sent.first.sourceChanged.sourceToken, 't1');
  });

  test('the queue advances itself when a source ends', () {
    final h = Harness()..playing('t1');
    h.enqueue('t2');
    expect(h.sent, isEmpty); // queued silently, behind the current source
    h.backend.emit(const BackendEnded());
    final changed = h.sent.first.sourceChanged;
    expect(changed.sourceToken, 't2');
    expect(changed.previousSourceToken, 't1');
    h.backend.emit(const BackendPlaying());

    h.sent.clear();
    h.backend.emit(const BackendEnded());
    final finished = h.last.playbackStateChanged;
    expect(finished.state, pb.PlaybackState.PLAYBACK_STATE_FINISHED);
    expect(finished.sourceToken, 't2');
    expect(finished.positionValid, isFalse);
  });

  test('removing the current source hands over to the next', () {
    final h = Harness()..playing('t1');
    h.enqueue('t2');
    h.command(
      pb.Command()..removeSource = (pb.RemoveSource()..sourceToken = 't1'),
    );
    expect(h.sent.first.sourceChanged.sourceToken, 't2');

    h.sent.clear();
    h.command(
      pb.Command()..removeSource = (pb.RemoveSource()..sourceToken = 't2'),
    );
    expect(h.backend.calls, contains('stop'));
    final finished = h.last.playbackStateChanged;
    expect(finished.state, pb.PlaybackState.PLAYBACK_STATE_FINISHED);
    expect(finished.sourceToken, 't2');
  });

  test('removing a queued source is silent', () {
    final h = Harness()..playing('t1');
    h.enqueue('t2');
    h.command(
      pb.Command()..removeSource = (pb.RemoveSource()..sourceToken = 't2'),
    );
    expect(h.sent, isEmpty);
    h.backend.emit(const BackendEnded());
    expect(
      h.last.playbackStateChanged.state,
      pb.PlaybackState.PLAYBACK_STATE_FINISHED,
    );
  });

  test('clear_queue finishes without naming a source', () {
    final h = Harness()..playing('t1');
    h.command(pb.Command()..clearQueue = pb.ClearQueue());
    expect(h.backend.calls, contains('stop'));
    final state = h.last.playbackStateChanged;
    expect(state.state, pb.PlaybackState.PLAYBACK_STATE_FINISHED);
    expect(state.hasSourceToken(), isFalse);
  });

  test('stop closes the device and reports stopped without a source', () {
    final h = Harness()..playing('t1');
    h.command(pb.Command()..stop = pb.Stop());
    expect(h.backend.calls, contains('stop'));
    final state = h.last.playbackStateChanged;
    expect(state.state, pb.PlaybackState.PLAYBACK_STATE_STOPPED);
    expect(state.hasSourceToken(), isFalse);
  });

  test('pause and resume report with valid positions', () {
    final h = Harness()..playing('t1');
    h.backend.positionMs = 42000;
    h.command(pb.Command()..pause = pb.Pause());
    final paused = h.last.playbackStateChanged;
    expect(paused.state, pb.PlaybackState.PLAYBACK_STATE_PAUSED);
    expect(paused.positionMs.toInt(), 42000);
    expect(paused.positionValid, isTrue);

    h.command(pb.Command()..resume = pb.Resume());
    expect(
      h.last.playbackStateChanged.state,
      pb.PlaybackState.PLAYBACK_STATE_PLAYING,
    );
  });

  test('seek re-buffers at the target position', () {
    final h = Harness()..playing('t1');
    h.command(pb.Command()..seek = (pb.Seek()..positionMs = Int64(5000)));
    expect(h.backend.calls, contains('seek 5000'));
    final preparing = h.last.playbackStateChanged;
    expect(preparing.state, pb.PlaybackState.PLAYBACK_STATE_PREPARING);
    expect(preparing.positionMs.toInt(), 5000);
    h.backend.positionMs = 5000;
    h.backend.emit(const BackendPlaying());
    expect(
      h.last.playbackStateChanged.state,
      pb.PlaybackState.PLAYBACK_STATE_PLAYING,
    );
  });

  test('a seek that settles on a paused element reports paused', () {
    final h = Harness()..playing('t1');
    h.command(pb.Command()..pause = pb.Pause());
    h.command(pb.Command()..seek = (pb.Seek()..positionMs = Int64(5000)));
    h.backend.emit(const BackendPaused());
    expect(
      h.last.playbackStateChanged.state,
      pb.PlaybackState.PLAYBACK_STATE_PAUSED,
    );
  });

  test('a stall while playing reports preparing, recovery playing', () {
    final h = Harness()..playing('t1');
    h.backend.emit(const BackendStalled());
    expect(
      h.last.playbackStateChanged.state,
      pb.PlaybackState.PLAYBACK_STATE_PREPARING,
    );
    h.backend.emit(const BackendPlaying());
    expect(
      h.last.playbackStateChanged.state,
      pb.PlaybackState.PLAYBACK_STATE_PLAYING,
    );
  });

  test('set_volume applies software gain and reports it', () {
    final h = Harness()..playing('t1');
    h.command(pb.Command()..setVolume = (pb.SetVolume()..percent = 30));
    expect(h.backend.volume, 0.3);
    final volume = h.last.volumeChanged.volume;
    expect(volume.current, 30);
    expect(volume.supported, isTrue);
    expect(volume.max, 100);
  });

  test('a fixed-volume session pins the level for its lifetime', () {
    final h = Harness();
    h.welcome();
    h.openSession('s1', volumeMode: 'fixed', volumePercent: 55);
    expect(h.backend.volume, 0.55);
    expect(h.last.stateSnapshot.volume.supported, isFalse);

    h.command(pb.Command()..setVolume = (pb.SetVolume()..percent = 80));
    expect(h.backend.volume, 0.55);
    expect(h.last.volumeChanged.volume.current, 55);

    // Undone when the session ends: the next user gets the old level back.
    h.deliver(
      pb.Envelope()..sessionClose = (pb.SessionClose()..sessionId = 's1'),
    );
    expect(h.backend.volume, 1.0);
  });

  test('session close stops playback and acks', () {
    final h = Harness()..playing('t1');
    h.deliver(
      pb.Envelope()..sessionClose = (pb.SessionClose()..sessionId = 's1'),
    );
    expect(h.backend.calls, contains('stop'));
    final closed = h.last.sessionClosed;
    expect(closed.sessionId, 's1');
    expect(closed.reason, pb.SessionClosed_Reason.REASON_ACK);
    expect(h.engine.activeSessionId, isEmpty);
  });

  test('a command naming another session is rejected untouched', () {
    final h = Harness()..playing('t1');
    h.command(pb.Command()..pause = pb.Pause(), sessionId: 'stale');
    expect(h.backend.calls, isEmpty);
    final rejected = h.last.commandRejected;
    expect(rejected.sessionId, 'stale');
    expect(rejected.command, pb.ControlKind.CONTROL_KIND_PAUSE);
  });

  test('a broken stream reports an error naming the source', () {
    final h = Harness()..playing('t1');
    h.backend.emit(const BackendFailed(BackendErrorKind.network, 'http error'));
    final state = h.last.playbackStateChanged;
    expect(state.state, pb.PlaybackState.PLAYBACK_STATE_ERROR);
    expect(state.sourceToken, 't1');
    expect(state.positionValid, isFalse);
    expect(state.error.source, pb.ErrorSource.ERROR_SOURCE_HTTP_STREAM);
    expect(state.error.message, 'http error');
  });

  test('an autoplay refusal surfaces as a renderer-internal error', () {
    final h = Harness()..playing('t1');
    h.backend.emit(
      const BackendFailed(BackendErrorKind.internal, 'playback refused'),
    );
    expect(
      h.last.playbackStateChanged.error.source,
      pb.ErrorSource.ERROR_SOURCE_RENDERER_INTERNAL,
    );
  });

  test('request_snapshot describes source, queue and position', () {
    final h = Harness()..playing('t1');
    h.enqueue('t2');
    h.enqueue('t3');
    h.backend.positionMs = 9000;
    h.command(pb.Command()..requestSnapshot = pb.RequestSnapshot());
    final snapshot = h.last.stateSnapshot;
    expect(snapshot.playbackState, pb.PlaybackState.PLAYBACK_STATE_PLAYING);
    expect(snapshot.currentSource.sourceToken, 't1');
    expect(snapshot.positionMs.toInt(), 9000);
    expect(snapshot.positionValid, isTrue);
    expect(snapshot.queuedSourceTokens, ['t2', 't3']);
  });

  test('config plane answers promptly with an empty schema', () {
    final h = Harness();
    h.welcome();
    h.deliver(pb.Envelope()..configRequest = pb.ConfigRequest());
    expect(h.last.inReplyTo.toInt(), 2);
    expect(h.last.configSnapshot.sections, isEmpty);

    h.deliver(
      pb.Envelope()
        ..configUpdate = (pb.ConfigUpdate()
          ..settings.add(
            pb.ConfigUpdate_Setting()
              ..path = 'output.device'
              ..value = 'x',
          )),
    );
    expect(h.last.inReplyTo.toInt(), 3);
    final outcome = h.last.configResult.outcomes.single;
    expect(outcome.applied, isFalse);
    expect(outcome.path, 'output.device');
  });

  test('goodbye replaced stops playback: another tab took over', () {
    final h = Harness()..playing('t1');
    h.deliver(
      pb.Envelope()
        ..goodbye = (pb.Goodbye()..reason = pb.Goodbye_Reason.REASON_REPLACED),
    );
    expect(h.backend.calls, contains('stop'));
    expect(h.engine.activeSessionId, isEmpty);
  });

  test('a reconnect hello reports the running session for reconciliation', () {
    final h = Harness()..playing('t1');
    // The first socket dies; playback carries on. A fresh connection on the
    // same engine must tell the server what it is still running.
    final sent = <pb.Envelope>[];
    RendererConnection(
      incoming: const Stream<dynamic>.empty(),
      send: (frame) => sent.add(pb.Envelope.fromBuffer(frame)),
      engine: h.engine,
      identity: identity,
    );
    final hello = sent.single.hello;
    expect(hello.activeSessionId, 's1');
    expect(hello.sessionOwnerServerId, 'core-1');
  });
}
