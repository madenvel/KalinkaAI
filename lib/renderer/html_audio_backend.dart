/// RendererAudioBackend over a single HTMLAudioElement — the no-gapless first
/// step. The element streams and decodes natively (FLAC included), so no
/// CORS is needed on media hosts; the cost is a short silence at each track
/// boundary, closed later by a preloading second element.
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'renderer_backend.dart';

class HtmlAudioBackend implements RendererAudioBackend {
  final web.HTMLAudioElement _element = web.HTMLAudioElement();
  final _events = StreamController<BackendEvent>.broadcast();
  final _listeners = <String, JSFunction>{};

  /// Deferred to loadedmetadata: currentTime set on an unloaded element is
  /// silently lost, so a start offset holds play() until the duration is in.
  int? _pendingOffsetMs;

  HtmlAudioBackend() {
    _element.preload = 'auto';
    _listen('playing', (_) => _events.add(const BackendPlaying()));
    _listen('waiting', (_) => _events.add(const BackendStalled()));
    _listen('ended', (_) => _events.add(const BackendEnded()));
    // The element also pauses itself at end of stream; that is BackendEnded.
    _listen('pause', (_) {
      if (!_element.ended) _events.add(const BackendPaused());
    });
    // A seek can settle on a paused element, where no 'playing' will follow.
    _listen('seeked', (_) {
      if (_element.paused && !_element.ended) {
        _events.add(const BackendPaused());
      }
    });
    _listen('loadedmetadata', (_) {
      final offset = _pendingOffsetMs;
      if (offset != null) {
        _pendingOffsetMs = null;
        _element.currentTime = offset / 1000;
        _play();
      }
    });
    _listen('error', (_) {
      if (_element.src.isEmpty) return; // fired by the reset in stop()
      final error = _element.error;
      _events.add(
        BackendFailed(
          switch (error?.code) {
            web.MediaError.MEDIA_ERR_NETWORK => BackendErrorKind.network,
            web.MediaError.MEDIA_ERR_DECODE ||
            web.MediaError.MEDIA_ERR_SRC_NOT_SUPPORTED =>
              BackendErrorKind.decode,
            _ => BackendErrorKind.internal,
          },
          error?.message.isNotEmpty == true
              ? error!.message
              : 'media error ${error?.code}',
        ),
      );
    });
  }

  void _listen(String type, void Function(web.Event) handler) {
    final js = handler.toJS;
    _listeners[type] = js;
    _element.addEventListener(type, js);
  }

  @override
  Stream<BackendEvent> get events => _events.stream;

  @override
  int get positionMs => (_element.currentTime * 1000).round();

  @override
  bool get isPaused => _element.paused;

  @override
  void play({required String uri, required int startOffsetMs}) {
    _element.src = uri;
    if (startOffsetMs > 0) {
      _pendingOffsetMs = startOffsetMs;
      _element.load();
    } else {
      _pendingOffsetMs = null;
      _play();
    }
  }

  @override
  void pause() => _element.pause();

  @override
  void resume() => _play();

  @override
  void stop() {
    _pendingOffsetMs = null;
    _element.pause();
    _element.removeAttribute('src');
    _element.load();
  }

  @override
  void seek(int positionMs) {
    _element.currentTime = positionMs / 1000;
  }

  @override
  void setVolume(double fraction) {
    _element.volume = fraction;
  }

  /// play() rejects instead of firing 'error' when the browser refuses —
  /// most importantly the autoplay policy, until the user has interacted
  /// with the page.
  void _play() {
    _element.play().toDart.then(
      (_) {},
      onError: (Object e) => _events.add(
        BackendFailed(BackendErrorKind.internal, 'playback refused: $e'),
      ),
    );
  }

  @override
  void dispose() {
    stop();
    for (final entry in _listeners.entries) {
      _element.removeEventListener(entry.key, entry.value);
    }
    _events.close();
  }
}
