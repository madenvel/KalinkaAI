import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalinka/providers/connection_settings_provider.dart';
import 'package:kalinka/widgets/kalinka_search_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpSearchBar(
    WidgetTester tester, {
    VoidCallback? onActivate,
    VoidCallback? onServerChipTap,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(0.5)),
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 420,
                  child: KalinkaSearchBar(
                    onActivate: onActivate,
                    onServerChipTap: onServerChipTap,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
  }

  testWidgets('search bar still activates while disconnected', (
    WidgetTester tester,
  ) async {
    var activationCount = 0;

    await pumpSearchBar(tester, onActivate: () => activationCount++);

    await tester.tap(find.byType(TextField));
    await tester.pump();

    expect(activationCount, 1);
  });

  testWidgets('server settings dot stays tappable while disconnected', (
    WidgetTester tester,
  ) async {
    var serverTapCount = 0;
    final semantics = tester.ensureSemantics();

    try {
      await pumpSearchBar(tester, onServerChipTap: () => serverTapCount++);

      await tester.tap(
        find.bySemanticsLabel('No server configured. Tap for server settings.'),
      );
      await tester.pump();

      expect(serverTapCount, 1);
    } finally {
      semantics.dispose();
    }
  });
}
