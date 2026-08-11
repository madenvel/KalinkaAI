@TestOn('browser')
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kalinka/renderer/html_audio_backend.dart';
import 'package:kalinka/renderer/renderer_backend.dart';

/// A silent WAV, small enough to inline and real enough for the element to
/// begin a load that the next command then interrupts.
const _silence =
    'data:audio/wav;base64,UklGRiQAAABXQVZFZm10IBAAAAABAAEAgD4AAAB9AAACABAAZGF0YQAAAAA=';

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

  // The element cannot have started within the same tick, so play() is still
  // pending when the next command lands — the browser then rejects it, which
  // is the whole point of these cases.
  Future<List<BackendFailed>> failuresAfterSettling() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return events.whereType<BackendFailed>().toList();
  }

  test('stopping mid-load is not a playback failure', () async {
    backend.play(uri: _silence, startOffsetMs: 0);
    backend.stop();
    expect(await failuresAfterSettling(), isEmpty);
  });

  test('pausing mid-load is not a playback failure', () async {
    backend.play(uri: _silence, startOffsetMs: 0);
    backend.pause();
    expect(await failuresAfterSettling(), isEmpty);
  });

  test('a replaced source reports only for the source that stands', () async {
    backend.play(uri: _silence, startOffsetMs: 0);
    backend.play(uri: _silence, startOffsetMs: 0);
    expect(await failuresAfterSettling(), hasLength(lessThanOrEqualTo(1)));
  });

  // The counterweight to the three above: a refusal nothing superseded must
  // still reach the engine. Headless Chrome supplies one for free — it denies
  // play() until the document has been interacted with.
  test('an undisturbed refusal is still reported', () async {
    backend.play(uri: _silence, startOffsetMs: 0);
    expect(await failuresAfterSettling(), isNotEmpty);
  });
}
