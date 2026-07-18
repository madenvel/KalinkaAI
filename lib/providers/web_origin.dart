import 'web_origin_io.dart' if (dart.library.js_interop) 'web_origin_web.dart'
    as impl;

/// Host + port the web app was served from, or `null` on native platforms.
({String host, int port})? webServingOrigin() => impl.webServingOrigin();
