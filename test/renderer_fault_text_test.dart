// A renderer fault reaches the app in the server's words, which name outputs
// by id because logs read them first. Nothing the user has seen carries that
// id, so it must not be what they are told.

import 'package:flutter_test/flutter_test.dart';

import 'package:kalinka/utils/renderer_fault_text.dart';

void main() {
  group('nameRenderersIn', () {
    test('swaps an id — and the noun in front of it — for the name', () {
      expect(
        nameRenderersIn('renderer r-attic is in use by another Core', {
          'r-attic': 'Attic Pi',
        }),
        'Attic Pi is in use by another Core',
      );
    });

    test('reaches an id that stands on its own', () {
      expect(
        nameRenderersIn('no route to r-attic', {'r-attic': 'Attic Pi'}),
        'no route to Attic Pi',
      );
    });

    test('leaves a message naming a renderer nobody knows about', () {
      const said = 'renderer r-ghost is in use by another Core';
      expect(nameRenderersIn(said, {'r-attic': 'Attic Pi'}), said);
    });

    test('leaves a message that names no renderer at all', () {
      expect(
        nameRenderersIn('no renderer is connected', {'r-attic': 'Attic Pi'}),
        'no renderer is connected',
      );
    });

    test('a nameless renderer keeps its id rather than losing the subject', () {
      expect(
        nameRenderersIn('renderer r-attic is offline', {'r-attic': ''}),
        'renderer r-attic is offline',
      );
    });

    // rendererDisplayName shows the id when a renderer reports no name, so an
    // id arrives here as its own name. Swapping it for itself would drop the
    // one word saying what the id is.
    test('a renderer named by its own id keeps the label too', () {
      expect(
        nameRenderersIn('renderer r-attic is offline', {'r-attic': 'r-attic'}),
        'renderer r-attic is offline',
      );
    });
  });

  group('rendererSwitchRefusal', () {
    test('names the claimed output instead of quoting the id back', () {
      expect(
        rendererSwitchRefusal(
          status: 409,
          detail: 'renderer r-attic is in use by another Core',
          rendererId: 'r-attic',
          rendererName: 'Attic Pi',
        ),
        'Attic Pi is playing through another Kalinka server',
      );
    });

    test('still says what happened when the picker had no name', () {
      expect(
        rendererSwitchRefusal(
          status: 409,
          detail: 'renderer r-attic is in use by another Core',
          rendererId: 'r-attic',
        ),
        'That output is playing through another Kalinka server',
      );
    });

    // The picker passes the id as the name for a renderer that reported none,
    // which would otherwise read "r-attic is playing…" — the id this whole
    // exercise exists to keep off the screen.
    test('does not pass an id off as a name', () {
      expect(
        rendererSwitchRefusal(
          status: 409,
          detail: 'renderer r-attic is in use by another Core',
          rendererId: 'r-attic',
          rendererName: 'r-attic',
        ),
        'That output is playing through another Kalinka server',
      );
    });

    test('keeps the server\'s reason where it knows more than we do', () {
      expect(
        rendererSwitchRefusal(
          status: 503,
          detail:
              'renderer r-attic speaks a protocol this server does not, and '
              'cannot play until it is upgraded',
          rendererId: 'r-attic',
          rendererName: 'Attic Pi',
        ),
        'Attic Pi speaks a protocol this server does not, and cannot play '
        'until it is upgraded',
      );
    });

    test('falls back to the name when the server gave no reason', () {
      expect(
        rendererSwitchRefusal(status: 504, rendererName: 'Attic Pi'),
        'Attic Pi didn’t respond',
      );
    });

    test('has something to say about a status it does not know', () {
      expect(
        rendererSwitchRefusal(status: 500, rendererName: 'Attic Pi'),
        'Couldn’t switch output',
      );
    });
  });
}
