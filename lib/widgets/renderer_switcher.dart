import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data_model/data_model.dart' show RendererInfo;
import '../providers/kalinka_player_api_provider.dart'
    show RendererSwitchException;
import '../providers/renderer_provider.dart';
import '../providers/toast_provider.dart';
import '../screens/renderer_settings_screen.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';
import 'kalinka_bottom_sheet.dart';
import 'transport_button.dart';

/// What a row in the picker was asked to do.
enum RendererPickerIntent { play, configure }

/// The renderer a row names, and which of its two controls was tapped.
class RendererPickerChoice {
  final String rendererId;
  final String rendererName;
  final RendererPickerIntent intent;

  const RendererPickerChoice({
    required this.rendererId,
    required this.rendererName,
    required this.intent,
  });
}

/// Icon button that opens the renderer picker — the list of playback endpoints
/// the server knows about, with a tick on the one playback is running on.
///
/// Renders nothing while the server reports no renderers (or predates the
/// `/renderer/*` endpoints), so it stays out of the way on a plain
/// single-output setup.
class RendererSwitcherButton extends ConsumerWidget {
  final double hitDiameter;
  final double iconSize;

  const RendererSwitcherButton({
    super.key,
    this.hitDiameter = 46,
    this.iconSize = 22,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(
      rendererListProvider.select((s) => s.hasRenderers),
    );
    if (!visible) return const SizedBox.shrink();

    return TransportButton(
      hitDiameter: hitDiameter,
      onTapDown: (_) => KalinkaHaptics.selectionClick(),
      onTap: () => _openPicker(context, ref),
      child: Icon(
        Icons.speaker_outlined,
        size: iconSize,
        color: KalinkaColors.textSecondary,
      ),
    );
  }

  Future<void> _openPicker(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(rendererListProvider.notifier);
    final toast = ref.read(toastProvider.notifier);
    final navigator = Navigator.of(context);
    // The list has no push channel — re-read it as the sheet opens so a
    // renderer that came or went since the last fetch shows up.
    notifier.refresh();
    final choice = await showKalinkaBottomSheet<RendererPickerChoice>(
      context: context,
      contentBuilder: (_) => const RendererPickerContent(),
    );
    if (choice == null) return;

    switch (choice.intent) {
      case RendererPickerIntent.configure:
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => RendererSettingsScreen(
              rendererId: choice.rendererId,
              rendererName: choice.rendererName,
            ),
          ),
        );
      case RendererPickerIntent.play:
        try {
          await notifier.select(choice.rendererId);
        } on RendererSwitchException catch (e) {
          toast.show(e.message, isError: true);
        } catch (_) {
          toast.show('Couldn’t switch output', isError: true);
        }
    }
  }
}

/// Body of the renderer picker sheet. Pops a [RendererPickerChoice].
class RendererPickerContent extends ConsumerWidget {
  const RendererPickerContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rendererListProvider);
    final renderers = state.renderers;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          child: Row(
            children: [
              Text('PLAY ON', style: KalinkaTextStyles.sectionHeaderMuted),
              const SizedBox(width: 10),
              if (state.loading)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: KalinkaColors.textMuted,
                  ),
                ),
            ],
          ),
        ),
        if (renderers.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Text(
              state.loading ? 'Looking for outputs…' : 'No outputs available',
              style: KalinkaTextStyles.trayRowSublabel,
            ),
          )
        else
          // Many-renderer installs are rare, but a scroll cap keeps the sheet
          // from swallowing the screen if one turns up.
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: renderers.length,
              itemBuilder: (ctx, i) => _RendererRow(
                renderer: renderers[i],
                onIntent: (intent) => Navigator.pop(
                  ctx,
                  RendererPickerChoice(
                    rendererId: renderers[i].rendererId,
                    rendererName: _displayName(renderers[i]),
                    intent: intent,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Friendly name, falling back to the id for a renderer that reported none.
String _displayName(RendererInfo renderer) =>
    renderer.friendlyName.isEmpty ? renderer.rendererId : renderer.friendlyName;

class _RendererRow extends StatelessWidget {
  final RendererInfo renderer;
  final ValueChanged<RendererPickerIntent> onIntent;

  const _RendererRow({required this.renderer, required this.onIntent});

  @override
  Widget build(BuildContext context) {
    final connected = renderer.isConnected;
    final active = renderer.active;
    // Pinning an offline renderer leaves playback where it is, so those rows
    // are shown for context but can't be chosen.
    final canPlayHere = connected && !active;
    // Settings are read from the renderer over its own socket, so an offline
    // one has nothing to serve — but the renderer playback is already on is a
    // perfectly good thing to configure.
    final canConfigure = connected;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canPlayHere
            ? () {
                KalinkaHaptics.selectionClick();
                onIntent(RendererPickerIntent.play);
              }
            : null,
        child: Opacity(
          opacity: connected ? 1.0 : 0.45,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: active
                        ? KalinkaColors.accentSubtle
                        : KalinkaColors.surfaceOverlay,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.speaker_outlined,
                    size: 16,
                    color: active
                        ? KalinkaColors.accentTint
                        : KalinkaColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displayName(renderer),
                        style: KalinkaTextStyles.trayRowLabel.copyWith(
                          color: active
                              ? KalinkaColors.accentTint
                              : KalinkaColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!connected) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Offline',
                          style: KalinkaTextStyles.trayRowSublabel,
                        ),
                      ],
                    ],
                  ),
                ),
                if (active) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.check,
                    size: 18,
                    color: KalinkaColors.accentTint,
                  ),
                ],
                const SizedBox(width: 4),
                // Its own tap target inside the row: the row switches
                // playback, the gear opens that renderer's settings.
                _GearButton(
                  rendererName: _displayName(renderer),
                  onTap: canConfigure
                      ? () {
                          KalinkaHaptics.selectionClick();
                          onIntent(RendererPickerIntent.configure);
                        }
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GearButton extends StatelessWidget {
  final String rendererName;
  final VoidCallback? onTap;

  const _GearButton({required this.rendererName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$rendererName settings',
      button: true,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(
              Icons.settings_outlined,
              size: 18,
              color: onTap == null
                  ? KalinkaColors.textMuted
                  : KalinkaColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
