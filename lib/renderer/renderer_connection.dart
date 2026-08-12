/// Renderer protocol handling for one WebSocket connection.
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

enum RendererDisconnectKind { retryable, terminal }

class RendererConnection {
  final void Function(List<int> frame) _send;
  final RendererEngine _engine;
  final void Function()? _onWelcomed;
  final void Function(RendererDisconnectKind kind)? _onDisconnected;
  late final StreamSubscription<dynamic> _incomingSub;
  late final StreamSubscription<RendererOutbound> _engineSub;

  int _outId = 0;
  String _serverId = '';
  bool _welcomed = false;
  bool _closed = false;
  bool _disconnectNotified = false;

  RendererConnection({
    required Stream<dynamic> incoming,
    required this._send,
    required RendererEngine engine,
    required RendererIdentity identity,
    this._onWelcomed,
    this._onDisconnected,
  }) : _engine = engine {
    _engineSub = engine.messages.listen(_dispatchOutbound);
    _incomingSub = incoming.listen(
      _onFrame,
      onError: (Object e) {
        _logger.w('Renderer socket error: $e');
        _finish(RendererDisconnectKind.retryable);
      },
      onDone: () => _finish(RendererDisconnectKind.retryable),
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
    if (_closed) return;
    if (_welcomed) {
      try {
        _dispatch(
          pb.Envelope()
            ..goodbye = (pb.Goodbye()
              ..reason = pb.Goodbye_Reason.REASON_SHUTDOWN),
        );
      } catch (_) {}
    }
    _finish(null);
  }

  /// Close a route without sending renderer-shutdown Goodbye.
  void disconnect() => _finish(null);

  void _finish(RendererDisconnectKind? kind) {
    if (_closed) return;
    _closed = true;
    _welcomed = false;
    _engine.detachConnection(this);
    _incomingSub.cancel();
    _engineSub.cancel();
    if (kind != null && !_disconnectNotified) {
      _disconnectNotified = true;
      _onDisconnected?.call(kind);
    }
  }

  void _dispatchOutbound(RendererOutbound outbound) {
    if (identical(outbound.connection, this)) _dispatch(outbound.envelope);
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
    final payload = envelope.whichPayload();
    if (!_welcomed &&
        payload != pb.Envelope_Payload.welcome &&
        payload != pb.Envelope_Payload.goodbye) {
      if (payload == pb.Envelope_Payload.sessionOpen) {
        _dispatch(
          pb.Envelope()
            ..sessionOpenResult = (pb.SessionOpenResult()
              ..sessionId = envelope.sessionOpen.sessionId
              ..accepted = false
              ..error = pb.SessionOpenResult_Error.ERROR_INTERNAL
              ..detail = 'session opened before the handshake completed'),
        );
      } else if (payload == pb.Envelope_Payload.command) {
        _engine.handleCommand(
          connection: this,
          requesterServerId: '',
          sessionId: envelope.sessionId,
          command: envelope.command,
        );
      }
      return;
    }
    switch (payload) {
      case pb.Envelope_Payload.welcome:
        if (_welcomed) {
          _logger.w('Ignoring a second Welcome on one renderer connection');
          return;
        }
        _welcomed = true;
        _serverId = envelope.welcome.serverId;
        _engine.attachConnection(this, _serverId);
        _onWelcomed?.call();
      case pb.Envelope_Payload.sessionOpen:
        final open = envelope.sessionOpen;
        _engine.openSession(
          connection: this,
          sessionId: open.sessionId,
          ownerServerId: _serverId,
          volumeMode: open.volumeMode,
          volumePercent: open.hasVolumePercent() ? open.volumePercent : null,
          volumeControlDelegated: open.volumeControlDelegated,
        );
      case pb.Envelope_Payload.sessionClose:
        _engine.closeSession(
          envelope.sessionClose.sessionId,
          connection: this,
          requesterServerId: _serverId,
        );
      case pb.Envelope_Payload.command:
        _engine.handleCommand(
          connection: this,
          requesterServerId: _serverId,
          sessionId: envelope.sessionId,
          command: envelope.command,
        );
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
        final reason = envelope.goodbye.reason;
        if (reason == pb.Goodbye_Reason.REASON_REPLACED) {
          // Another instance (a second tab) took this renderer over; playing
          // on here would leave audio nobody controls.
          _engine.abandonSession();
        }
        final terminal =
            reason == pb.Goodbye_Reason.REASON_VERSION_UNSUPPORTED ||
            reason == pb.Goodbye_Reason.REASON_REPLACED ||
            reason == pb.Goodbye_Reason.REASON_REJECTED;
        _finish(
          terminal
              ? RendererDisconnectKind.terminal
              : RendererDisconnectKind.retryable,
        );
      default:
        break;
    }
  }
}
