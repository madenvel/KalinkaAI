import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import 'settings_controls/settings_toggle.dart';

/// Compact "EXPERT" label + toggle that sits at the right of a settings header.
/// Off = the structured page, on = the flat about:config-style list.
///
/// One switch for the whole app: expert is a disposition the user is in, not a
/// per-page mode, so the server's settings and a renderer's follow each other.
///
/// The label is muted-uppercase to match other meta chrome in the header; the
/// toggle is scaled slightly down so it sits proportional to the back button
/// and title rather than dominating the row.
class ExpertModeToggle extends ConsumerWidget {
  const ExpertModeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expert = ref.watch(expertModeProvider);
    final notifier = ref.read(expertModeProvider.notifier);
    return Semantics(
      label: 'Expert settings',
      toggled: expert,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: notifier.toggle,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'EXPERT',
              style: KalinkaTextStyles.sectionHeaderMuted.copyWith(
                letterSpacing: 1.0,
                color: expert
                    ? KalinkaColors.accent
                    : KalinkaColors.textSecondary,
              ),
            ),
            const SizedBox(width: 10),
            Transform.scale(
              scale: 0.82,
              alignment: Alignment.centerRight,
              child: SettingsToggle(
                value: expert,
                onChanged: (_) => notifier.toggle(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
