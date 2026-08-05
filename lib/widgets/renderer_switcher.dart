import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data_model/data_model.dart' show RendererInfo;
import '../providers/kalinka_player_api_provider.dart'
    show RendererSwitchException;
import '../providers/renderer_provider.dart';
import '../providers/toast_provider.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';
import 'kalinka_bottom_sheet.dart';
import 'transport_button.dart';

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
    // The list has no push channel — re-read it as the sheet opens so a
    // renderer that came or went since the last fetch shows up.
    notifier.refresh();
    final picked = await showKalinkaBottomSheet<String>(
      context: context,
      contentBuilder: (_) => const RendererPickerContent(),
    );
    if (picked == null) return;
    try {
      await notifier.select(picked);
    } on RendererSwitchException catch (e) {
      toast.show(e.message, isError: true);
    } catch (_) {
      toast.show('Couldn’t switch output', isError: true);
    }
  }
}

/// Body of the renderer picker sheet. Pops the chosen renderer's id.
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
                onTap: () => Navigator.pop(ctx, renderers[i].rendererId),
              ),
            ),
          ),
      ],
    );
  }
}

class _RendererRow extends StatelessWidget {
  final RendererInfo renderer;
  final VoidCallback onTap;

  const _RendererRow({required this.renderer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final connected = renderer.isConnected;
    final active = renderer.active;
    // Pinning an offline renderer leaves playback where it is, so those rows
    // are shown for context but can't be chosen.
    final enabled = connected && !active;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled
            ? () {
                KalinkaHaptics.selectionClick();
                onTap();
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
                        renderer.friendlyName.isEmpty
                            ? renderer.rendererId
                            : renderer.friendlyName,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
