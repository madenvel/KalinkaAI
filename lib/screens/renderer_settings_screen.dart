import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/kalinka_player_api_provider.dart';
import '../providers/renderer_settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/connection_banner.dart';
import '../widgets/kalinka_button.dart';
import '../widgets/kalinka_dialog.dart' show showKalinkaDialog;
import '../widgets/onboarding/speaker_test_dialog.dart';
import '../widgets/pending_changes_banner.dart';
import '../widgets/settings_controls/settings_binding.dart';
import '../widgets/settings_controls/settings_card.dart';
import '../widgets/settings_renderer.dart';

/// One renderer's own settings, drawn by the same schema renderer as the
/// server's settings page.
///
/// A separate page rather than a section of server settings, because the
/// values live on the renderer: they are read from it on demand, written path
/// by path, and apply without restarting the server.
class RendererSettingsScreen extends ConsumerStatefulWidget {
  final String rendererId;
  final String rendererName;

  const RendererSettingsScreen({
    super.key,
    required this.rendererId,
    required this.rendererName,
  });

  @override
  ConsumerState<RendererSettingsScreen> createState() =>
      _RendererSettingsScreenState();
}

class _RendererSettingsScreenState
    extends ConsumerState<RendererSettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notifier.load();
    });
  }

  RendererSettingsNotifier get _notifier =>
      ref.read(rendererSettingsProvider(widget.rendererId).notifier);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rendererSettingsProvider(widget.rendererId));

    return Scaffold(
      backgroundColor: KalinkaColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const ConnectionBanner(),
            PendingChangesBanner(
              pendingCount: state.pendingCount,
              consequence: state.pendingCost.warning,
              busy: state.saving,
              onDiscard: _notifier.discard,
              onApply: _notifier.save,
            ),
            Expanded(child: _buildBody(state)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(RendererSettingsState state) {
    if (state.loading && !state.loaded) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(KalinkaColors.accent),
        ),
      );
    }
    if (state.sections.isEmpty) {
      return _buildLoadFailure(state.error);
    }

    return SettingsScope(
      binding: RendererSettingsBinding(state, _notifier),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (state.error != null) _ErrorNote(message: state.error!),
          for (final section in state.sections)
            SchemaSectionRenderer(
              key: ValueKey(section.id),
              section: section,
              isTopLevel: true,
            ),
          _SpeakerTestSection(
            rendererId: widget.rendererId,
            rendererName: widget.rendererName,
            hasPendingChanges: state.hasPendingChanges,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadFailure(String? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.speaker_outlined,
              color: KalinkaColors.textSecondary,
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              error == null ? 'No settings to show' : 'Couldn’t load settings',
              style: KalinkaTextStyles.cardTitle,
            ),
            const SizedBox(height: 8),
            Text(
              error ?? 'This output reports no settings of its own.',
              textAlign: TextAlign.center,
              style: KalinkaTextStyles.trayRowSublabel,
            ),
            if (error != null) ...[
              const SizedBox(height: 16),
              KalinkaButton(
                label: 'Retry',
                variant: KalinkaButtonVariant.accent,
                size: KalinkaButtonSize.compact,
                onTap: _notifier.load,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: kKalinkaTopBarDecoration,
      child: SizedBox(
        height: kKalinkaTopBarHeight,
        child: Padding(
          padding: const EdgeInsets.only(left: 6, right: 20),
          child: Row(
            children: [
              // Plain, borderless back — the same control settings and Find
              // Music use.
              Semantics(
                label: 'Back',
                button: true,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  behavior: HitTestBehavior.opaque,
                  child: const SizedBox(
                    width: 42,
                    height: 42,
                    child: Icon(
                      Icons.arrow_back,
                      size: 22,
                      color: KalinkaColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.rendererName,
                      style: KalinkaTextStyles.cardTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'OUTPUT SETTINGS',
                      style: KalinkaTextStyles.sectionHeaderMuted,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Amber inline note for a save the renderer partly refused. Distinct from the
/// full-page failure: the page still holds good content.
class _ErrorNote extends StatelessWidget {
  final String message;
  const _ErrorNote({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_rounded,
            size: 15,
            color: KalinkaColors.statusPendingLight,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: KalinkaTextStyles.trayRowSublabel.copyWith(
                color: KalinkaColors.statusPendingLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Test settings" — plays a tone down the left speaker, then the right, so a
/// device or driver change can be checked by ear.
class _SpeakerTestSection extends ConsumerWidget {
  final String rendererId;
  final String rendererName;

  /// Staged edits are not on the renderer yet, so the tone would come out of
  /// the old configuration and prove nothing.
  final bool hasPendingChanges;

  const _SpeakerTestSection({
    required this.rendererId,
    required this.rendererName,
    required this.hasPendingChanges,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 10),
          child: Text(
            'SPEAKER TEST',
            style: KalinkaTextStyles.sectionHeaderMuted,
          ),
        ),
        SettingsCard(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    hasPendingChanges
                        ? 'Apply your changes first — the tone plays through '
                              'the settings currently on this output.'
                        : 'Plays a tone down the left channel, then the right, '
                              'so you can check the wiring by ear.',
                    style: KalinkaTextStyles.trayRowSublabel,
                  ),
                  const SizedBox(height: 12),
                  KalinkaButton(
                    label: 'Test settings',
                    variant: KalinkaButtonVariant.neutral,
                    fullWidth: true,
                    enabled: !hasPendingChanges,
                    leading: const Icon(
                      Icons.volume_up_rounded,
                      size: 16,
                      color: KalinkaColors.textPrimary,
                    ),
                    onTap: () => showKalinkaDialog<void>(
                      context: context,
                      builder: (_) => SpeakerTestDialog(
                        targetName: rendererName,
                        playTone: (channel) => ref
                            .read(kalinkaProxyProvider)
                            .testTone(channel, rendererId: rendererId),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
