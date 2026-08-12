/// RendererAudioBackend backed by one HTMLAudioElement at a time.
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'renderer_backend.dart';

class HtmlAudioBackend implements RendererAudioBackend {
  late web.HTMLAudioElement _element;
  web.AudioContext? _formatContext;
  final _events = StreamController<BackendEvent>.broadcast();
  final _listeners = <String, JSFunction>{};

  /// Deferred to loadedmetadata: currentTime set on an unloaded element is
  /// silently lost, so a start offset holds play() until the duration is in.
  int? _pendingOffsetMs;

  /// Invalidates play() failures from interrupted attempts.
  int _attempt = 0;
  int _generation = 0;
  double _volume = 1;
  bool _playWhenReady = false;
  bool _disposed = false;

  HtmlAudioBackend() {
    try {
      // HTMLMediaElement has duration but not decoded format; use the browser
      // output timebase so Core can derive duration.
      _formatContext = web.AudioContext();
    } catch (_) {
      _formatContext = null;
    }
    _element = web.HTMLAudioElement();
    _configureElement(0);
  }

  void _configureElement(int generation) {
    final element = _element;
    _generation = generation;
    element
      ..preload = 'auto'
      ..volume = _volume;
    _listen(element, 'playing', (_) {
      _events.add(BackendPlaying(generation));
    });
    _listen(element, 'waiting', (_) {
      _events.add(BackendStalled(generation));
    });
    _listen(element, 'ended', (_) {
      _events.add(BackendEnded(generation));
    });
    // The element also pauses itself at end of stream; that is BackendEnded.
    _listen(element, 'pause', (_) {
      if (!element.ended) _events.add(BackendPaused(generation));
    });
    // A seek can settle on a paused element, where no 'playing' will follow.
    _listen(element, 'seeked', (_) {
      if (element.paused && !element.ended) {
        _events.add(BackendPaused(generation));
      }
    });
    _listen(element, 'loadedmetadata', (_) {
      final duration = element.duration;
      if (duration.isFinite && duration >= 0) {
        final context = _formatContext;
        final sampleRate = context?.sampleRate.round() ?? 48000;
        final channels = context?.destination.channelCount ?? 2;
        _events.add(
          BackendAudioFormat(
            generation,
            sampleRateHz: sampleRate,
            channels: channels,
            bitsPerSample: 32,
            sampleFormat: 'FLOAT32',
            durationMs: (duration * 1000).round(),
          ),
        );
      }
      final offset = _pendingOffsetMs;
      if (offset != null) {
        _pendingOffsetMs = null;
        element.currentTime = offset / 1000;
        if (_playWhenReady) _play(generation);
      }
    });
    _listen(element, 'error', (_) {
      if (element.src.isEmpty) return; // fired by the reset in stop()
      final error = element.error;
      _events.add(
        BackendFailed(
          generation,
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

  void _listen(
    web.HTMLAudioElement element,
    String type,
    void Function(web.Event) handler,
  ) {
    final js = handler.toJS;
    _listeners[type] = js;
    element.addEventListener(type, js);
  }

  void _removeListeners(web.HTMLAudioElement element) {
    for (final entry in _listeners.entries) {
      element.removeEventListener(entry.key, entry.value);
    }
    _listeners.clear();
  }

  void _retireElement({required bool replace, int generation = 0}) {
    final old = _element;
    _removeListeners(old);
    old.pause();
    old.removeAttribute('src');
    old.load();
    if (replace) {
      _element = web.HTMLAudioElement();
      _configureElement(generation);
    }
  }

  void _beginGeneration(int generation) {
    _retireElement(replace: true, generation: generation);
  }

  @override
  Stream<BackendEvent> get events => _events.stream;

  @override
  int get positionMs => (_element.currentTime * 1000).round();

  @override
  bool get isPaused => _element.paused;

  @override
  void play({
    required String uri,
    required int startOffsetMs,
    required int generation,
  }) {
    _attempt++;
    _playWhenReady = true;
    _beginGeneration(generation);
    _element.src = uri;
    if (startOffsetMs > 0) {
      _pendingOffsetMs = startOffsetMs;
      _element.load();
    } else {
      _pendingOffsetMs = null;
      _play(generation);
    }
  }

  @override
  void pause() {
    _attempt++;
    _playWhenReady = false;
    _element.pause();
  }

  @override
  void resume() {
    _attempt++;
    _playWhenReady = true;
    // Wait for metadata before applying a non-zero start offset.
    if (_pendingOffsetMs == null) _play(_generation);
  }

  @override
  void stop() {
    _attempt++;
    _playWhenReady = false;
    _pendingOffsetMs = null;
    _retireElement(replace: true);
  }

  @override
  void seek(int positionMs) {
    _element.currentTime = positionMs / 1000;
  }

  @override
  void setVolume(double fraction) {
    _volume = fraction.clamp(0, 1);
    _element.volume = _volume;
  }

  /// play() rejects instead of firing 'error' when the browser refuses —
  /// most importantly the autoplay policy, until the user has interacted
  /// with the page.
  void _play(int generation) {
    final attempt = _attempt;
    _element.play().toDart.then(
      (_) {},
      onError: (Object e) {
        if (attempt != _attempt) return;
        _events.add(
          BackendFailed(
            generation,
            BackendErrorKind.internal,
            'playback refused: $e',
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _attempt++;
    _playWhenReady = false;
    _pendingOffsetMs = null;
    _retireElement(replace: false);
    _formatContext?.close();
    _formatContext = null;
    _events.close();
  }
}
