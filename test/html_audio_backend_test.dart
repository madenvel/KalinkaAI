@TestOn('browser')
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kalinka/renderer/html_audio_backend.dart';
import 'package:kalinka/renderer/renderer_backend.dart';

// Zero-length WAV used for interrupted-load tests.
const _silence =
    'data:audio/wav;base64,UklGRiQAAABXQVZFZm10IBAAAAABAAEAgD4AAAB9AAACABAAZGF0YQAAAAA=';

// Ten milliseconds of 8 kHz mono PCM silence.
const _finiteSilence =
    'data:audio/wav;base64,UklGRsQAAABXQVZFZm10IBAAAAABAAEAQB8AAIA+AAACABAAZGF0YaAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

void main() {
  late HtmlAudioBackend backend;
  late List<BackendEvent> events;
  late StreamSubscription<BackendEvent> subscription;

  setUp(() {
    backend = HtmlAudioBackend();
    events = [];
    subscription = backend.events.listen(events.add);
  });

  tearDown(() async {
    await subscription.cancel();
    backend.dispose();
  });

  Future<List<BackendFailed>> failuresAfterSettling() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return events.whereType<BackendFailed>().toList();
  }

  test('stopping mid-load is not a playback failure', () async {
    backend.play(uri: _silence, startOffsetMs: 0, generation: 1);
    backend.stop();
    expect(await failuresAfterSettling(), isEmpty);
  });

  test('pausing a pending start offset does not restart or fail', () async {
    backend.play(uri: _finiteSilence, startOffsetMs: 5, generation: 1);
    backend.pause();
    expect(await failuresAfterSettling(), isEmpty);
    expect(backend.isPaused, isTrue);
    expect(events.whereType<BackendPlaying>(), isEmpty);
  });

  test('a replaced source reports only for the source that stands', () async {
    backend.play(uri: _silence, startOffsetMs: 0, generation: 1);
    backend.play(uri: _silence, startOffsetMs: 0, generation: 2);
    final failures = await failuresAfterSettling();
    expect(failures, hasLength(lessThanOrEqualTo(1)));
    expect(failures.every((event) => event.generation == 2), isTrue);
  });

  test('loaded metadata reports the browser output and the length', () async {
    backend.play(uri: _finiteSilence, startOffsetMs: 0, generation: 7);
    await Future<void>.delayed(const Duration(milliseconds: 400));

    final device = events.whereType<BackendDeviceFormat>().single;
    expect(device.generation, 7);
    expect(device.sampleRateHz, greaterThan(0));
    expect(device.channels, greaterThan(0));

    // A separate event: a live stream reports the device and no length.
    final duration = events.whereType<BackendDuration>().single;
    expect(duration.generation, 7);
    expect(duration.durationMs, greaterThanOrEqualTo(0));
  });

  // Headless Chrome denies play before user interaction.
  test('an undisturbed refusal is still reported', () async {
    backend.play(uri: _silence, startOffsetMs: 0, generation: 1);
    expect(await failuresAfterSettling(), isNotEmpty);
  });
}
