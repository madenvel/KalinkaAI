import 'renderer_backend.dart';
import 'renderer_platform_io.dart'
    if (dart.library.js_interop) 'renderer_platform_web.dart'
    as impl;

/// The audio backend this platform can host a renderer on, or null where
/// none is implemented yet (everywhere but web, for now).
RendererAudioBackend? createRendererBackend() => impl.createRendererBackend();

/// User-agent-derived renderer name, e.g. "Chrome on Linux"; null off web.
String? browserDescription() => impl.browserDescription();

/// Runs [handler] when the page is being unloaded (tab close, navigation);
/// returns the unregister. No-op off web.
void Function() onPageHide(void Function() handler) => impl.onPageHide(handler);
