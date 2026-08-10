import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../settings_controls/settings_card.dart';
import 'onboarding_fields.dart';
import 'onboarding_step_scaffold.dart';

/// Wizard step: the server's own setup questions — whatever `base_config`
/// fields the schema tags for setup (the service name today). Every one of
/// them has a working default, so the step is optional by construction.
class OnboardingServerConfigStep extends ConsumerWidget {
  const OnboardingServerConfigStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsProvider);
    final fields = serverSetupFields(state);

    if (fields.isEmpty) {
      return const OnboardingNote(
        'Nothing to configure — this server runs fine on its defaults. '
        'Everything else lives in Settings.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const OnboardingSectionLabel('Server'),
        SettingsCard(
          children: [for (final f in fields) OnboardingFieldRow(path: f.path)],
        ),
        const OnboardingNote(
          'The defaults are all fine — continue whenever you like. '
          'Everything else about the server lives in Settings.',
        ),
      ],
    );
  }
}
