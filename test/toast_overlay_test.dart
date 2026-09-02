// A toast answers something the user just did, so it has to be readable where
// they did it. Both of these used to fail: an error looked like every other
// toast, and one raised from the phone's Now Playing sheet was painted behind
// the sheet, because the overlay was mounted on the screen the sheet covers.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kalinka/providers/toast_provider.dart';
import 'package:kalinka/theme/app_theme.dart';
import 'package:kalinka/widgets/kalinka_toast_overlay.dart';

const _busy = 'Attic Pi is playing through another Kalinka server';
const _sheetColor = Color(0xFF00FF00);
const _boundaryKey = Key('boundary');
final _navKey = GlobalKey<NavigatorState>();

/// The app as [KalinkaApp] assembles it: the toast host wrapping the navigator.
Future<ProviderContainer> _pumpApp(WidgetTester tester) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundaryKey,
      child: UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: _navKey,
          builder: (_, child) => KalinkaToastHost(child: child!),
          home: const Scaffold(body: SizedBox.expand()),
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

/// The colour actually on screen at [at], read back off the rendered frame.
///
/// Render-tree ancestry can't answer this: an overlay child is reparented out
/// of its host and still painted under a later route, which is exactly the bug
/// the first attempt at this shipped with.
Future<int> _pixelAt(WidgetTester tester, Offset at) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundaryKey),
  );
  late final ByteData? data;
  late final int width;
  // toImage never completes under the test's fake async.
  await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage();
    width = image.width;
    data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  });
  final rgba = data!.buffer.asUint8List();
  final i = ((at.dy.round() * width) + at.dx.round()) * 4;
  return (0xFF << 24) | (rgba[i] << 16) | (rgba[i + 1] << 8) | rgba[i + 2];
}

void main() {
  testWidgets('a toast raised behind a covering route paints over it', (
    tester,
  ) async {
    final toasts = await _pumpApp(tester);

    // The phone's Now Playing sheet, pared back to what matters: a route
    // covering the screen, from which the output picker — the thing that
    // raises this toast — is opened. Edge to edge, as that sheet is, so the
    // sample below lands on it rather than beside it.
    showModalBottomSheet<void>(
      context: _navKey.currentContext!,
      isScrollControlled: true,
      backgroundColor: _sheetColor,
      constraints: const BoxConstraints(maxWidth: double.infinity),
      builder: (_) => const SizedBox.expand(),
    );
    await tester.pumpAndSettle();

    toasts.read(toastProvider.notifier).show(_busy, isError: true);
    await tester.pumpAndSettle();

    // Inside the card but clear of its border, glyph and text.
    final rect = tester.getRect(
      find
          .ancestor(of: find.text(_busy), matching: find.byType(Container))
          .first,
    );
    expect(
      await _pixelAt(tester, Offset(rect.center.dx, rect.top + 4)),
      KalinkaColors.actionDeleteSurface.toARGB32(),
      reason: 'the sheet is painted over the toast',
    );
    await _retireToast(tester);
  });

  testWidgets('a failure does not look like every other toast', (tester) async {
    final toasts = await _pumpApp(tester);

    toasts.read(toastProvider.notifier).show(_busy, isError: true);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    expect(_card(tester, _busy).color, KalinkaColors.actionDeleteSurface);
    await _retireToast(tester);
  });

  testWidgets('a success toast keeps the quiet surface and its dot', (
    tester,
  ) async {
    final toasts = await _pumpApp(tester);

    toasts.read(toastProvider.notifier).show('Queue cleared');
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
    expect(_card(tester, 'Queue cleared').color, KalinkaColors.surfaceElevated);
    await _retireToast(tester);
  });
}
