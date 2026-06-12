import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../settings_controls/footer_note.dart';
import '../settings_controls/settings_card.dart';
import 'onboarding_fields.dart';
import 'onboarding_step_scaffold.dart';

/// Wizard step: AI search and metadata features.
class OnboardingFeaturesStep extends ConsumerWidget {
  const OnboardingFeaturesStep({super.key});

  static const aiSearchPath = 'input_modules.localfiles.embedder.enabled';
  static const acoustidEnabledPath =
      'input_modules.localfiles.enricher.plugins.acoustid.enabled';
  static const acoustidKeyPath =
      'input_modules.localfiles.enricher.plugins.acoustid.api_key';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsProvider);
    final acoustidEnabled = state.getEffective(acoustidEnabledPath) == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const OnboardingSectionLabel('AI search'),
        const SettingsCard(
          children: [
            OnboardingFieldRow(
              path: aiSearchPath,
              label: 'AI search',
              help: 'Find music by mood or description — “mellow '
                  'late-night jazz” — instead of exact titles.',
            ),
          ],
        ),
        const FooterNote(
          text: 'The server downloads a ~285 MB model the first time AI '
              'search runs, then indexes your library in the background. '
              'Searches stay on your server — nothing leaves your network.',
        ),
        const OnboardingSectionLabel('Track identification'),
        SettingsCard(
          children: [
            const OnboardingFieldRow(
              path: acoustidEnabledPath,
              label: 'AcoustID fingerprinting',
              help: 'Identifies poorly tagged tracks by their audio '
                  'fingerprint and fills in the metadata.',
            ),
            if (acoustidEnabled)
              const OnboardingFieldRow(
                path: acoustidKeyPath,
                label: 'AcoustID API key',
                help: 'Required for fingerprint lookups.',
              ),
          ],
        ),
        const FooterNote(
          text: 'AcoustID needs a free API key: create an account at '
              'acoustid.org, register an application, and paste its API '
              'key here. You can also do this later in Settings — '
              'fingerprinting stays off until a key is set.',
        ),
      ],
    );
  }
}
