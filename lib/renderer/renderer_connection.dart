/// One WebSocket's worth of renderer protocol: Hello/Welcome, envelope
/// framing and message ids, command routing into the engine, and the config
/// plane (this renderer has no settings yet, so it answers with an empty
/// schema — promptly, because the server's request times out in seconds).
///
/// The connection is disposable; RendererEngine carries playback and the
/// session across reconnects.
library;

import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:logger/logger.dart';

import '../generated/kalinka/renderer/v1/renderer.pb.dart' as pb;
import 'renderer_engine.dart';
import 'renderer_identity.dart';

final _logger = Logger();

const _protocolVersion = 1;

/// Nothing configurable yet; bumped when the schema grows a first field.
const _configVersion = '1';

class RendererConnection {
  final void Function(List<int> frame) _send;
  final RendererEngine _engine;
  late final StreamSubscription<dynamic> _incomingSub;
  late final StreamSubscription<pb.Envelope> _engineSub;

  int _outId = 0;
  String _serverId = '';
  bool _closed = false;

  RendererConnection({
    required Stream<dynamic> incoming,
    required this._send,
    required RendererEngine engine,
    required RendererIdentity identity,
  }) : _engine = engine {
    _engineSub = engine.messages.listen(_dispatch);
    _incomingSub = incoming.listen(
      _onFrame,
      onError: (Object e) => _logger.w('Renderer socket error: $e'),
      onDone: () => _closed = true,
    );
    _dispatch(
      pb.Envelope()
        ..hello = (pb.Hello()
          ..protocolVersions = (pb.ProtocolVersionRange()
            ..min = _protocolVersion
            ..max = _protocolVersion)
          ..rendererId = identity.rendererId
          ..instanceId = identity.instanceId
          ..friendlyName = identity.friendlyName
          ..softwareVersion = identity.softwareVersion
          ..kind = pb.RendererKind.RENDERER_KIND_WEB
          ..platform = (pb.Platform()..os = identity.os)
          ..activeSessionId = engine.activeSessionId
          ..sessionOwnerServerId = engine.sessionOwnerServerId),
    );
  }

  /// Parting Goodbye lets the server drop this renderer from its list right
  /// away instead of holding an offline entry; best effort, the socket may
  /// already be gone.
  void close() {
    try {
      _dispatch(
        pb.Envelope()
          ..goodbye = (pb.Goodbye()
            ..reason = pb.Goodbye_Reason.REASON_SHUTDOWN),
      );
    } catch (_) {}
    _closed = true;
    _incomingSub.cancel();
    _engineSub.cancel();
  }

  /// Stamp the per-connection message id and put [envelope] on the wire.
  void _dispatch(pb.Envelope envelope) {
    if (_closed) return;
    envelope.messageId = Int64(++_outId);
    _send(envelope.writeToBuffer());
  }

  void _onFrame(dynamic data) {
    if (data is! List<int>) return;
    final pb.Envelope envelope;
    try {
      envelope = pb.Envelope.fromBuffer(data);
    } catch (e) {
      _logger.w('Dropping unparseable renderer message: $e');
      return;
    }
    switch (envelope.whichPayload()) {
      case pb.Envelope_Payload.welcome:
        _serverId = envelope.welcome.serverId;
      case pb.Envelope_Payload.sessionOpen:
        final open = envelope.sessionOpen;
        _engine.openSession(
          sessionId: open.sessionId,
          ownerServerId: _serverId,
          volumeMode: open.volumeMode,
          volumePercent: open.hasVolumePercent() ? open.volumePercent : null,
        );
      case pb.Envelope_Payload.sessionClose:
        _engine.closeSession(envelope.sessionClose.sessionId);
      case pb.Envelope_Payload.command:
        _engine.handleCommand(envelope.sessionId, envelope.command);
      case pb.Envelope_Payload.configRequest:
        _dispatch(
          pb.Envelope()
            ..inReplyTo = envelope.messageId
            ..configSnapshot = (pb.ConfigSnapshot()
              ..configVersion = _configVersion),
        );
      case pb.Envelope_Payload.configUpdate:
        final result = pb.ConfigResult()..configVersion = _configVersion;
        for (final setting in envelope.configUpdate.settings) {
          result.outcomes.add(
            pb.ConfigResult_Outcome()
              ..path = setting.path
              ..applied = false
              ..error = 'unknown setting',
          );
        }
        _dispatch(
          pb.Envelope()
            ..inReplyTo = envelope.messageId
            ..configResult = result,
        );
      case pb.Envelope_Payload.goodbye:
        _closed = true;
        if (envelope.goodbye.reason == pb.Goodbye_Reason.REASON_REPLACED) {
          // Another instance (a second tab) took this renderer over; playing
          // on here would leave audio nobody controls.
          _engine.abandonSession();
        }
      default:
        break;
    }
  }
}
