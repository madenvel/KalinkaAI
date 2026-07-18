import 'package:web_socket_channel/web_socket_channel.dart';

import 'ws_connect_io.dart' if (dart.library.js_interop) 'ws_connect_web.dart'
    as impl;

/// Opens a [WebSocketChannel] to [uri]. Native applies the [pingInterval]
/// heartbeat via `dart:io`; on web the browser owns it. The connect is bounded
/// by the caller (`channel.ready.timeout`).
WebSocketChannel connectWs(Uri uri, {required Duration pingInterval}) =>
    impl.connectWs(uri, pingInterval: pingInterval);
