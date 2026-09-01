// The release check resolves once and is cached for the app session, so an
// answer taken minutes before a release would stand until the app restarts.
// Opening settings has to drop that cache and ask again.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kalinka/providers/connection_settings_provider.dart';
import 'package:kalinka/providers/connection_state_provider.dart';
import 'package:kalinka/providers/kalinka_player_api_provider.dart';
import 'package:kalinka/providers/server_update_provider.dart';
import 'package:kalinka/providers/settings_provider.dart';
import 'package:kalinka/screens/settings_screen.dart';

class _CountingApi implements KalinkaPlayerProxy {
  int updateChecks = 0;

  @override
  Future<Map<String, dynamic>?> getServerUpdateInfo() async {
    updateChecks++;
    return {
      'current_version': '4.1.0',
      'latest_version': '4.2.0',
      'update_available': true,
      'upgrade_supported': true,
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeConnectionNotifier extends ConnectionStateNotifier {
  @override
  ConnectionStatus build() => ConnectionStatus.connected;
}

/// The screen loads config on open; that path is not what this test drives.
class _InertSettingsNotifier extends SettingsNotifier {
  @override
  SettingsState build() => const SettingsState();

  @override
  Future<void> loadConfig() async {}
}

void main() {
  testWidgets('opening settings re-checks for a release', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = _CountingApi();
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        kalinkaProxyProvider.overrideWithValue(api),
        connectionStateProvider.overrideWith(_FakeConnectionNotifier.new),
        settingsProvider.overrideWith(_InertSettingsNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    // The stale answer a long-lived session is left holding.
    await container.read(serverUpdateProvider.future);
    expect(api.updateChecks, 1);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();

    expect(await container.read(serverUpdateProvider.future), isNotNull);
    expect(api.updateChecks, 2);
  });
}
