import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'html_audio_backend.dart';
import 'renderer_backend.dart';

RendererAudioBackend? createRendererBackend() => HtmlAudioBackend();

/// "Chrome on Linux" — the browser is the machine's face here; it cannot see
/// a hostname, and the user agent is the only identity it has.
String? browserDescription() {
  final ua = web.window.navigator.userAgent;
  final browser = switch (ua) {
    _ when ua.contains('Edg/') => 'Edge',
    _ when ua.contains('OPR/') => 'Opera',
    _ when ua.contains('Firefox/') => 'Firefox',
    _ when ua.contains('Chrome/') => 'Chrome',
    _ when ua.contains('Safari/') => 'Safari',
    _ => 'Browser',
  };
  final os = switch (ua) {
    _ when ua.contains('iPhone') || ua.contains('iPad') => 'iOS',
    _ when ua.contains('Android') => 'Android',
    _ when ua.contains('CrOS') => 'ChromeOS',
    _ when ua.contains('Windows') => 'Windows',
    _ when ua.contains('Mac OS X') => 'macOS',
    _ when ua.contains('Linux') => 'Linux',
    _ => '',
  };
  return os.isEmpty ? browser : '$browser on $os';
}

void Function() onPageHide(void Function() handler) {
  final js = ((web.Event _) => handler()).toJS;
  web.window.addEventListener('pagehide', js);
  return () => web.window.removeEventListener('pagehide', js);
}
