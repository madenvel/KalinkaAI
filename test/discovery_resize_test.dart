import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalinka/providers/connection_settings_provider.dart';
import 'package:kalinka/providers/onboarding_provider.dart';
import 'package:kalinka/screens/music_player_screen.dart';
import 'package:kalinka/widgets/discovery_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Regression test: the discovery overlay is hosted above the phone/tablet
// layout switch in MusicPlayerScreen, so resizing across the breakpoint
// while a scan is showing must not remove (or re-add) it.

void main() {
  testWidgets('discovery overlay survives resizes across the breakpoint', (
    tester,
  ) async {
    // Set up complete but no stored server — MusicPlayerScreen opens the
    // discovery overlay on launch at tablet width.
    SharedPreferences.setMockInitialValues({
      OnboardingStatusNotifier.sharedPrefOobeComplete: true,
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: MusicPlayerScreen()),
      ),
    );
    await tester.pump(); // post-frame callback flips _discoveryOpen
    await tester.pump(const Duration(milliseconds: 300)); // fade-in
    expect(find.byType(DiscoveryScreen), findsOneWidget);

    // Let the scan's min-duration and timeout timers elapse so none are
    // pending at teardown.
    await tester.pump(const Duration(seconds: 6));

    await tester.binding.setSurfaceSize(const Size(880, 800));
    await tester.pump();
    // The tablet subtree being disposed overflows a Row by a few pixels on
    // this one frame (pre-existing on main, test fonts only) — swallow just
    // that exception.
    final exception = tester.takeException();
    if (exception != null) {
      expect('$exception', contains('RenderFlex overflowed'));
    }
    expect(find.byType(DiscoveryScreen), findsOneWidget);

    await tester.binding.setSurfaceSize(const Size(1280, 800));
    await tester.pump();
    expect(find.byType(DiscoveryScreen), findsOneWidget);
  });
}
