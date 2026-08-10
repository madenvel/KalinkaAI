import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalinka/data_model/presentation_schema.dart';
import 'package:kalinka/providers/connection_settings_provider.dart';
import 'package:kalinka/providers/onboarding_provider.dart';
import 'package:kalinka/providers/settings_provider.dart';
import 'package:kalinka/widgets/onboarding/onboarding_fields.dart';
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

  test(
    'interrupted wizard run leaves no stored server, restarts wizard',
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
    },
  );

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
    await container.read(onboardingStatusProvider.notifier).markOobeComplete();
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

  group('setup-tag wizard gates', () {
    FieldSpec field(String path, String label, Setup setup) => FieldSpec(
      path: path,
      label: label,
      widget: WidgetKind.text,
      type: 'str',
      setup: setup,
    );

    // Jamendo with a required Client ID and a prompt-tier format, the
    // shape the tagged server serves.
    const enabledPath = 'input_modules.jamendo.enabled';
    final jamendoModule = ModuleSpec(
      id: 'jamendo',
      kind: 'input_module',
      title: 'Jamendo',
      fields: [field(enabledPath, 'Enabled', Setup.hidden)],
    );
    final taggedSchema = PresentationSchema(
      schemaVersion: '1',
      pages: [
        PageSpec(id: 'sources', title: 'Sources', modules: [jamendoModule]),
      ],
      expertFields: [
        field(enabledPath, 'Enabled', Setup.hidden),
        field(
          'input_modules.jamendo.audio_format',
          'Audio quality',
          Setup.prompt,
        ),
        field('input_modules.jamendo.client_id', 'Client ID', Setup.required),
      ],
    );

    SettingsState state({
      PresentationSchema? schema,
      Map<String, dynamic> values = const {},
      Map<String, dynamic> staged = const {},
    }) => SettingsState(schema: schema, values: values, stagedChanges: staged);

    test('a required question left empty gates the source', () {
      final s = state(
        schema: taggedSchema,
        values: {enabledPath: true, 'input_modules.jamendo.client_id': ''},
      );
      expect(moduleConfigured(s, jamendoModule), false);
      expect(moduleMissingFields(s, jamendoModule), ['Client ID']);
      expect(anySourceConfigured(s), false);
    });

    test('answering the required question unblocks it', () {
      final s = state(
        schema: taggedSchema,
        values: {enabledPath: true, 'input_modules.jamendo.client_id': ''},
        staged: {'input_modules.jamendo.client_id': 'abc123'},
      );
      expect(moduleConfigured(s, jamendoModule), true);
      expect(anySourceConfigured(s), true);
    });

    test('a prompt question never gates, but is still asked', () {
      final s = state(
        schema: taggedSchema,
        values: {
          enabledPath: true,
          'input_modules.jamendo.client_id': 'abc123',
          'input_modules.jamendo.audio_format': '',
        },
      );
      expect(moduleConfigured(s, jamendoModule), true);
      expect(
        setupModuleFields(taggedSchema, jamendoModule).map((f) => f.path),
        [
          // Required first, then prompt; the enable flag never renders.
          'input_modules.jamendo.client_id',
          'input_modules.jamendo.audio_format',
        ],
      );
    });

    test('a schema with no setup tags falls back to tier rules', () {
      final untaggedModule = ModuleSpec(
        id: 'jamendo',
        kind: 'input_module',
        title: 'Jamendo',
        fields: [
          field(enabledPath, 'Enabled', Setup.hidden),
          field('input_modules.jamendo.client_id', 'Client ID', Setup.hidden),
        ],
      );
      final untaggedSchema = PresentationSchema(
        schemaVersion: '1',
        pages: [
          PageSpec(id: 'sources', title: 'Sources', modules: [untaggedModule]),
        ],
        expertFields: [
          field(enabledPath, 'Enabled', Setup.hidden),
          field('input_modules.jamendo.client_id', 'Client ID', Setup.hidden),
        ],
      );
      final s = state(
        schema: untaggedSchema,
        values: {enabledPath: true, 'input_modules.jamendo.client_id': ''},
      );
      expect(schemaHasSetupTags(untaggedSchema), false);
      // The old rule: the module's simple top-level fields, minus enabled.
      expect(
        setupModuleFields(untaggedSchema, untaggedModule).map((f) => f.path),
        ['input_modules.jamendo.client_id'],
      );
      // Nothing is marked required, so nothing gates.
      expect(moduleConfigured(s, untaggedModule), true);
    });
  });
}
