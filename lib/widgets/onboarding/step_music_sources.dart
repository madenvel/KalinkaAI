import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data_model/presentation_schema.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';
import '../settings_controls/footer_note.dart';
import '../settings_controls/settings_card.dart';
import '../settings_controls/settings_toggle.dart';
import '../settings_controls/warning_note.dart';
import 'onboarding_fields.dart';
import 'onboarding_step_scaffold.dart';

/// Wizard step: input plugins (Local files locked on) + music folders.
class OnboardingMusicSourcesStep extends ConsumerWidget {
  const OnboardingMusicSourcesStep({super.key});

  static const _foldersPath = 'input_modules.localfiles.music_folders';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsProvider);
    final modules = schemaModulesOfKind(state.schema, 'input_module');

    final folders =
        (state.getEffective(_foldersPath) as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    final hasHomeFolder = folders.any(
      (f) => f.startsWith('~') || f.startsWith('/home'),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const OnboardingSectionLabel('Input plugins'),
        SettingsCard(
          children: [
            for (final m in modules) _PluginRow(module: m),
          ],
        ),
        const FooterNote(
          text: 'More plugins — like Jamendo internet radio — will appear '
              'here in future releases.',
        ),
        const OnboardingSectionLabel('Music folders'),
        const SettingsCard(
          children: [
            OnboardingFieldRow(
              path: _foldersPath,
              label: 'Folders to scan',
              help: 'Add every folder that holds your music. The server '
                  'scans them and keeps the library up to date as files '
                  'change.',
            ),
          ],
        ),
        if (hasHomeFolder)
          const WarningNote(
            message: 'The server can’t read home directories (its sandbox '
                'blocks /home). Move music to /srv/music or a drive '
                'mounted under /media instead.',
          ),
        const FooterNote(
          text: 'Folders live on the server, not on this device, and must '
              'be readable by the server’s service user. The initial scan '
              'of a large library can take a while — it runs in the '
              'background after setup.',
        ),
      ],
    );
  }
}

/// One input-module row: icon tile, title, toggle. Local files is the
/// built-in library backend — its toggle renders on and locked.
class _PluginRow extends ConsumerWidget {
  final ModuleSpec module;

  const _PluginRow({required this.module});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    final isLocalFiles = module.id == 'localfiles';
    FieldSpec? enabledField;
    for (final f in module.fields) {
      if (f.path.endsWith('.enabled')) {
        enabledField = f;
        break;
      }
    }
    final enabled = isLocalFiles
        ? true
        : enabledField != null &&
              (state.getEffective(enabledField.path) ??
                      enabledField.defaultValue ??
                      false) ==
                  true;

    final sublabel = isLocalFiles
        ? 'Always enabled — your library on the server is built in and '
              'can’t be turned off.'
        : enabledField == null
        ? 'Set up later in Settings.'
        : 'Streaming source — can be changed later in Settings.';

    Widget toggle = SettingsToggle(
      value: enabled,
      onChanged: (v) {
        if (isLocalFiles || enabledField == null) return;
        notifier.stageChange(enabledField.path, v);
      },
    );
    if (isLocalFiles || enabledField == null) {
      toggle = IgnorePointer(
        child: Opacity(opacity: 0.4, child: toggle),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: KalinkaColors.surfaceOverlay,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isLocalFiles ? Icons.folder_outlined : Icons.extension_outlined,
              size: 18,
              color: KalinkaColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(module.title, style: KalinkaTextStyles.trayRowLabel),
                const SizedBox(height: 2),
                Text(sublabel, style: KalinkaTextStyles.trayRowSublabel),
              ],
            ),
          ),
          const SizedBox(width: 12),
          toggle,
        ],
      ),
    );
  }
}
