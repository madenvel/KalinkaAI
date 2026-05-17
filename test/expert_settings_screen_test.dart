// Reproduces the crash the user reported when flipping into expert
// mode. We mount the screen with a populated SettingsState (the
// real production state shape — schema + flat expert_fields + values),
// pump a couple of frames, and let the test framework surface any
// thrown exception or assertion.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kalinka/data_model/presentation_schema.dart';
import 'package:kalinka/providers/settings_provider.dart';
import 'package:kalinka/widgets/expert_settings_screen.dart';

class _StubSettingsNotifier extends SettingsNotifier {
  final SettingsState seed;
  _StubSettingsNotifier(this.seed);
  @override
  SettingsState build() => seed;
}

PresentationSchema _schema() {
  return PresentationSchema(
    schemaVersion: 'test',
    pages: const [],
    expertFields: [
      const FieldSpec(
        path: 'base_config.output.alsa.device',
        label: 'ALSA device',
        widget: WidgetKind.enumDropdown,
        type: 'str',
        importance: Importance.simple,
        help: 'Hardware output',
      ),
      const FieldSpec(
        path: 'base_config.server.port',
        label: 'Port',
        widget: WidgetKind.numberInput,
        type: 'int',
        importance: Importance.simple,
        defaultValue: 8000,
      ),
      const FieldSpec(
        path: 'input_modules.localfiles.searcher.weight_fts',
        label: 'FTS rank weight',
        widget: WidgetKind.numberInput,
        type: 'float',
        importance: Importance.expert,
      ),
      const FieldSpec(
        path: 'input_modules.localfiles.music_folders',
        label: 'Music folders',
        widget: WidgetKind.folderList,
        type: 'list[str]',
        importance: Importance.simple,
      ),
      const FieldSpec(
        path: 'input_modules.localfiles.enricher.enabled',
        label: 'Enable enricher',
        widget: WidgetKind.toggle,
        type: 'bool',
        importance: Importance.simple,
      ),
    ],
  );
}

void main() {
  testWidgets('Expert screen mounts without crashing', (tester) async {
    final state = SettingsState(
      schema: _schema(),
      schemaVersion: 'test',
      values: const {
        'base_config.output.alsa.device': 'hw:CARD=foo,DEV=0',
        'base_config.server.port': 8000,
        'input_modules.localfiles.searcher.weight_fts': 0.35,
        'input_modules.localfiles.music_folders': ['/music'],
        'input_modules.localfiles.enricher.enabled': true,
      },
      enumOptions: const {
        'base_config.output.alsa.device': [
          OptionSpec(value: 'default', label: 'System default'),
          OptionSpec(value: 'hw:CARD=foo,DEV=0', label: 'Foo card'),
        ],
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(() => _StubSettingsNotifier(state)),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ExpertSettingsScreen()),
        ),
      ),
    );

    // Multiple frames so the debounced filter timer can fire if any
    // initial query is being processed, and any async UI work settles.
    await tester.pump(const Duration(milliseconds: 200));

    // If any exception was thrown during build, takeException returns
    // it; otherwise null. The test fails loudly with the actual
    // stack trace.
    final ex = tester.takeException();
    expect(ex, isNull, reason: 'Expert screen threw: $ex');
  });
}
