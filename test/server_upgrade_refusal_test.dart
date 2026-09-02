// A refused upgrade is not always a failure: renderers being brought forward
// first means "press it again in a moment", which only the server can say.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kalinka/providers/kalinka_player_api_provider.dart';
import 'package:kalinka/providers/upgrade_provider.dart';

class _RefusingApi implements KalinkaPlayerProxy {
  const _RefusingApi();

  @override
  Future<void> upgradeServer(String version) async {
    throw const ServerUpgradeException(
      'Upgrading the renderers first; try again in a moment',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  test('the server\'s reason for refusing is what the user reads', () async {
    final container = ProviderContainer(
      overrides: [kalinkaProxyProvider.overrideWithValue(const _RefusingApi())],
    );
    addTearDown(container.dispose);

    await container.read(upgradeProvider.notifier).executeUpgrade('4.2.0');

    expect(
      container.read(upgradeProvider).error,
      'Upgrading the renderers first; try again in a moment',
    );
  });
}
