/// Hosts a renderer inside the app itself: on platforms with an audio
/// backend (web, for now) it registers with the connected server over
/// `/renderer/ws`, making this device an output the server can play through.
library;

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../renderer/renderer_connection.dart';
import '../renderer/renderer_engine.dart';
import '../renderer/renderer_identity.dart';
import '../renderer/renderer_platform.dart';
import 'connection_settings_provider.dart';
import 'renderer_provider.dart';
import 'websocket_provider.dart';

const String sharedPrefRendererId = 'Kalinka.rendererId';

/// Playback and the session live here, for the whole app run — a WebSocket
/// drop must not silence the music, so the engine outlives connections.
final rendererEngineProvider = Provider<RendererEngine?>((ref) {
  final backend = createRendererBackend();
  if (backend == null) return null;
  final engine = RendererEngine(backend);
  ref.onDispose(engine.dispose);
  // A session belongs to the server that opened it. Moving the app to a
  // different server would leave that playback running with nobody able to
  // stop it, so end it here; a drop of the same server keeps playing.
  ref.listen(connectionSettingsProvider, (previous, next) {
    if (previous != null &&
        (previous.host != next.host || previous.port != next.port)) {
      engine.abandonSession();
    }
  });
  return engine;
});

final rendererIdentityProvider = FutureProvider<RendererIdentity>((ref) async {
  final prefs = ref.watch(sharedPrefsProvider);
  var rendererId = prefs.getString(sharedPrefRendererId);
  if (rendererId == null) {
    rendererId = newUuid();
    await prefs.setString(sharedPrefRendererId, rendererId);
  }
  final info = await PackageInfo.fromPlatform();
  return RendererIdentity(
    rendererId: rendererId,
    instanceId: newUuid(),
    friendlyName: browserDescription() ?? 'Kalinka',
    softwareVersion: info.version,
    os: kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase(),
  );
});

final rendererWebSocketProvider = webSocketProvider('/renderer/ws');

/// One protocol connection per live socket; watch from the app root. Gated on
/// the server actually speaking `/renderer/*`, which rendererListProvider
/// already probes. Rebuilt by the shared retry epoch on reconnects; a page
/// unload or a server switch says Goodbye so the server drops the entry
/// instead of holding an offline row.
final rendererHostProvider = Provider<void>((ref) {
  final engine = ref.watch(rendererEngineProvider);
  if (engine == null) return;
  if (!ref.watch(rendererListProvider.select((s) => s.supported))) return;
  final identity = ref.watch(rendererIdentityProvider).value;
  if (identity == null) return;
  // Only a settled AsyncData holds a live socket; while loading or errored,
  // `value` would replay the previous — closed — channel.
  final channel = switch (ref.watch(rendererWebSocketProvider)) {
    AsyncData(:final value) => value,
    _ => null,
  };
  if (channel == null) return;

  final connection = RendererConnection(
    incoming: channel.stream,
    send: channel.sink.add,
    engine: engine,
    identity: identity,
  );
  final unregisterPageHide = onPageHide(connection.close);
  ref.onDispose(() {
    unregisterPageHide();
    connection.close();
  });
});
