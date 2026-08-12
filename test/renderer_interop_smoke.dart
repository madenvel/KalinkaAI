// Interop smoke against a live kalinka-server: real WebSocket, real protobuf.
// Not part of `flutter test` — run by hand when the wire matters:
//
//   make dev-run   (in the server repo)
//   dart run test/renderer_interop_smoke.dart [host:port]
//
// Registers via Hello, then polls GET /renderer/list until this renderer
// appears connected, proving envelope framing and the handshake against the
// Python side end to end.

// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:kalinka/renderer/renderer_backend.dart';
import 'package:kalinka/renderer/renderer_connection.dart';
import 'package:kalinka/renderer/renderer_engine.dart';
import 'package:kalinka/renderer/renderer_identity.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class SilentBackend implements RendererAudioBackend {
  final _events = StreamController<BackendEvent>.broadcast();
  @override
  Stream<BackendEvent> get events => _events.stream;
  @override
  int get positionMs => 0;
  @override
  bool get isPaused => false;
  @override
  void play({
    required String uri,
    required int startOffsetMs,
    required int generation,
  }) {}
  @override
  void pause() {}
  @override
  void resume() {}
  @override
  void stop() {}
  @override
  void seek(int positionMs) {}
  @override
  void setVolume(double fraction) {}
  @override
  void dispose() => _events.close();
}

Future<void> main(List<String> args) async {
  final endpoint = args.isEmpty ? '127.0.0.1:8000' : args.first;
  final rendererId = 'smoke-${DateTime.now().millisecondsSinceEpoch}';
  final engine = RendererEngine(SilentBackend());
  final channel = WebSocketChannel.connect(
    Uri.parse('ws://$endpoint/renderer/ws'),
  );
  await channel.ready;
  final connection = RendererConnection(
    incoming: channel.stream,
    send: channel.sink.add,
    engine: engine,
    identity: RendererIdentity(
      rendererId: rendererId,
      instanceId: newUuid(),
      friendlyName: 'Interop Smoke',
      softwareVersion: '0.0.0',
      os: 'web',
    ),
  );

  final http = HttpClient();
  var seen = false;
  for (var attempt = 0; attempt < 20 && !seen; attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final request = await http.getUrl(
      Uri.parse('http://$endpoint/renderer/list'),
    );
    final response = await request.close();
    final body = jsonDecode(await response.transform(utf8.decoder).join());
    for (final renderer in (body['renderers'] as List? ?? const [])) {
      if (renderer['renderer_id'] == rendererId) {
        print('registered: $renderer');
        seen = true;
      }
    }
  }

  connection.close();
  await channel.sink.close();
  engine.dispose();
  http.close();
  if (!seen) {
    print('FAILED: renderer never appeared in /renderer/list');
    exit(1);
  }
  print('OK');
}
