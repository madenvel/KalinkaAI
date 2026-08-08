import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data_model/data_model.dart' show RendererInfo;
import '../providers/kalinka_player_api_provider.dart'
    show RendererSwitchException;
import '../providers/renderer_host_provider.dart' show rendererIdentityProvider;
import '../providers/renderer_provider.dart';
import '../providers/renderer_settings_route_provider.dart';
import '../providers/toast_provider.dart';
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
/// the server knows about, with the one playback is running on marked.
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

    // The button is too small for a name, so the current output goes in the
    // label instead — otherwise nothing tells you where sound is going.
    final playingOn = ref.watch(
      rendererListProvider.select((s) => s.active?.friendlyName),
    );
    // Live = sound has somewhere to go: an output is chosen and reachable.
    final outputLive = ref.watch(
      rendererListProvider.select((s) => s.active?.isConnected ?? false),
    );

    return Semantics(
      label: playingOn == null || playingOn.isEmpty
          ? 'Choose output'
          : 'Output: $playingOn',
      button: true,
      child: Tooltip(
        message: 'Choose output',
        excludeFromSemantics: true,
        child: TransportButton(
          hitDiameter: hitDiameter,
          onTapDown: (_) => KalinkaHaptics.selectionClick(),
          onTap: () => _openPicker(context, ref),
          child: _CastGlyph(size: iconSize, live: outputLive),
        ),
      ),
    );
  }
}

/// Cast icon with a corner state badge: a green dot while an output is
/// active, a grey cross while none is — the one fact worth a glance at the
/// playbar, since the picker is a tap away for everything else.
class _CastGlyph extends StatelessWidget {
  final double size;
  final bool live;

