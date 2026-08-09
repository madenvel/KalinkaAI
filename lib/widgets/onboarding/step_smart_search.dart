import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data_model/presentation_schema.dart';
import '../../providers/settings_provider.dart';
import '../settings_controls/settings_card.dart';
import '../settings_controls/warning_note.dart';
import 'onboarding_fields.dart';
import 'onboarding_step_scaffold.dart';

/// Wizard step: Smart Search, per source. Optional throughout.
///
/// Not a server-wide switch — each source that can search by description
/// carries its own toggle, found in the schema (see
/// [kSmartSearchFieldSuffixes]); only enabled sources are offered. The
/// schema's own label and help draw the row, with wizard copy layered on
/// where the cost of saying yes isn't obvious — localfiles' toggle means a
/// model download and a long analysis of the whole library, and nothing
/// starts until setup finishes.
class OnboardingSmartSearchStep extends ConsumerWidget {
  const OnboardingSmartSearchStep({super.key});

  /// Wizard-specific copy per module id: friendlier label, plus what the
  /// toggle costs. Modules without an entry run on their schema copy alone.
  static const _copy = {
    'localfiles': (
      label: 'Smart search for Local files',
      help:
          'Find your own files by mood or description. The server '
          'downloads a ~285 MB model, then analyses every track in the '
          'background. Searches stay on your server — nothing leaves '
          'your network.',
      warning:
          'Analysing a large library is heavy work — expect hours of '
          'high CPU load and a few hundred MB of storage on the server. '
          'Indexing your library and analysing it for Smart Search are '
          'separate jobs; your music is browsable either way.',
    ),
    'jamendo': (
      label: 'Smart search for Jamendo',
      help: null, // The schema's own help already says it all.
      warning: null,
    ),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsProvider);
    final candidates = smartSearchCandidates(state);

    if (candidates.isEmpty) {
      return const OnboardingNote(
        'None of your enabled sources offer Smart Search. More sources '
        'can be connected any time in Settings.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const OnboardingNote(
          'Find music by describing it — “energetic electronic music”, '
          '“quiet melancholic piano” — instead of exact titles. Each '
          'source decides for itself, and nothing runs until setup '
          'finishes; heavyweight analysis only happens where you turn '
          'it on.',
        ),
        for (final (module, field) in candidates) ...[
          OnboardingSectionLabel(module.title),
          _SmartSearchCard(module: module, field: field),
        ],
      ],
    );
  }
}

class _SmartSearchCard extends ConsumerWidget {
  final ModuleSpec module;
  final FieldSpec field;

  const _SmartSearchCard({required this.module, required this.field});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsProvider);
    final copy = OnboardingSmartSearchStep._copy[module.id];
    final on = (state.getEffective(field.path) ?? field.defaultValue) == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsCard(
          children: [
            OnboardingFieldRow(
              path: field.path,
              label: copy?.label,
              help: copy?.help,
            ),
          ],
        ),
        if (on && copy?.warning != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: WarningNote(
              severity: WarningNoteSeverity.warning,
              message: copy!.warning!,
            ),
          ),
      ],
    );
  }
}
