import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalinka/providers/connection_settings_provider.dart';
import 'package:kalinka/providers/onboarding_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> makeContainer(
    Map<String, Object> initialPrefs,
  ) async {
    SharedPreferences.setMockInitialValues(initialPrefs);
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('fresh install: wizard required, coach marks pending', () async {
    final container = await makeContainer({});
    final status = container.read(onboardingStatusProvider);
    expect(status.oobeComplete, false);
    expect(status.coachMarksShown, false);
  });

  test('interrupted wizard run leaves no stored server, restarts wizard',
      () async {
    // The wizard connects ephemerally — nothing in prefs — so a kill
    // mid-run looks exactly like a fresh install on the next launch.
    final container = await makeContainer({});
    container
        .read(connectionSettingsProvider.notifier)
        .setDeviceEphemeral('Kalinka', '192.168.1.10', 8000);
    expect(container.read(connectionSettingsProvider).isSet, true);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ConnectionSettingsNotifier.sharedPrefHost), null);
    expect(
      prefs.getBool(OnboardingStatusNotifier.sharedPrefOobeComplete),
      null,
    );
  });

  test('upgrade path: stored server marks wizard complete', () async {
    final container = await makeContainer({
      ConnectionSettingsNotifier.sharedPrefName: 'Old Server',
      ConnectionSettingsNotifier.sharedPrefHost: '192.168.1.20',
      ConnectionSettingsNotifier.sharedPrefPort: 8000,
    });
    final status = container.read(onboardingStatusProvider);
    expect(status.oobeComplete, true);
    // Coach marks still pending — upgrading users get the tour once.
    expect(status.coachMarksShown, false);

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getBool(OnboardingStatusNotifier.sharedPrefOobeComplete),
      true,
    );
  });

  test('markOobeComplete and markCoachMarksShown persist', () async {
    final container = await makeContainer({});
    await container
        .read(onboardingStatusProvider.notifier)
        .markOobeComplete();
    await container
        .read(onboardingStatusProvider.notifier)
        .markCoachMarksShown();

    final status = container.read(onboardingStatusProvider);
    expect(status.oobeComplete, true);
    expect(status.coachMarksShown, true);

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getBool(OnboardingStatusNotifier.sharedPrefOobeComplete),
      true,
    );
    expect(
      prefs.getBool(OnboardingStatusNotifier.sharedPrefCoachMarksShown),
      true,
    );
  });
}
