import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kalinka/data_model/playqueue_events.dart';
import 'package:kalinka/providers/app_state_provider.dart';
import 'package:kalinka/providers/connection_settings_provider.dart';
import 'package:kalinka/widgets/queue_management_tray.dart';
import 'package:kalinka/widgets/tap_highlight.dart';

/// A queue that stands still, so the tray can be built without a socket
/// behind it.
class _StillQueue extends PlayQueueStateStore {
  @override
  PlayQueueState build() => PlayQueueState.empty;
}

Finder _within(Finder? of, Type type) => find
    .descendant(
      of: of ?? find.byType(TapHighlight),
      matching: find.byType(type),
    )
    .first;

/// The tint the row is currently asking for — null while it is at rest.
Color? tint(WidgetTester tester, [Finder? of]) {
  final box = tester.widget<AnimatedContainer>(_within(of, AnimatedContainer));
  return (box.decoration as BoxDecoration?)?.color;
}

MouseCursor cursorOf(WidgetTester tester) =>
    tester.widget<MouseRegion>(_within(null, MouseRegion)).cursor;

/// A pointer that stays on the screen, the way a desktop mouse does.
Future<TestGesture> mouse(WidgetTester tester) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  return gesture;
}

void main() {
  Future<void> pumpRow(WidgetTester tester, {required bool live}) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: TapHighlight(
              onTap: live ? () {} : null,
              child: const SizedBox(width: 200, height: 48),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('a row with somewhere to go says so under the pointer', (
    tester,
  ) async {
    await pumpRow(tester, live: true);

    expect(cursorOf(tester), SystemMouseCursors.click);
    expect(tint(tester), isNull);

    await (await mouse(
      tester,
    )).moveTo(tester.getCenter(find.byType(TapHighlight)));
    await tester.pump();

    expect(tint(tester), isNotNull);
  });

  testWidgets('and lifts further while it is held', (tester) async {
    await pumpRow(tester, live: true);
    final pointer = await mouse(tester);
    await pointer.moveTo(tester.getCenter(find.byType(TapHighlight)));
    await tester.pump();
    final hovered = tint(tester)!;

    await pointer.down(tester.getCenter(find.byType(TapHighlight)));
    await tester.pump();

    expect(tint(tester)!.a, greaterThan(hovered.a));

    await pointer.up();
    await tester.pump();

    expect(tint(tester), hovered);
  });

  testWidgets('a row that does nothing keeps the plain arrow and stays flat', (
    tester,
  ) async {
    await pumpRow(tester, live: false);

    await (await mouse(
      tester,
    )).moveTo(tester.getCenter(find.byType(TapHighlight)));
    await tester.pump();

    expect(cursorOf(tester), SystemMouseCursors.basic);
    expect(tint(tester), isNull);
  });

  testWidgets('the mark stops where the rule between rows does', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          playQueueStateStoreProvider.overrideWith(_StillQueue.new),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: QueueManagementTrayContent()),
          ),
        ),
      ),
    );

    final row = find.ancestor(
      of: find.text('Clear queue'),
      matching: find.byType(TapHighlight),
    );
    final mark = tester.getRect(
      find.descendant(of: row, matching: find.byType(AnimatedContainer)).first,
    );
    final rule = tester.getRect(find.byType(Divider).first);

    expect(mark.left, rule.left);
    expect(mark.right, rule.right);
    // The row itself stays tappable past where it is marked.
    expect(tester.getRect(row).width, greaterThan(mark.width));
  });

  testWidgets('the queue tray lights its rows the same way', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          playQueueStateStoreProvider.overrideWith(_StillQueue.new),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: QueueManagementTrayContent()),
          ),
        ),
      ),
    );

    final row = find.ancestor(
      of: find.text('Clear queue'),
      matching: find.byType(TapHighlight),
    );
    expect(tint(tester, row), isNull);

    await (await mouse(tester)).moveTo(tester.getCenter(row));
    await tester.pump();

    expect(tint(tester, row), isNotNull);
  });
}
