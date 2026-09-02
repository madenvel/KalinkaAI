// A toast answers something the user just did, so it has to be readable where
// they did it. Both of these used to fail: an error looked like every other
// toast, and one raised from the phone's Now Playing sheet was painted behind
// the sheet, because the overlay is mounted on the screen the sheet covers.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kalinka/providers/toast_provider.dart';
import 'package:kalinka/theme/app_theme.dart';
import 'package:kalinka/widgets/kalinka_toast_overlay.dart';

const _busy = 'Attic Pi is playing through another Kalinka server';
const _screenKey = Key('screen');
final _navKey = GlobalKey<NavigatorState>();

/// The screen the overlay is mounted on, as both layouts mount it.
Future<ProviderContainer> _pumpScreen(WidgetTester tester) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        navigatorKey: _navKey,
        home: const Stack(
          key: _screenKey,
          children: [
            KalinkaToastPortal(
              child: Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: KalinkaToastOverlay(bottomOffset: 0),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return container;
}

/// Runs out the display timer a toast leaves behind, which would otherwise
/// fail the test as still pending once the tree is gone.
Future<void> _retireToast(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 10));

/// The card a toast is drawn on — its outermost decorated ancestor.
BoxDecoration _card(WidgetTester tester, String message) {
  final container = tester.widget<Container>(
    find
        .ancestor(of: find.text(message), matching: find.byType(Container))
        .first,
  );
  return container.decoration! as BoxDecoration;
}

/// Whether [node] paints inside [ancestor] — the question `find` can't answer,
/// since a hoisted overlay child stays an element-tree descendant of the
/// widget that hosts it.
bool _paintsUnder(RenderObject node, RenderObject ancestor) {
  for (RenderObject? p = node.parent; p != null; p = p.parent) {
    if (identical(p, ancestor)) return true;
  }
  return false;
}

void main() {
  testWidgets('a toast raised behind a covering route paints over it', (
    tester,
  ) async {
    final toasts = await _pumpScreen(tester);

    // The phone's Now Playing sheet, pared back to what matters: a route that
    // covers the screen the toast overlay is mounted on, and from which the
    // output picker — the thing that raises this toast — is opened.
    showModalBottomSheet<void>(
      context: _navKey.currentContext!,
      isScrollControlled: true,
      builder: (_) => const SizedBox.expand(child: Text('Now Playing')),
    );
    await tester.pumpAndSettle();

    toasts.read(toastProvider.notifier).show(_busy, isError: true);
    await tester.pumpAndSettle();

    expect(find.text(_busy), findsOneWidget);
    expect(
      _paintsUnder(
        tester.renderObject(find.text(_busy)),
        tester.renderObject(find.byKey(_screenKey)),
      ),
      isFalse,
      reason: 'the toast is still inside the screen the route covers',
    );
    await _retireToast(tester);
  });

  testWidgets('a failure does not look like every other toast', (tester) async {
    final toasts = await _pumpScreen(tester);

    toasts.read(toastProvider.notifier).show(_busy, isError: true);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    expect(_card(tester, _busy).color, KalinkaColors.actionDeleteSurface);
    await _retireToast(tester);
  });

  testWidgets('a success toast keeps the quiet surface and its dot', (
    tester,
  ) async {
    final toasts = await _pumpScreen(tester);

    toasts.read(toastProvider.notifier).show('Queue cleared');
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
    expect(_card(tester, 'Queue cleared').color, KalinkaColors.surfaceElevated);
    await _retireToast(tester);
  });
}