  const _CastGlyph({required this.size, required this.live});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size + 4,
      height: size + 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.cast, size: size, color: KalinkaColors.textSecondary),
          Positioned(
            right: 0,
            bottom: 0,
            child: live
                ? Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: KalinkaColors.statusOnline,
                      shape: BoxShape.circle,
                    ),
                  )
                : const Icon(
                    Icons.close,
                    size: 10,
                    color: KalinkaColors.statusOffline,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Renderer switch for the Now Playing header: the current output by name,
/// with a chevron saying a menu drops from it. Same picker as the playbar
/// button, same self-hiding on a single-output setup.
class RendererSwitcherDropdown extends ConsumerWidget {
  /// Longer names are ellipsised; the header has a centred label to respect.
  final double maxNameWidth;

  const RendererSwitcherDropdown({super.key, this.maxNameWidth = 140});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(
      rendererListProvider.select((s) => s.hasRenderers),
    );
    if (!visible) return const SizedBox.shrink();

    final active = ref.watch(rendererListProvider.select((s) => s.active));
    final ownId = ref.watch(rendererIdentityProvider).value?.rendererId;
    final name = active == null
        ? 'Choose output'
        : _displayName(active, isSelf: active.rendererId == ownId);

    return Semantics(
      label: active == null ? 'Choose output' : 'Output: $name',
      button: true,
      child: Tooltip(
        message: 'Choose output',
        excludeFromSemantics: true,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              KalinkaHaptics.selectionClick();
              _openPicker(context, ref);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cast,
                    size: 18,
                    color: KalinkaColors.textSecondary,
                  ),
                  const SizedBox(width: 7),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxNameWidth),
                    child: Text(
                      name,
                      style: KalinkaTextStyles.trayRowSublabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    size: 18,
                    color: KalinkaColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _openPicker(BuildContext context, WidgetRef ref) async {
  final notifier = ref.read(rendererListProvider.notifier);
  final toast = ref.read(toastProvider.notifier);
  final route = ref.read(rendererSettingsRouteProvider.notifier);
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
      // The panel is hosted by MusicPlayerScreen, under anything still on
      // the navigator — the phone's Now Playing sheet, for one. Fall back
      // to it first so the panel is what the user ends up looking at.
      navigator.popUntil((r) => r.isFirst);
      route.open(choice.rendererId, choice.rendererName);
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

/// Body of the renderer picker sheet. Pops a [RendererPickerChoice].
class RendererPickerContent extends ConsumerWidget {
  const RendererPickerContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rendererListProvider);
    final renderers = state.renderers;
    final ownId = ref.watch(rendererIdentityProvider).value?.rendererId;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PickerHeader(
          loading: state.loading,
          onRefresh: ref.read(rendererListProvider.notifier).refresh,
        ),
        if (renderers.isEmpty)
          _EmptyNote(loading: state.loading)
        else
          // Many-renderer installs are rare, but a scroll cap keeps the sheet
          // from swallowing the screen if one turns up.
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 10),
              itemCount: renderers.length,
              itemBuilder: (ctx, i) => _RendererRow(
                renderer: renderers[i],
                isSelf: renderers[i].rendererId == ownId,
                onIntent: (intent) => Navigator.pop(
                  ctx,
                  RendererPickerChoice(
                    rendererId: renderers[i].rendererId,
                    rendererName: _displayName(
                      renderers[i],
                      isSelf: renderers[i].rendererId == ownId,
                    ),
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

/// Sheet title plus a re-read control. Renderers announce themselves to the
/// server, so there is nothing to scan for from here — refresh is the only
/// honest action.
class _PickerHeader extends StatelessWidget {
  final bool loading;
  final VoidCallback onRefresh;

  const _PickerHeader({required this.loading, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Right inset is what puts this glyph on the same vertical line as the
      // rows' gears (row margin 8 + border 1 + half of a 48 target).
      padding: const EdgeInsets.fromLTRB(20, 14, 13, 6),
      child: Row(
        children: [
          Expanded(
            child: Text('PLAY ON', style: KalinkaTextStyles.sectionHeaderMuted),
          ),
          Semantics(
            label: 'Refresh outputs',
            button: true,
            enabled: !loading,
            child: Tooltip(
              message: 'Refresh',
              excludeFromSemantics: true,
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: loading
                      ? null
                      : () {
                          KalinkaHaptics.selectionClick();
                          onRefresh();
                        },
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(
                      child: loading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: KalinkaColors.textMuted,
                              ),
                            )
                          : const Icon(
                              Icons.refresh,
                              size: 18,
                              color: KalinkaColors.textSecondary,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  final bool loading;

  const _EmptyNote({required this.loading});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loading ? 'Looking for outputs…' : 'No outputs available',
            style: KalinkaTextStyles.trayRowLabel,
          ),
          if (!loading) ...[
            const SizedBox(height: 4),
            Text(
              'An output appears here once it connects to your server.',
              style: KalinkaTextStyles.trayRowSublabel,
            ),
          ],
        ],
      ),
    );
  }
}

/// Friendly name, falling back to the id for a renderer that reported none.
/// The renderer this page itself hosts is simply "This browser" — the
/// UA-derived name it registers under is for everyone else's picker.
String _displayName(RendererInfo renderer, {bool isSelf = false}) {
  if (isSelf && renderer.kind == 'web') return 'This browser';
  return renderer.friendlyName.isEmpty
      ? renderer.rendererId
      : renderer.friendlyName;
}

const _backendLabels = {
  'alsa': 'ALSA',
  'pipewire': 'PipeWire',
  'pulse': 'PulseAudio',
  'pulseaudio': 'PulseAudio',
  'coreaudio': 'Core Audio',
  'wasapi': 'WASAPI',
  'oboe': 'Oboe',
};

/// Supporting line: which machine this output is and how it plays — the
/// question the picker exists to answer, since friendly names alone don't
/// distinguish two boxes. Offline leads, because it's why the row is dead.
String _detailFor(RendererInfo renderer, {bool isSelf = false}) {
  final parts = <String>[];
  if (!renderer.isConnected) parts.add('Offline');
  final host = renderer.hostname;
  // Skipped when the name already carries it — most default to "… on <host>".
  if (host.isNotEmpty &&
      !renderer.friendlyName.toLowerCase().contains(host.toLowerCase())) {
    parts.add(host);
  }
  if (renderer.isConnected) {
    // Skipped for the self row, whose name already reads "This browser".
    if (renderer.kind == 'web' && !isSelf) parts.add('Browser');
    final backend = renderer.audioBackend;
    if (backend.isNotEmpty) {
      parts.add(_backendLabels[backend.toLowerCase()] ?? backend);
    }
  }
  return parts.join(' · ');
}

class _RendererRow extends StatelessWidget {
  final RendererInfo renderer;

  /// The renderer this app itself hosts (web build); its row says so.
  final bool isSelf;
  final ValueChanged<RendererPickerIntent> onIntent;

  const _RendererRow({
    required this.renderer,
    required this.isSelf,
    required this.onIntent,
  });

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
    final name = _displayName(renderer, isSelf: isSelf);
    final detail = _detailFor(renderer, isSelf: isSelf);

    return Semantics(
      // One output plays at a time; say so rather than leaving a screen reader
      // to infer it from a tick.
      inMutuallyExclusiveGroup: true,
      selected: active,
      enabled: connected,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          // Selection lives in the container, not the label colour — it
          // survives a glance and doesn't lean on hue to carry state.
          color: active ? KalinkaColors.accentSubtle : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? KalinkaColors.accentBorder : Colors.transparent,
          ),
        ),
        child: Opacity(
          opacity: connected ? 1.0 : 0.45,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Full-bleed, and under the content: hovering the name lights
                // the whole item rather than the strip left of the rule. The
                // gear is painted over it and takes its own hits first, so its
                // highlight stays a circle.
                Positioned.fill(
                  child: InkWell(
                    onTap: canPlayHere
                        ? () {
                            KalinkaHaptics.selectionClick();
                            onIntent(RendererPickerIntent.play);
                          }
                        : null,
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      // Text swallows pointers (RenderParagraph hit-tests
                      // itself for selection), which would keep the hover off
                      // the InkWell below. Nothing here is a target anyway.
                      child: IgnorePointer(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(11, 10, 8, 10),
                          child: Row(
                            children: [
                              _SelectionMark(selected: active),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: KalinkaTextStyles.trayRowLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (detail.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        detail,
                                        style:
                                            KalinkaTextStyles.trayRowSublabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Two targets in one row: the rule is what says so.
                    Container(
                      width: 1,
                      height: 26,
                      color: KalinkaColors.borderSubtle,
                    ),
                    _GearButton(
                      rendererName: name,
                      onTap: canConfigure
                          ? () {
                              KalinkaHaptics.selectionClick();
                              onIntent(RendererPickerIntent.configure);
                            }
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Leading single-choice mark: an empty ring, filled with a check on the
/// output playback runs on. Shape carries the state, colour only reinforces.
class _SelectionMark extends StatelessWidget {
  final bool selected;

  const _SelectionMark({required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? KalinkaColors.accent : Colors.transparent,
        border: Border.all(
          color: selected ? KalinkaColors.accent : KalinkaColors.borderDefault,
          width: 1.5,
        ),
      ),
      child: selected
          ? const Icon(Icons.check, size: 13, color: KalinkaColors.textPrimary)
          : null,
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
      enabled: onTap != null,
      child: Tooltip(
        message: 'Output settings',
        excludeFromSemantics: true,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                Icons.settings_outlined,
                size: 19,
                color: onTap == null
                    ? KalinkaColors.textMuted
                    : KalinkaColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
