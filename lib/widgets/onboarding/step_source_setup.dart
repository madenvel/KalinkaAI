import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data_model/presentation_schema.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';
import '../settings_controls/settings_card.dart';
import '../settings_controls/warning_note.dart';
import 'onboarding_fields.dart';
import 'onboarding_step_scaffold.dart';

/// Wizard step: each chosen source's own questions, exactly as the server
/// tags them — `required` fields first (the module can't work without an
/// answer), then `prompt` fields (worth a look, defaults fine). A source
/// with nothing tagged simply doesn't appear. The step's Continue gates on
/// at least one source being fully answered; prompts never gate.
class OnboardingSourceSetupStep extends ConsumerWidget {
  const OnboardingSourceSetupStep({super.key});

  /// The setup tag says when to ask, not what saying yes costs — this
  /// wizard copy rides along where a toggle means heavyweight work.
  static const _smartSearchWarnings = {
    'localfiles':
        'Smart search analyses every track: a ~285 MB model download, '
        'then hours of high CPU load on a big library and a few hundred '
        'MB of storage. It runs in the background after setup — your '
        'music is browsable while it works.',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsProvider);
    final blocks = [
      for (final m in schemaModulesOfKind(state.schema, 'input_module'))
        if (inputModuleEnabled(state, m))
          if (setupModuleFields(state.schema, m) case final fields
              when fields.isNotEmpty)
            (m, fields),
    ];

    if (blocks.isEmpty) {
      return const OnboardingNote(
        'Nothing to set up — your sources are ready to go.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (module, fields) in blocks) ...[
          _ModuleHeader(module: module),
          SettingsCard(
            children: [
              for (final f in fields) OnboardingFieldRow(path: f.path),
            ],
          ),
          if (moduleMissingFields(state, module) case final missing
              when missing.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: WarningNote(
                severity: WarningNoteSeverity.warning,
                message:
                    '${missing.join(' and ')} '
                    '${missing.length == 1 ? 'is' : 'are'} required for '
                    '${module.title} to work.',
              ),
            ),
          if (_smartSearchOn(state, fields) &&
              _smartSearchWarnings[module.id] != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: WarningNote(
                severity: WarningNoteSeverity.warning,
                message: _smartSearchWarnings[module.id]!,
              ),
            ),
        ],
      ],
    );
  }

  static bool _smartSearchOn(SettingsState state, List<FieldSpec> fields) {
    for (final f in fields) {
      if (kSmartSearchFieldSuffixes.any((s) => f.path.endsWith(s))) {
        return (state.getEffective(f.path) ?? f.defaultValue) == true;
      }
    }
    return false;
  }
}

/// Section label naming the source, with its readiness beside it.
class _ModuleHeader extends ConsumerWidget {
  final ModuleSpec module;

  const _ModuleHeader({required this.module});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsProvider);
    final ready = moduleConfigured(state, module);
    final color = ready
        ? KalinkaColors.statusOnline
        : KalinkaColors.statusPendingLight;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        children: [
          Text(
            module.title.toUpperCase(),
            style: KalinkaTextStyles.sectionHeaderMuted,
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withValues(alpha: 0.45)),
            ),
            child: Text(
              ready ? 'READY' : 'NEEDS SETUP',
              style: KalinkaTextStyles.tagPill.copyWith(
                color: color,
                fontSize: KalinkaTypography.baseSize - 1,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
